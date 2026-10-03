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

from conventions_tools import generate
from conventions_tools.cli import main
from conventions_tools.content import Content
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
# clean, gha-07-display-name and gha-15-required-context are held to the runner
# by test_launcher_prints_what_the_runner_prints instead.
CASES = [
    "mise-pin-without-declaration",
    "adopt-02-invalid-declaration",
    "adopt-09-unpinned",
    # The launcher hashes vendored copies itself (DEPS-06, decision 0022).
    "deps-06-edited-file",
    "deps-06-passes-every-interface-when-none-named",
    # The launcher derives the contract with bin/env-contract.jq, as the
    # runner does (decision 0026), and reads each .gitignore (ENVS-27).
    "envs-20-stale-contract",
    "envs-20-passes-derived-contract",
    "envs-27-negated",
]


# Where the launcher learns a repository's actual name; cleared so a run in
# GitHub Actions tests the same thing as a run anywhere else.
NAME_SOURCES = ("CONVENTIONS_REPOSITORY", "GITHUB_REPOSITORY", "GITHUB_WORKSPACE")

# The launcher runs the tools on PATH, which the suite has already resolved to
# the pinned versions, rather than paying mise's start-up on every tool call.
# test_launcher_runs_its_tools_through_mise keeps the mise path covered.
ON_PATH = {"CONVENTIONS_NO_MISE": "1"}


