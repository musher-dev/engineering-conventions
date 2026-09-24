"""Meta-checks over the content, the Rego checks and the fixtures.

Each check returns problems as strings; an empty list means the invariant
holds. `check_all` runs every one and never stops at the first failure.
"""

import re
import shutil
import subprocess
import sys
from collections import Counter
from collections.abc import Callable, Iterable
from pathlib import Path

from conventions_tools.content import (
    Content,
    Convention,
    Terminology,
    load_content,
    requirement_sort_key,
)
from conventions_tools.fixtures import case_dirs, expected_findings
from conventions_tools.loading import (
    ContentError,
    as_map,
    get_str,
    parse_yaml,
)
from conventions_tools.paths import PRODUCT_DIR_NAME, index_file, rego_dir
from conventions_tools.profiles import ProfileError, resolve_all

REQUIREMENT_ID = r"[A-Z][A-Z0-9]{1,7}-[0-9]{2,3}"
_QUOTED_ID = re.compile(rf'"({REQUIREMENT_ID})"')
_PACKAGE = re.compile(r"^package\s+([A-Za-z0-9_.]+)", re.MULTILINE)
_HEADING = re.compile(rf"^###\s+({REQUIREMENT_ID})\s*$", re.MULTILINE)
_WORD = re.compile(r"[a-z0-9]+")

type Check = Callable[[Content], list[str]]


def _duplicates(values: Iterable[str]) -> list[str]:
    return sorted(value for value, count in Counter(values).items() if count > 1)


def ids_unique(content: Content) -> list[str]:
    conventions = _duplicates(convention.id for convention in content.conventions)
    requirements = _duplicates(req.id for req in content.requirements)
    return [
        *(f"convention ID {cid} is used by more than one document" for cid in conventions),
        *(f"requirement ID {rid} is declared more than once" for rid in requirements),
    ]


def families_registered(content: Content) -> list[str]:
    families = {family.prefix: family for family in content.families}
    found = [
        f"families.yml lists {prefix} more than once"
        for prefix in _duplicates(family.prefix for family in content.families)
    ]
    for convention in content.conventions:
        directory = Path(convention.path).parent.name
        if directory != convention.topic:
            found.append(
                f"{convention.path}: topic is {convention.topic!r} but the file is in {directory}/"
            )
        for req in convention.requirements:
            family = families.get(req.family)
            if family is None:
                found.append(f"{convention.path}: {req.id} uses unregistered family {req.family}")
            elif family.topic != convention.topic:
                found.append(
                    f"{convention.path}: {req.id} belongs to family {req.family}, whose topic is "
                    f"{family.topic!r}, not {convention.topic!r}"
                )
    return found


def references_resolve(content: Content) -> list[str]:
    requirements = {req.id for req in content.requirements}
    conventions = {convention.id for convention in content.conventions}
    found = [
        f"{req.path}: {req.id} is replaced_by unknown requirement {target}"
        for req in content.requirements
        for target in req.replaced_by
        if target not in requirements
    ]
    found += [
        f"{convention.path}: {req.id} names schema {req.schema}, which does not exist"
        for convention in content.conventions
        for req in convention.requirements
        if req.schema is not None and not (content.product / req.schema).is_file()
    ]
    found += [
        f"{convention.path}: {key} names unknown convention {target}"
        for convention in content.conventions
        for key, targets in (
            ("supersedes", convention.supersedes),
            ("superseded_by", convention.superseded_by),
        )
        for target in targets
        if target not in conventions
    ]
    return found


def _words(text: str) -> list[str]:
    # The bold line may format the title (code spans, a closing period), so
    # the comparison is over words, not characters.
    return _WORD.findall(text.lower())


def _heading_problems(convention: Convention) -> list[str]:
    headings = Counter(_HEADING.findall(convention.body))
    declared = {req.id for req in convention.requirements}
    found = [
        f"{convention.path}: heading ### {rid} appears {headings[rid]} times; it must appear once"
        if headings[rid]
        else f"{convention.path}: {rid} has no '### {rid}' heading in the body"
        for rid in sorted(declared, key=requirement_sort_key)
        if headings[rid] != 1
    ]
    found += [
        f"{convention.path}: heading ### {rid} is not a requirement declared in the frontmatter"
        for rid in sorted(set(headings) - declared, key=requirement_sort_key)
    ]
    lines = convention.body.splitlines()
    for req in convention.requirements:
        if headings[req.id] != 1:
            continue
        start = next(i for i, line in enumerate(lines) if line.strip() == f"### {req.id}")
        following = next((line.strip() for line in lines[start + 1 :] if line.strip()), "")
        bold = following.startswith("**") and following.endswith("**") and len(following) > 4
        if not bold or _words(following) != _words(req.title):
            found.append(
                f"{convention.path}: the first line under ### {req.id} must be its title in bold, "
                f"**{req.title}**; found {following!r}"
            )
    return found


