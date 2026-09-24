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
from conventions_tools.run import check, render_json, render_text, requirement_titles, utc_now

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
    findings = [as_map(finding) for finding in as_list(json.loads(stdout))]
    found = {
        (get_str(finding, "path"), get_str(finding, "id"), get_str(finding, "severity"))
        for finding in findings
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
        ("JQ_VERSION", "aqua:jqlang/jq"),
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


def test_launcher_is_committed_executable() -> None:
    # A checkout with core.fileMode=false (a WSL or Windows mount) keeps the
    # working file executable while committing it as 100644, which only a
    # fresh checkout, like CI's, would notice.
    git = shutil.which("git")
    if git is None or not (PRODUCT.parent / ".git").exists():
        pytest.skip("not a git checkout of the repository")
    staged = subprocess.run(
        [git, "-C", str(PRODUCT), "ls-files", "--stage", "bin/conventions"],
        capture_output=True,
        text=True,
        check=True,
    )
    assert staged.stdout.startswith("100755 "), "run: git update-index --chmod=+x bin/conventions"


@pytest.mark.parametrize("name", ["clean", "gha-07-display-name", "gha-15-required-context"])
def test_launcher_prints_what_the_runner_prints(name: str, tmp_path: Path) -> None:
    # Both renderers take the same findings to the same text and JSON, so a
    # consumer and a contributor read one report.
    repo = materialize(fixture_repos_dir(PRODUCT) / name, tmp_path / name)
    report = check(PRODUCT, repo, utc_now())
    text = _launch("check", cwd=repo)
    assert text.stdout == render_text(report, requirement_titles(PRODUCT)), text.stderr
    assert _launch("check", "--output", "json", cwd=repo).stdout == render_json(report)


def test_conftest_formats_pass_through(tmp_path: Path) -> None:
    repo = materialize(fixture_repos_dir(PRODUCT) / "gha-07-display-name", tmp_path / "repo")
    completed = _launch("check", "--output", "github", cwd=repo)
    assert completed.returncode == 0, completed.stderr
    assert "::warning file=" in completed.stdout
