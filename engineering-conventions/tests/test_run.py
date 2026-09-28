import json
import shutil
import subprocess
from dataclasses import replace
from pathlib import Path

import pytest

from conventions_tools import run
from conventions_tools.cli import main
from conventions_tools.loading import as_list, as_map, get_str, read_json, yaml_problem
from conventions_tools.paths import HOME_ENV
from conventions_tools.run import Finding, RunnerError

NOW = "2026-09-23T00:00:00Z"
BASE_URL = "https://github.com/musher-dev/engineering-conventions/blob"

STUB = """#!/bin/sh
printf '%s\\n' "$@" > "$STUB_DIR/args"
pwd > "$STUB_DIR/cwd"
for argument in "$@"; do
  case "$argument" in
    */runtime.json) cp "$argument" "$STUB_DIR/runtime.json" ;;
    */inventory.json) cp "$argument" "$STUB_DIR/inventory.json" ;;
  esac
done
cat "$STUB_DIR/output.json"
exit "${STUB_EXIT:-0}"
"""

WARNING = Finding(
    id="GHA-07",
    path=".github/workflows/ci.yml",
    message='name "CI" should be "Validate": a name is its filename stem in Title Case.',
    severity="warning",
    url=f"{BASE_URL}/main/engineering-conventions/definitions/conventions/github-actions/"
    "workflow-files.md#gha-07",
    convention="EC-0002",
)


def _result(finding: Finding) -> dict[str, object]:
    metadata = {
        "id": finding.id,
        "path": finding.path,
        "message": finding.message,
        "severity": finding.severity,
        "url": finding.url,
        "convention": finding.convention,
        "msg": finding.line(),
    }
    return {"msg": finding.line(), "metadata": metadata}


