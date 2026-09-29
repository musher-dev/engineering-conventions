"""bin/conventions, the consumer's launcher, agrees with the runner the fixtures use."""

import json
import os
import re
import shutil
import subprocess
import tomllib
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from conventions_tools.cli import main
from conventions_tools.fixtures import expected_findings, materialize
from conventions_tools.loading import as_list, as_map, get_str
from conventions_tools.paths import HOME_ENV, fixture_repos_dir, product_dir
from conventions_tools.run import (
    check,
    fails,
    render_json,
    render_text,
    repository_name,
    requirement_titles,
    utc_now,
)

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


# Where the launcher learns a repository's actual name; cleared so a run in
# GitHub Actions tests the same thing as a run anywhere else.
NAME_SOURCES = ("CONVENTIONS_REPOSITORY", "GITHUB_REPOSITORY", "GITHUB_WORKSPACE")


def _launch(
    *arguments: str, cwd: Path, env: dict[str, str] | None = None
) -> subprocess.CompletedProcess[str]:
    environment = {key: value for key, value in os.environ.items() if key not in NAME_SOURCES}
    return subprocess.run(
        [str(LAUNCHER), *arguments],
        cwd=cwd,
        capture_output=True,
        text=True,
        check=False,
        env=environment | (env or {}),
    )


