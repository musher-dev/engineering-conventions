import json
import shutil
import subprocess
from dataclasses import replace
from pathlib import Path

import pytest

from conventions_tools import generate, vocabulary
from conventions_tools.cli import main
from conventions_tools.content import Content, load_profiles
from conventions_tools.loading import ContentError, as_list, as_map
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
        "copy",
        "decision_schema",
        "declaration_schema",
        "dependencies_schema",
        "discussion_forms_schema",
        "env_schema",
        "funding_schema",
        "issue_config_schema",
        "issue_forms_schema",
        "outputs_schema",
        "product_dir",
        "profiles",
        "release_record_schema",
        "repository",
        "repository_schema",
        "requirements",
        "schema_version",
        "skill_frontmatter_schema",
        "subagent_frontmatter_schema",
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
        "notify",
        "publish",
        "release",
        "repository",
        "validate",
        "verify",
    ]
    assert projected["capability_tokens"] == ["build", "check", "promote"]
    assert projected["action_tokens"] == ["authenticate", "check", "install", "setup", "sync"]
    assert projected["action_synonyms"] == {
        "auth": "authenticate",
        "validate": "check",
        "verify": "check",
    }
    assert projected["output_kinds"] == [
        "bundle",
        "cli",
        "image",
        "library",
        "site",
        "vmimage",
    ]
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
    assert projected["interface_formats"] == [
        "asyncapi",
        "data",
        "env-schema",
        "json-schema",
        "openapi",
        "protobuf",
        "systemd-unit",
        "weaver",
    ]
    assert projected["interface_compatibilities"] == ["gated", "lockstep", "versioned"]
    assert "postgresql" in as_list(projected["runtime_capabilities"])


def test_repository_vocabulary_projection(content: Content) -> None:
    projected = as_map(_index(content)["vocabulary"])
    assert projected["repository_systems"] == [
        "brand",
        "catalog",
        "company",
        "engineering",
        "host",
        "infra",
        "observability",
        "platform",
        "sdk",
    ]
    assert projected["repository_kinds"] == [
        "content",
        "documentation",
        "infrastructure",
        "library",
        "service",
        "specification",
        "template",
        "tool",
        "website",
    ]
    assert projected["repository_lifecycles"] == ["deprecated", "experimental", "production"]
    assert projected["repository_audiences"] == ["internal", "public"]
    banned = as_map(projected["banned_repository_tokens"])
    assert sorted(banned) == [
        "common",
        "legacy",
        "misc",
        "musher",
        "new",
        "old",
        "repo",
        "shared",
        "util",
        "utils",
    ]
    assert 'lifecycle = "experimental"' in str(banned["new"])


def test_repository_name_tokens_do_not_leak_into_other_scopes(content: Content) -> None:
    identifiers = vocabulary.banned_identifier_tokens(content.terminology)
    prose = {swap.text for swap in vocabulary.prose_swaps(content.terminology, "banned")}
    for token in ("musher", "repo", "shared", "utils", "new", "old"):
        assert token not in identifiers
        assert token not in prose


def test_action_synonyms_do_not_leak_into_other_scopes(content: Content) -> None:
    # They only drive GHA-20's suggestion: validate and verify stay workflow
    # responsibility tokens, so no banned list may carry them.
    identifiers = vocabulary.banned_identifier_tokens(content.terminology)
    repository = vocabulary.banned_repository_tokens(content.terminology)
    prose = {swap.text for swap in vocabulary.prose_swaps(content.terminology, "banned")}
    for token in ("auth", "validate", "verify"):
        assert token not in identifiers
        assert token not in repository
        assert token not in prose


def test_action_synonyms_need_an_action_term(content: Content) -> None:
    term = next(t for t in content.terminology.terms if t.id == "gha.responsibility.notify")
    alias = vocabulary.Alias("tell", "banned", ("action-token",), None, None)
    stray = replace(term, aliases=(alias,))
    terms = tuple(stray if t.id == term.id else t for t in content.terminology.terms)
    with pytest.raises(vocabulary.ContentError):
        vocabulary.action_synonyms(replace(content.terminology, terms=terms))


def test_index_carries_a_self_contained_repository_schema(content: Content) -> None:
    schema = as_map(_index(content)["repository_schema"])
    assert "common.schema.json" not in json.dumps(schema)
    assert "tier" in as_list(schema["required"])


def test_prose_aliases_do_not_leak_into_identifier_tokens(content: Content) -> None:
    banned = vocabulary.banned_identifier_tokens(content.terminology)
    assert "conventions manifest" not in banned
    assert "exception" not in banned


# Requirements only a kind's own profile selects: the build, test and dev
# tasks (EC-0016) and a service's environment contract (EC-0019).
KIND_SPECIFIC = {
    "TASK-11": "library",
    "TASK-12": "service",
    "ENVS-01": "service",
    "TOFU-01": "infrastructure",
    "IFACE-08": "service",
}


def test_base_profile_includes_every_non_retired_requirement(content: Content) -> None:
    profiles = as_map(_index(content)["profiles"])
    base = as_map(profiles["base-repo"])
    expected = [
        req.id
        for req in content.requirements
        if req.status != "retired" and req.id not in KIND_SPECIFIC
    ]
    assert sorted(as_list(base["requirements"]), key=str) == sorted(expected)
    for requirement, kind in KIND_SPECIFIC.items():
        assert requirement in as_list(as_map(profiles[kind])["requirements"])
    assert as_map(base["severity"])["GHA-07"] == "warning"
    assert base["display_name"] == "Base repository"


