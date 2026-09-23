"""What can go wrong with committed rulesets, and why each rule exists."""

from __future__ import annotations

from governance.reporting import Violation

DOCS = ".github/rulesets/RULESETS.md"


def invalid_json(name: str, detail: str) -> Violation:
    return Violation(
        code="RS-01",
        summary=f"{name} is not valid JSON ({detail})",
        reason=(
            "Rulesets are applied by pasting or importing this file into "
            "GitHub. A malformed file fails at the moment someone is trying "
            "to restore branch protection, which is the worst time to find out."
        ),
        fix="Fix the JSON syntax.",
        where=f".github/rulesets/{name}",
        docs=DOCS,
    )


def missing_key(name: str, key: str) -> Violation:
    return Violation(
        code="RS-02",
        summary=f"{name} has no '{key}' key",
        reason=(
            "GitHub rejects a ruleset payload missing any of the required "
            "top-level keys, and the error it returns does not name them."
        ),
        fix=f"Add a '{key}' key to the ruleset.",
        where=f".github/rulesets/{name}",
        docs=DOCS,
    )


def unknown_status_check(name: str, context: str, known: list[str]) -> Violation:
    return Violation(
        code="RS-03",
        summary=f"{name} requires status check '{context}', which no CI job produces",
        reason=(
            "A required status check that never reports leaves every pull "
            "request permanently blocked on a check that cannot arrive -- and "
            "the only fix is admin access, at the moment the repo is already "
            "unmergeable. Renaming a CI job is the usual way to cause it."
        ),
        fix=(
            f"Rename the job so its `name:` is '{context}', or update the "
            f"ruleset to one of: {', '.join(known)}."
        ),
        where=f".github/rulesets/{name}",
        docs=DOCS,
    )


def unguarded_ci_job(name: str, job: str) -> Violation:
    return Violation(
        code="RS-04",
        summary=f"CI job '{job}' is not a required status check",
        reason=(
            "A gate that runs but is not required is advisory: a red run can "
            "still merge. Every job in the validate workflow is meant to be "
            "blocking, so a missing entry is drift rather than a decision."
        ),
        fix=(
            f"Add a required_status_checks entry for '{job}' to {name}, or "
            "record it in ADVISORY_JOBS with a reason "
            "(.repo/governance/policies/rulesets/check.py)."
        ),
        where=f".github/rulesets/{name}",
        docs=DOCS,
    )