def _found(stdout: str) -> list[tuple[str, str, str, bool]]:
    findings = [as_map(finding) for finding in as_list(json.loads(stdout))]
    found = {
        (
            get_str(finding, "path"),
            get_str(finding, "id"),
            get_str(finding, "severity"),
            finding.get("enforced") is not False,
        )
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
    pins = PRODUCT.parent / ".config" / "mise" / "config.toml"
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
    found = {finding_id for _, finding_id, _, _ in _found(completed.stdout)}
    # The case holds no .repo/ declarations and no Taskfile, so they are
    # reported missing: this repository's own were not read.
    assert found == {"GHA-07", "ADOPT-09", "REPO-01", "TASK-10"}


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


def _ids(stdout: str) -> set[str]:
    return {finding_id for _, finding_id, _, _ in _found(stdout)}


def test_a_file_parsed_first_is_reported_alike(tmp_path: Path) -> None:
    # devcontainer.json and Dockerfiles are parsed before the check (decision
    # 0015); one that does not parse is a PARSE error from either runner.
    repo = materialize(fixture_repos_dir(PRODUCT) / "clean", tmp_path / "repo")
    (repo / ".devcontainer").mkdir()
    (repo / ".devcontainer" / "devcontainer.json").write_text('// fine\n{"name": "x",}\n')
    (repo / "Dockerfile").write_text("FROM scratch\n")
    (repo / "docker").mkdir()
    (repo / "docker" / "build.Dockerfile").write_text("")
    # BuildKit's per-Dockerfile ignore file is not a Dockerfile, so it is not parsed.
    (repo / "docker" / "build.Dockerfile.dockerignore").write_text("**/node_modules\n")
    completed = _launch("check", "--output", "json", cwd=repo)
    assert completed.returncode == 1, completed.stderr
    assert _found(completed.stdout) == [("docker/build.Dockerfile", "PARSE", "error", True)]
    assert completed.stdout == render_json(check(PRODUCT, repo, utc_now()))
    text = _launch("check", cwd=repo).stdout
    assert text == render_text(check(PRODUCT, repo, utc_now()), requirement_titles(PRODUCT))


def test_repository_flag_matches_the_runner(tmp_path: Path) -> None:
    repo = materialize(fixture_repos_dir(PRODUCT) / "clean", tmp_path / "repo")
    completed = _launch("check", "--output", "json", "--repository", "platform-web", cwd=repo)
    assert completed.returncode == 0, completed.stderr
    assert _ids(completed.stdout) == {"REPO-07"}
    report = check(PRODUCT, repo, utc_now(), repository="platform-web")
    assert completed.stdout == render_json(report)
    env = {"CONVENTIONS_REPOSITORY": "platform-web"}
    assert _launch("check", "--output", "json", cwd=repo, env=env).stdout == completed.stdout


def test_github_repository_names_only_the_workspace(tmp_path: Path) -> None:
    repo = materialize(fixture_repos_dir(PRODUCT) / "clean", tmp_path / "repo")
    named = {"GITHUB_REPOSITORY": "musher-dev/platform-web", "GITHUB_WORKSPACE": str(repo)}
    assert _ids(_launch("check", "--output", "json", cwd=repo, env=named).stdout) == {"REPO-07"}
    # A directory other than the workspace, such as a fixture checked with -C
    # in CI, must not borrow the workspace's name.
    elsewhere = named | {"GITHUB_WORKSPACE": str(tmp_path)}
    assert _ids(_launch("check", "--output", "json", cwd=repo, env=elsewhere).stdout) == set()


@pytest.mark.parametrize(
    "url",
    [
        "https://github.com/musher-dev/platform-web.git",
        "git@github.com:musher-dev/platform-web.git",
        "ssh://git@github.com/musher-dev/platform-web/",
    ],
)
def test_origin_remote_names_a_work_tree_root(url: str, tmp_path: Path) -> None:
    repo = materialize(fixture_repos_dir(PRODUCT) / "clean", tmp_path / "repo")
    git = shutil.which("git")
    assert git
    subprocess.run([git, "init", "-q", str(repo)], check=True)
    subprocess.run([git, "-C", str(repo), "remote", "add", "origin", url], check=True)
    completed = _launch("check", "--output", "json", cwd=repo)
    assert completed.returncode == 0, completed.stderr
    assert _ids(completed.stdout) == {"REPO-07"}
    assert repository_name(repo) == "platform-web"
    # Checked as a subdirectory of the work tree, the origin is not its name.
    subdirectory = _launch("check", "--output", "json", "-C", ".github", cwd=repo)
    assert "REPO-07" not in _ids(subdirectory.stdout)


def test_an_unusable_name_is_unknown(tmp_path: Path) -> None:
    repo = materialize(fixture_repos_dir(PRODUCT) / "clean", tmp_path / "repo")
    completed = _launch("check", "--output", "json", "--repository", "not a name", cwd=repo)
    assert _ids(completed.stdout) == set()
    assert repository_name(repo, "not a name") is None


def _stage(repo: Path, families: list[str]) -> None:
    """Declare a staged adoption of `families`, in force for the next 30 days."""
    expires = (datetime.now(UTC) + timedelta(days=30)).strftime("%Y-%m-%d")
    enforce = ", ".join(f'"{family}"' for family in families)
    (repo / ".repo" / "conventions.toml").write_text(
        "schema_version = 1\n"
        "\n"
        "[conventions]\n"
        'version = "0.1.0"\n'
        "\n"
        "[adoption]\n"
        f"enforce = [{enforce}]\n"
        'tracking = "https://github.com/example/repo/issues/1"\n'
        f'expires = "{expires}"\n',
        encoding="utf-8",
    )


@pytest.mark.parametrize("output", ["text", "json", "github"])
def test_only_enforced_families_fail(output: str, tmp_path: Path) -> None:
    # A staged adoption reports every family but fails only on the ones it
    # enforces, with the same exit status for every output format.
    repo = materialize(fixture_repos_dir(PRODUCT) / "gha-07-display-name", tmp_path / "repo")
    _stage(repo, ["ADOPT", "OUT"])
    unenforced = _launch("check", "--fail-on", "warning", "--output", output, cwd=repo)
    assert unenforced.returncode == 0, unenforced.stderr
    assert "not enforced" in unenforced.stdout or output == "json"
    _stage(repo, ["ADOPT", "GHA"])
    enforced = _launch("check", "--fail-on", "warning", "--output", output, cwd=repo)
    assert enforced.returncode == 1, enforced.stderr
    assert "not enforced" not in enforced.stdout


def test_a_staged_report_matches_the_runner(tmp_path: Path) -> None:
    repo = materialize(fixture_repos_dir(PRODUCT) / "gha-07-display-name", tmp_path / "repo")
    _stage(repo, ["ADOPT", "OUT"])
    report = check(PRODUCT, repo, utc_now())
    assert [finding.enforced for finding in report.findings] == [False]
    text = _launch("check", "--fail-on", "warning", cwd=repo)
    assert text.stdout == render_text(report, requirement_titles(PRODUCT), "warning"), text.stderr
    assert _launch("check", "--output", "json", cwd=repo).stdout == render_json(report)


# Each format the launcher prints, with a line only that format prints: its
# own two, and conftest's, which it passes through.
FORMATS = {
    "text": "GHA-07  warning",
    "json": '"id": "GHA-07"',
    "github": "::warning file=",
    "sarif": '"runs":',
    "junit": "<testsuites>",
    "tap": "not ok ",
    "table": "│",
    "azuredevops": "##vso[task.logissue type=warning]",
    "stdout": "WARN - ",
}


@pytest.mark.parametrize("output", sorted(FORMATS))
def test_every_output_format_reports_the_finding(output: str, tmp_path: Path) -> None:
    repo = materialize(fixture_repos_dir(PRODUCT) / "gha-07-display-name", tmp_path / "repo")
    completed = _launch("check", "--output", output, cwd=repo)
    assert completed.returncode == 0, completed.stderr
    assert FORMATS[output] in completed.stdout
    assert "GHA-07" in completed.stdout


def test_fail_on_warning_fails_a_passed_through_format(tmp_path: Path) -> None:
    repo = materialize(fixture_repos_dir(PRODUCT) / "gha-07-display-name", tmp_path / "repo")
    completed = _launch("check", "--fail-on", "warning", "--output", "github", cwd=repo)
    assert completed.returncode == 1, completed.stderr
    assert "::warning file=" in completed.stdout


def _strict_product(tmp_path: Path) -> Path:
    """A copy of the release in which every profile raises GHA-07 to error, as a profile may."""
    rego = PRODUCT / "checks" / "rego"
    strict = tmp_path / "strict"
    shutil.copytree(PRODUCT / "bin", strict / "bin")
    for source in rego.rglob("*.rego"):
        if not source.name.endswith("_test.rego"):
            target = strict / "checks" / "rego" / source.relative_to(rego)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
    document = as_map(json.loads((PRODUCT / "checks" / "data" / "index.json").read_text()))
    index = as_map(as_map(document["conventions"])["index"])
    for profile in as_map(index["profiles"]).values():
        as_map(as_map(profile)["severity"])["GHA-07"] = "error"
    (strict / "checks" / "data").mkdir(parents=True)
    (strict / "checks" / "data" / "index.json").write_text(json.dumps(document))
    return strict


def test_an_error_fails_the_check_end_to_end(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    # Every real requirement is a warning today, so nothing else runs the path
    # an error takes: a profile raising one must fail the check through both
    # runners and every output format.
    strict = _strict_product(tmp_path)
    repo = materialize(fixture_repos_dir(PRODUCT) / "gha-07-display-name", tmp_path / "repo")

    report = check(strict, repo, utc_now())
    assert [(f.id, f.severity) for f in report.findings] == [("GHA-07", "error")]
    assert fails(report.findings, "error")
    monkeypatch.setenv(HOME_ENV, str(strict))
    assert main(["check", str(repo)]) == 1

    environment = {key: value for key, value in os.environ.items() if key not in NAME_SOURCES}

    def launch(*arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(strict / "bin" / "conventions"), "check", *arguments],
            cwd=repo,
            capture_output=True,
            text=True,
            check=False,
            env=environment,
        )

    as_json = launch("--output", "json")
    assert as_json.returncode == 1, as_json.stderr
    assert _found(as_json.stdout) == [(".github/workflows/validate.yml", "GHA-07", "error", True)]
    github = launch("--output", "github")
    assert github.returncode == 1, github.stderr
    assert "::error file=" in github.stdout
    assert launch().returncode == 1
