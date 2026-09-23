"""Detect configured globs, directories and path vars that resolve to nothing.

The generic half of host-agent's scripts/check-path-refs.py. Ecosystem- and
repo-specific sources (rust-cache, release-please extra-files, a mutants
matrix) extend this in the repo that has them.
"""

from __future__ import annotations

import re

import yaml

from governance import globs, repo
from governance.policies.paths import violations as v
from governance.reporting import Report

LEFTHOOK = ".config/lefthook.yml"
GITATTRIBUTES = ".gitattributes"
DEPENDABOT = ".github/dependabot.yml"
TASKFILES = ("Taskfile.yml", "taskfiles/*.yml", "taskfiles/*.yaml")

#: Patterns that may legitimately match no tracked file (generated or
#: gitignored output), each with a reason. Empty until something needs it.
UNTRACKED_OK: dict[str, str] = {}

_TASK_PATH = re.compile(r"^\{\{\.(ROOT_DIR|PRODUCT_DIR)\}\}(/[^{}]*)?$")


def _walk(node: object):
    yield node
    if isinstance(node, dict):
        for value in node.values():
            yield from _walk(value)
    elif isinstance(node, list):
        for value in node:
            yield from _walk(value)


def _yaml_files(*patterns: str):
    for pattern in patterns:
        for path in repo.glob(pattern):
            if path.is_file():
                yield repo.rel(path), yaml.safe_load(path.read_text(encoding="utf-8"))


def _glob_sources() -> list[tuple[str, str, bool]]:
    """(source, pattern, gitignore_style) for every glob a tool scopes itself by."""
    found: list[tuple[str, str, bool]] = []
    if repo.exists(LEFTHOOK):
        for node in _walk(repo.read_yaml(LEFTHOOK)):
            if isinstance(node, dict) and isinstance(node.get("glob"), str) and node["glob"] != "**":
                found.append((f"{LEFTHOOK} job `{node.get('name', '?')}`", node["glob"], False))
    if repo.exists(GITATTRIBUTES):
        for line in repo.read_text(GITATTRIBUTES).splitlines():
            if line.strip() and not line.lstrip().startswith("#"):
                found.append((GITATTRIBUTES, line.split()[0], True))
    for source, doc in _yaml_files(".github/workflows/*.yml", ".github/workflows/*.yaml"):
        for node in _walk(doc):
            if isinstance(node, dict) and str(node.get("uses", "")).startswith("dorny/paths-filter@"):
                filters = (node.get("with") or {}).get("filters")
                parsed = yaml.safe_load(filters) if isinstance(filters, str) else filters
                for name, patterns in (parsed or {}).items():
                    for pattern in patterns if isinstance(patterns, list) else [patterns]:
                        if isinstance(pattern, str):
                            found.append((f"{source} paths-filter `{name}`", pattern, False))
    for path in repo.glob(".claude/rules/*.md"):
        text = path.read_text(encoding="utf-8")
        if text.startswith("---\n") and "\n---" in text[4:]:
            front = yaml.safe_load(text[4:].split("\n---", 1)[0]) or {}
            for pattern in front.get("paths", []) if isinstance(front, dict) else []:
                found.append((repo.rel(path), pattern, False))
    return found


def _directory_sources() -> list[tuple[str, str]]:
    """(source, directory) for every setting that names a directory."""
    found: list[tuple[str, str]] = []
    for source, doc in _yaml_files(".github/**/*.yml", ".github/**/*.yaml"):
        for node in _walk(doc):
            if isinstance(node, dict) and isinstance(node.get("working-directory"), str):
                found.append((f"{source} working-directory", node["working-directory"]))
    if repo.exists(DEPENDABOT):
        for update in (repo.read_yaml(DEPENDABOT) or {}).get("updates", []):
            ecosystem = update.get("package-ecosystem", "?")
            for directory in update.get("directories") or [update.get("directory", "/")]:
                found.append((f"{DEPENDABOT} {ecosystem}", str(directory)))
    return found


def _directory_exists(directory: str, tracked_dirs: set[str]) -> bool:
    path = directory.strip().strip("/")
    if "${{" in path:
        return True
    if not path:
        return True
    if any(char in path for char in "*?["):
        return globs.matches(path, sorted(tracked_dirs))
    return (repo.repo_root() / path).is_dir()


def run() -> Report:
    report = Report(policy="paths")
    files = repo.tracked_files()
    tracked_dirs = {
        "/".join(parts[:i]) for parts in (f.split("/") for f in files) for i in range(1, len(parts))
    }

    used: set[str] = set()
    for source, pattern, gitignore_style in _glob_sources():
        if pattern in UNTRACKED_OK:
            used.add(pattern)
        elif not globs.matches(pattern, files, gitignore_style):
            report.add(v.glob_matches_nothing(source, pattern))

    for source, directory in _directory_sources():
        if not _directory_exists(directory, tracked_dirs):
            report.add(v.missing_directory(source, directory))

    bases = {"ROOT_DIR": repo.repo_root()}
    product = repo.product()
    if product:
        bases["PRODUCT_DIR"] = repo.repo_root() / product
    for source, doc in _yaml_files(*TASKFILES):
        for name, value in ((doc or {}).get("vars") or {}).items():
            match = _TASK_PATH.match(value) if isinstance(value, str) else None
            if not match or match.group(1) not in bases:
                continue
            if not (bases[match.group(1)] / (match.group(2) or "").lstrip("/")).exists():
                report.add(v.dead_task_var(source, name, value))

    for pattern in sorted(set(UNTRACKED_OK) - used):
        report.add(v.stale_allowance(pattern))

    return report
