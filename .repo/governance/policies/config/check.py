"""Detect .config/ layout drift."""

from __future__ import annotations

import os
import re
from pathlib import Path

from governance import repo
from governance.policies.config import violations as v
from governance.reporting import Report

CONFIG_DIR = ".config"

#: Configs the tool finds on its own. Everything else must be named by a
#: caller. Keep this list short -- each entry is a discovery dependency.
AUTO_DISCOVERED = {
    "lefthook.yml": "lefthook searches .config/ natively",
}

#: Gitignored personal overrides. Present or absent, never indexed.
LOCAL_OVERRIDES = {"lefthook-local.yml", "lefthook-local.yaml"}

#: The only files allowed at the top level of .config/ rather than inside a
#: concern bucket. Lefthook qualifies solely because its config search does
#: not descend past .config/lefthook.* -- bucketing it would silently stop
#: every hook running.
TOP_LEVEL_ALLOWED = {"README.md"} | set(AUTO_DISCOVERED) | LOCAL_OVERRIDES

#: Suffixes that make a file a program rather than a declaration. A denylist
#: rather than a config allowlist because legitimate configs may carry no
#: extension at all, and the failure to prevent is specifically an executable
#: drifting in.
EXECUTABLE_SUFFIXES = {
    ".sh", ".bash", ".zsh", ".py", ".mjs", ".cjs", ".js", ".ts", ".rb", ".pl",
}

#: Root filenames that would win lefthook's first-match-wins search.
SHADOWING = (
    "lefthook.yml", "lefthook.yaml", "lefthook.json", "lefthook.jsonc",
    "lefthook.toml", ".lefthook.yml", ".lefthook.yaml", ".lefthook.json",
    ".lefthook.jsonc", ".lefthook.toml",
)

#: Tool configs that belong in .config/ and must never appear at the root.
#: Git, Task and editor files are deliberately absent -- they are root-only
#: by the tools' own rules.
STRAY_ROOT_CONFIGS = (
    ".markdownlint.json", ".markdownlint.jsonc", ".markdownlint.yaml",
    ".markdownlint-cli2.jsonc", ".markdownlint-cli2.yaml",
    ".yamllint", ".yamllint.yml", ".yamllint.yaml",
    ".codespellrc", "codespell.cfg",
    "actionlint.yaml", "actionlint.yml",
    ".prettierrc", ".prettierrc.json", ".prettierrc.yaml",
    ".eslintrc", ".eslintrc.json", "eslint.config.js",
    ".stylelintrc", ".shellcheckrc",
)

#: Files scanned for explicit `.config/<path>` references.
CALLER_GLOBS = (
    "Taskfile.yml",
    "taskfiles/*.yml",
    "taskfiles/*.yaml",
    ".github/workflows/*.yml",
    ".github/workflows/*.yaml",
    ".config/lefthook.yml",
    ".devcontainer/scripts/**/*.sh",
)

#: Directory names never worth walking inside .config/.
EXCLUDED_DIR_NAMES = {"node_modules", "__pycache__", ".git"}

_BACKTICKED = re.compile(r"`([^`]+)`")

#: A `.config/<path>` a caller names. The lookbehind skips paths that merely end
#: in `.config/`, such as the gh CLI's `/home/vscode/.config/gh`.
_REFERENCE = re.compile(r"(?<![\w/~$}.])\.config/[\w./-]*\w")


def _config_files(config_dir: Path) -> list[Path]:
    files = []
    for dirpath, dirnames, filenames in os.walk(config_dir):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDED_DIR_NAMES]
        files.extend(Path(dirpath) / f for f in filenames)
    return sorted(files)


def _referenced_paths() -> dict[str, str]:
    """Every `.config/...` path named on a non-comment caller line, mapped to its caller."""
    found: dict[str, str] = {}
    for pattern in CALLER_GLOBS:
        for path in repo.glob(pattern):
            if not path.is_file():
                continue
            for line in path.read_text(encoding="utf-8").splitlines():
                if line.lstrip().startswith("#"):
                    continue
                for match in _REFERENCE.finditer(line):
                    found.setdefault(match.group(0), repo.rel(path))
    return found


def _caller_text() -> str:
    chunks = []
    for pattern in CALLER_GLOBS:
        for path in repo.glob(pattern):
            if path.is_file():
                chunks.append(path.read_text(encoding="utf-8"))
    return "\n".join(chunks)


def run() -> Report:
    report = Report(policy="config")
    root = repo.repo_root()
    config_dir = root / CONFIG_DIR

    if not config_dir.is_dir():
        report.add(v.missing_config_dir())
        return report

    index_path = config_dir / "README.md"
    index = index_path.read_text(encoding="utf-8") if index_path.is_file() else None
    if index is None:
        report.add(v.missing_index())
    indexed = set(_BACKTICKED.findall(index)) if index is not None else set()

    callers = _caller_text()

    for path in _config_files(config_dir):
        rel = path.relative_to(config_dir).as_posix()
        name = path.name
        if name == "README.md" or name in LOCAL_OVERRIDES:
            continue

        if name.startswith("."):
            report.add(v.dotted_filename(rel))

        if path.suffix in EXECUTABLE_SUFFIXES:
            report.add(v.executable_in_config(rel))

        if "/" not in rel and name not in TOP_LEVEL_ALLOWED:
            report.add(v.misplaced_top_level(name))

        if index is not None and rel not in indexed and name not in indexed:
            report.add(v.not_in_index(rel))

        if name not in AUTO_DISCOVERED and f"{CONFIG_DIR}/{rel}" not in callers:
            report.add(v.orphaned(rel))

    for ref, caller in sorted(_referenced_paths().items()):
        if ref.rsplit("/", 1)[-1] in LOCAL_OVERRIDES:
            continue
        if not (root / ref).is_file():
            report.add(v.dangling_reference(ref, caller))

    for name in SHADOWING:
        if (root / name).is_file():
            report.add(v.shadowing_root_config(name))

    for name in STRAY_ROOT_CONFIGS:
        if (root / name).is_file():
            report.add(v.stray_root_config(name))

    return report
