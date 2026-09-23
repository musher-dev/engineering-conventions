"""Running the fixture repositories under tests/fixtures/repos/ and comparing results.

Each case is an overlay on the clean case; see `materialize`.
"""

import json
import shutil
import tempfile
from dataclasses import dataclass
from pathlib import Path

from conventions_tools.loading import as_list, as_map, get_str, read_json
from conventions_tools.paths import fixture_repos_dir
from conventions_tools.run import check

FIXTURE_NOW = "2026-09-23T00:00:00Z"

type Expectation = tuple[str, str, str]


@dataclass(frozen=True)
class CaseResult:
    """Expected and actual findings of one case, compared as sets.

    Two findings of one requirement on one path (an action and one of its
    inputs both lacking a description, say) count once: expected.json states
    which requirements fire where, not how many messages a check phrases.
    """

    name: str
    expected: list[Expectation]
    actual: list[Expectation]

    @property
    def passed(self) -> bool:
        return self.expected == self.actual

    def report(self) -> str:
        if self.passed:
            return f"ok   {self.name}"

        def render(items: list[Expectation]) -> str:
            return json.dumps(
                [{"id": id_, "path": path, "severity": severity} for path, id_, severity in items],
                indent=2,
            )

        return (
            f"FAIL {self.name}\n"
            f"  expected: {render(self.expected)}\n"
            f"  actual:   {render(self.actual)}"
        )


def case_dirs(product: Path) -> list[Path]:
    root = fixture_repos_dir(product)
    return sorted(path.parent for path in root.glob("*/expected.json"))


def expected_findings(case: Path) -> list[Expectation]:
    return sorted(
        {
            (get_str(item, "path"), get_str(item, "id"), get_str(item, "severity"))
            for item in map(as_map, as_list(read_json(case / "expected.json")))
        }
    )


# A case that needs release data (ADOPT-08, say) carries it next to its
# expected.json, in the shape bundle:build writes into a release.
RELEASE_FILE = "release.json"

# Every case is an overlay on the clean case, which conforms fully: the case
# directory holds only the files that differ, and removed.txt lists the clean
# files the case lacks, one repository-relative path per line.
BASE_CASE = "clean"
REMOVED_FILE = "removed.txt"
CASE_FILES = frozenset({"expected.json", RELEASE_FILE, REMOVED_FILE})


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


def run_case(product: Path, case: Path) -> CaseResult:
    release = case / RELEASE_FILE
    with tempfile.TemporaryDirectory() as directory:
        repo = materialize(case, Path(directory) / case.name)
        report = check(product, repo, FIXTURE_NOW, release if release.is_file() else None)
    findings = [*report.findings, *(error.as_finding() for error in report.errors)]
    return CaseResult(
        name=case.name,
        expected=expected_findings(case),
        actual=sorted({(finding.path, finding.id, finding.severity) for finding in findings}),
    )
