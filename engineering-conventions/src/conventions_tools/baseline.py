"""The index published at a git ref, which the append-only check and classify compare against."""

import re
import shutil
import subprocess
from pathlib import Path

from conventions_tools.loading import ContentError, as_map, parse_yaml
from conventions_tools.paths import PRODUCT_DIR_NAME, index_file

# CI passes the push event's `before` SHA, which is all zeros on a branch's
# first push, and an unset variable expands to nothing: neither names a
# baseline, so there is nothing to be append-only against.
NO_BASELINE = re.compile(r"0*")


def _git(product: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
    git = shutil.which("git")
    if git is None:
        raise ContentError(["git is not on PATH, so the append-only check cannot run"])
    return subprocess.run(
        [git, "-C", str(product), *arguments], capture_output=True, text=True, check=False
    )


def baseline_index(product: Path, ref: str) -> dict[str, object] | None:
    """The index published at `ref`, or None when `ref` predates it.

    Raises ContentError when `ref` does not resolve: a mistyped or unfetched
    baseline must fail rather than pass by checking nothing.
    """
    if _git(product, "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}").returncode != 0:
        raise ContentError(
            [
                f"--baseline {ref!r} does not resolve to a commit; fetch it "
                "(e.g. git fetch origin main) or pass a ref that exists"
            ]
        )
    relative = index_file(product).relative_to(product).as_posix()
    shown = _git(product, "show", f"{ref}:{PRODUCT_DIR_NAME}/{relative}")
    if shown.returncode != 0:
        return None
    try:
        return unwrap_index(parse_yaml(shown.stdout, ref))
    except ContentError:
        return None


def unwrap_index(document: object) -> dict[str, object]:
    """The index inside a parsed index.json, which nests it as data.conventions.index."""
    return as_map(as_map(as_map(document).get("conventions")).get("index"))
