"""A throwaway git repository per test, so each policy runs against real files."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

from governance import repo

MINIMAL_DEVCONTAINER = json.dumps({"name": "fixture", "mounts": []})

#: A clean, fully adapted product repo: the state every layout rule accepts.
HOST_AGENT = {
    ".repo/layout.toml": 'product = "demo"\n',
    ".devcontainer/devcontainer.json": json.dumps({
        "mounts": [
            "source=x-target,target=/workspaces/${localWorkspaceFolderBasename}/demo/target,type=volume",
        ],
        "customizations": {"vscode": {"settings": {
            "rust-analyzer.linkedProjects": ["demo/Cargo.toml"],
        }}},
    }),
    ".github/dependabot.yml": (
        "version: 2\nupdates:\n"
        "  - package-ecosystem: cargo\n    directory: /demo\n    schedule: {interval: weekly}\n"
    ),
    "Taskfile.yml": "version: '3'\nvars:\n  PRODUCT_DIR: '{{.ROOT_DIR}}/demo'\n",
    "demo/Cargo.toml": "[workspace]\n",
    "demo/env.schema.yaml": (
        "service: demo\nruntime: rust\nbindings:\n"
        "  HOST_ID:\n    type: string\n    required: true\n"
        "    sensitivity: internal\n    description: The host.\n"
    ),
}


@pytest.fixture
def make_repo(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    """Write `files` into a fresh git repo named `demo`, and make it the repo root."""

    def build(files: dict[str, str]) -> Path:
        merged = {".devcontainer/devcontainer.json": MINIMAL_DEVCONTAINER, **files}
        for rel, content in merged.items():
            path = tmp_path / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
        subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
        subprocess.run(["git", "add", "-A"], cwd=tmp_path, check=True)
        monkeypatch.chdir(tmp_path)
        monkeypatch.setenv("GITHUB_REPOSITORY", "musher-dev/demo")
        repo.repo_root.cache_clear()
        repo.tracked_files.cache_clear()
        return tmp_path

    yield build
    repo.repo_root.cache_clear()
    repo.tracked_files.cache_clear()


def codes(report) -> set[str]:
    return {violation.code for violation in report.violations}
