from __future__ import annotations

from conftest import codes
from governance.policies.config import run

INDEX = "# idx\n\n| `markdown/markdownlint.jsonc` | markdownlint | --config |\n"


def _files(caller: str) -> dict[str, str]:
    return {
        ".config/README.md": INDEX,
        ".config/markdown/markdownlint.jsonc": "{}",
        "taskfiles/lint.Taskfile.yml": caller,
    }


def test_live_reference(make_repo):
    make_repo(_files("vars:\n  MD: .config/markdown/markdownlint.jsonc\n"))
    assert "CFG-09" not in codes(run())


def test_dangling_reference(make_repo):
    make_repo(_files(
        "vars:\n  MD: .config/markdown/markdownlint.jsonc\n  OLD: .config/markdown/markdownlint.json\n"
    ))
    assert "CFG-09" in codes(run())


def test_home_config_paths_and_comments_are_ignored(make_repo):
    make_repo({
        **_files("vars:\n  MD: .config/markdown/markdownlint.jsonc\n"),
        ".devcontainer/scripts/x.sh": (
            "# lefthook searches .config/lefthook.* natively\n"
            "ensure_writable_dir /home/vscode/.config/gh\n"
        ),
    })
    assert "CFG-09" not in codes(run())
