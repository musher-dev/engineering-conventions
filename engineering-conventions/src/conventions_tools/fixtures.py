"""Running the fixture repositories under tests/fixtures/repos/ and comparing results.

Each case is an overlay on the clean case; see `materialize`.
"""

import json
import re
import shutil
import tempfile
from dataclasses import dataclass, field
from functools import cache
from pathlib import Path

from conventions_tools.loading import as_list, as_map, get_str, read_json
from conventions_tools.paths import fixture_repos_dir, index_file, release_file
from conventions_tools.run import PARSE_ID, Finding, check

FIXTURE_NOW = "2026-09-23T00:00:00Z"

# (path, id, severity, enforced). A finding in a family a staged adoption does
# not enforce is expected with "enforced": false; the key is omitted otherwise.
type Expectation = tuple[str, str, str, bool]

# One finding as the snapshot records it: (path, id, severity, message,
# enforced). Unlike an Expectation it keeps the message, and duplicates count.
type SnapshotEntry = tuple[str, str, str, str, bool]

# Every case's findings, message included, committed beside the cases so a
# change to what a check says shows up as a diff (decision 0005: a message
# change is a fix). `conventions fixtures --update-snapshot` rewrites it.
SNAPSHOT_FILE = "findings.snapshot.json"

# What a message must never carry: sprintf's marker for a missing or
# mistyped argument, or a verb left unformatted.
UNFORMATTED = re.compile(r"%!|%[vsdq]\b")


@dataclass(frozen=True)
class CaseResult:
    """Expected and actual findings of one case, compared as sets.

    Two findings of one requirement on one path (an action and one of its
    inputs both lacking a description, say) count once: expected.json states
    which requirements fire where, not how many messages a check phrases. The
    snapshot keeps every message, duplicates included, so a doubled finding or
    a reworded message still shows.
    """

    name: str
    expected: list[Expectation]
    actual: list[Expectation]
    snapshot: list[SnapshotEntry] = field(default_factory=list[SnapshotEntry])
    recorded: list[SnapshotEntry] | None = None
    problems: list[str] = field(default_factory=list[str])

    @property
    def matches_snapshot(self) -> bool:
        return self.recorded is None or self.recorded == self.snapshot

    @property
    def passed(self) -> bool:
        return self.expected == self.actual and not self.problems and self.matches_snapshot

    def report(self) -> str:
        if self.passed:
            return f"ok   {self.name}"

        def render(items: list[Expectation]) -> str:
            return json.dumps([as_entry(item) for item in items], indent=2)

        lines = [f"FAIL {self.name}"]
        if self.expected != self.actual:
            lines += [f"  expected: {render(self.expected)}", f"  actual:   {render(self.actual)}"]
        lines += [f"  {problem}" for problem in self.problems]
        if not self.matches_snapshot:
            lines += [
                f"  the findings differ from {SNAPSHOT_FILE}; if the change is intended, run "
                "`conventions fixtures --update-snapshot` and commit the diff",
                f"  recorded: {json.dumps(self.recorded)}",
                f"  actual:   {json.dumps(self.snapshot)}",
            ]
        return "\n".join(lines)


def case_dirs(product: Path) -> list[Path]:
    root = fixture_repos_dir(product)
    return sorted(path.parent for path in root.glob("*/expected.json"))


def as_entry(item: Expectation) -> dict[str, object]:
    """One expectation as expected.json writes it."""
    path, id_, severity, enforced = item
    entry: dict[str, object] = {"id": id_, "path": path, "severity": severity}
    if not enforced:
        entry["enforced"] = False
    return entry


def expected_findings(case: Path) -> list[Expectation]:
    return sorted(
        {
            (
                get_str(item, "path"),
                get_str(item, "id"),
                get_str(item, "severity"),
                item.get("enforced") is not False,
            )
            for item in map(as_map, as_list(read_json(case / "expected.json")))
        }
    )


# A case that needs release data (ADOPT-08, say) carries it next to its
# expected.json, in the shape bundle:build writes into a release.
RELEASE_FILE = "release.json"
# A case whose repository has a known actual name (REPO-07, say) gives it as
# {"name": ...}, as bin/conventions would learn it from the origin remote.
REPOSITORY_FILE = "repository.json"

# Every case is an overlay on the clean case, which conforms fully: the case
# directory holds only the files that differ, and removed.txt lists the clean
# files the case lacks, one repository-relative path per line.
BASE_CASE = "clean"
REMOVED_FILE = "removed.txt"
CASE_FILES = frozenset({"expected.json", RELEASE_FILE, REMOVED_FILE, REPOSITORY_FILE})


def _repository_files(directory: Path) -> list[Path]:
    """The files of a case that belong to the repository it describes, not its metadata."""
    return sorted(
        path
        for path in directory.rglob("*")
        if path.is_file() and path.relative_to(directory).as_posix() not in CASE_FILES
    )


def removed_paths(case: Path) -> list[str]:
    removed = case / REMOVED_FILE
    if not removed.is_file():
        return []
    lines = (line.strip() for line in removed.read_text(encoding="utf-8").splitlines())
    return [line for line in lines if line and not line.startswith("#")]