def headings_present(content: Content) -> list[str]:
    return [
        problem for convention in content.conventions for problem in _heading_problems(convention)
    ]


def _rego_sources(product: Path) -> list[Path]:
    return sorted(
        path for path in rego_dir(product).rglob("*.rego") if not path.name.endswith("_test.rego")
    )


def rego_ids(content: Content) -> list[str]:
    """Every conftest requirement is emitted by its package; every emitted ID is declared."""
    directory = rego_dir(content.product)
    if not directory.is_dir():
        return [f"{directory.relative_to(content.product)} does not exist"]
    ids_by_package: dict[str, set[str]] = {}
    mentioned: dict[str, Path] = {}
    for path in _rego_sources(content.product):
        text = path.read_text(encoding="utf-8")
        package = _PACKAGE.search(text)
        ids = set(_QUOTED_ID.findall(text))
        if package:
            ids_by_package.setdefault(package.group(1), set()).update(ids)
        for rid in ids:
            mentioned.setdefault(rid, path)
    requirements = {req.id: req for req in content.requirements}
    found: list[str] = []
    for req in content.requirements:
        if req.engine != "conftest" or req.status == "retired" or req.package is None:
            continue
        if req.package not in ids_by_package:
            found.append(f"{req.id}: package {req.package} does not exist under checks/rego")
        elif req.id not in ids_by_package[req.package]:
            found.append(f"{req.id}: package {req.package} never emits {req.id}")
    for rid, path in sorted(mentioned.items(), key=lambda item: requirement_sort_key(item[0])):
        relative = path.relative_to(content.product)
        if rid not in requirements:
            found.append(f"{relative}: emits {rid}, which no convention declares")
        elif requirements[rid].status == "retired":
            found.append(f"{relative}: emits {rid}, which is retired")
    return found


def waivers_see_every_family(content: Content) -> list[str]:
    """ADOPT-06 reads each family's findings by name: Rego forbids it reading its own tree.

    A family whose check directory it does not name would have every waiver on
    it reported as stale, so a new family must be added there with its checks.
    """
    rego = rego_dir(content.product)
    declaration = rego / "adoption" / "declaration.rego"
    if not declaration.is_file():
        return []
    text = declaration.read_text(encoding="utf-8")
    return [
        f"{declaration.relative_to(content.product)} does not read "
        f"data.conventions.checks.{family.name}, so ADOPT-06 cannot see the findings "
        f"its waivers cover; add it to raw_findings"
        for family in sorted(rego.iterdir())
        if family.is_dir()
        and family.name not in {"adoption", "lib"}
        and f"data.conventions.checks.{family.name}[" not in text
    ]


def fixtures_cover(content: Content) -> list[str]:
    """Every conftest requirement has a fixture repository that expects it (anti-vacuity)."""
    cases = case_dirs(content.product)
    expected: dict[str, set[str]] = {}
    for case in cases:
        for _, rid, _ in expected_findings(case):
            expected.setdefault(rid, set()).add(case.name)
    requirements = {req.id: req for req in content.requirements}
    found = [
        f"{req.id}: no fixture repository expects it; "
        f"add tests/fixtures/repos/{req.id.lower()}-<slug>/"
        for req in content.requirements
        if req.engine == "conftest" and req.status != "retired" and req.id not in expected
    ]
    found += [
        f"fixture {', '.join(sorted(names))} expects {rid}, which no convention declares"
        for rid, names in sorted(expected.items())
        if rid not in requirements
    ]
    clean = [case for case in cases if case.name == "clean"]
    if not clean:
        found.append("tests/fixtures/repos/clean/ is missing: a fully conforming case expecting []")
    elif expected_findings(clean[0]):
        found.append("tests/fixtures/repos/clean/expected.json must be []")
    return found


def _alias_owners(terminology: Terminology) -> dict[tuple[str, str], set[str]]:
    owners: dict[tuple[str, str], set[str]] = {}
    for term in terminology.terms:
        for alias in term.aliases:
            for scope in alias.scope:
                owners.setdefault((alias.text, scope), set()).add(term.id)
    return owners


