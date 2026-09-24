from pathlib import Path

import pytest

from conventions_tools.fixtures import (
    FIXTURE_NOW,
    REMOVED_FILE,
    case_dirs,
    materialize,
    run_case,
)
from conventions_tools.paths import product_dir
from conventions_tools.run import check

CASES = case_dirs(product_dir())


def test_fixture_repositories_exist() -> None:
    assert CASES, "tests/fixtures/repos/ must hold at least one case"
    assert "clean" in {case.name for case in CASES}


@pytest.mark.parametrize("case", CASES, ids=lambda case: case.name)
def test_fixture_repository(product: Path, case: Path) -> None:
    result = run_case(product, case)
    assert result.passed, result.report()


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
