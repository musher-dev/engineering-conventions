"""`conventions release changes`: a release's change manifest (decision 0045).

Each case in fixtures/release-changes/ is a real release, recorded with gh:
`<case>.github.json` holds every answer GitHub gave the command, under the
name the stand-in below asks for it by, and `<case>.changes.json` what the
command wrote from them. The releases' repositories are private and this one
is public, so each answer was reduced to the fields the command reads, and
every title, commit message and changelog line keeps only its structure (its
Conventional Commits header, its (#N) references, BREAKING CHANGE footers and
links) with its prose withheld. Commits, pull requests, numbers and times are
GitHub's. No test reaches the network.
"""

import json
import os
import re
import subprocess
from collections.abc import Callable
from pathlib import Path
from typing import NamedTuple

import pytest

from conventions_tools import schemas
from conventions_tools.loading import as_list, as_map, get_str, read_json
from conventions_tools.paths import product_dir

PRODUCT = product_dir()
LAUNCHER = PRODUCT / "bin" / "conventions"
RELEASES = PRODUCT / "tests" / "fixtures" / "release-changes"

# Set to rewrite each case's <case>.changes.json after a deliberate change to
# bin/changes.jq; read the diff before committing it.
UPDATE = "CONVENTIONS_UPDATE_CHANGES"

# Where the launcher learns the repository; cleared so a run in GitHub
# Actions tests the same thing as a run anywhere else.
NAME_SOURCES = ("CONVENTIONS_REPOSITORY", "GITHUB_REPOSITORY", "GITHUB_WORKSPACE")

# A stand-in for gh: it names each `gh api` call as a URL would, by its
# endpoint, the GraphQL operation it sends and its fields, sorted, as the
# query; logs the name; and prints every page recorded under it, or fails as
# GitHub does for something that does not exist.
GH_STUB = r"""#!/bin/sh
here=$(dirname "$0")
shift
endpoint='' operation='' fields=''
while [ $# -gt 0 ]; do
  case $1 in
    -f | -F | --raw-field | --field)
      case $2 in
        query=*)
          operation=$(printf '%s\n' "${2#query=}" | sed -n '1s/^query \([A-Za-z]*\).*/\1/p') ;;
        *) fields="${fields}
$2" ;;
      esac
      shift 2 ;;
    -H | --header | -X | --method) shift 2 ;;
    -*) shift ;;
    *) endpoint=$1; shift ;;
  esac
done
sorted=$(printf '%s\n' "${fields}" | sed '/^$/d' | LC_ALL=C sort | tr '\n' '&')
key="${endpoint}${operation:+ ${operation}}${sorted:+?${sorted%&}}"
printf '%s\n' "${key}" >> "${here}/calls"
if jq -e --arg key "${key}" '.responses | has($key)' "${here}/github.json" > /dev/null; then
  jq -r --arg key "${key}" '.responses[$key][] | if type == "string" then . else tojson end' \
    "${here}/github.json"
  exit 0
fi
echo 'gh: Not Found (HTTP 404)' >&2
exit 1
"""

CASES = sorted(path.name.removesuffix(".github.json") for path in RELEASES.glob("*.github.json"))


def _recorded(case: str) -> dict[str, object]:
    return as_map(read_json(RELEASES / f"{case}.github.json"))


def _responses(release: dict[str, object]) -> dict[str, object]:
    return as_map(release["responses"])


def _stub(tmp_path: Path, release: dict[str, object]) -> Path:
    stub = tmp_path / "stub"
    stub.mkdir()
    (stub / "gh").write_text(GH_STUB)
    (stub / "gh").chmod(0o755)
    (stub / "github.json").write_text(json.dumps(release))
    return stub


def _launch(
    *arguments: str, cwd: Path, stub: Path, env: dict[str, str] | None = None
) -> subprocess.CompletedProcess[str]:
    environment = {key: value for key, value in os.environ.items() if key not in NAME_SOURCES}
    environment |= {"CONVENTIONS_NO_MISE": "1", "PATH": f"{stub}{os.pathsep}{os.environ['PATH']}"}
    return subprocess.run(
        [str(LAUNCHER), *arguments],
        cwd=cwd,
        capture_output=True,
        text=True,
        check=False,
        env=environment | (env or {}),
    )


