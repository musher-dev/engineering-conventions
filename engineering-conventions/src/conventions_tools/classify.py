"""The lowest change class a pull request's index.json diff implies.

Decision 0005's change classification maps each kind of change to a
Conventional Commit type, and the pull request title's type is what tells
release-please how far to bump. This module diffs the index published at a
baseline commit against the one in the working tree, names each change the
index can show, and ranks it. It is a lower bound: a diagnostic message lives
in Rego and a check's logic in its code, neither of which the index records,
so a pull request can need a stronger type than this finds, never a weaker one.
"""

import json
import re
from collections.abc import Iterable
from dataclasses import dataclass
from enum import IntEnum
from pathlib import Path

from conventions_tools.invariants import NO_BASELINE, baseline_index, unwrap_index
from conventions_tools.loading import ContentError, as_list, as_map, get_str
from conventions_tools.paths import REPOSITORY_URL, index_file

CLASSIFICATION_URL = (
    f"{REPOSITORY_URL}/blob/main/docs/decisions/"
    "0005-status-severity-and-versioning.md#change-classification"
)


class Rank(IntEnum):
    """Change classes in the order of what a consumer's upgrade can break."""

    NONE = 0
    FIX = 1
    FEAT = 2
    BREAKING = 3

    @property
    def label(self) -> str:
        return {0: "none", 1: "fix", 2: "feat", 3: "feat!"}[self.value]


@dataclass(frozen=True)
class Change:
    rank: Rank
    description: str


@dataclass(frozen=True)
class Title:
    type: str
    scope: str | None
    breaking: bool

    @property
    def rank(self) -> Rank:
        if self.breaking:
            return Rank.BREAKING
        if self.type == "feat":
            return Rank.FEAT
        if self.type in {"fix", "perf"}:
            return Rank.FIX
        return Rank.NONE

    @property
    def label(self) -> str:
        scope = f"({self.scope})" if self.scope is not None else ""
        return f"{self.type}{scope}{'!' if self.breaking else ''}"

    @property
    def is_release(self) -> bool:
        """A release-please pull request, which carries no change of its own."""
        return self.type == "chore" and self.scope == "release" and not self.breaking


_TITLE = re.compile(r"(?P<type>[a-z]+)(?:\((?P<scope>[^()]*)\))?(?P<bang>!)?: \S")

# Vocabulary lists that ban an alias: growing one is a new banned alias at
# warning (feat), shrinking one reports less (fix). Every other vocabulary
# entry is a term's tokens or display forms, whose removal or rename breaks.
BANNED_VOCABULARY = frozenset(
    {"banned_identifier_tokens", "banned_repository_tokens", "schedule_tokens"}
)

# Schema keywords that describe rather than constrain: a change to only these
# changes no declaration's validity.
_ANNOTATIONS = frozenset({"$comment", "description", "examples", "title"})


def parse_title(title: str) -> Title:
    match = _TITLE.match(title.strip())
    if match is None:
        raise ContentError(
            [f"the title {title.strip()!r} is not a Conventional Commit (type(scope): subject)"]
        )
    return Title(match["type"], match["scope"], match["bang"] is not None)


def current_index(product: Path) -> dict[str, object]:
    path = index_file(product)
    try:
        return unwrap_index(json.loads(path.read_text(encoding="utf-8")))
    except (OSError, ValueError) as error:
        raise ContentError([f"{path}: cannot read the index: {error}"]) from error


def _strings(value: object) -> set[str]:
    """The keys of a map, or the strings in a list: a vocabulary entry is either."""
    return set(as_map(value)) | {item for item in as_list(value) if isinstance(item, str)}


def _ids(values: Iterable[str]) -> str:
    return ", ".join(sorted(values))


def _requirement_changes(before: dict[str, object], after: dict[str, object]) -> list[Change]:
    changes: list[Change] = []
    for rid in sorted(set(before) | set(after)):
        old, new = as_map(before.get(rid)), as_map(after.get(rid))
        if rid not in after:
            changes.append(Change(Rank.BREAKING, f"requirement {rid} removed from the index"))
            continue
        if rid not in before:
            if get_str(new, "severity") == "error":
                changes.append(Change(Rank.BREAKING, f"new requirement {rid} at error"))
            else:
                changes.append(Change(Rank.FEAT, f"new requirement {rid}"))
            continue
        changes += [
            _requirement_field(rid, key, old.get(key), new.get(key))
            for key in sorted(set(old) | set(new))
            if old.get(key) != new.get(key)
        ]
    return changes


