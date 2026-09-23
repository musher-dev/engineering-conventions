from pathlib import Path

import pytest

from conventions_tools.cli import main
from conventions_tools.fixtures import case_dirs, run_case
from conventions_tools.paths import HOME_ENV, product_dir

CASES = case_dirs(product_dir())


def test_fixture_repositories_exist() -> None:
    assert CASES, "tests/fixtures/repos/ must hold at least one case"
    assert "clean" in {case.name for case in CASES}


@pytest.mark.parametrize("case", CASES, ids=lambda case: case.name)
def test_fixture_repository(product: Path, case: Path) -> None:
    result = run_case(product, case)
    assert result.passed, result.report()


def test_cli_fixtures_passes(product: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv(HOME_ENV, str(product))
    assert main(["fixtures"]) == 0