def _write(
    tmp_path: Path, release: dict[str, object], *arguments: str
) -> tuple[dict[str, object], list[str]]:
    """The manifest the command writes for a recorded release, and the calls it made."""
    stub = _stub(tmp_path, release)
    completed = _launch(
        "release",
        "changes",
        "--repository",
        get_str(release, "repository"),
        "--tag",
        get_str(release, "tag"),
        *arguments,
        cwd=tmp_path,
        stub=stub,
    )
    assert completed.returncode == 0, completed.stderr
    manifest = as_map(json.loads(completed.stdout))
    assert schemas.problems(PRODUCT, schemas.CHANGE_MANIFEST, manifest, "changes.json") == []
    return manifest, (stub / "calls").read_text().splitlines()


def _change(manifest: dict[str, object], number: int) -> dict[str, object]:
    [change] = [
        as_map(change)
        for change in as_list(manifest["changes"])
        if as_map(as_map(change)["pull_request"])["number"] == number
    ]
    return change


def _numbers(manifest: dict[str, object], *, listed: bool | None = None) -> set[int]:
    changes = [as_map(change) for change in as_list(manifest["changes"])]
    return {
        int(str(as_map(change["pull_request"])["number"]))
        for change in changes
        if listed is None or change["listed"] is listed
    }


def _key(release: dict[str, object], pattern: str) -> str:
    [key] = [key for key in _responses(release) if re.search(pattern, key)]
    return key


def _edit_changelog(release: dict[str, object], edit: Callable[[str], str]) -> None:
    responses = _responses(release)
    key = _key(release, r"/CHANGELOG\.md\?")
    [text] = as_list(responses[key])
    responses[key] = [edit(str(text))]


@pytest.mark.parametrize("case", CASES)
def test_writes_what_each_recorded_release_carries(case: str, tmp_path: Path) -> None:
    release = _recorded(case)
    manifest, calls = _write(tmp_path, release)
    # It asks for each recorded answer once, and for nothing else.
    assert sorted(calls) == sorted(_responses(release))
    assert get_str(manifest, "generator").startswith("engineering-conventions ")
    assert re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", get_str(manifest, "generated_at"))
    written = {
        key: value for key, value in manifest.items() if key not in ("generated_at", "generator")
    }
    expected = RELEASES / f"{case}.changes.json"
    if os.environ.get(UPDATE):
        expected.write_text(json.dumps(written, indent=2) + "\n")
    assert written == read_json(expected), f"{case} differs from {expected.name}; set {UPDATE}=1"


class Golden(NamedTuple):
    """One change of a golden trace: what the lead time measure must read."""

    number: int
    first_commit: str
    authored: str
    created: str
    merged: str
    released_by: int


# The golden traces of the change lead time measure (decision 0045).
GOLDEN = {
    "platform-docs-0.26.9": Golden(
        141,
        "1257412344c9a29efd699d6e0eca0fe81572bafb",
        "2026-11-22T05:13:07Z",
        "2026-11-22T05:15:56Z",
        "2026-11-22T05:27:46Z",
        142,
    ),
    "platform-console-6.1.0": Golden(
        406,
        "0d42fb00f5e1c093d77b0f4c4b6961944743f337",
        "2026-11-21T22:58:25Z",
        "2026-11-21T23:49:47Z",
        "2026-11-22T01:14:18Z",
        407,
    ),
    "platform-api-35.4.0": Golden(
        1807,
        "71047fe0406321e638b7badd7f27c0e36933f941",
        "2026-11-21T23:27:42Z",
        "2026-11-22T04:02:20Z",
        "2026-11-22T06:15:43Z",
        1810,
    ),
}


