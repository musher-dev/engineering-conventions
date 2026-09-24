import json
import shutil
import subprocess
from dataclasses import replace
from pathlib import Path

import pytest

from conventions_tools import generate, vocabulary
from conventions_tools.cli import main
from conventions_tools.content import Content, load_profiles
from conventions_tools.loading import as_list, as_map
from conventions_tools.paths import HOME_ENV
from conventions_tools.profiles import ProfileError, ResolvedProfile, resolve_all


def _index(content: Content) -> dict[str, object]:
    return as_map(as_map(generate.build_index(content)["conventions"])["index"])


def test_outputs_are_deterministic(content: Content) -> None:
    first = [(output.path, output.text) for output in generate.build_outputs(content)]
    second = [(output.path, output.text) for output in generate.build_outputs(content)]
    assert first == second
    assert all(text.endswith("\n") and not text.endswith("\n\n") for _, text in first)


def test_committed_outputs_match_the_source(content: Content, product: Path) -> None:
    assert generate.drift(generate.build_outputs(content), product) == []


def test_index_json_is_sorted_with_two_space_indent(content: Content) -> None:
    text = generate.render_json(generate.build_index(content))
    assert text == json.dumps(json.loads(text), indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def test_index_top_level_shape(content: Content) -> None:
    index = _index(content)
    assert sorted(index) == [
        "conventions",
        "declaration_schema",
        "outputs_schema",
        "product_dir",
        "profiles",
        "repository",
        "requirements",
        "schema_version",
        "vocabulary",
    ]
    assert index["schema_version"] == 1
    assert index["repository"] == "https://github.com/musher-dev/engineering-conventions"
    assert index["product_dir"] == "engineering-conventions"


def test_requirement_entry(content: Content) -> None:
    requirements = as_map(_index(content)["requirements"])
    assert requirements["GHA-07"] == {
        "aliases": ["platform:CI-15"],
        "anchor": "gha-07",
        "convention": "EC-0002",
        "engine": "conftest",
        "package": "conventions.checks.github_actions.workflow_files",
        "path": "definitions/conventions/github-actions/workflow-files.md",
        "severity": "warning",
        "since": "0.1.0",
        "status": "proposed",
        "title": "A workflow's name is its filename stem in Title Case",
        "waivable": True,
    }
    adopt = as_map(requirements["ADOPT-02"])
    assert adopt["waivable"] is False
    assert adopt["package"] == "conventions.checks.adoption.declaration"
    assert "schema" not in adopt
    retired = as_map(requirements["ADOPT-01"])
    assert retired["status"] == "retired"
    assert retired["replaced_by"] == ["ADOPT-09"]


def test_index_carries_a_self_contained_declaration_schema(content: Content) -> None:
    schema = as_map(_index(content)["declaration_schema"])
    refs = json.dumps(schema)
    assert "common.schema.json" not in refs
    assert schema["required"] == ["schema_version"]


def test_convention_entry_keeps_authority(content: Content) -> None:
    conventions = as_map(_index(content)["conventions"])
    assert as_map(conventions["EC-0001"])["authority"] == "self"
    assert as_map(conventions["EC-0002"])["authority"] == {
        "ref": "https://github.com/musher-dev/platform/issues/2892",
        "repo": "musher-dev/platform",
    }


def test_vocabulary_projection(content: Content) -> None:
    projected = as_map(_index(content)["vocabulary"])
    assert projected["responsibility_tokens"] == [
        "audit",
        "deploy",
        "maintain",
        "monitor",
        "publish",
        "release",
        "repository",
        "validate",
        "verify",
    ]
    assert projected["capability_tokens"] == ["build", "check", "promote"]
    assert projected["action_tokens"] == ["authenticate", "check", "install", "setup"]
    assert projected["output_kinds"] == ["bundle", "cli", "contract", "image", "library"]
    assert projected["display_forms"] == {
        "api": "API",
        "ci": "CI",
        "cli": "CLI",
        "codeowners": "CODEOWNERS",
        "dco": "DCO",
        "devcontainer": "Dev Container",
        "e2e": "E2E",
        "hq": "HQ",
        "oci": "OCI",
        "pr": "PR",
        "sast": "SAST",
        "uv": "uv",
    }
    banned = as_map(projected["banned_identifier_tokens"])
    for alias in ("ci", "checks", "quality", "lint", "test", "tests", "gates", "pr"):
        assert banned[alias] == "validate"
    for alias, token in {
        "cd": "deploy",
        "rollout": "deploy",
        "ship": "deploy",
        "maintenance": "maintain",
        "cleanup": "maintain",
        "drift": "monitor",
        "forensics": "audit",
    }.items():
        assert banned[alias] == token
    for alias in ("scheduled", "nightly", "cron", "weekly", "daily"):
        assert banned[alias] == "audit, monitor or maintain"
    assert projected["schedule_tokens"] == ["cron", "daily", "nightly", "scheduled", "weekly"]


def test_prose_aliases_do_not_leak_into_identifier_tokens(content: Content) -> None:
    banned = vocabulary.banned_identifier_tokens(content.terminology)
    assert "conventions manifest" not in banned
    assert "exception" not in banned


def test_base_profile_includes_every_non_retired_requirement(content: Content) -> None:
    profiles = as_map(_index(content)["profiles"])
    base = as_map(profiles["base-repo"])
    expected = [req.id for req in content.requirements if req.status != "retired"]
    assert sorted(as_list(base["requirements"]), key=str) == sorted(expected)
    assert as_map(base["severity"])["GHA-07"] == "warning"
    assert base["display_name"] == "Base repository"


def _resolve_with(content: Content, directory: Path) -> dict[str, ResolvedProfile]:
    profiles = content.profiles + load_profiles(content.product, directory)
    families = {family.prefix for family in content.families}
    return resolve_all(profiles, content.requirements, families)


def test_profile_inherits_excludes_and_raises(content: Content, fixtures: Path) -> None:
    resolved = _resolve_with(content, fixtures / "profiles" / "valid")
    strict = resolved["strict"]
    assert "GHA-06" not in strict.requirements
    assert strict.severity["GHA-07"] == "error"
    assert strict.severity["GHA-08"] == "warning"
    assert len(strict.requirements) == len(resolved["base-repo"].requirements) - 1
    assert resolved["strict-child"].requirements == strict.requirements


def test_proposed_requirements_need_an_opt_in(content: Content, fixtures: Path) -> None:
    resolved = _resolve_with(content, fixtures / "profiles" / "valid")
    assert resolved["actions-only"].requirements == ()


def test_retired_requirements_never_apply(content: Content) -> None:
    first = content.conventions[0]
    retired = replace(
        first.requirements[0],
        status="retired",
        replaced_by=(first.requirements[1].id,),
    )
    changed = replace(first, requirements=(retired, *first.requirements[1:]))
    edited = replace(content, conventions=(changed, *content.conventions[1:]))
    resolved = resolve_all(
        edited.profiles, edited.requirements, {family.prefix for family in edited.families}
    )
    assert retired.id not in resolved["base-repo"].requirements


@pytest.mark.parametrize(
    ("case", "message"),
    [
        ("cycle", "inheritance cycle"),
        ("lowers", "may only raise"),
        ("unknown", "unknown family NOPE"),
        ("stray", "does not select"),
    ],
)
def test_invalid_profiles_are_rejected(
    content: Content, fixtures: Path, case: str, message: str
) -> None:
    with pytest.raises(ProfileError, match=message):
        _resolve_with(content, fixtures / "profiles" / "invalid" / case)


def test_profile_cannot_lower_a_default_severity(content: Content) -> None:
    first = content.conventions[0]
    index, active = next(
        (i, req) for i, req in enumerate(first.requirements) if req.status != "retired"
    )
    raised = replace(active, severity="error")
    requirements = list(first.requirements)
    requirements[index] = raised
    changed = replace(first, requirements=tuple(requirements))
    edited = replace(content, conventions=(changed, *content.conventions[1:]))
    lowering = replace(content.profiles[0], severity={raised.id: "warning"})
    with pytest.raises(ProfileError, match=f"lowers {raised.id} from error to warning"):
        resolve_all((lowering,), edited.requirements, {"ADOPT", "GHA", "OUT"})


def test_vale_styles_are_substitutions(content: Content) -> None:
    outputs = {output.path.name: output.text for output in generate.build_outputs(content)}
    terms = outputs["Terms.yml"]
    assert "extends: substitution" in terms
    assert "level: error" in terms
    assert '"conventions manifest": "conventions declaration"' in terms
    assert "exception" not in terms
    discouraged = outputs["Discouraged.yml"]
    assert "level: warning" in discouraged


def test_empty_style_is_still_valid_yaml() -> None:
    text = generate.render_vale_style([], level="error", message="Use '%s' instead of '%s'.")
    assert "swap: {}" in text


def test_vale_accepts_the_generated_styles(product: Path, tmp_path: Path) -> None:
    executable = shutil.which("vale")
    assert executable, "vale must be on PATH (see .devcontainer/mise.toml)"
    styles = product / "checks" / "vale"
    (tmp_path / ".vale.ini").write_text(
        f"StylesPath = {styles}\nMinAlertLevel = suggestion\n"
        "[*.md]\nBasedOnStyles = MusherConventions\n",
        encoding="utf-8",
    )
    (tmp_path / "sample.md").write_text(
        "# Sample\n\nThe conventions manifest grants a waiver.\n", encoding="utf-8"
    )
    completed = subprocess.run(
        [executable, "--output", "JSON", "sample.md"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
    )
    alerts = as_list(as_map(json.loads(completed.stdout)).get("sample.md"))
    checks = sorted(str(as_map(alert).get("Check")) for alert in alerts)
    assert checks == ["MusherConventions.Terms"]


def test_readme_lists_every_requirement(content: Content) -> None:
    readme = generate.render_readme(content)
    assert readme.startswith("# Conventions\n")
    assert "Do not edit" in readme
    for req in content.requirements:
        assert f"[{req.id}](" in readme
    assert "\\<Subject\\>" in readme


def _copy_product(product: Path, tmp_path: Path) -> Path:
    copy = tmp_path / "product"
    for name in ("definitions", "checks"):
        shutil.copytree(product / name, copy / name)
    return copy


def test_generate_check_reports_drift(
    product: Path,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    copy = _copy_product(product, tmp_path)
    monkeypatch.setenv(HOME_ENV, str(copy))
    assert main(["generate", "--check"]) == 0
    index = copy / "checks" / "data" / "index.json"
    index.write_text(index.read_text(encoding="utf-8").replace('"GHA-07"', '"GHA-7"', 1))
    assert main(["generate", "--check"]) == 1
    output = capsys.readouterr().out
    assert "--- checks/data/index.json (committed)" in output
    assert "+++ checks/data/index.json (generated)" in output
    assert index.read_text(encoding="utf-8").count('"GHA-7"') == 1
    assert main(["generate"]) == 0
    assert main(["generate", "--check"]) == 0