def _requirement_field(rid: str, key: str, old: object, new: object) -> Change:
    if key == "severity" and new == "error":
        return Change(Rank.BREAKING, f"requirement {rid} becomes error (was {old})")
    if key == "status" and old == "proposed" and new == "active":
        return Change(Rank.FEAT, f"requirement {rid} activated")
    if key == "waivable" and old is True and new is False:
        return Change(Rank.FEAT, f"requirement {rid} can no longer be waived")
    if key == "title":
        return Change(Rank.FIX, f"requirement {rid} title changed")
    if key in {"severity", "status"}:
        return Change(Rank.FIX, f"requirement {rid} {key} changed from {old} to {new}")
    return Change(Rank.FIX, f"requirement {rid} {key} changed")


def _profile_changes(
    before: dict[str, object], after: dict[str, object], published: set[str]
) -> list[Change]:
    """`published` is the requirements the baseline had: selecting a new one is already listed."""
    changes: list[Change] = []
    for pid in sorted(set(before) | set(after)):
        if pid not in after:
            changes.append(Change(Rank.BREAKING, f"profile {pid} removed"))
            continue
        if pid not in before:
            changes.append(Change(Rank.FEAT, f"new profile {pid}"))
            continue
        old, new = as_map(before[pid]), as_map(after[pid])
        selected_old = _strings(old.get("requirements"))
        selected_new = _strings(new.get("requirements"))
        if added := (selected_new - selected_old) & published:
            changes.append(Change(Rank.FEAT, f"profile {pid} now selects {_ids(added)}"))
        if dropped := selected_old - selected_new:
            changes.append(Change(Rank.FIX, f"profile {pid} no longer selects {_ids(dropped)}"))
        severity_old, severity_new = as_map(old.get("severity")), as_map(new.get("severity"))
        shared = set(severity_old) & set(severity_new)
        raised = {r for r in shared if severity_old[r] != "error" and severity_new[r] == "error"}
        if raised:
            changes.append(Change(Rank.BREAKING, f"profile {pid} makes {_ids(raised)} error"))
        if lowered := {r for r in shared if severity_old[r] != severity_new[r]} - raised:
            changes.append(Change(Rank.FIX, f"profile {pid} changes severity of {_ids(lowered)}"))
        changes += [
            Change(Rank.FIX, f"profile {pid} {key} changed")
            for key in sorted((set(old) | set(new)) - {"requirements", "severity"})
            if old.get(key) != new.get(key)
        ]
    return changes


def _vocabulary_changes(before: dict[str, object], after: dict[str, object]) -> list[Change]:
    changes: list[Change] = []
    for name in sorted(set(before) | set(after)):
        old, new = before.get(name), after.get(name)
        if old == new:
            continue
        added = _strings(new) - _strings(old)
        removed = _strings(old) - _strings(new)
        renamed = sorted(
            key
            for key in _strings(old) & _strings(new)
            if as_map(old).get(key) != as_map(new).get(key)
        )
        if name in BANNED_VOCABULARY:
            if added:
                changes.append(Change(Rank.FEAT, f"{name}: newly banned {_ids(added)}"))
            if removed:
                changes.append(Change(Rank.FIX, f"{name}: no longer banned {_ids(removed)}"))
            if renamed:
                changes.append(Change(Rank.FIX, f"{name}: advice changed for {_ids(renamed)}"))
            continue
        if removed:
            changes.append(Change(Rank.BREAKING, f"{name}: removed {_ids(removed)}"))
        if renamed:
            changes.append(Change(Rank.BREAKING, f"{name}: changed {_ids(renamed)}"))
        if added:
            changes.append(Change(Rank.FEAT, f"{name}: added {_ids(added)}"))
    return changes