@pytest.mark.parametrize("case", sorted(GOLDEN))
def test_records_each_change_from_its_first_commit(case: str, tmp_path: Path) -> None:
    golden = GOLDEN[case]
    manifest, _ = _write(tmp_path, _recorded(case))
    change = _change(manifest, golden.number)
    assert change["listed"] is True
    assert as_map(change["first_commit"]) == {
        "sha": golden.first_commit,
        "authored_at": golden.authored,
        "at": golden.authored,
        "rewritten": False,
        "truncated": False,
    }
    pull_request = as_map(change["pull_request"])
    assert (pull_request["created_at"], pull_request["merged_at"]) == (
        golden.created,
        golden.merged,
    )
    assert pull_request["author_kind"] == "agent"
    assert as_map(manifest["release_pull_request"])["number"] == golden.released_by


def test_counts_only_the_changes_to_its_package(tmp_path: Path) -> None:
    # platform-docs releases docs/product and docs/engineering apart. Of the
    # seven commits since platform-docs/v0.26.4, one changed only packages/.
    release = _recorded("platform-docs-0.26.5")
    manifest, calls = _write(tmp_path, release)
    assert manifest["path"] == "docs/product"
    assert manifest["previous_tag"] == "platform-docs/v0.26.4"
    compared = as_list(
        as_map(as_list(_responses(release)[_key(release, "/compare/")])[0])["commits"]
    )
    assert "1c6a6c642b2e8624aae54037f54e16ba414b4311" in {as_map(c)["sha"] for c in compared}
    assert "1c6a6c642b2e8624aae54037f54e16ba414b4311" not in json.dumps(manifest)
    assert _numbers(manifest) == {121, 122, 123, 125, 126}
    assert _numbers(manifest, listed=True) == {123}
    # The history of the path, from the earliest compared commit.
    assert (
        "repos/musher-dev/platform-docs/commits?path=docs/product&per_page=100"
        "&sha=35a0da4283d561ce45535c1c65c6c254b0dea5b6&since=2026-11-16T19:34:12Z"
    ) in calls


def test_a_change_counts_from_the_release_pull_request_s_next_refresh(tmp_path: Path) -> None:
    # Release pull request #1810 opened before #1807 merged, and release-please
    # refreshed it after each merge.
    manifest, _ = _write(tmp_path, _recorded("platform-api-35.4.0"))
    release = as_map(manifest["release_pull_request"])
    assert release["created_at"] == "2026-11-22T04:48:18Z"
    assert release["merged_at"] == "2026-11-22T10:11:23Z"
    assert release["refreshed_at"] == [
        "2026-11-22T06:18:42Z",
        "2026-11-22T07:09:55Z",
        "2026-11-22T07:36:38Z",
        "2026-11-22T10:08:33Z",
    ]
    opened = {
        number: _change(manifest, number)["release_pull_request_opened_at"]
        for number in (1803, 1807, 1813)
    }
    assert opened == {
        # It merged before the release pull request opened.
        1803: "2026-11-22T04:48:18Z",
        1807: "2026-11-22T06:18:42Z",
        # A refactor rewrites no notes; the next refresh still carried it.
        1813: "2026-11-22T10:08:33Z",
    }
    assert _numbers(manifest, listed=False) == {1813}


def test_a_change_no_refresh_followed_counts_from_its_merge(tmp_path: Path) -> None:
    release = _recorded("platform-api-35.4.0")
    key = _key(release, "ReleaseRefreshes")
    [page] = as_list(_responses(release)[key])
    items = as_map(as_map(as_map(as_map(page)["data"])["repository"])["pullRequest"])
    timeline = as_map(items["timelineItems"])
    timeline["nodes"] = as_list(timeline["nodes"])[:-1]
    manifest, _ = _write(tmp_path, release)
    for number in (1813, 1814):
        change = _change(manifest, number)
        merged = as_map(change["pull_request"])["merged_at"]
        assert change["release_pull_request_opened_at"] == merged
    assert _change(manifest, 1812)["release_pull_request_opened_at"] == "2026-11-22T07:36:38Z"