def terminology_consistent(content: Content) -> list[str]:
    glob = content.terminology
    found = [
        f"{glob.path}: term {tid} is defined more than once"
        for tid in _duplicates(t.id for t in glob.terms)
    ]
    found += [
        f"{glob.path}: display form {tok} is listed more than once"
        for tok in _duplicates(t for t, _ in glob.display_forms)
    ]
    for tag in ("gha.responsibility", "gha.capability", "gha.action"):
        tokens = [term.token for term in glob.terms if tag in term.tags and term.token]
        found += [
            f"{glob.path}: token {tok!r} is used by more than one {tag} term"
            for tok in _duplicates(tokens)
        ]
    found += [
        f"alias {text!r} ({scope}) belongs to more than one term: {', '.join(sorted(owners))}"
        for (text, scope), owners in sorted(_alias_owners(glob).items())
        if len(owners) > 1
    ]
    return found


def profiles_resolve(content: Content) -> list[str]:
    found = [
        f"{profile.path}: id {profile.id!r} does not match the filename"
        for profile in content.profiles
        if Path(profile.path).stem != profile.id
    ]
    if "base-repo" not in {profile.id for profile in content.profiles}:
        found.append("definitions/profiles/base-repo.yml is missing; it is the default profile")
    families = {family.prefix for family in content.families}
    try:
        resolve_all(content.profiles, content.requirements, families)
    except ProfileError as error:
        found.append(str(error))
    return found


# CI passes the push event's `before` SHA, which is all zeros on a branch's
# first push, and an unset variable expands to nothing: neither names a
# baseline, so there is nothing to be append-only against.
NO_BASELINE = re.compile(r"0*")


def _git(product: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
    git = shutil.which("git")
    if git is None:
        raise ContentError(["git is not on PATH, so the append-only check cannot run"])
    return subprocess.run(
        [git, "-C", str(product), *arguments], capture_output=True, text=True, check=False
    )


def baseline_index(product: Path, ref: str) -> dict[str, object] | None:
    """The index published at `ref`, or None when `ref` predates it.

    Raises ContentError when `ref` does not resolve: a mistyped or unfetched
    baseline must fail rather than pass by checking nothing.
    """
    if _git(product, "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}").returncode != 0:
        raise ContentError(
            [
                f"--baseline {ref!r} does not resolve to a commit; fetch it "
                "(e.g. git fetch origin main) or pass a ref that exists"
            ]
        )
    relative = index_file(product).relative_to(product).as_posix()
    shown = _git(product, "show", f"{ref}:{PRODUCT_DIR_NAME}/{relative}")
    if shown.returncode != 0:
        return None
    try:
        return as_map(as_map(as_map(parse_yaml(shown.stdout, ref)).get("conventions")).get("index"))
    except ContentError:
        return None


def append_only(content: Content, ref: str) -> list[str]:
    if NO_BASELINE.fullmatch(ref.strip()):
        print(
            f"invariants: no baseline ({ref.strip() or 'empty'}), as on a branch's first push; "
            "skipping the append-only check",
            file=sys.stderr,
        )
        return []
    try:
        baseline = baseline_index(content.product, ref)
    except ContentError as error:
        return error.problems
    return [] if baseline is None else compare_to_baseline(content, baseline, ref)


def compare_to_baseline(content: Content, baseline: dict[str, object], ref: str) -> list[str]:
    """IDs published at `ref` still exist, keep their convention, and stay retired once retired."""
    requirements = {req.id: req for req in content.requirements}
    conventions = {convention.id for convention in content.conventions}
    found = [
        f"convention {cid} existed at {ref} and has been removed; set its status to retired instead"
        for cid in sorted(as_map(baseline.get("conventions")))
        if cid not in conventions
    ]
    for rid, value in sorted(as_map(baseline.get("requirements")).items()):
        before = as_map(value)
        current = requirements.get(rid)
        if current is None:
            found.append(
                f"requirement {rid} existed at {ref} and has been removed; retire it instead"
            )
            continue
        if current.convention != get_str(before, "convention"):
            found.append(
                f"requirement {rid} moved from {get_str(before, 'convention')} to "
                f"{current.convention}; an ID never changes convention"
            )
        if get_str(before, "status") == "retired" and current.status != "retired":
            found.append(f"requirement {rid} was retired at {ref}; a retired ID is never reused")
    return found


CHECKS: tuple[Check, ...] = (
    ids_unique,
    families_registered,
    references_resolve,
    headings_present,
    rego_ids,
    waivers_see_every_family,
    fixtures_cover,
    terminology_consistent,
    profiles_resolve,
)


def check_all(product: Path, baseline_ref: str = "HEAD") -> list[str]:
    try:
        content = load_content(product)
    except ContentError as error:
        return error.problems
    found = [problem for check in CHECKS for problem in check(content)]
    return found + append_only(content, baseline_ref)