@pytest.fixture
def stub(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """A fake conftest on PATH that records its invocation and prints output.json."""
    directory = tmp_path / "stub"
    directory.mkdir()
    executable = directory / "conftest"
    executable.write_text(STUB, encoding="utf-8")
    executable.chmod(0o755)
    (directory / "output.json").write_text("[]", encoding="utf-8")
    monkeypatch.setenv("STUB_DIR", str(directory))
    monkeypatch.setenv("PATH", f"{directory}:/usr/bin:/bin")
    return directory


def _set_output(stub: Path, warnings: list[Finding], failures: list[Finding]) -> None:
    output = [
        {
            "filename": "Combined",
            "namespace": "main",
            "successes": 0,
            "warnings": [_result(finding) for finding in warnings],
            "failures": [_result(finding) for finding in failures],
        }
    ]
    (stub / "output.json").write_text(json.dumps(output), encoding="utf-8")


@pytest.fixture
def home(product: Path, tmp_path: Path) -> Path:
    """A product directory with the real index and schemas and an empty rule directory."""
    copy = tmp_path / "home"
    shutil.copytree(product / "checks" / "schemas", copy / "checks" / "schemas")
    shutil.copytree(product / "checks" / "data", copy / "checks" / "data")
    shutil.copytree(product / "bin", copy / "bin")
    (copy / "checks" / "rego").mkdir()
    return copy


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    root = tmp_path / "repo"
    (root / ".github" / "workflows").mkdir(parents=True)
    (root / ".github" / "workflows" / "validate.yml").write_text("name: Validate\n")
    return root


def _write_declaration(repo: Path, text: str) -> None:
    (repo / ".repo").mkdir(exist_ok=True)
    (repo / ".repo" / "conventions.toml").write_text(text, encoding="utf-8")


def test_diagnostic_line_format() -> None:
    assert WARNING.line() == (
        "warning [GHA-07] .github/workflows/ci.yml — "
        'name "CI" should be "Validate": a name is its filename stem in Title Case. '
        f"{WARNING.url}"
    )


@pytest.mark.parametrize(
    ("severities", "fail_on", "fails"),
    [
        ([], "warning", False),
        (["warning"], "error", False),
        (["warning"], "warning", True),
        (["error"], "error", True),
        (["warning", "error"], "error", True),
    ],
)
def test_fail_on_threshold(severities: list[str], fail_on: str, *, fails: bool) -> None:
    findings = [Finding("GHA-07", "a", "m", severity, "u", "EC-0002") for severity in severities]
    assert run.fails(findings, fail_on) is fails


def test_findings_sort_by_path_then_id() -> None:
    findings = [
        Finding("GHA-10", "b.yml", "m", "warning", "u", "c"),
        Finding("GHA-07", "b.yml", "m", "warning", "u", "c"),
        Finding("GHA-20", "a.yml", "m", "warning", "u", "c"),
    ]
    ordered = run.sort_findings(findings)
    assert [(f.path, f.id) for f in ordered] == [
        ("a.yml", "GHA-20"),
        ("b.yml", "GHA-07"),
        ("b.yml", "GHA-10"),
    ]


def test_render_json_is_an_array_of_findings() -> None:
    parse_error = run.ParseError(".github/workflows/bad.yml", "not valid YAML: line 1, column 1: x")
    rendered = json.loads(run.render_json(run.Report([WARNING], [parse_error])))
    assert rendered == [
        {
            "convention": "EC-0002",
            "id": "GHA-07",
            "message": WARNING.message,
            "path": WARNING.path,
            "severity": "warning",
            "url": WARNING.url,
        },
        {
            "convention": "",
            "id": "PARSE",
            "message": "not valid YAML: line 1, column 1: x",
            "path": ".github/workflows/bad.yml",
            "severity": "error",
            "url": "",
        },
    ]
    assert run.render_json(run.Report([], [])) == "[]\n"


def test_input_files(tmp_path: Path) -> None:
    for name in (
        ".github/workflows/validate.yml",
        ".github/workflows/release.yaml",
        ".github/workflows/deploy.YML",
        ".github/workflows/notes.md",
        ".github/actions/setup-tools/action.yml",
        ".github/actions/nested/deeper/action.yaml",
        ".github/rulesets/main-branch.json",
        ".repo/conventions.toml",
        ".repo/outputs.toml",
        ".repo/repository.toml",
        "mise.toml",
        ".devcontainer/mise.toml",
        "nested/mise.toml",
        "README.md",
        "Taskfile.yml",
        "services/api/Taskfile.yml",
        "services/api/taskfiles/lint.Taskfile.yml",
        "a/b/c/Taskfile.yml",
        ".config/lefthook.yml",
        "api/env.schema.yaml",
        "package.json",
        ".github/dependabot.yml",
        ".config/security/trivyignore.yaml",
        ".devcontainer/devcontainer.json",
        "CLAUDE.md",
    ):
        (tmp_path / name).parent.mkdir(parents=True, exist_ok=True)
        (tmp_path / name).write_text("{}\n")
    assert run.input_files(tmp_path) == [
        ".config/lefthook.yml",
        ".config/security/trivyignore.yaml",
        ".devcontainer/mise.toml",
        ".github/actions/nested/deeper/action.yaml",
        ".github/actions/setup-tools/action.yml",
        ".github/dependabot.yml",
        ".github/rulesets/main-branch.json",
        ".github/workflows/deploy.YML",
        ".github/workflows/release.yaml",
        ".github/workflows/validate.yml",
        ".repo/conventions.toml",
        ".repo/outputs.toml",
        ".repo/repository.toml",
        "Taskfile.yml",
        "api/env.schema.yaml",
        "mise.toml",
        "package.json",
        "services/api/Taskfile.yml",
        "services/api/taskfiles/lint.Taskfile.yml",
    ]


def test_selection_is_read_from_the_launcher(product: Path) -> None:
    chosen = run.selection(product)
    assert chosen.jsonnet.search(".devcontainer/devcontainer.json")
    assert chosen.jsonnet.search(".devcontainer/python/devcontainer.json")
    assert not chosen.jsonnet.search("devcontainer.json")
    for name in ("Dockerfile", "docker/build.Dockerfile", "Containerfile", "Dockerfile.dev"):
        assert chosen.dockerfiles.search(name), name
    assert not chosen.dockerfiles.search(".dockerignore")
    for name in (
        "CLAUDE.md",
        "api/CLAUDE.md",
        ".claude/rules/a/b.md",
        "docs/decisions/0001-x.md",
        "docs/adrs/0001-x/+page.md",
        ".nvmrc",
        "api/.python-version",
        ".config/README.md",
        ".trivyignore",
        ".config/security/trivyignore",
        ".config/security/gitleaksignore",
    ):
        assert chosen.texts.search(name), name
    assert not chosen.texts.search("README.md")
    assert not chosen.texts.search("docs/trivyignore")
    assert chosen.sizes.search("docs/guide.md")
    assert chosen.text_limit > 0


def test_selection_needs_the_launcher_patterns(tmp_path: Path) -> None:
    (tmp_path / "bin").mkdir()
    (tmp_path / "bin" / "conventions").write_text("INPUTS='x'\nTEXT_LIMIT=1\n")
    with pytest.raises(RunnerError, match="no JSONNET pattern"):
        run.selection(tmp_path)


def test_conftest_reason_is_one_line() -> None:
    error = "Error: parse configurations: parser unmarshal: bad token\n\n\n, path: x.json\n"
    assert run.conftest_reason(error) == "conftest cannot parse it: parser unmarshal: bad token"


def test_inventory_document_embeds_text_sizes_and_parses(product: Path, tmp_path: Path) -> None:
    (tmp_path / ".devcontainer").mkdir()
    (tmp_path / ".devcontainer" / "devcontainer.json").write_text('// c\n{"name": "x",}\n')
    (tmp_path / "Dockerfile").write_text("ARG X=1\nFROM scratch\n")
    (tmp_path / "broken.Dockerfile").write_text("")
    (tmp_path / "CLAUDE.md").write_text("@README.md\n")
    (tmp_path / "big").mkdir()
    (tmp_path / "big" / "CLAUDE.md").write_text("x" * (run.selection(product).text_limit + 1))
    files = run.inventory(tmp_path)
    document = run.inventory_document(tmp_path, files, "sdk-cli", run.selection(product))
    listing = as_map(document["conventions_inventory"])
    assert listing["files"] == files
    assert listing["repository"] == {"name": "sdk-cli"}
    assert listing["texts"] == {"CLAUDE.md": "@README.md\n"}
    assert listing["sizes"] == {"CLAUDE.md": 11, "big/CLAUDE.md": 262145}
    parsed = {
        get_str(entry, "path"): entry.get("contents")
        for entry in map(as_map, as_list(listing["parsed"]))
    }
    assert parsed[".devcontainer/devcontainer.json"] == {"name": "x"}
    assert as_map(as_list(parsed["Dockerfile"])[1])["Cmd"] == "from"


def test_inventory_walks_a_plain_directory(tmp_path: Path) -> None:
    (tmp_path / ".git").mkdir()
    (tmp_path / ".git" / "HEAD").write_text("ref")
    (tmp_path / "a" / "b").mkdir(parents=True)
    (tmp_path / "a" / "b" / "c.txt").write_text("c")
    assert run.inventory(tmp_path) == ["a/b/c.txt"]


def test_inventory_uses_git_at_a_work_tree_root(tmp_path: Path) -> None:
    git = shutil.which("git")
    assert git
    subprocess.run([git, "init", "-q", str(tmp_path)], check=True)
    (tmp_path / ".gitignore").write_text("ignored.txt\n")
    (tmp_path / "ignored.txt").write_text("x")
    (tmp_path / "kept.txt").write_text("x")
    (tmp_path / "deleted.txt").write_text("x")
    subprocess.run([git, "-C", str(tmp_path), "add", "deleted.txt"], check=True)
    (tmp_path / "deleted.txt").unlink()
    assert run.inventory(tmp_path) == [".gitignore", "kept.txt"]


def test_check_plumbs_runtime_inventory_and_release(stub: Path, home: Path, repo: Path) -> None:
    (home / "checks" / "data" / "release.json").write_text(
        json.dumps({"conventions": {"release": {"version": "1.2.3"}}})
    )
    error = Finding("GHA-26", ".github/workflows/validate.yml", "m", "error", "u", "EC-0005")
    _set_output(stub, warnings=[WARNING], failures=[error])

    report = run.check(home, repo, NOW)

    assert report.findings == [WARNING, error]
    assert report.errors == []
    args = (stub / "args").read_text().splitlines()
    assert args[:4] == ["test", "--combine", "-p", str(home / "checks" / "rego")]
    data = [args[i + 1] for i, arg in enumerate(args) if arg == "-d"]
    assert data[0] == str(home / "checks" / "data" / "index.json")
    assert data[1].endswith("runtime.json")
    assert data[2] == str(home / "checks" / "data" / "release.json")
    assert args[args.index("-o") + 1] == "json"
    assert "--no-color" in args
    assert ".github/workflows/validate.yml" in args
    assert args[-1].endswith("inventory.json")
    assert Path((stub / "cwd").read_text().strip()) == repo.resolve()
    assert read_json(stub / "runtime.json") == {"conventions": {"runtime": {"now": NOW}}}
    inventory = as_map(as_map(read_json(stub / "inventory.json"))["conventions_inventory"])
    assert inventory["files"] == [".github/workflows/validate.yml"]


def test_the_inventory_carries_a_known_repository_name(stub: Path, home: Path, repo: Path) -> None:
    run.check(home, repo, NOW)
    inventory = as_map(as_map(read_json(stub / "inventory.json"))["conventions_inventory"])
    assert "repository" not in inventory
    run.check(home, repo, NOW, repository="platform-api")
    inventory = as_map(as_map(read_json(stub / "inventory.json"))["conventions_inventory"])
    assert inventory["repository"] == {"name": "platform-api"}
    # A name the launcher would not pass on is treated as unknown here too.
    run.check(home, repo, NOW, repository="not a name")
    inventory = as_map(as_map(read_json(stub / "inventory.json"))["conventions_inventory"])
    assert "repository" not in inventory


@pytest.mark.parametrize(
    "url",
    [
        "https://github.com/musher-dev/platform-api.git",
        "https://github.com/musher-dev/platform-api",
        "git@github.com:musher-dev/platform-api.git",
        "ssh://git@github.com/musher-dev/platform-api.git/",
        "git@example.com:platform-api.git\n",
    ],
)
def test_remote_name(url: str) -> None:
    assert run.remote_name(url) == "platform-api"


def test_repository_name_sources_in_order(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    for variable in ("CONVENTIONS_REPOSITORY", "GITHUB_REPOSITORY", "GITHUB_WORKSPACE"):
        monkeypatch.delenv(variable, raising=False)
    assert run.repository_name(tmp_path) is None
    monkeypatch.setenv("GITHUB_REPOSITORY", "musher-dev/sdk-python")
    monkeypatch.setenv("GITHUB_WORKSPACE", str(tmp_path / "elsewhere"))
    assert run.repository_name(tmp_path) is None
    monkeypatch.setenv("GITHUB_WORKSPACE", str(tmp_path))
    assert run.repository_name(tmp_path) == "sdk-python"
    monkeypatch.setenv("CONVENTIONS_REPOSITORY", "sdk-typescript")
    assert run.repository_name(tmp_path) == "sdk-typescript"
    assert run.repository_name(tmp_path, "sdk-cli") == "sdk-cli"
    assert run.repository_name(tmp_path, "..") is None


def test_cli_check_passes_the_repository_name(
    stub: Path, home: Path, repo: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv(HOME_ENV, str(home))
    monkeypatch.delenv("CONVENTIONS_REPOSITORY", raising=False)
    assert main(["check", str(repo), "--now", NOW, "--repository", "platform-api"]) == 0
    inventory = as_map(as_map(read_json(stub / "inventory.json"))["conventions_inventory"])
    assert inventory["repository"] == {"name": "platform-api"}


def test_release_data_is_optional(stub: Path, home: Path, repo: Path) -> None:
    run.check(home, repo, NOW)
    args = (stub / "args").read_text().splitlines()
    assert args.count("-d") == 2


def test_declaration_is_passed_to_conftest(stub: Path, home: Path, repo: Path) -> None:
    # ADOPT-02 is decided in Rego like every other requirement.
    _write_declaration(repo, 'schema_version = 1\nprofile = "no-such-profile"\n')
    assert run.check(home, repo, NOW).findings == []
    assert ".repo/conventions.toml" in (stub / "args").read_text().splitlines()


def test_unparsable_declaration_is_a_parse_error(stub: Path, home: Path, repo: Path) -> None:
    _write_declaration(repo, "profile = [unterminated\n")
    report = run.check(home, repo, NOW)
    assert [error.path for error in report.errors] == [".repo/conventions.toml"]
    assert ".repo/conventions.toml" not in (stub / "args").read_text().splitlines()


def test_unparsable_mise_config_is_a_parse_error(stub: Path, home: Path, repo: Path) -> None:
    (repo / "mise.toml").write_text("[tools\n")
    report = run.check(home, repo, NOW)
    assert [(error.path, error.reason[:15]) for error in report.errors] == [
        ("mise.toml", "not valid TOML:")
    ]
    assert stub.is_dir()


def test_missing_conftest_is_a_clear_error(
    home: Path, repo: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("PATH", str(tmp_path / "empty"))
    with pytest.raises(RunnerError, match="conftest is not on PATH"):
        run.check(home, repo, NOW)


def test_conftest_crash_is_reported(
    stub: Path, home: Path, repo: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("STUB_EXIT", "2")
    with pytest.raises(RunnerError, match="conftest exited 2"):
        run.check(home, repo, NOW)
    assert stub.is_dir()


def test_conftest_error_without_results_is_reported(
    stub: Path, home: Path, repo: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    (stub / "output.json").write_text("")
    monkeypatch.setenv("STUB_EXIT", "1")
    with pytest.raises(RunnerError, match="conftest exited 1"):
        run.check(home, repo, NOW)


def test_result_without_metadata_is_rejected() -> None:
    output = json.dumps([{"warnings": [{"msg": "bare"}], "failures": []}])
    with pytest.raises(RunnerError, match="without id, path, message, url, convention"):
        run.parse_conftest_output(output)


def test_non_json_output_is_rejected() -> None:
    with pytest.raises(RunnerError, match="not JSON"):
        run.parse_conftest_output("Error: rego_parse_error")


@pytest.mark.parametrize("value", ["2026-09-23", "yesterday", "2026-09-23T00:00:00"])
def test_now_must_be_rfc3339_with_offset(value: str) -> None:
    with pytest.raises(RunnerError):
        run.validate_now(value)


def test_now_accepts_utc() -> None:
    assert run.validate_now(NOW) == NOW
    assert run.utc_now().endswith("Z")


def test_cli_check_exit_codes_and_formats(
    stub: Path,
    home: Path,
    repo: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    monkeypatch.setenv(HOME_ENV, str(home))
    _set_output(stub, warnings=[WARNING], failures=[])

    assert main(["check", str(repo), "--now", NOW]) == 0
    text = capsys.readouterr().out
    assert text.startswith("GHA-07  warning  1 finding\n")
    assert f"  {WARNING.path}\n    {WARNING.message}\n" in text

    assert main(["check", str(repo), "--now", NOW, "--fail-on", "warning"]) == 1
    capsys.readouterr()

    for flag in ("--format", "--output"):
        assert main(["check", str(repo), "--now", NOW, flag, "json"]) == 0
        assert as_map(json.loads(capsys.readouterr().out)[0])["id"] == "GHA-07"

    assert main(["check", str(repo), "--now", "not-a-time"]) == 2
    assert "not an RFC 3339 timestamp" in capsys.readouterr().err


def test_unparsable_files_are_left_out_and_reported(
    stub: Path,
    home: Path,
    repo: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    workflows = repo / ".github" / "workflows"
    (workflows / "broken.yml").write_text("name: [unterminated\n")
    (repo / ".github" / "rulesets").mkdir()
    (repo / ".github" / "rulesets" / "main.json").write_text('{"rules": [}')
    (repo / ".github" / "actions" / "setup-x").mkdir(parents=True)
    (repo / ".github" / "actions" / "setup-x" / "action.yml").write_bytes(b"name: \xff\n")
    _set_output(stub, warnings=[WARNING], failures=[])

    report = run.check(home, repo, NOW)

    assert report.findings == [WARNING]
    assert report.errors == [
        run.ParseError(
            ".github/actions/setup-x/action.yml", "not UTF-8 text: invalid start byte at byte 6"
        ),
        run.ParseError(
            ".github/rulesets/main.json",
            "not valid JSON: line 1, column 12: Expecting value",
        ),
        run.ParseError(
            ".github/workflows/broken.yml",
            "not valid YAML: line 2, column 1: expected ',' or ']', but got '<stream end>'",
        ),
    ]
    args = (stub / "args").read_text().splitlines()
    assert ".github/workflows/validate.yml" in args
    assert ".github/workflows/broken.yml" not in args

    monkeypatch.setenv(HOME_ENV, str(home))
    assert main(["check", str(repo), "--now", NOW]) == 2
    out = capsys.readouterr().out.splitlines()
    assert out[0] == "PARSE  error  3 findings"
    assert "  .github/workflows/broken.yml" in out
    assert "GHA-07  warning  1 finding" in out


def test_yaml_errors_without_a_mark_are_one_line() -> None:
    assert yaml_problem("a: !!python/name:os.system x\n") == (
        "not valid YAML: line 1, column 4: could not determine a constructor for the tag "
        "'tag:yaml.org,2002:python/name:os.system'"
    )
    assert yaml_problem("---\na: 1\n---\nb: 2\n") is None


PICKY_STUB = """#!/bin/sh
for argument in "$@"; do
  if [ "$argument" = "$PICKY_PATH" ]; then
    echo "Error: running test: parse configurations: parser unmarshal: yaml: bad thing, \\
path: $PICKY_PATH" >&2
    exit 1
  fi
done
printf '%s\\n' "$@" > "$STUB_DIR/args"
cat "$STUB_DIR/output.json"
"""


def test_a_file_conftest_cannot_parse_is_left_out(
    stub: Path, home: Path, repo: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    (stub / "conftest").write_text(PICKY_STUB, encoding="utf-8")
    monkeypatch.setenv("PICKY_PATH", ".github/workflows/validate.yml")
    _set_output(stub, warnings=[WARNING], failures=[])

    report = run.check(home, repo, NOW)

    assert report.findings == [WARNING]
    assert report.errors == [
        run.ParseError(
            ".github/workflows/validate.yml",
            "conftest cannot parse it: parser unmarshal: yaml: bad thing",
        )
    ]
    assert ".github/workflows/validate.yml" not in (stub / "args").read_text().splitlines()


def test_render_text_groups_findings_by_requirement() -> None:
    parse_error = run.ParseError(".github/workflows/bad.yml", "not valid YAML: line 1, column 1: x")
    second = replace(WARNING, path=".github/workflows/a.yml")
    titles = {"GHA-07": "A workflow's name is its filename stem in Title Case"}
    assert run.render_text(run.Report([WARNING, second], [parse_error]), titles) == (
        "PARSE  error  1 finding\n"
        f"{run.PARSE_TITLE}\n"
        "  .github/workflows/bad.yml\n"
        "    not valid YAML: line 1, column 1: x\n"
        "\n"
        "GHA-07  warning  2 findings\n"
        f"{titles['GHA-07']}\n"
        f"{WARNING.url}\n"
        "  .github/workflows/a.yml\n"
        f"    {WARNING.message}\n"
        "  .github/workflows/ci.yml\n"
        f"    {WARNING.message}\n"
        "\n"
        "2 warnings, 1 error in 2 requirements.\n"
    )


def test_render_text_summary() -> None:
    assert run.render_text(run.Report([], []), {}) == "No findings.\n"
    only_warnings = run.render_text(run.Report([WARNING], []), {})
    assert only_warnings.endswith(
        "1 warning, 0 errors in 1 requirement.\n"
        "Warnings do not fail the check; --fail-on warning makes them fail.\n"
    )
    assert "Warnings do not fail" not in run.render_text(run.Report([WARNING], []), {}, "warning")