def test_a_first_release_reads_the_whole_history(tmp_path: Path) -> None:
    # platform-api's first tag, whose history holds the import of 1270 commits.
    release = _recorded("platform-api-0.36.0")
    manifest, calls = _write(tmp_path, release)
    assert manifest["previous_tag"] is None
    assert not [call for call in calls if "/compare/" in call]
    assert (
        "repos/musher-dev/platform-api/commits?path=platform-api&per_page=100"
        "&sha=fee8118bed21b92500779efb77f862a1be6fab56"
    ) in calls
    # #4 changed only the repository's root, outside the package.
    assert _numbers(manifest) == {1, 7}
    assert _numbers(manifest, listed=True) == {7}
    imported = _change(manifest, 7)
    # GitHub lists 250 of its commits, in three pages; an earlier one may be missing.
    assert "graphql PullRequestCommits?name=platform-api&number=7&owner=musher-dev" in calls
    assert as_map(imported["first_commit"]) == {
        "sha": "ffc32db943a9fc6fb8a926556d169f3346cb2eec",
        "authored_at": "2026-08-29T13:33:56Z",
        "at": "2026-08-29T13:33:56Z",
        "rewritten": False,
        "truncated": True,
    }


def test_a_first_release_starts_after_the_bootstrap_sha(tmp_path: Path) -> None:
    # The same release, as if it were its package's first: the configuration's
    # bootstrap-sha bounds it, as it bounds release-please's notes.
    release = _recorded("platform-docs-0.26.9")
    responses = _responses(release)
    refs = _key(release, "/matching-refs/")
    responses[refs] = [[]]
    compare = _key(release, "/compare/")
    bootstrap = "cf5177652adc5303b40bea82cad1436dee4a11f3"
    responses[re.sub(r"compare/[0-9a-f]{40}", f"compare/{bootstrap}", compare)] = responses.pop(
        compare
    )
    manifest, calls = _write(tmp_path, release)
    assert manifest["previous_tag"] is None
    assert any(f"/compare/{bootstrap}..." in call for call in calls)
    assert _numbers(manifest) == {141}


def test_pages_through_a_pull_request_s_commits(tmp_path: Path) -> None:
    release = _recorded("platform-api-24.0.0")
    manifest, calls = _write(tmp_path, release)
    assert "graphql PullRequestCommits?name=platform-api&number=1482&owner=musher-dev" in calls
    pages = as_list(_responses(release)[_key(release, "PullRequestCommits")])
    assert len(pages) == 2
    # 112 commits, all listed, so the earliest is certain.
    assert as_map(_change(manifest, 1482)["first_commit"]) == {
        "sha": "7d2a51c1ca4f9f11370cb6fe6eb3e7a6f3f43895",
        "authored_at": "2026-11-12T21:28:36Z",
        "at": "2026-11-12T21:28:36Z",
        "rewritten": False,
        "truncated": False,
    }


def test_reads_type_and_breaking_from_the_squash_commit(tmp_path: Path) -> None:
    manifest, _ = _write(tmp_path, _recorded("platform-api-24.0.0"))
    kinds = {
        number: (
            as_map(_change(manifest, number)["pull_request"])["type"],
            as_map(_change(manifest, number)["pull_request"])["breaking"],
        )
        for number in _numbers(manifest)
    }
    assert kinds == {
        1469: ("feat", True),
        1473: ("feat", True),
        1477: ("chore", False),
        1479: ("fix", False),
        1481: ("chore", False),
        1482: ("feat", False),
        1483: ("chore", False),
        1500: ("feat", False),
        1509: ("feat", True),
    }
    # The section lists feat, fix and breaking changes; chores are carried, unlisted.
    assert _numbers(manifest, listed=True) == {1469, 1473, 1479, 1482, 1500, 1509}