def _launch(
    *arguments: str, cwd: Path, env: dict[str, str] | None = None
) -> subprocess.CompletedProcess[str]:
    environment = {key: value for key, value in os.environ.items() if key not in NAME_SOURCES}
    environment |= ON_PATH | (env or {})
    return subprocess.run(
        [str(LAUNCHER), *arguments],
        cwd=cwd,
        capture_output=True,
        text=True,
        check=False,
        # An empty value removes the variable, so a test can unset a default.
        env={key: value for key, value in environment.items() if value},
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


def test_launcher_runs_its_tools_through_mise(tmp_path: Path) -> None:
    if shutil.which("mise") is None:
        pytest.skip("mise is not installed")
    case = fixture_repos_dir(PRODUCT) / "gha-07-display-name"
    repo = materialize(case, tmp_path / "repo")
    completed = _launch("check", "--output", "json", cwd=repo, env={"CONVENTIONS_NO_MISE": ""})
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
    with (repo / ".gitignore").open("a", encoding="utf-8") as ignore:
        ignore.write(".github/workflows/ci.yml\n")
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
        ("SPECTRAL_VERSION", "aqua:stoplightio/spectral"),
        ("HADOLINT_VERSION", "aqua:hadolint/hadolint"),
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
    # The case holds no .repo/ declarations, Taskfile or commit rules, so they
    # are reported missing: this repository's own were not read.
    assert found == {
        "GHA-07",
        "ADOPT-09",
        "REPO-01",
        "TASK-10",
        "COMMIT-01",
        "COMMIT-04",
    }


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
    # The clean case's devcontainer.json has comments and trailing commas.
    repo = materialize(fixture_repos_dir(PRODUCT) / "clean", tmp_path / "repo")
    assert "\n  },\n" in (repo / ".devcontainer" / "devcontainer.json").read_text()
    (repo / "Dockerfile").write_text("FROM scratch\n")
    (repo / "docker").mkdir()
    (repo / "docker" / "build.Dockerfile").write_text("")
    # BuildKit's per-Dockerfile ignore file is not a Dockerfile, so it is not parsed.
    (repo / "docker" / "build.Dockerfile.dockerignore").write_text("**/node_modules\n")
    completed = _launch("check", "--output", "json", cwd=repo)
    assert completed.returncode == 1, completed.stderr
    # The IMAGE checks judge the files too; only the parse error is the point here.
    assert [f for f in _found(completed.stdout) if f[1] == "PARSE"] == [
        ("docker/build.Dockerfile", "PARSE", "error", True)
    ]
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


# The launcher's sha256 function, run on its own with only one hashing tool on
# PATH, so each fallback is seen to give the same digest.
@pytest.mark.parametrize("tool", ["sha256sum", "shasum", "openssl"])
def test_sha256_falls_back_to_whichever_tool_exists(tool: str, tmp_path: Path) -> None:
    found = shutil.which(tool)
    if found is None:
        pytest.skip(f"{tool} is not installed")
    tools = tmp_path / "bin"
    tools.mkdir()
    for name in (tool, "sed"):
        located = shutil.which(name)
        assert located is not None
        (tools / name).symlink_to(located)
    text = LAUNCHER.read_text(encoding="utf-8")
    function = re.search(r"^sha256\(\) \{\n.*?^\}\n", text, re.MULTILINE | re.DOTALL)
    assert function is not None
    (tmp_path / "file").write_text("")
    completed = subprocess.run(
        [
            "/bin/sh",
            "-c",
            'die() { echo "$*" >&2; exit 2; }\n' + function.group(0) + 'sha256 "$1"',
            "sh",
            "file",
        ],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
        env={"PATH": str(tools)},
    )
    assert completed.returncode == 0, completed.stderr
    assert (
        completed.stdout.strip()
        == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    )


def test_env_contract_prints_what_the_check_compares(tmp_path: Path) -> None:
    # The committed contract of the passing case is what the command prints
    # today, so a change to the mapping shows up here.
    schema = fixture_repos_dir(PRODUCT) / "clean" / "platform-api" / "env.schema.yaml"
    contract = _launch("env-contract", str(schema), cwd=tmp_path)
    assert contract.returncode == 0, contract.stderr
    committed = (
        fixture_repos_dir(PRODUCT)
        / "envs-20-passes-derived-contract"
        / "platform-api"
        / "contracts"
        / "env"
        / "platform-api.env.schema.json"
    )
    assert contract.stdout == committed.read_text(encoding="utf-8")
    # The .env.example it once printed is retired (ENVS-21, decision 0029).
    assert _launch("env-contract", "--example", str(schema), cwd=tmp_path).returncode == 2


def test_env_contract_needs_a_schema_that_parses(tmp_path: Path) -> None:
    (tmp_path / "env.schema.yaml").write_text("- a list\n")
    completed = _launch("env-contract", "-C", str(tmp_path), "env.schema.yaml", cwd=tmp_path)
    assert completed.returncode == 2
    assert "cannot derive the environment contract from env.schema.yaml" in completed.stderr
    missing = _launch("env-contract", "absent.yaml", cwd=tmp_path)
    assert missing.returncode == 2
    assert "absent.yaml does not exist" in missing.stderr
    assert _launch("env-contract", cwd=tmp_path).returncode == 2


ENV_SCHEMA = """\
service: api
runtime: go
bindings:
  API_PORT: {type: integer, default: 8080, sensitivity: internal, description: TCP port.}
  DATABASE_URL:
    type: string
    required: true
    sensitivity: secret
    local_default: postgres://postgres@localhost:5432/app
    description: The database.
  API_TOKEN: {type: string, required: true, sensitivity: secret, description: A token.}
  SESSION_KEY:
    type: string
    sensitivity: secret
    local_generate: "base64url:32"
    description: Signs cookies.
  NONCE_SALT: {type: string, sensitivity: secret, local_generate: "hex:16", description: Salts.}
"""


def _env_lines(path: Path) -> dict[str, str]:
    return {
        line.split("=", 1)[0]: line.split("=", 1)[1]
        for line in path.read_text(encoding="utf-8").splitlines()
        if line and not line.startswith("#")
    }


def test_env_file_writes_a_ready_to_run_env(tmp_path: Path) -> None:
    (tmp_path / "api").mkdir()
    (tmp_path / "api" / "env.schema.yaml").write_text(ENV_SCHEMA)
    completed = _launch("env-file", "-C", str(tmp_path), "api/env.schema.yaml", cwd=tmp_path)
    assert completed.returncode == 0, completed.stderr
    written = tmp_path / "api" / ".env"
    assert written.stat().st_mode & 0o777 == 0o600
    text = written.read_text(encoding="utf-8")
    assert text.startswith("# The local environment api reads, generated from its env.schema.yaml")
    assert "\n# API_PORT=8080\n" in text
    values = _env_lines(written)
    assert values["DATABASE_URL"] == "postgres://postgres@localhost:5432/app"
    assert values["API_TOKEN"] == ""
    assert len(values["NONCE_SALT"]) == 32
    assert all(character in "0123456789abcdef" for character in values["NONCE_SALT"])
    assert len(values["SESSION_KEY"]) == 43
    assert not set(values["SESSION_KEY"]) & set("+/=")


def test_env_file_never_replaces_an_env_without_force(tmp_path: Path) -> None:
    (tmp_path / "env.schema.yaml").write_text(ENV_SCHEMA)
    (tmp_path / ".env").write_text("API_TOKEN=mine\n# API_PORT=9090\nDATABASE_URL=x\n")
    missing = _launch("env-file", "-C", str(tmp_path), "env.schema.yaml", cwd=tmp_path)
    assert missing.returncode == 1
    assert missing.stderr.splitlines()[1:] == ["NONCE_SALT", "SESSION_KEY"]
    assert (tmp_path / ".env").read_text(encoding="utf-8").startswith("API_TOKEN=mine\n")
    (tmp_path / ".env").write_text(
        "API_TOKEN=mine\n# API_PORT=9090\nDATABASE_URL=x\nexport NONCE_SALT=a\nSESSION_KEY=b\n"
    )
    complete = _launch("env-file", "-C", str(tmp_path), "env.schema.yaml", cwd=tmp_path)
    assert complete.returncode == 0, complete.stderr
    assert "already has every variable" in complete.stderr
    first = _env_lines(tmp_path / ".env")
    forced = _launch("env-file", "--force", "-C", str(tmp_path), "env.schema.yaml", cwd=tmp_path)
    assert forced.returncode == 0, forced.stderr
    assert "every secret in it is minted again" in forced.stderr
    assert _env_lines(tmp_path / ".env")["SESSION_KEY"] != first["SESSION_KEY"]


def test_env_file_needs_a_schema_that_parses(tmp_path: Path) -> None:
    (tmp_path / "env.schema.yaml").write_text("- a list\n")
    completed = _launch("env-file", "-C", str(tmp_path), "env.schema.yaml", cwd=tmp_path)
    assert completed.returncode == 2
    assert "cannot derive the local environment from env.schema.yaml" in completed.stderr
    assert not (tmp_path / ".env").exists()
    assert _launch("env-file", "absent.yaml", cwd=tmp_path).returncode == 2


OPENAPI_FIXTURES = PRODUCT / "tests" / "fixtures" / "openapi"


def _openapi_repo(tmp_path: Path) -> Path:
    # A repository that declares one openapi interface, as a YAML document,
    # with a ruleset that extends spectral:oas and the OWASP ruleset.
    repo = materialize(
        fixture_repos_dir(PRODUCT) / "oas-03-passes-through-check-task", tmp_path / "repo"
    )
    outputs = repo / ".repo" / "outputs.toml"
    outputs.write_text(outputs.read_text(encoding="utf-8").replace("public.json", "public.yaml"))
    documents = repo / "platform-api" / "contracts" / "openapi"
    (documents / "public.json").unlink()
    shutil.copy(OPENAPI_FIXTURES / "clean.yaml", documents / "public.yaml")
    return repo


def test_openapi_lints_the_declared_documents(tmp_path: Path) -> None:
    if shutil.which("spectral") is None:
        pytest.skip("spectral is not installed")
    repo = _openapi_repo(tmp_path)
    completed = _launch("openapi", "--ruleset", ".config/openapi/spectral.yaml", cwd=repo)
    assert completed.returncode == 0, completed.stdout + completed.stderr
    assert not (repo / ".conventions").exists()


def test_openapi_fails_on_an_error_in_a_named_file(tmp_path: Path) -> None:
    if shutil.which("spectral") is None:
        pytest.skip("spectral is not installed")
    repo = _openapi_repo(tmp_path)
    shutil.copy(OPENAPI_FIXTURES / "insecure.yaml", repo / "insecure.yaml")
    completed = _launch("openapi", "-C", str(repo), "insecure.yaml", cwd=tmp_path)
    assert completed.returncode == 1, completed.stdout + completed.stderr
    assert "owasp:api2:2023-write-restricted" in completed.stdout


def test_openapi_without_a_ruleset_cannot_run(tmp_path: Path) -> None:
    repo = _openapi_repo(tmp_path)
    shutil.rmtree(repo / ".config" / "openapi")
    completed = _launch("openapi", cwd=repo)
    assert completed.returncode == 2
    assert "(OAS-02)" in completed.stderr


def test_openapi_with_no_interface_has_nothing_to_check(tmp_path: Path) -> None:
    repo = materialize(fixture_repos_dir(PRODUCT) / "clean", tmp_path / "repo")
    completed = _launch("openapi", cwd=repo)
    assert completed.returncode == 0, completed.stderr
    assert "no OpenAPI documents to check" in completed.stderr
    assert not (repo / ".conventions").exists()


def test_prose_runs_the_copy_style_where_the_vale_config_applies_it(tmp_path: Path) -> None:
    config = tmp_path / ".config" / "markdown" / "vale.ini"
    config.parent.mkdir(parents=True)
    config.write_text(
        "StylesPath = styles\n"
        "Packages = https://github.com/musher-dev/engineering-conventions/releases/download/"
        "v0.7.1/MusherProse.zip\n"
        "[formats]\nsvelte = html\n"
        "[site/**/*.{md,svelte}]\nBasedOnStyles = MusherCopy, proselint, write-good\n"
        "[site/reference/*.md]\nMusherCopy.Placeholders = NO\n",
        encoding="utf-8",
    )
    (tmp_path / "site" / "reference").mkdir(parents=True)
    (tmp_path / "site" / "index.svelte").write_text("<p>Pricing: coming soon.</p>\n")
    (tmp_path / "site" / "reference" / "terms.md").write_text("# Terms\n\nPricing: coming soon.\n")
    (tmp_path / "README.md").write_text("# Readme\n\nPricing: coming soon.\n")
    completed = _launch("prose", "-C", str(tmp_path), cwd=tmp_path)
    # Placeholders is a warning, which does not fail Vale's run.
    assert completed.returncode == 0, completed.stdout + completed.stderr
    # The copy style runs where the config applies it, honours the config's
    # [formats] and its toggles, and nowhere else.
    assert re.findall(r"^ (\S+)$", re.sub(r"\x1b\[[0-9;]*m", "", completed.stdout), re.M) == [
        "site/index.svelte"
    ]
    assert "MusherCopy.Placeholders" in completed.stdout


def test_prose_hands_vale_every_copy_extension(content: Content) -> None:
    text = LAUNCHER.read_text(encoding="utf-8")
    found = re.search(r"^COPY_FILES='\\\.\(([a-z0-9|?]+)\)\$'$", text, re.M)
    assert found, "bin/conventions defines COPY_FILES as '\\.(ext|ext)$'"
    listed = set(found.group(1).replace("html?", "html|htm").split("|"))
    assert listed == set(generate.copy_extensions(content.copy_style))