def test_kind_profiles_add_their_own_task_verbs(content: Content) -> None:
    profiles = as_map(_index(content)["profiles"])
    base = set(as_list(as_map(profiles["base-repo"])["requirements"]))
    added = {
        name: set(as_list(as_map(profiles[name])["requirements"])) - base
        for name in ("library", "tool", "website", "service", "specification")
    }
    assert added == {
        "library": {"TASK-11", "IFACE-08"},
        "tool": {"TASK-11", "IFACE-08"},
        "website": {"TASK-11", "IFACE-08"},
        "service": {"TASK-11", "TASK-12", "ENVS-01", "IFACE-08"},
        "specification": set(),
    }


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
        resolve_all((lowering,), edited.requirements, {family.prefix for family in edited.families})


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
    assert executable, "vale must be on PATH (see .config/mise/config.toml)"
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


def test_index_copy_block(content: Content) -> None:
    assert _index(content)["copy"] == {
        "based_on": ["MusherCopy", "proselint", "write-good"],
        "locked_rules": ["MusherCopy.Banned", "MusherCopy.Placeholders"],
        "package": "MusherProse",
        "release_url": "https://github.com/musher-dev/engineering-conventions/releases/download",
        "style": "MusherCopy",
        "template_formats": dict(content.copy_style.template_formats),
    }
    assert as_map(as_map(_index(content)["copy"])["template_formats"])["svelte"] == "html"


def test_a_vale_requirement_records_its_style(content: Content) -> None:
    requirements = as_map(_index(content)["requirements"])
    assert as_map(requirements["COPY-05"])["style"] == "MusherCopy.Banned"
    assert "style" not in as_map(requirements["GHA-07"])


def test_each_copy_rule_links_to_its_requirement(content: Content) -> None:
    outputs = {output.path.name: output.text for output in generate.build_outputs(content)}
    assert (
        outputs["Banned.yml"].count(
            '"https://github.com/musher-dev/engineering-conventions/blob/main/engineering-conventions/'
            'definitions/conventions/copy/public-copy.md#copy-05"'
        )
        == 1
    )
    assert "level: error" in outputs["Banned.yml"]
    assert "ignorecase: true" in outputs["Banned.yml"]
    assert "ignorecase" not in outputs["SentenceAverage.yml"]


def test_adopted_packages_are_pinned_to_their_version(content: Content) -> None:
    for item in content.copy_style.adopted:
        assert f"/releases/download/v{item.version}/{item.style}.zip" in item.package


def test_the_package_config_installs_and_toggles_the_adopted_packages(content: Content) -> None:
    text = generate.render_package_config(content.copy_style)
    packages = next(line for line in text.splitlines() if line.startswith("Packages = "))
    assert packages.count("https://github.com/vale-cli/") == len(content.copy_style.adopted)
    assert "\nwrite-good.Passive = NO\n" in text
    assert "\nMicrosoft.Wordiness = YES\n" in text
    assert "BasedOnStyles" not in text
    # The toggles reach copy files, never a code file's comments.
    section = next(line for line in text.splitlines() if line.startswith("["))
    assert section == f"[*.{{{','.join(generate.copy_extensions(content.copy_style))}}}]"
    assert "svelte" in section
    assert ",ts," not in section


def test_a_rule_without_a_requirement_fails_generation(content: Content) -> None:
    style = content.copy_style
    extra = replace(style.rules[0], name="Unclaimed")
    edited = replace(content, copy_style=replace(style, rules=(*style.rules, extra)))
    with pytest.raises(ContentError, match=r"MusherCopy\.Unclaimed needs exactly one requirement"):
        generate.build_outputs(edited)


def test_a_removed_rule_is_stale(content: Content, product: Path, tmp_path: Path) -> None:
    copy = _copy_product(product, tmp_path)
    leftover = copy / "checks" / "vale" / "MusherCopy" / "Retired.yml"
    leftover.write_text("extends: existence\n", encoding="utf-8")
    outputs = generate.build_outputs(replace(content, product=copy))
    assert generate.stale(outputs, copy) == [leftover]
    drifted = generate.drift(outputs, copy)
    assert any("Retired.yml: committed, but nothing generates it" in d for d in drifted)
    generate.write(outputs, copy)
    assert not leftover.exists()


COPY_SAMPLE = """# Sample

Our seamless platform is coming soon. It is really powerful.

Plain words that say what the product does.
"""


def test_vale_accepts_the_copy_style(product: Path, tmp_path: Path) -> None:
    executable = shutil.which("vale")
    assert executable, "vale must be on PATH (see .config/mise/config.toml)"
    styles = product / "checks" / "vale"
    (tmp_path / ".vale.ini").write_text(
        f"StylesPath = {styles}\nMinAlertLevel = suggestion\n[*.md]\nBasedOnStyles = MusherCopy\n",
        encoding="utf-8",
    )
    (tmp_path / "sample.md").write_text(COPY_SAMPLE, encoding="utf-8")
    completed = subprocess.run(
        [executable, "--output", "JSON", "sample.md"],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
    )
    alerts = as_list(as_map(json.loads(completed.stdout)).get("sample.md"))
    found = sorted({(str(as_map(a).get("Check")), str(as_map(a).get("Match"))) for a in alerts})
    assert found == [
        ("MusherCopy.Banned", "seamless"),
        ("MusherCopy.Filler", "really"),
        ("MusherCopy.Generic", "powerful"),
        ("MusherCopy.Placeholders", "coming soon"),
    ]