def _without_annotations(schema: object) -> object:
    if mapping := as_map(schema):
        return {
            key: _without_annotations(value)
            for key, value in mapping.items()
            if key not in _ANNOTATIONS
        }
    if items := as_list(schema):
        return [_without_annotations(item) for item in items]
    return schema


def _schema_change(name: str, old: object, new: object) -> list[Change]:
    if _without_annotations(old) == _without_annotations(new):
        return []
    # Tightening is feat! and relaxing feat; the index cannot tell which.
    return [
        Change(Rank.FEAT, f"{name} changed what it accepts (feat if relaxed, feat! if tighter)")
    ]


def _convention_changes(before: dict[str, object], after: dict[str, object]) -> list[Change]:
    changes: list[Change] = []
    for cid in sorted(set(before) | set(after)):
        if cid not in after:
            changes.append(Change(Rank.BREAKING, f"convention {cid} removed from the index"))
        elif cid not in before:
            changes.append(Change(Rank.FIX, f"new convention {cid}"))
        elif before[cid] != after[cid]:
            old, new = as_map(before[cid]), as_map(after[cid])
            fields = sorted(k for k in set(old) | set(new) if old.get(k) != new.get(k))
            changes.append(Change(Rank.FIX, f"convention {cid} {', '.join(fields)} changed"))
    return changes


def diff(before: dict[str, object], after: dict[str, object]) -> list[Change]:
    """Every change between two indexes that decision 0005 classifies, strongest first."""
    changes: list[Change] = []
    for key in sorted(set(before) | set(after)):
        old, new = before.get(key), after.get(key)
        if old == new:
            continue
        if key == "requirements":
            changes += _requirement_changes(as_map(old), as_map(new))
        elif key == "profiles":
            published = set(as_map(before.get("requirements")))
            changes += _profile_changes(as_map(old), as_map(new), published)
        elif key == "vocabulary":
            changes += _vocabulary_changes(as_map(old), as_map(new))
        elif key == "conventions":
            changes += _convention_changes(as_map(old), as_map(new))
        elif key.endswith("_schema"):
            changes += _schema_change(key, old, new)
        else:
            changes.append(Change(Rank.FIX, f"{key} changed"))
    return sorted(changes, key=lambda change: -change.rank)


def minimum(changes: Iterable[Change]) -> Rank:
    return max((change.rank for change in changes), default=Rank.NONE)


@dataclass(frozen=True)
class Verdict:
    title: Title
    changes: tuple[Change, ...]
    skipped: str | None = None

    @property
    def minimum(self) -> Rank:
        return minimum(self.changes)

    @property
    def passed(self) -> bool:
        return self.skipped is not None or self.title.rank >= self.minimum

    def report(self) -> str:
        if self.skipped is not None:
            return f"classify: {self.skipped}; nothing to classify\n"
        lines = [f"  {change.rank.label:<6} {change.description}" for change in self.changes]
        if self.passed:
            head = (
                f"classify: {self.title.label} meets the change class the index diff implies "
                f"({self.minimum.label})"
            )
            return "\n".join([head, *lines]) + "\n"
        driving = [
            f"  {change.rank.label:<6} {change.description}"
            for change in self.changes
            if change.rank > self.title.rank
        ]
        return (
            "\n".join(
                [
                    f"classify: the title's type {self.title.label} is below the change class "
                    f"the index diff implies, {self.minimum.label}, because of:",
                    *driving,
                    f"Retitle the pull request with {self.minimum.label} or stronger; the "
                    f"classification is {CLASSIFICATION_URL}",
                ]
            )
            + "\n"
        )


def classify(product: Path, baseline_ref: str, title: str) -> Verdict:
    parsed = parse_title(title)
    if parsed.is_release:
        return Verdict(parsed, (), skipped="a release pull request")
    if NO_BASELINE.fullmatch(baseline_ref.strip()):
        return Verdict(parsed, (), skipped=f"no baseline ({baseline_ref.strip() or 'empty'})")
    baseline = baseline_index(product, baseline_ref)
    if baseline is None:
        return Verdict(parsed, (), skipped=f"{baseline_ref} predates index.json")
    return Verdict(parsed, tuple(diff(baseline, current_index(product))))
