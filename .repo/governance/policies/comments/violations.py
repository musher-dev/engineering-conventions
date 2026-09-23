"""What can go wrong with comment volume, and why each rule exists."""

from __future__ import annotations

from governance.reporting import Violation

DOCS = "CONFIGURATION.md#comments"


def block_too_long(path: str, line: int, length: int, limit: int) -> Violation:
    return Violation(
        code="CMT-01",
        summary=f"comment block of {length} lines (limit {limit})",
        reason=(
            "This template is read before it is run, so a header that buries the "
            "file is a cost paid by every reader. Blocks here run 4-8 lines; past "
            "the limit the content is almost always rationale, which belongs in "
            "CONFIGURATION.md with a pointer left behind."
        ),
        fix=(
            "Move the detail into CONFIGURATION.md and leave a one-line summary "
            "and a pointer, or register the block in ALLOWED_LONG_BLOCKS with a "
            "reason."
        ),
        where=f"{path}:{line}",
        docs=DOCS,
    )


def stale_allowance(path: str) -> Violation:
    return Violation(
        code="CMT-02",
        summary=f"ALLOWED_LONG_BLOCKS still excuses {path}, which no longer needs it",
        reason=(
            "An allowlist that outlives what it excused stops describing the repo "
            "and starts hiding the next violation."
        ),
        fix=f"Drop the {path!r} entry from ALLOWED_LONG_BLOCKS.",
        where=".repo/governance/policies/comments/check.py",
        docs=DOCS,
    )


def dead_pointer(source: str, ref: str, target: str) -> Violation:
    return Violation(
        code="CMT-03",
        summary=f"docs pointer {ref!r} does not resolve",
        reason=(
            "Comments here reference a single canonical explanation instead of "
            "repeating it. That trade is only safe while the references hold: a "
            "renamed heading turns the reasoning into something nobody can find, "
            "and the next reader writes the explanation out again."
        ),
        fix=f"Point at a heading that exists in {target}, or restore the heading.",
        where=source,
        docs=DOCS,
    )
