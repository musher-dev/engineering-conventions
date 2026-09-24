import json
import shutil
import subprocess
from pathlib import Path

import pytest

from conventions_tools import run
from conventions_tools.cli import main
from conventions_tools.loading import as_map, read_json, yaml_problem
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
    url=f"{BASE_URL}/main/engineering-conventions/conventions/github-actions/"
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
    (repo / ".repo" / "conventions.yaml").write_text(text, encoding="utf-8")


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
    assert run.render_text(run.Report([WARNING], [parse_error])) == (
        f"{WARNING.line()}\n"
        "error [PARSE] .github/workflows/bad.yml — not valid YAML: line 1, column 1: x\n"
    )


def test_input_files(tmp_path: Path) -> None:
    for name in (
        ".github/workflows/validate.yml",
        ".github/workflows/release.yaml",
        ".github/workflows/deploy.YML",
        ".github/workflows/notes.md",
        ".github/actions/setup-tools/action.yml",
        ".github/actions/nested/deeper/action.yaml",
        ".github/rulesets/main-branch.json",
        ".repo/conventions.yaml",
        "mise.toml",
        ".devcontainer/mise.toml",
        "nested/mise.toml",
        "README.md",
    ):
        (tmp_path / name).parent.mkdir(parents=True, exist_ok=True)
        (tmp_path / name).write_text("{}\n")
    assert run.input_files(tmp_path) == [
        ".devcontainer/mise.toml",
        ".github/actions/nested/deeper/action.yaml",
        ".github/actions/setup-tools/action.yml",
        ".github/rulesets/main-branch.json",
        ".github/workflows/deploy.YML",
        ".github/workflows/release.yaml",
        ".github/workflows/validate.yml",
        ".repo/conventions.yaml",
        "mise.toml",
    ]


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


def test_release_data_is_optional(stub: Path, home: Path, repo: Path) -> None:
    run.check(home, repo, NOW)
    args = (stub / "args").read_text().splitlines()
    assert args.count("-d") == 2


def test_declaration_is_passed_to_conftest(stub: Path, home: Path, repo: Path) -> None:
    # ADOPT-02 is decided in Rego like every other requirement.
    _write_declaration(repo, "schema_version: 1\nprofile: no-such-profile\n")
    assert run.check(home, repo, NOW).findings == []
    assert ".repo/conventions.yaml" in (stub / "args").read_text().splitlines()


def test_unparsable_declaration_is_a_parse_error(stub: Path, home: Path, repo: Path) -> None:
    _write_declaration(repo, "profile: [unterminated\n")
    report = run.check(home, repo, NOW)
    assert [error.path for error in report.errors] == [".repo/conventions.yaml"]
    assert ".repo/conventions.yaml" not in (stub / "args").read_text().splitlines()


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
    assert capsys.readouterr().out == WARNING.line() + "\n"

    assert main(["check", str(repo), "--now", NOW, "--fail-on", "warning"]) == 1
    capsys.readouterr()

    assert main(["check", str(repo), "--now", NOW, "--format", "json"]) == 0
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
    assert out[0] == WARNING.line()
    assert out[-1].startswith("error [PARSE] .github/workflows/broken.yml — not valid YAML")


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
