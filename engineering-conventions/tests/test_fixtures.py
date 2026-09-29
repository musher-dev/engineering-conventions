from pathlib import Path

import pytest

from conventions_tools.fixtures import (
    FIXTURE_NOW,
    REMOVED_FILE,
    SNAPSHOT_FILE,
    SnapshotEntry,
    case_dirs,
    finding_problems,
    materialize,
    read_snapshot,
    run_case,
)
from conventions_tools.paths import product_dir
from conventions_tools.run import PARSE_ID, Finding, check, fails

CASES = case_dirs(product_dir())


def test_fixture_repositories_exist() -> None:
    assert CASES, "tests/fixtures/repos/ must hold at least one case"
    assert "clean" in {case.name for case in CASES}


@pytest.fixture(scope="session")
def recorded(product: Path) -> dict[str, list[SnapshotEntry]]:
    return read_snapshot(product)


@pytest.mark.parametrize("case", CASES, ids=lambda case: case.name)
def test_fixture_repository(
    product: Path, case: Path, recorded: dict[str, list[SnapshotEntry]]
) -> None:
    result = run_case(product, case, recorded)
    assert result.passed, result.report()


def test_the_snapshot_names_only_cases_that_exist(
    recorded: dict[str, list[SnapshotEntry]],
) -> None:
    stale = sorted(set(recorded) - {case.name for case in CASES})
    assert not stale, f"{SNAPSHOT_FILE} records deleted cases {stale}; run --update-snapshot"


def test_a_reworded_message_fails_against_the_snapshot(product: Path) -> None:
    case = product / "tests" / "fixtures" / "repos" / "gha-07-display-name"
    result = run_case(product, case, {})
    ((path, rid, severity, _, enforced),) = result.snapshot
    reworded = {case.name: [(path, rid, severity, "something else", enforced)]}
    changed = run_case(product, case, reworded)
    assert not changed.passed
    assert "--update-snapshot" in changed.report()


def test_a_finding_that_links_elsewhere_is_a_problem(product: Path) -> None:
    finding = Finding("GHA-07", "a.yml", "wrong", "warning", "https://example.com/x", "EC-0002")
    (problem,) = finding_problems(product, [finding], "main")
    assert "workflow-files.md#gha-07" in problem


@pytest.mark.parametrize("message", ["", "two\nlines", "name %!v(MISSING)", "left %s here"])
def test_a_malformed_message_is_a_problem(product: Path, message: str) -> None:
    # PARSE carries no URL, so only the message is judged.
    finding = Finding(PARSE_ID, "a.yml", message, "error", "", "")
    assert finding_problems(product, [finding], "main")


def _case(tmp_path: Path, name: str, files: dict[str, str]) -> Path:
    for relative, text in files.items():
        path = tmp_path / name / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    return tmp_path / name


def test_a_case_overlays_clean_and_removes_what_it_lists(tmp_path: Path) -> None:
    _case(tmp_path, "clean", {"a.yml": "base\n", "b.yml": "base\n", "expected.json": "[]\n"})
    case = _case(
        tmp_path,
        "gha-99-example",
        {"a.yml": "changed\n", "c.yml": "added\n", REMOVED_FILE: "b.yml\n", "expected.json": "[]"},
    )
    repo = materialize(case, tmp_path / "out")
    files = {p.relative_to(repo).as_posix(): p.read_text() for p in repo.rglob("*")}
    assert files == {"a.yml": "changed\n", "c.yml": "added\n"}


def test_removing_a_file_clean_does_not_have_fails(tmp_path: Path) -> None:
    _case(tmp_path, "clean", {"a.yml": "base\n"})
    case = _case(tmp_path, "gha-99-example", {REMOVED_FILE: "typo.yml\n"})
    with pytest.raises(FileNotFoundError, match=r"typo\.yml"):
        materialize(case, tmp_path / "out")


def test_the_example_consumer_meets_every_check(product: Path) -> None:
    report = check(product, product / "examples" / "consumer", FIXTURE_NOW)
    assert [*report.findings, *report.errors] == []


# The example passes the output and release checks only by holding the files
# they read; without them those checks have nothing to report, and the example
# would stop showing adopters how to declare and release an output.
EXAMPLE_RELEASE_FILES = (
    ".repo/outputs.toml",
    ".github/release-please/config.json",
    ".github/release-please/manifest.json",
    ".github/rulesets/release-tags.json",
    ".github/workflows/release.yml",
)


@pytest.mark.parametrize("relative", EXAMPLE_RELEASE_FILES)
def test_the_example_consumer_declares_and_releases_an_output(product: Path, relative: str) -> None:
    assert (product / "examples" / "consumer" / relative).is_file()


def test_the_staged_example_reports_what_it_does_not_enforce(product: Path) -> None:
    # A staged adoption: the waiver is used (no ADOPT-06), and the one finding
    # left is in a family the build does not enforce yet, so it cannot fail.
    report = check(product, product / "examples" / "staged-consumer", FIXTURE_NOW)
    assert report.errors == []
    assert [(f.id, f.path, f.enforced) for f in report.findings] == [
        ("TASK-05", "Taskfile.yml", False)
    ]
    assert not fails(report.findings, "warning")
