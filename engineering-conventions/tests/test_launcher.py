"""bin/conventions, the consumer's launcher, agrees with the runner the fixtures use."""

import json
import re
import shutil
import subprocess
import tomllib
from pathlib import Path

import pytest

from conventions_tools.fixtures import expected_findings, materialize
from conventions_tools.loading import as_list, as_map, get_str
from conventions_tools.paths import fixture_repos_dir, product_dir

PRODUCT = product_dir()
LAUNCHER = PRODUCT / "bin" / "conventions"

# Cases whose findings depend on neither the date (waiver expiry) nor release
# data, which the launcher takes from the bundle rather than from the case.
CASES = [
    "clean",
    "mise-pin-without-declaration",
    "adopt-02-invalid-declaration",
    "adopt-09-unpinned",
    "gha-07-display-name",
    "gha-15-required-context",
]


def _launch(*arguments: str, cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(LAUNCHER), *arguments], cwd=cwd, capture_output=True, text=True, check=False
    )


def _found(stdout: str) -> list[tuple[str, str, str]]:
    results = [
        as_map(result)
        for entry in map(as_map, as_list(json.loads(stdout)))
        for bucket in ("failures", "warnings")
        for result in as_list(entry.get(bucket))
    ]
    found = {
        (get_str(meta, "path"), get_str(meta, "id"), get_str(meta, "severity"))
        for meta in (as_map(result.get("metadata")) for result in results)
    }
    return sorted(found)


@pytest.mark.parametrize("name", CASES)
def test_launcher_matches_the_fixture(name: str, tmp_path: Path) -> None:
    case = fixture_repos_dir(PRODUCT) / name
    repo = materialize(case, tmp_path / name)
    completed = _launch("check", "--output", "json", cwd=repo)
    assert completed.returncode == 0, completed.stderr
    assert _found(completed.stdout) == expected_findings(case)


def test_fail_on_warning_fails_on_a_warning(tmp_path: Path) -> None:
    repo = materialize(fixture_repos_dir(PRODUCT) / "adopt-09-unpinned", tmp_path / "repo")
    assert _launch("check", cwd=repo).returncode == 0
    assert _launch("check", "--fail-on", "warning", cwd=repo).returncode == 1


def test_a_git_work_tree_is_listed_by_git(tmp_path: Path) -> None:
    repo = materialize(fixture_repos_dir(PRODUCT) / "clean", tmp_path / "repo")
    git = shutil.which("git")
    assert git
    subprocess.run([git, "init", "-q", str(repo)], check=True)
    # An ignored workflow is not the repository's, so it is not checked.
    (repo / ".gitignore").write_text(".github/workflows/ci.yml\n")
    (repo / ".github" / "workflows" / "ci.yml").write_text("name: CI\n")
    completed = _launch("check", "--output", "json", cwd=repo / ".github")
    assert completed.returncode == 0, completed.stderr
    assert _found(completed.stdout) == []


def test_unknown_arguments_print_usage(tmp_path: Path) -> None:
    completed = _launch("check", "--nope", cwd=tmp_path)
    assert completed.returncode == 2
    assert "conventions check [--fail-on error|warning]" in completed.stderr


def test_tool_versions_move_with_the_repository_pins() -> None:
    pins = PRODUCT.parent / ".devcontainer" / "mise.toml"
    if not pins.is_file():
        pytest.skip("not a checkout of the repository")
    tools = as_map(tomllib.loads(pins.read_text(encoding="utf-8")).get("tools"))
    text = LAUNCHER.read_text(encoding="utf-8")
    for variable, key in (
        ("CONFTEST_VERSION", "aqua:open-policy-agent/conftest"),
        ("VALE_VERSION", "aqua:vale-cli/vale"),
    ):
        declared = re.search(rf"^{variable}=(\S+)$", text, re.MULTILINE)
        assert declared, f"{variable} is not set in bin/conventions"
        assert declared.group(1) == tools[key], f"{variable} and {key} must match"


def test_dash_c_checks_that_directory_not_its_work_tree() -> None:
    # A fixture sits inside this repository's work tree; -C must not climb out.
    case = fixture_repos_dir(PRODUCT) / "gha-07-display-name"
    completed = _launch("check", "--output", "json", "-C", str(case), cwd=PRODUCT)
    assert completed.returncode == 0, completed.stderr
    found = {finding_id for _, finding_id, _ in _found(completed.stdout)}
    assert found == {"GHA-07", "ADOPT-09"}