@pytest.mark.parametrize(
    ("heading", "listed"), [("### ⚠ BREAKING CHANGES", False), ("### Bug Fixes", True)]
)
def test_a_breaking_note_without_a_commit_link_lists_nothing(
    heading: str, *, listed: bool, tmp_path: Path
) -> None:
    # A breaking-change note repeats an entry the section lists with its
    # commit link, so its #N is prose; anywhere else, an entry without a
    # commit link names its pull request by its #N.
    release = _recorded("platform-api-24.0.0")
    note = "* **api:** withheld ([#1483](https://github.com/musher-dev/platform-api/issues/1483))"
    _edit_changelog(release, lambda text: text.replace(f"{heading}\n", f"{heading}\n\n{note}\n", 1))
    manifest, _ = _write(tmp_path, release)
    assert _change(manifest, 1483)["listed"] is listed


def test_lists_a_pull_request_once_however_many_entries_name_it(tmp_path: Path) -> None:
    # release-please wrote two entries for one squash commit, b17a051.
    release = _recorded("platform-backstage-11.0.2")
    changelog = str(as_list(_responses(release)[_key(release, r"/CHANGELOG\.md\?")])[0])
    assert changelog.count("/commit/b17a0515dba25923ec14bda60875420a0d05269e") == 2
    manifest, _ = _write(tmp_path, release)
    assert _numbers(manifest) == _numbers(manifest, listed=True) == {370}


def test_a_squash_commit_names_its_pull_request_without_its_number(tmp_path: Path) -> None:
    # The squash commit of #383 has no (#383) in its subject, so only GitHub's
    # association of the commit with the pull request finds it.
    release = _recorded("platform-console-5.0.1")
    compared = as_list(
        as_map(as_list(_responses(release)[_key(release, "/compare/")])[0])["commits"]
    )
    [squash] = [
        as_map(c)
        for c in compared
        if as_map(c)["sha"] == "8044edc540355cee3fb9ab029cc54dd83ae906af"
    ]
    assert "#383" not in json.dumps(squash)
    manifest, _ = _write(tmp_path, release)
    assert _numbers(manifest, listed=True) == {383}


def test_an_entry_without_a_commit_link_names_its_pull_request_last(tmp_path: Path) -> None:
    # Without its commit link, an entry falls back to its last #N that is a
    # pull request of the release: #1809 after the issues it closed, and
    # #1814 before the "closes #1808" release-please adds.
    release = _recorded("platform-api-35.4.0")
    links = re.compile(r" \(\[(46dc0a3|3d73558)\]\([^)]*\)\)")
    _edit_changelog(release, lambda text: links.sub("", text))
    manifest, _ = _write(tmp_path, release)
    assert _numbers(manifest, listed=True) == {1803, 1807, 1809, 1812, 1814}


@pytest.mark.parametrize(("version", "listed"), [("35.3.0", False), ("35.4.0", True)])
def test_lists_only_what_the_version_s_section_names(
    version: str, *, listed: bool, tmp_path: Path
) -> None:
    release = _recorded("platform-api-35.4.0")
    entry = (
        "* **api:** withheld ([#1813](https://github.com/musher-dev/platform-api/issues/1813))"
        " ([7ceebfc](https://github.com/musher-dev/platform-api/commit/"
        "7ceebfc95321e24528885a98fff9dcd86f9be804))"
    )
    heading = re.compile(rf"(## \[{re.escape(version)}\][^\n]*\n)")
    _edit_changelog(release, lambda text: heading.sub(rf"\1\n### Bug Fixes\n\n{entry}\n", text, 1))
    manifest, _ = _write(tmp_path, release)
    assert _change(manifest, 1813)["listed"] is listed


def test_a_history_rewritten_after_opening_counts_from_the_opening(tmp_path: Path) -> None:
    # #809 opened on 2026-10-17; its earliest commit, after a force-push, is
    # from 2026-11-11.
    manifest, _ = _write(tmp_path, _recorded("platform-api-20.4.0"))
    first_commit = as_map(_change(manifest, 809)["first_commit"])
    assert first_commit["authored_at"] == "2026-11-11T14:17:42Z"
    assert first_commit["at"] == "2026-10-17T11:47:27Z"
    assert first_commit["rewritten"] is True


