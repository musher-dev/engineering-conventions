"""`conventions dependencies`: each pin's currency, and the badges that show it (decision 0042)."""

import json
import os
import subprocess
from pathlib import Path

import pytest

from conventions_tools.paths import product_dir

PRODUCT = product_dir()
LAUNCHER = PRODUCT / "bin" / "conventions"
SNAPSHOTS = PRODUCT / "tests" / "fixtures" / "badges"

# Set to rewrite the SVG snapshots after a deliberate change to badges.jq;
# read the diff before committing it.
UPDATE = "CONVENTIONS_UPDATE_BADGES"

# A stand-in for gh: `gh api repos/musher-dev/<name>/releases --paginate`
# prints <name>.json, as gh prints each page, or fails as GitHub does for a
# repository the token cannot read. Every call is logged.
GH_STUB = """#!/bin/sh
here=$(dirname "$0")
printf '%s\\n' "$*" >> "${here}/calls"
name=${2#repos/musher-dev/}
name=${name%/releases}
if [ -f "${here}/${name}.json" ]; then cat "${here}/${name}.json"; exit 0; fi
echo 'gh: Not Found (HTTP 404)' >&2
exit 1
"""


def _release(tag: str, *, draft: bool = False, prerelease: bool = False) -> dict[str, object]:
    return {"tag_name": tag, "draft": draft, "prerelease": prerelease}


# Two pages, as `gh api --paginate` prints them: arrays back to back.
PAGES = {
    "specifications": [
        [_release("schemas/v1.6.0"), _release("schemas/v1.7.0"), _release("v9.0.0")],
        [
            _release("schemas/v2.0.0-rc.1", prerelease=True),
            _release("schemas/v1.8.0", draft=True),
        ],
    ],
    "platform": [[_release("musher-v2.3.0"), _release("musher-v3.0.0"), _release("v4.0.0")]],
    "topicgraph": [[_release("events/v0.4.0"), _release("v0.5.0")]],
    "engineering-conventions": [[_release("v0.9.4"), _release("v0.9.3")]],
}

DEPENDENCIES = """\
[[dependencies]]
repository = "specifications"
output = "schemas"
interfaces = ["component-schema"]
version = "1.6.0"

[[dependencies]]
repository = "platform"
output = "api"
version = "3.0.0"
fetched = true

[[dependencies]]
repository = "topicgraph"
output = "events-release"
version = "0.4.0"
fetched = true

[[dependencies]]
repository = "platform-api"
output = "contracts"
version = "0.36.1"
fetched = true
"""

RECORD = {
    "repository": "specifications",
    "output": "schemas",
    "version": "1.6.0",
    "tag": "schemas/v1.6.0",
}


def _repository(tmp_path: Path, *, conventions: str | None = "0.9.4") -> Path:
    repo = tmp_path / "repo"
    (repo / ".repo").mkdir(parents=True)
    (repo / ".repo" / "dependencies.toml").write_text(DEPENDENCIES)
    vendored = repo / "web" / "contracts" / "vendor" / "specifications" / "schemas"
    vendored.mkdir(parents=True)
    (vendored / "release.json").write_text(json.dumps(RECORD))
    if conventions is not None:
        (repo / ".config" / "mise").mkdir(parents=True)
        (repo / ".config" / "mise" / "config.toml").write_text(
            f'[tools]\n"github:musher-dev/engineering-conventions" = "{conventions}"\n'
        )
    return repo


def _launch(
    *arguments: str, cwd: Path, stub: Path | None = None
) -> subprocess.CompletedProcess[str]:
    environment = dict(os.environ) | {"CONVENTIONS_NO_MISE": "1"}
    if stub is not None:
        environment["PATH"] = f"{stub}{os.pathsep}{environment['PATH']}"
    return subprocess.run(
        [str(LAUNCHER), "dependencies", *arguments],
        cwd=cwd,
        capture_output=True,
        text=True,
        check=False,
        env=environment,
    )


def _gh(tmp_path: Path) -> Path:
    stub = tmp_path / "stub"
    stub.mkdir()
    (stub / "gh").write_text(GH_STUB)
    (stub / "gh").chmod(0o755)
    for name, pages in PAGES.items():
        (stub / f"{name}.json").write_text("".join(json.dumps(page) for page in pages))
    return stub


