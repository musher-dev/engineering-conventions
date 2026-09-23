"""What can go wrong with hook/CI parity, and why the rule exists."""

from __future__ import annotations

from governance.reporting import Violation

DOCS = "CONFIGURATION.md#where-configuration-lives"

_WHY = (
    "A check that runs locally but not in CI is unenforced -- anyone can "
    "push past it. A check that runs in CI but not locally is discovered at "
    "review time instead of before the commit. Both directions have to be a "
    "deliberate, recorded decision rather than an accident."
)


def unregistered_hook(name: str) -> Violation:
    return Violation(
        code="HOOK-01",
        summary=f"lefthook job '{name}' has no registered CI counterpart",
        reason=_WHY,
        fix=(
            f"Add a CI job that runs the same check and map it in "
            f"HOOK_TO_CI, or record '{name}' in LOCAL_ONLY with a reason "
            "(.repo/governance/policies/hooks/check.py)."
        ),
        where=".config/lefthook.yml",
        docs=DOCS,
    )


def missing_ci_job(hook: str, ci_job: str) -> Violation:
    return Violation(
        code="HOOK-02",
        summary=f"lefthook job '{hook}' maps to CI job '{ci_job}', which does not exist",
        reason=_WHY,
        fix=f"Add the '{ci_job}' job to .github/workflows/validate.yaml, or fix the mapping.",
        where=".github/workflows/validate.yaml",
        docs=DOCS,
    )


def unregistered_ci_job(name: str) -> Violation:
    return Violation(
        code="HOOK-03",
        summary=f"CI job '{name}' is not accounted for by any policy entry",
        reason=_WHY,
        fix=(
            f"Add a lefthook job mapped to '{name}', or record it in CI_ONLY "
            "with a reason (.repo/governance/policies/hooks/check.py)."
        ),
        where=".github/workflows/validate.yaml",
        docs=DOCS,
    )


def stale_registration(kind: str, name: str) -> Violation:
    return Violation(
        code="HOOK-04",
        summary=f"{kind} entry '{name}' no longer matches anything in the repo",
        reason=(
            "An allowlist that outlives the thing it excused quietly widens "
            "over time until it excuses something nobody chose to excuse."
        ),
        fix=f"Remove '{name}' from the {kind} table.",
        where=".repo/governance/policies/hooks/check.py",
        docs=DOCS,
    )
