import copy
import shutil
import subprocess
from pathlib import Path

import pytest

from conventions_tools import classify, invariants
from conventions_tools.classify import Rank
from conventions_tools.cli import main
from conventions_tools.loading import ContentError, as_map, get_str_list
from conventions_tools.paths import HOME_ENV


@pytest.fixture
def index(product: Path) -> dict[str, object]:
    return classify.current_index(product)


def _edited(index: dict[str, object], *path: str) -> tuple[dict[str, object], dict[str, object]]:
    """A deep copy of `index` and the map at `path` inside it, to edit."""
    after = copy.deepcopy(index)
    node = after
    for key in path:
        node = as_map(node[key])
    return after, node


def _ranked(before: dict[str, object], after: dict[str, object]) -> list[tuple[Rank, str]]:
    return [(change.rank, change.description) for change in classify.diff(before, after)]


def test_an_unchanged_index_implies_nothing(index: dict[str, object]) -> None:
    assert classify.diff(index, copy.deepcopy(index)) == []
    assert classify.minimum([]) is Rank.NONE


@pytest.mark.parametrize(
    ("title", "rank", "label"),
    [
        ("feat!: drop a token", Rank.BREAKING, "feat!"),
        ("fix(checks)!: make GHA-07 an error", Rank.BREAKING, "fix(checks)!"),
        ("feat(conventions): add GHA-50", Rank.FEAT, "feat(conventions)"),
        ("fix(checks): stop a false positive", Rank.FIX, "fix(checks)"),
        ("perf(cli): faster", Rank.FIX, "perf(cli)"),
        ("docs: clarify", Rank.NONE, "docs"),
        ("ci(cli): add a step", Rank.NONE, "ci(cli)"),
    ],
)
def test_title_rank(title: str, rank: Rank, label: str) -> None:
    parsed = classify.parse_title(title)
    assert parsed.rank is rank
    assert parsed.label == label


def test_a_title_that_is_not_a_conventional_commit_fails() -> None:
    with pytest.raises(ContentError, match="is not a Conventional Commit"):
        classify.parse_title("Update things")


def test_requirement_changes(index: dict[str, object]) -> None:
    after, requirements = _edited(index, "requirements")
    gha07 = as_map(requirements["GHA-07"])
    gha08 = as_map(requirements["GHA-08"])
    gha09 = as_map(requirements["GHA-09"])
    gha10 = as_map(requirements["GHA-10"])
    gha07["severity"] = "error"
    gha08["status"] = "active"
    gha09["title"] = "Something else"
    gha09["waivable"] = False
    gha10["status"] = "retired"
    gha10["path"] = "elsewhere.md"
    requirements["GHA-98"] = {**gha08, "severity": "warning"}
    requirements["GHA-99"] = {**gha08, "severity": "error"}
    del requirements["GHA-11"]
    assert _ranked(index, after) == [
        (Rank.BREAKING, "requirement GHA-07 becomes error (was warning)"),
        (Rank.BREAKING, "requirement GHA-11 removed from the index"),
        (Rank.BREAKING, "new requirement GHA-99 at error"),
        (Rank.FEAT, "requirement GHA-08 activated"),
        (Rank.FEAT, "requirement GHA-09 can no longer be waived"),
        (Rank.FEAT, "new requirement GHA-98"),
        (Rank.FIX, "requirement GHA-09 title changed"),
        (Rank.FIX, "requirement GHA-10 path changed"),
        (Rank.FIX, "requirement GHA-10 status changed from proposed to retired"),
    ]


def test_profile_changes(index: dict[str, object]) -> None:
    before = copy.deepcopy(index)
    as_map(as_map(as_map(before["profiles"])["tool"])["severity"])["GHA-07"] = "error"
    after, profiles = _edited(index, "profiles")
    base = as_map(profiles["base-repo"])
    selected = get_str_list(base, "requirements")
    # GHA-98 is new to the index, so only its own entry lists it; GHA-99 is not.
    as_map(before["requirements"])["GHA-99"] = {}
    as_map(after["requirements"])["GHA-99"] = {}
    as_map(after["requirements"])["GHA-98"] = {}
    base["requirements"] = [*selected[1:], "GHA-98", "GHA-99"]
    as_map(base["severity"])["GHA-07"] = "error"
    base["display_name"] = "Renamed"
    profiles["new-kind"] = {"display_name": "New", "requirements": [], "severity": {}}
    del profiles["website"]
    assert _ranked(before, after) == [
        (Rank.BREAKING, "profile base-repo makes GHA-07 error"),
        (Rank.BREAKING, "profile website removed"),
        (Rank.FEAT, "profile base-repo now selects GHA-99"),
        (Rank.FEAT, "new profile new-kind"),
        (Rank.FEAT, "new requirement GHA-98"),
        (Rank.FIX, f"profile base-repo no longer selects {selected[0]}"),
        (Rank.FIX, "profile base-repo display_name changed"),
        (Rank.FIX, "profile tool changes severity of GHA-07"),
    ]


