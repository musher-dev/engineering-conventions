"""Running the fixture repositories under tests/fixtures/repos/ and comparing results."""

import json
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


def run_case(product: Path, case: Path) -> CaseResult:
    release = case / RELEASE_FILE
    report = check(product, case, FIXTURE_NOW, release if release.is_file() else None)
    findings = [*report.findings, *(error.as_finding() for error in report.errors)]
    return CaseResult(
        name=case.name,
        expected=expected_findings(case),
        actual=sorted({(finding.path, finding.id, finding.severity) for finding in findings}),
    )