def test_status_compares_each_pin_with_its_tag_line(tmp_path: Path) -> None:
    repo = _repository(tmp_path)
    stub = _gh(tmp_path)
    completed = _launch("status", "--json", cwd=repo, stub=stub)
    assert completed.returncode == 0, completed.stderr
    status = {(pin["repository"], pin["output"]): pin for pin in json.loads(completed.stdout)}
    # The record's tag line, schemas/v: v9.0.0, the prerelease and the draft are other things.
    assert status["specifications", "schemas"] == {
        "repository": "specifications",
        "output": "schemas",
        "pinned": "1.6.0",
        "latest": "1.7.0",
        "latestInMajor": "1.7.0",
        "state": "behind-minor",
        "label": "specifications schemas",
        "badge": "specifications-schemas.svg",
    }
    # No record: platform's line is musher-v, so v4.0.0 is not a newer major.
    assert status["platform", "api"]["state"] == "current"
    assert status["platform", "api"]["latest"] == "3.0.0"
    # No record: a <family>-release output's line is <family>/v.
    assert status["topicgraph", "events-release"]["state"] == "current"
    # A producer gh cannot read is unknown, and only a warning.
    assert status["platform-api", "contracts"]["state"] == "unknown"
    assert status["platform-api", "contracts"]["latest"] is None
    assert "cannot read the releases of musher-dev/platform-api" in completed.stderr
    assert status["engineering-conventions", None]["state"] == "current"
    assert status["engineering-conventions", None]["badge"] == "engineering-conventions.svg"
    # One call per producer, every page.
    calls = (stub / "calls").read_text().splitlines()
    assert sorted(calls) == sorted(
        f"api repos/musher-dev/{name}/releases --paginate"
        for name in (
            "specifications",
            "platform",
            "topicgraph",
            "platform-api",
            "engineering-conventions",
        )
    )


def test_status_reports_a_newer_major_only_from_the_newest_of_its_own(tmp_path: Path) -> None:
    stub = _gh(tmp_path)
    (stub / "engineering-conventions.json").write_text(
        json.dumps([_release("v0.9.3"), _release("v0.9.4"), _release("v1.0.0")])
    )
    newest = _launch("status", "--json", cwd=_repository(tmp_path, conventions="0.9.4"), stub=stub)
    [conventions] = [pin for pin in json.loads(newest.stdout) if pin["output"] is None]
    assert (conventions["state"], conventions["latest"], conventions["latestInMajor"]) == (
        "behind-major",
        "1.0.0",
        "0.9.4",
    )


def test_status_prints_a_line_per_pin(tmp_path: Path) -> None:
    completed = _launch("status", cwd=_repository(tmp_path), stub=_gh(tmp_path))
    assert completed.returncode == 0, completed.stderr
    assert completed.stdout.splitlines() == [
        "specifications schemas  1.6.0  behind-minor  1.7.0 is out",
        "platform api  3.0.0  current",
        "topicgraph events-release  0.4.0  current",
        "platform-api contracts  0.36.1  unknown",
        "engineering-conventions  0.9.4  current",
    ]


def test_status_without_pins(tmp_path: Path) -> None:
    completed = _launch("status", cwd=tmp_path, stub=_gh(tmp_path))
    assert completed.returncode == 0, completed.stderr
    assert completed.stdout == "no pins of another Musher release\n"


@pytest.mark.parametrize(
    "arguments",
    [("status", "--out", "x"), ("badges",), ("badges", "--json", "--out", "x"), ("sync",)],
)
def test_refuses_what_it_does_not_take(tmp_path: Path, arguments: tuple[str, ...]) -> None:
    assert _launch(*arguments, cwd=tmp_path).returncode == 2