@pytest.mark.parametrize(
    ("author", "kind"),
    [
        ({"__typename": "Bot", "login": "musher-dagger"}, "agent"),
        ({"__typename": "Bot", "login": "dependabot"}, "dependency-bot"),
        ({"__typename": "Bot", "login": "renovate"}, "dependency-bot"),
        ({"__typename": "Bot", "login": "github-actions"}, "automation"),
        ({"__typename": "User", "login": "someone"}, "human"),
        ({"__typename": "Mannequin", "login": "someone"}, "human"),
        # A deleted account.
        (None, "human"),
    ],
)
def test_author_kind_is_a_kind_never_a_login(
    author: dict[str, str] | None, kind: str, tmp_path: Path
) -> None:
    release = _recorded("platform-console-6.1.0")
    responses = _responses(release)
    key = _key(release, "oid=441d1106")
    [page] = as_list(responses[key])
    commit = as_map(as_map(as_map(as_map(page)["data"])["repository"])["object"])
    [pull] = as_list(as_map(commit["associatedPullRequests"])["nodes"])
    as_map(pull)["author"] = author
    manifest, _ = _write(tmp_path, release)
    assert as_map(_change(manifest, 406)["pull_request"])["author_kind"] == kind
    assert "someone" not in json.dumps(manifest)


def test_follows_annotated_tags(tmp_path: Path) -> None:
    release = _recorded("platform-console-6.1.0")
    responses = _responses(release)
    ref = _key(release, "/git/ref/tags/v6.1.0$")
    commit = as_map(as_map(as_list(responses[ref])[0])["object"])["sha"]
    responses[ref] = [{"object": {"type": "tag", "sha": "a" * 40}}]
    responses[f"repos/musher-dev/platform-console/git/tags/{'a' * 40}"] = [
        {"object": {"type": "commit", "sha": commit}}
    ]
    # The previous release's tag, annotated too.
    refs = _key(release, "/matching-refs/")
    [listing] = as_list(responses[refs])
    [previous] = [
        as_map(ref) for ref in as_list(listing) if as_map(ref)["ref"] == "refs/tags/v6.0.2"
    ]
    previous_commit = as_map(previous["object"])["sha"]
    previous["object"] = {"type": "tag", "sha": "b" * 40}
    responses[f"repos/musher-dev/platform-console/git/tags/{'b' * 40}"] = [
        {"object": {"type": "commit", "sha": previous_commit}}
    ]
    manifest, _ = _write(tmp_path, release)
    assert manifest["commit"] == commit
    assert manifest["previous_tag"] == "v6.0.2"
    assert _numbers(manifest, listed=True) == {406}


def test_writes_out_where_it_was_run_and_says_what_it_wrote(tmp_path: Path) -> None:
    release = _recorded("platform-console-6.1.0")
    stub = _stub(tmp_path, release)
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    arguments = ("--repository", "musher-dev/platform-console", "--tag", "v6.1.0")
    completed = _launch(
        "release",
        "changes",
        *arguments,
        "--out",
        "out/changes.json",
        "-C",
        str(elsewhere),
        cwd=tmp_path,
        stub=stub,
    )
    assert completed.returncode == 0, completed.stderr
    assert completed.stdout == ""
    written = tmp_path / "out" / "changes.json"
    assert completed.stderr == f"wrote {written}: 1 pull request, 1 listed, released by #407\n"
    manifest = as_map(read_json(written))
    assert schemas.problems(PRODUCT, schemas.CHANGE_MANIFEST, manifest, "changes.json") == []
    # A file where its directory should be.
    (tmp_path / "taken").write_text("")
    blocked = _launch(
        "release", "changes", *arguments, "--out", "taken/changes.json", cwd=tmp_path, stub=stub
    )
    assert blocked.returncode == 2
    assert f"cannot write {tmp_path / 'taken' / 'changes.json'}" in blocked.stderr


