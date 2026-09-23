"""Detect drift between local git hooks and CI.

Both tables below are deliberate: an entry is a recorded decision that a
check runs in only one place, with the reason attached. Adding a job on
either side without registering it here fails the build.
"""

from __future__ import annotations

from governance import repo
from governance.policies.hooks import violations as v
from governance.reporting import Report

LEFTHOOK = ".config/lefthook.yml"
WORKFLOW = ".github/workflows/validate.yaml"

#: lefthook job -> the CI job that runs the equivalent check.
HOOK_TO_CI = {
    "markdown": "lint",
    "yaml": "lint",
    "actions": "lint",
    "spelling": "lint",
    "governance": "governance",
}

#: lefthook jobs with no CI counterpart, and why.
LOCAL_ONLY = {
    "block-devcontainer-env": (
        "Guards against staging a gitignored secrets file. CI never has a "
        ".devcontainer/.env to stage, so the check has nothing to assert there."
    ),
}

#: CI jobs with no local counterpart, and why.
CI_ONLY = {
    "shellcheck": (
        "Runs against the whole scripts tree via a pinned action; the "
        "equivalent local run would need shellcheck installed on every host."
    ),
    "compose": (
        "Requires a Docker daemon to resolve `docker compose config`, which "
        "is not guaranteed inside the dev container."
    ),
    "lockfile": (
        "Resolves every Feature digest over the network; too slow and too "
        "network-dependent for a pre-commit hook."
    ),
    "build": (
        "Builds the whole dev container image. Minutes, not seconds -- a "
        "pre-commit hook cannot absorb that."
    ),
}


def _lefthook_jobs() -> set[str]:
    config = repo.read_yaml(LEFTHOOK) or {}
    names: set[str] = set()
    for hook, body in config.items():
        if not isinstance(body, dict):
            continue
        for job in body.get("jobs", []) or []:
            if isinstance(job, dict) and "name" in job:
                names.add(str(job["name"]))
    return names


def _ci_jobs() -> set[str]:
    workflow = repo.read_yaml(WORKFLOW) or {}
    return set(workflow.get("jobs", {}) or {})


def run() -> Report:
    report = Report(policy="hooks")

    hooks = _lefthook_jobs()
    ci = _ci_jobs()

    for name in sorted(hooks):
        if name in LOCAL_ONLY:
            continue
        target = HOOK_TO_CI.get(name)
        if target is None:
            report.add(v.unregistered_hook(name))
        elif target not in ci:
            report.add(v.missing_ci_job(name, target))

    accounted = set(HOOK_TO_CI.values()) | set(CI_ONLY)
    for name in sorted(ci - accounted):
        report.add(v.unregistered_ci_job(name))

    # Allowlists must not outlive what they excuse.
    for name in sorted(set(LOCAL_ONLY) - hooks):
        report.add(v.stale_registration("LOCAL_ONLY", name))
    for name in sorted(set(CI_ONLY) - ci):
        report.add(v.stale_registration("CI_ONLY", name))
    for name in sorted(set(HOOK_TO_CI) - hooks):
        report.add(v.stale_registration("HOOK_TO_CI", name))

    return report
