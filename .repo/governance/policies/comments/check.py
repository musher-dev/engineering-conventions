"""Detect comment blocks that have outgrown their file, and dead doc pointers.

The rule this enforces is written in CONFIGURATION.md -> "Comments": say the
non-obvious, say it once, and point at it from everywhere else. CMT-01 caps the
volume; CMT-03 keeps the pointers that make the trade possible from rotting.
"""

from __future__ import annotations

import ast
import re
from pathlib import Path

from governance import repo
from governance.policies.comments import violations as v
from governance.reporting import Report

#: Longest contiguous run of comment lines a file may carry. The natural block
#: size in this repo is 4-8 lines and nothing legitimate sits between 16 and 22,
#: so the limit lands in a real gap rather than on an arbitrary round number.
MAX_BLOCK = 20

#: Files whose long block is the point of the file, and why. Empty by design --
#: an entry here is a standing exemption, so it has to earn its place.
ALLOWED_LONG_BLOCKS: dict[str, str] = {}

#: Where comments sit next to code. Markdown is absent on purpose: `#` starts a
#: heading there, not a comment.
SCAN_GLOBS = (
    ".devcontainer/Dockerfile",
    ".devcontainer/.dockerignore",
    ".devcontainer/.env.example",
    ".devcontainer/*.toml",
    ".devcontainer/**/*.sh",
    ".devcontainer/**/*.yaml",
    ".config/*.yml",
    ".config/*.yaml",
    ".github/**/*.yml",
    ".github/**/*.yaml",
    "taskfiles/*.yml",
    "Taskfile.yml",
    ".repo/**/*.py",
    ".repo/*.toml",
)

#: Lines that start with `#` but are instructions to a tool, not prose. They sit
#: inside blocks and must not inflate them.
_DIRECTIVE = re.compile(
    r"^#\s*(!|shellcheck\b|syntax=|type:\s|noqa\b|pylint:|mypy:|fmt:|nosec\b)"
)

#: `docs="CONFIGURATION.md#anchor"` and the DOCS constants the policies share.
_DOC_REF = re.compile(r'"([A-Za-z0-9_./-]+\.md#[^"]+)"')

_HEADING = re.compile(r"^#{1,6}\s+(.*)$", re.MULTILINE)


def _slug(heading: str) -> str:
    """GitHub's heading-anchor slug: lowercase, drop punctuation, spaces to dashes."""
    text = heading.strip().lower()
    text = re.sub(r"[^\w\s-]", "", text)
    return re.sub(r"\s", "-", text)


def _anchors(rel: str) -> set[str]:
    return {_slug(m.group(1)) for m in _HEADING.finditer(repo.read_text(rel))}


def _blocks(path: Path) -> list[tuple[int, int]]:
    """Contiguous comment runs as (start_line, length), directives excluded."""
    found: list[tuple[int, int]] = []
    start = length = 0
    for number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = raw.strip()
        is_comment = stripped.startswith("#") and not _DIRECTIVE.match(stripped)
        if is_comment:
            start = start or number
            length += 1
            continue
        # A directive interrupts prose without ending the block it sits in, so
        # only a genuine line of code closes one.
        if stripped.startswith("#"):
            continue
        if start:
            found.append((start, length))
        start = length = 0
    if start:
        found.append((start, length))
    return found


def _tracked(pattern: str) -> list[Path]:
    """Tracked matches only: `uv run` builds .repo/.venv, whose vendored code is not ours."""
    tracked = set(repo.tracked_files())
    return [p for p in repo.glob(pattern) if p.is_file() and repo.rel(p) in tracked]


def _scanned_files() -> list[Path]:
    seen: dict[str, Path] = {}
    for pattern in SCAN_GLOBS:
        for path in _tracked(pattern):
            seen[repo.rel(path)] = path
    return [seen[key] for key in sorted(seen)]


def run() -> Report:
    report = Report(policy="comments")

    used: set[str] = set()
    for path in _scanned_files():
        rel = repo.rel(path)
        for line, length in _blocks(path):
            if length <= MAX_BLOCK:
                continue
            if rel in ALLOWED_LONG_BLOCKS:
                used.add(rel)
                continue
            report.add(v.block_too_long(rel, line, length, MAX_BLOCK))

    for rel in sorted(set(ALLOWED_LONG_BLOCKS) - used):
        report.add(v.stale_allowance(rel))

    # Pointers are read statically: the violation factories take arguments, so
    # calling them just to inspect `docs` would mean inventing fixture values.
    for path in _tracked(".repo/**/*.py"):
        source = repo.rel(path)
        for node in ast.walk(ast.parse(path.read_text(encoding="utf-8"))):
            if not isinstance(node, ast.Constant) or not isinstance(node.value, str):
                continue
            match = _DOC_REF.fullmatch(f'"{node.value}"')
            if not match:
                continue
            target, _, anchor = node.value.partition("#")
            if not repo.exists(target) or anchor not in _anchors(target):
                report.add(v.dead_pointer(f"{source}:{node.lineno}", node.value, target))

    return report