# One pin in each state the badges show.
STATES = [
    {
        "repository": "engineering-conventions",
        "output": None,
        "pinned": "0.9.4",
        "latest": "0.9.4",
        "latestInMajor": "0.9.4",
        "state": "current",
        "label": "engineering-conventions",
        "badge": "engineering-conventions.svg",
    },
    {
        "repository": "platform-api",
        "output": "contracts",
        "pinned": "0.36.1",
        "latest": "1.2.0",
        "latestInMajor": "0.38.0",
        "state": "behind-minor",
        "label": "platform-api contracts",
        "badge": "platform-api-contracts.svg",
    },
    {
        "repository": "specifications",
        "output": "schemas",
        "pinned": "1.6.0",
        "latest": "2.0.0",
        "latestInMajor": "1.6.0",
        "state": "behind-major",
        "label": "specifications schemas",
        "badge": "specifications-schemas.svg",
    },
    {
        "repository": "topicgraph",
        "output": "events-release",
        "pinned": "0.4.0",
        "latest": None,
        "latestInMajor": None,
        "state": "unknown",
        "label": "topicgraph events-release",
        "badge": "topicgraph-events-release.svg",
    },
]


def test_badges_match_their_snapshots(tmp_path: Path) -> None:
    status = tmp_path / "status.json"
    status.write_text(json.dumps(STATES))
    out = tmp_path / "out"
    # --status renders without reaching GitHub; no gh is on PATH for it to call.
    completed = _launch("badges", "--out", str(out), "--status", str(status), cwd=tmp_path)
    assert completed.returncode == 0, completed.stderr
    assert sorted(path.name for path in out.iterdir()) == sorted(
        [*(str(pin["badge"]) for pin in STATES), "index.json", "README.md"]
    )
    assert json.loads((out / "index.json").read_text()) == STATES
    for name in [*(str(pin["badge"]) for pin in STATES), "README.md"]:
        rendered = (out / name).read_text()
        snapshot = SNAPSHOTS / name
        if os.environ.get(UPDATE):
            snapshot.write_text(rendered)
        assert rendered == snapshot.read_text(), f"{name} differs from its snapshot; set {UPDATE}=1"


def test_badges_show_the_colour_and_target_of_each_state() -> None:
    expected = {
        "engineering-conventions.svg": ("#4c1", "engineering-conventions: 0.9.4"),
        "platform-api-contracts.svg": ("#dfb317", "platform-api contracts: 0.36.1 → 0.38.0"),
        "specifications-schemas.svg": ("#fe7d37", "specifications schemas: 1.6.0 → 2.0.0"),
        "topicgraph-events-release.svg": ("#9f9f9f", "topicgraph events-release: 0.4.0"),
    }
    for name, (colour, title) in expected.items():
        svg = (SNAPSHOTS / name).read_text()
        assert f'fill="{colour}"' in svg
        assert f"<title>{title}</title>" in svg
        assert "http" not in svg.replace('xmlns="http://www.w3.org/2000/svg"', "")


def test_badges_escape_their_text(tmp_path: Path) -> None:
    status = tmp_path / "status.json"
    pin = STATES[0] | {"label": "a<b>&\"c'", "pinned": "<1>"}
    status.write_text(json.dumps([pin]))
    out = tmp_path / "out"
    completed = _launch("badges", "--out", str(out), "--status", str(status), cwd=tmp_path)
    assert completed.returncode == 0, completed.stderr
    svg = (out / "engineering-conventions.svg").read_text()
    assert "<title>a&lt;b&gt;&amp;&quot;c&apos;: &lt;1&gt;</title>" in svg
    assert "<b>" not in svg


def test_badges_never_write_outside_the_directory(tmp_path: Path) -> None:
    status = tmp_path / "status.json"
    status.write_text(json.dumps([STATES[0] | {"badge": "../escape.svg"}]))
    out = tmp_path / "out"
    completed = _launch("badges", "--out", str(out), "--status", str(status), cwd=tmp_path)
    assert completed.returncode == 0, completed.stderr
    assert not (tmp_path / "escape.svg").exists()
    assert "skipping a pin whose badge name ../escape.svg" in completed.stderr


def test_badges_from_the_producers(tmp_path: Path) -> None:
    repo = _repository(tmp_path)
    out = tmp_path / "out"
    completed = _launch("badges", "--out", "out", "-C", str(repo), cwd=tmp_path, stub=_gh(tmp_path))
    assert completed.returncode == 0, completed.stderr
    index = json.loads((out / "index.json").read_text())
    assert [pin["state"] for pin in index] == [
        "behind-minor",
        "current",
        "current",
        "unknown",
        "current",
    ]
    assert (out / "platform-api-contracts.svg").read_text().count('fill="#9f9f9f"') == 1
