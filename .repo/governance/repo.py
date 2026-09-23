"""Repository location and the file readers the policies share."""

from __future__ import annotations

import json
import os
import re
import subprocess
import tomllib
from functools import lru_cache
from pathlib import Path

import yaml


@lru_cache(maxsize=1)
def repo_root() -> Path:
    """The repository root.

    Walks up from the working directory looking for the marker files this
    template is guaranteed to have, so `repo check` works from any
    subdirectory the way git does.
    """
    here = Path.cwd().resolve()
    for candidate in (here, *here.parents):
        if (candidate / ".devcontainer").is_dir() and (candidate / ".git").exists():
            return candidate
    return here


def read_text(rel: str) -> str:
    return (repo_root() / rel).read_text(encoding="utf-8")


def read_yaml(rel: str):
    return yaml.safe_load(read_text(rel))


_LINE_COMMENT = re.compile(r"//[^\n]*")
_TRAILING_COMMA = re.compile(r",(\s*[}\]])")


def read_jsonc(rel: str):
    """Parse a JSON-with-comments file such as devcontainer.json.

    devcontainer.json is JSONC by specification, so `json.loads` cannot read
    it directly and this repo's copy is heavily commented on purpose.
    """
    raw = read_text(rel)
    out: list[str] = []
    in_string = escaped = False
    i = 0
    while i < len(raw):
        char = raw[i]
        if in_string:
            out.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            i += 1
            continue
        if char == '"':
            in_string = True
            out.append(char)
            i += 1
        elif raw.startswith("//", i):
            newline = raw.find("\n", i)
            i = len(raw) if newline < 0 else newline
        elif raw.startswith("/*", i):
            end = raw.find("*/", i)
            i = len(raw) if end < 0 else end + 2
        else:
            out.append(char)
            i += 1
    return json.loads(_TRAILING_COMMA.sub(r"\1", "".join(out)))


def read_toml(rel: str) -> dict:
    return tomllib.loads(read_text(rel))


def exists(rel: str) -> bool:
    return (repo_root() / rel).exists()


def glob(pattern: str) -> list[Path]:
    return sorted(repo_root().glob(pattern))


def rel(path: Path) -> str:
    return path.relative_to(repo_root()).as_posix()


@lru_cache(maxsize=1)
def tracked_files() -> tuple[str, ...]:
    """Repo-relative paths git tracks, staged files included.

    `ls-files` reads the index, so a root `Cargo.toml` that has only been
    `git add`-ed is already visible to a pre-commit run. Outside a git
    checkout, falls back to walking the tree.
    """
    root = repo_root()
    try:
        out = subprocess.run(
            ["git", "ls-files", "-z"], cwd=root, capture_output=True, check=True
        ).stdout
        return tuple(sorted(p for p in out.decode().split("\0") if p))
    except (OSError, subprocess.CalledProcessError):
        found = []
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d != ".git"]
            found.extend(rel(Path(dirpath) / f) for f in filenames)
        return tuple(sorted(found))


def repo_name() -> str | None:
    """The repository's name, from CI or the origin remote; None if unknowable.

    Not the checkout directory's name: a clone can live under any folder.
    """
    slug = os.environ.get("GITHUB_REPOSITORY", "")
    if "/" in slug:
        return slug.rsplit("/", 1)[-1]
    try:
        url = subprocess.run(
            ["git", "config", "--get", "remote.origin.url"],
            cwd=repo_root(), capture_output=True, check=True, text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None
    name = url.rstrip("/").rsplit("/", 1)[-1].rsplit(":", 1)[-1]
    return name.removesuffix(".git") or None


LAYOUT_FILE = ".repo/layout.toml"

#: A product directory name: one path segment, no leading dot.
PRODUCT_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")


def product() -> str | None:
    """The declared product directory, or None if none (or none valid) is declared.

    Never raises: `repo layout check` owns reporting a broken declaration, and
    every other caller only needs to know where the product is, if anywhere.
    """
    try:
        value = read_toml(LAYOUT_FILE).get("product")
    except (OSError, tomllib.TOMLDecodeError):
        return None
    if isinstance(value, str) and PRODUCT_NAME.fullmatch(value):
        return value
    return None