def test_vocabulary_changes(index: dict[str, object]) -> None:
    after, vocabulary = _edited(index, "vocabulary")
    systems = get_str_list(vocabulary, "repository_systems")
    vocabulary["repository_systems"] = [*[s for s in systems if s != "brand"], "newsys"]
    display = as_map(vocabulary["display_forms"])
    display["cli"] = "Cli"
    display["k8s"] = "K8s"
    banned = as_map(vocabulary["banned_identifier_tokens"])
    del banned["cd"]
    banned["zz"] = "validate"
    banned["ci"] = "check"
    vocabulary["schedule_tokens"] = ["hourly"]
    assert _ranked(index, after) == [
        (Rank.BREAKING, "display_forms: changed cli"),
        (Rank.BREAKING, "repository_systems: removed brand"),
        (Rank.FEAT, "banned_identifier_tokens: newly banned zz"),
        (Rank.FEAT, "display_forms: added k8s"),
        (Rank.FEAT, "repository_systems: added newsys"),
        (Rank.FEAT, "schedule_tokens: newly banned hourly"),
        (Rank.FIX, "banned_identifier_tokens: no longer banned cd"),
        (Rank.FIX, "banned_identifier_tokens: advice changed for ci"),
        (Rank.FIX, "schedule_tokens: no longer banned cron, daily, nightly, scheduled, weekly"),
    ]


def test_schema_conventions_and_other_changes(index: dict[str, object]) -> None:
    after, schema = _edited(index, "declaration_schema")
    schema["description"] = "Reworded, which changes no declaration's validity"
    assert classify.diff(index, after) == []
    schema["required"] = [*get_str_list(schema, "required"), "extra"]
    conventions = as_map(after["conventions"])
    as_map(conventions["EC-0001"])["title"] = "Renamed"
    conventions["EC-9999"] = {"title": "New"}
    del conventions["EC-0002"]
    after["schema_version"] = 99
    assert _ranked(index, after) == [
        (Rank.BREAKING, "convention EC-0002 removed from the index"),
        (
            Rank.FEAT,
            "declaration_schema changed what it accepts (feat if relaxed, feat! if tighter)",
        ),
        (Rank.FIX, "convention EC-0001 title changed"),
        (Rank.FIX, "new convention EC-9999"),
        (Rank.FIX, "schema_version changed"),
    ]


def _verdict(title: str, *changes: classify.Change) -> classify.Verdict:
    return classify.Verdict(classify.parse_title(title), changes)


def test_a_type_below_the_minimum_fails_naming_the_driving_changes() -> None:
    verdict = _verdict(
        "fix(checks): tweak",
        classify.Change(Rank.FEAT, "new requirement GHA-98"),
        classify.Change(Rank.FIX, "requirement GHA-09 title changed"),
    )
    assert not verdict.passed
    report = verdict.report()
    assert "type fix(checks) is below the change class the index diff implies, feat" in report
    assert "  feat   new requirement GHA-98" in report
    assert "GHA-09" not in report
    assert report.rstrip().endswith("#change-classification")


@pytest.mark.parametrize("title", ["feat: add", "feat!: add", "refactor!: add"])
def test_a_type_at_or_above_the_minimum_passes(title: str) -> None:
    verdict = _verdict(title, classify.Change(Rank.FEAT, "new requirement GHA-98"))
    assert verdict.passed
    assert "meets the change class the index diff implies (feat)" in verdict.report()


@pytest.fixture
def unchanged(monkeypatch: pytest.MonkeyPatch) -> None:
    """The working tree's index is HEAD's, whatever a local checkout has regenerated."""

    def at_head(product: Path) -> dict[str, object]:
        return as_map(invariants.baseline_index(product, "HEAD"))

    monkeypatch.setattr(classify, "current_index", at_head)


@pytest.mark.usefixtures("unchanged")
def test_no_change_allows_any_type(product: Path) -> None:
    verdict = classify.classify(product, "HEAD", "docs: clarify")
    assert verdict.passed
    assert verdict.minimum is Rank.NONE


@pytest.mark.parametrize(
    ("baseline", "title", "reason"),
    [
        ("0000000000000000000000000000000000000000", "docs: x", "no baseline (0000"),
        ("", "docs: x", "no baseline (empty)"),
        ("no-such-ref-anywhere", "chore(release): release 9.9.9", "a release pull request"),
    ],
)
def test_skips(product: Path, baseline: str, title: str, reason: str) -> None:
    verdict = classify.classify(product, baseline, title)
    assert verdict.passed
    assert verdict.report().startswith(f"classify: {reason}")


def test_unresolvable_baseline_fails(product: Path) -> None:
    with pytest.raises(ContentError, match="does not resolve to a commit"):
        classify.classify(product, "no-such-ref-anywhere", "feat: x")


def test_baseline_that_predates_the_index_is_skipped(tmp_path: Path) -> None:
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
    verdict = classify.classify(tmp_path, "HEAD", "docs: x")
    assert verdict.skipped == "HEAD predates index.json"


def test_unreadable_index_fails(tmp_path: Path) -> None:
    with pytest.raises(ContentError, match="cannot read the index"):
        classify.current_index(tmp_path)


@pytest.mark.usefixtures("unchanged")
def test_cli_exit_codes(
    product: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setenv(HOME_ENV, str(product))
    assert main(["classify", "--baseline", "HEAD", "--title", "docs: clarify"]) == 0
    assert "meets the change class" in capsys.readouterr().out
    assert main(["classify", "--baseline", "HEAD", "--title", "Not a title"]) == 2
    assert "is not a Conventional Commit" in capsys.readouterr().err

    def breaking(_before: object, _after: object) -> list[classify.Change]:
        return [classify.Change(Rank.BREAKING, "display_forms: changed cli")]

    monkeypatch.setattr(classify, "diff", breaking)
    assert main(["classify", "--baseline", "HEAD", "--title", "feat: x"]) == 1
    assert "because of:\n  feat!  display_forms: changed cli" in capsys.readouterr().out
