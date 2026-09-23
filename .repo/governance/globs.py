"""Glob matching against the tracked-file list, shared by the path policies.

Tools that take a glob -- lefthook, .gitattributes, paths-filter -- never fail
when it matches nothing; the job it scopes just stops running. These helpers
answer "does this pattern still name something?" the way those tools read it.
"""

from __future__ import annotations

import re
from collections.abc import Iterable


def expand_braces(pattern: str) -> list[str]:
    """`a.{yml,yaml}` -> [`a.yml`, `a.yaml`], nested braces included."""
    match = re.search(r"\{([^{}]*)\}", pattern)
    if not match:
        return [pattern]
    head, tail = pattern[: match.start()], pattern[match.end() :]
    return [
        expanded
        for option in match.group(1).split(",")
        for expanded in expand_braces(head + option + tail)
    ]


def glob_regex(pattern: str) -> re.Pattern[str]:
    """Doublestar semantics: `**` spans directories, `*` and `?` do not.

    A match on a directory also matches everything beneath it.
    """
    out, i = [], 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif pattern.startswith("**", i):
            out.append(".*")
            i += 2
        elif pattern[i] == "*":
            out.append("[^/]*")
            i += 1
        elif pattern[i] == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return re.compile("".join(out) + r"(?:/.*)?\Z")


def _is_literal(pattern: str) -> bool:
    return not any(char in pattern for char in "*?[")


def matches(pattern: str, files: Iterable[str], gitignore_style: bool = False) -> bool:
    """Whether `pattern` still names at least one of `files`.

    A literal brace alternative must match on its own: `{docs,README.md}` with
    `README.md` deleted is a stale reference. A wildcard alternative need not:
    `*.{yml,yaml}` in a repo that only has `.yaml` files is a hedge, not a bug.

    `gitignore_style` anchors slash-free patterns anywhere in the tree, as
    .gitattributes and .gitignore do.
    """
    files = tuple(files)
    regexes = []
    for alternative in expand_braces(pattern.lstrip("/")):
        alternative = alternative.rstrip("/")
        literal = _is_literal(alternative)
        if gitignore_style and "/" not in alternative:
            alternative = "**/" + alternative
        regex = glob_regex(alternative)
        if literal and not any(regex.match(f) for f in files):
            return False
        regexes.append(regex)
    return any(regex.match(f) for regex in regexes for f in files)