def test_reads_the_repository_from_github_or_origin(tmp_path: Path) -> None:
    release = _recorded("platform-console-6.1.0")
    stub = _stub(tmp_path, release)
    env = {"GITHUB_REPOSITORY": "musher-dev/platform-console"}
    completed = _launch("release", "changes", "--tag", "v6.1.0", cwd=tmp_path, stub=stub, env=env)
    assert completed.returncode == 0, completed.stderr
    assert as_map(json.loads(completed.stdout))["repository"] == "musher-dev/platform-console"
    repo = tmp_path / "repo"
    repo.mkdir()
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    remote = "git@github.com:musher-dev/platform-console.git"
    subprocess.run(["git", "-C", str(repo), "remote", "add", "origin", remote], check=True)
    completed = _launch("release", "changes", "--tag", "v6.1.0", cwd=repo, stub=stub)
    assert completed.returncode == 0, completed.stderr
    assert as_map(json.loads(completed.stdout))["repository"] == "musher-dev/platform-console"


def _no_release_pull_request(release: dict[str, object]) -> None:
    responses = _responses(release)
    [page] = as_list(responses[_key(release, "oid=2eee8f91")])
    commit = as_map(as_map(as_map(as_map(page)["data"])["repository"])["object"])
    as_map(commit["associatedPullRequests"])["nodes"] = []


def _no_section(release: dict[str, object]) -> None:
    _edit_changelog(release, lambda text: text.replace("## [6.1.0]", "## [6.1.9]"))


def _another_tag(release: dict[str, object]) -> None:
    responses = _responses(release)
    responses["repos/musher-dev/platform-console/git/ref/tags/console/v6.1.0"] = responses[
        _key(release, "/git/ref/tags/v6.1.0$")
    ]


@pytest.mark.parametrize(
    ("tag", "edit", "reason"),
    [
        (
            "v9.9.9",
            None,
            "cannot read the tag v9.9.9 of musher-dev/platform-console on GitHub: gh: Not Found",
        ),
        (
            "console/v6.1.0",
            _another_tag,
            "no package in .github/release-please/config.json at console/v6.1.0 is released as"
            " console/v6.1.0: platform-console is released as vX.Y.Z",
        ),
        (
            "v6.1.0",
            _no_section,
            "platform-console/CHANGELOG.md at v6.1.0 has no section for 6.1.0",
        ),
        (
            "v6.1.0",
            _no_release_pull_request,
            "the commit v6.1.0 names, is no pull request's merge commit",
        ),
    ],
)
def test_stops_when_the_release_cannot_be_read(
    tag: str,
    edit: Callable[[dict[str, object]], None] | None,
    reason: str,
    tmp_path: Path,
) -> None:
    release = _recorded("platform-console-6.1.0")
    if edit is not None:
        edit(release)
    stub = _stub(tmp_path, release)
    arguments = ("--repository", "musher-dev/platform-console", "--tag", tag)
    completed = _launch("release", "changes", *arguments, cwd=tmp_path, stub=stub)
    assert completed.returncode == 2
    assert completed.stdout == ""
    assert reason in completed.stderr


@pytest.mark.parametrize(
    ("arguments", "reason"),
    [
        (("release",), "conventions release changes --tag TAG"),
        (("release", "notes", "--tag", "v1.0.0"), "conventions release changes --tag TAG"),
        (("release", "changes"), "conventions release changes --tag TAG"),
        (("release", "changes", "--tag", "v1.0.0", "--since", "x"), "conventions release changes"),
        (("release", "changes", "--tag", "v1;0"), "--tag must be a release tag"),
        (("release", "changes", "--tag", "../v1.0.0"), "--tag must be a release tag"),
        (
            ("release", "changes", "--tag", "v1.0.0", "--repository", "platform-console"),
            "--repository must be OWNER/NAME",
        ),
    ],
)
def test_refuses_what_it_does_not_take(
    arguments: tuple[str, ...], reason: str, tmp_path: Path
) -> None:
    stub = _stub(tmp_path, {"responses": {}})
    completed = _launch(*arguments, cwd=tmp_path, stub=stub)
    assert completed.returncode == 2
    assert reason in completed.stderr
    assert not (stub / "calls").exists()
