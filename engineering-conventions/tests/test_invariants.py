import shutil
import subprocess
from dataclasses import replace
from pathlib import Path

import pytest

from conventions_tools import invariants
from conventions_tools.cli import main
from conventions_tools.content import Content, Convention, load_profiles, load_terminology
from conventions_tools.paths import HOME_ENV


def _with_convention(content: Content, index: int, convention: Convention) -> Content:
    conventions = list(content.conventions)
    conventions[index] = convention
    return replace(content, conventions=tuple(conventions))


def test_every_invariant_holds(product: Path) -> None:
    assert invariants.check_all(product) == []


def test_cli_invariants_exits_zero(product: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv(HOME_ENV, str(product))
    assert main(["invariants"]) == 0


def test_duplicate_requirement_id_is_reported(content: Content) -> None:
    first = content.conventions[0]
    duplicated = replace(first, requirements=(*first.requirements, first.requirements[0]))
    problems = invariants.ids_unique(_with_convention(content, 0, duplicated))
    assert problems == [f"requirement ID {first.requirements[0].id} is declared more than once"]


def test_unregistered_family_is_reported(content: Content) -> None:
    first = content.conventions[0]
    stray = replace(first.requirements[0], id="NOPE-01")
    edited = _with_convention(content, 0, replace(first, requirements=(stray,)))
    assert any("unregistered family NOPE" in p for p in invariants.families_registered(edited))


def test_family_topic_must_match_convention_topic(content: Content) -> None:
    adoption = next(c for c in content.conventions if c.topic == "adoption")
    index = content.conventions.index(adoption)
    moved = replace(adoption.requirements[0], id="GHA-99")
    edited = _with_convention(content, index, replace(adoption, requirements=(moved,)))
    assert any(
        "whose topic is 'github-actions'" in p for p in invariants.families_registered(edited)
    )


def test_replaced_by_must_resolve(content: Content) -> None:
    first = content.conventions[0]
    retired = replace(first.requirements[0], status="retired", replaced_by=("GHA-98",))
    edited = _with_convention(
        content, 0, replace(first, requirements=(retired, *first.requirements[1:]))
    )
    assert any("unknown requirement GHA-98" in p for p in invariants.references_resolve(edited))


@pytest.mark.parametrize(
    ("body", "expected"),
    [
        ("", "has no '### {id}' heading"),
        ("### {id}\n\n**{title}**\n\n### {id}\n\n**{title}**\n", "appears 2 times"),
        ("### {id}\n\nNot bold.\n", "must be its title in bold"),
        ("### {id}\n\n**Something else entirely**\n", "must be its title in bold"),
        ("### {id}\n\n**{title}**\n\n### ZZZ-01\n", "ZZZ-01 is not a requirement declared"),
    ],
    ids=["missing", "duplicated", "not-bold", "wrong-title", "undeclared"],
)
def test_heading_problems(content: Content, body: str, expected: str) -> None:
    first = content.conventions[0]
    req = first.requirements[0]
    single = replace(
        first,
        requirements=(req,),
        body=body.format(id=req.id, title=req.title),
    )
    problems = invariants.headings_present(_with_convention(content, 0, single))
    assert any(expected.format(id=req.id) in p for p in problems), problems


def test_heading_title_may_be_formatted(content: Content) -> None:
    first = content.conventions[0]
    req = replace(first.requirements[0], title="A workflow's name is action.yml")
    body = f"### {req.id}\n\n**A workflow's name is `action.yml`.**\n"
    single = replace(first, requirements=(req,), body=body)
    assert invariants.headings_present(_with_convention(content, 0, single)) == []


def _product_copy(product: Path, tmp_path: Path) -> Path:
    copy = tmp_path / "product"
    for name in ("conventions", "profiles", "terminology", "checks", "tests/fixtures/repos"):
        if (product / name).exists():
            shutil.copytree(product / name, copy / name)
    return copy


def test_rego_emitting_an_undeclared_id_is_reported(
    content: Content, product: Path, tmp_path: Path
) -> None:
    copy = _product_copy(product, tmp_path)
    extra = copy / "checks" / "rego" / "extra.rego"
    extra.write_text(
        'package conventions.checks.extra.stray\n\nfindings contains {"id": "GHA-99"} if true\n',
        encoding="utf-8",
    )
    problems = invariants.rego_ids(replace(content, product=copy))
    assert "checks/rego/extra.rego: emits GHA-99, which no convention declares" in problems


def test_conftest_requirement_without_emitter_is_reported(
    content: Content, product: Path, tmp_path: Path
) -> None:
    copy = _product_copy(product, tmp_path)
    for rego in (copy / "checks" / "rego").rglob("*.rego"):
        text = rego.read_text(encoding="utf-8")
        rego.write_text(text.replace('"GHA-07"', '"GHA-7"'), encoding="utf-8")
    problems = invariants.rego_ids(replace(content, product=copy))
    assert (
        "GHA-07: package conventions.checks.github_actions.workflow_files never emits GHA-07"
        in problems
    )


def test_missing_fixture_coverage_is_reported(
    content: Content, product: Path, tmp_path: Path
) -> None:
    copy = _product_copy(product, tmp_path)
    repos = copy / "tests" / "fixtures" / "repos"
    for case in repos.glob("*/expected.json"):
        if case.parent.name != "clean":
            shutil.rmtree(case.parent)
    problems = invariants.fixtures_cover(replace(content, product=copy))
    assert any(p.startswith("GHA-07: no fixture repository expects it") for p in problems)
    assert not any(p.startswith("GHA-25") for p in problems)


def test_missing_clean_fixture_is_reported(content: Content, product: Path, tmp_path: Path) -> None:
    copy = _product_copy(product, tmp_path)
    shutil.rmtree(copy / "tests" / "fixtures" / "repos" / "clean", ignore_errors=True)
    problems = invariants.fixtures_cover(replace(content, product=copy))
    assert any("clean/ is missing" in p for p in problems)


def test_valid_overlay_is_accepted(content: Content, fixtures: Path) -> None:
    overlay = load_terminology(
        content.product, fixtures / "terminology" / "valid" / "example-area.yml"
    )
    edited = replace(content, areas=(overlay,))
    assert invariants.terminology_consistent(edited) == []


@pytest.mark.parametrize(
    ("name", "expected"),
    [
        ("redefines-term", "redefines a term that already exists"),
        ("redefines-display-form", "redefines a global display form"),
        ("alias-conflict", "alias 'ci' (identifier) belongs to more than one term"),
        ("unknown-extend", "extends unknown global term gha.responsibility.observe"),
        ("wrong-area-name", "area must be the file's name"),
    ],
)
def test_overlay_cannot_redefine_global_terms(
    content: Content, fixtures: Path, name: str, expected: str
) -> None:
    path = fixtures / "terminology" / "invalid" / "overlay" / f"{name}.yml"
    edited = replace(content, areas=(load_terminology(content.product, path),))
    problems = invariants.terminology_consistent(edited)
    assert any(expected in p for p in problems), problems


def test_profile_cycle_is_reported(content: Content, fixtures: Path) -> None:
    cycle = load_profiles(content.product, fixtures / "profiles" / "invalid" / "cycle")
    edited = replace(content, profiles=content.profiles + cycle)
    assert any("inheritance cycle" in p for p in invariants.profiles_resolve(edited))


def test_removed_or_moved_ids_break_append_only(content: Content) -> None:
    baseline: dict[str, object] = {
        "conventions": {"EC-0001": {}, "EC-0999": {}},
        "requirements": {
            "GHA-07": {"convention": "EC-0003", "status": "proposed"},
            "GHA-98": {"convention": "EC-0002", "status": "retired"},
        },
    }
    problems = invariants.compare_to_baseline(content, baseline, "v0.1.0")
    assert problems == [
        "convention EC-0999 existed at v0.1.0 and has been removed; "
        "set its status to retired instead",
        "requirement GHA-07 moved from EC-0003 to EC-0002; an ID never changes convention",
        "requirement GHA-98 existed at v0.1.0 and has been removed; retire it instead",
    ]


def test_unretiring_breaks_append_only(content: Content) -> None:
    baseline: dict[str, object] = {
        "conventions": {},
        "requirements": {"GHA-07": {"convention": "EC-0002", "status": "retired"}},
    }
    problems = invariants.compare_to_baseline(content, baseline, "v0.1.0")
    assert problems == ["requirement GHA-07 was retired at v0.1.0; a retired ID is never reused"]


@pytest.mark.parametrize("ref", ["", "  ", "0000000000000000000000000000000000000000"])
def test_no_baseline_skips_append_only_with_a_notice(
    content: Content, ref: str, capsys: pytest.CaptureFixture[str]
) -> None:
    assert invariants.append_only(content, ref) == []
    assert "skipping the append-only check" in capsys.readouterr().err


def test_unresolvable_baseline_fails(content: Content) -> None:
    assert invariants.append_only(content, "no-such-ref-anywhere") == [
        "--baseline 'no-such-ref-anywhere' does not resolve to a commit; fetch it "
        "(e.g. git fetch origin main) or pass a ref that exists"
    ]


def test_baseline_without_git_fails(content: Content, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("PATH", "")
    assert invariants.append_only(content, "HEAD") == [
        "git is not on PATH, so the append-only check cannot run"
    ]


def test_baseline_that_predates_the_index_is_skipped(content: Content, tmp_path: Path) -> None:
    git = shutil.which("git")
    assert git
    subprocess.run([git, "init", "-q", str(tmp_path)], check=True)
    subprocess.run(
        [
            git,
            "-C",
            str(tmp_path),
            "-c",
            "user.name=t",
            "-c",
            "user.email=t@example.com",
            "commit",
            "-q",
            "--allow-empty",
            "-m",
            "empty",
        ],
        check=True,
    )
    assert invariants.append_only(replace(content, product=tmp_path), "HEAD") == []


def test_family_unread_by_waiver_checks_is_reported(
    content: Content, product: Path, tmp_path: Path
) -> None:
    copy = _product_copy(product, tmp_path)
    layout = copy / "checks" / "rego" / "layout"
    layout.mkdir()
    (layout / "structure.rego").write_text(
        "package conventions.checks.layout.structure\n", encoding="utf-8"
    )
    problems = invariants.waivers_see_every_family(replace(content, product=copy))
    assert problems == [
        "checks/rego/adoption/declaration.rego does not read data.conventions.checks.layout, "
        "so ADOPT-06 cannot see the findings its waivers cover; add it to raw_findings"
    ]