def materialize(case: Path, target: Path) -> Path:
    """Write the repository `case` describes into `target`: clean, overlaid, minus removed."""
    base = case.parent / BASE_CASE
    for layer in (base, case):
        for source in _repository_files(layer):
            destination = target / source.relative_to(layer)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
    for relative in removed_paths(case):
        path = target / relative
        if not path.is_file():
            raise FileNotFoundError(
                f"{case.name}/{REMOVED_FILE} removes {relative}, which {BASE_CASE}/ does not have"
            )
        path.unlink()
    return target


def repository_of(case: Path) -> str | None:
    """The actual repository name a case gives in repository.json, if any."""
    path = case / REPOSITORY_FILE
    return get_str(as_map(read_json(path)), "name") or None if path.is_file() else None


def snapshot_file(product: Path) -> Path:
    return product / "tests" / "fixtures" / SNAPSHOT_FILE


def read_snapshot(product: Path) -> dict[str, list[SnapshotEntry]]:
    """The committed snapshot, or an empty one before the first --update-snapshot."""
    path = snapshot_file(product)
    if not path.is_file():
        return {}
    recorded: dict[str, list[SnapshotEntry]] = {}
    for name, entries in as_map(read_json(path)).items():
        recorded[name] = [
            (str(row[0]), str(row[1]), str(row[2]), str(row[3]), row[4] is not False)
            for row in (as_list(entry) for entry in as_list(entries))
        ]
    return recorded


def write_snapshot(product: Path, results: list[CaseResult]) -> Path:
    """Write every case's findings, one finding per line so a change reads as a small diff."""
    blocks: list[str] = []
    for result in sorted(results, key=lambda item: item.name):
        rows = ",\n".join(
            f"    {json.dumps(list(entry), ensure_ascii=False)}" for entry in result.snapshot
        )
        body = f"[\n{rows}\n  ]" if rows else "[]"
        blocks.append(f"  {json.dumps(result.name)}: {body}")
    path = snapshot_file(product)
    path.write_text("{\n" + ",\n".join(blocks) + "\n}\n", encoding="utf-8")
    return path


@cache
def _index(product: Path) -> dict[str, object]:
    return as_map(as_map(as_map(read_json(index_file(product))).get("conventions")).get("index"))


def _release_ref(product: Path, release: Path | None) -> str:
    """The ref a diagnostic links to: the release's tag, or main (lib/findings.rego)."""
    source = release if release is not None and release.is_file() else release_file(product)
    if not source.is_file():
        return "main"
    version = as_map(as_map(as_map(read_json(source)).get("conventions")).get("release")).get(
        "version"
    )
    return f"v{version}" if isinstance(version, str) else "main"


def finding_problems(product: Path, findings: list[Finding], ref: str) -> list[str]:
    """What is wrong with the findings themselves, beyond which requirements fired.

    Every finding links to its requirement's heading at the release it came
    from, and says in one line what is wrong, fully formatted.
    """
    index = _index(product)
    requirements = as_map(index.get("requirements"))
    problems: list[str] = []
    for finding in findings:
        where = f"{finding.id} on {finding.path}"
        if not finding.message.strip():
            problems.append(f"{where}: the message is empty")
        if "\n" in finding.message:
            problems.append(f"{where}: the message spans more than one line")
        if UNFORMATTED.search(finding.message):
            problems.append(f"{where}: the message has an unformatted value: {finding.message}")
        if finding.id == PARSE_ID:
            continue
        requirement = as_map(requirements.get(finding.id))
        url = "{}/blob/{}/{}/{}#{}".format(
            get_str(index, "repository"),
            ref,
            get_str(index, "product_dir"),
            get_str(requirement, "path"),
            get_str(requirement, "anchor"),
        )
        if finding.url != url:
            problems.append(f"{where}: links to {finding.url}, not {url}")
    return problems


def run_case(
    product: Path, case: Path, recorded: dict[str, list[SnapshotEntry]] | None = None
) -> CaseResult:
    """Run one case; with `recorded`, also compare its findings with the snapshot's."""
    release = case / RELEASE_FILE
    case_release = release if release.is_file() else None
    with tempfile.TemporaryDirectory() as directory:
        repo = materialize(case, Path(directory) / case.name)
        report = check(product, repo, FIXTURE_NOW, case_release, repository_of(case))
    findings = [*report.findings, *(error.as_finding() for error in report.errors)]
    snapshot = sorted(
        (finding.path, finding.id, finding.severity, finding.message, finding.enforced)
        for finding in findings
    )
    problems = finding_problems(product, findings, _release_ref(product, case_release))
    if recorded is not None and case.name not in recorded:
        problems.append(
            f"{SNAPSHOT_FILE} has no entry for this case; "
            "run `conventions fixtures --update-snapshot`"
        )
    return CaseResult(
        name=case.name,
        expected=expected_findings(case),
        actual=sorted(
            {(finding.path, finding.id, finding.severity, finding.enforced) for finding in findings}
        ),
        snapshot=snapshot,
        recorded=None if recorded is None else recorded.get(case.name),
        problems=problems,
    )
