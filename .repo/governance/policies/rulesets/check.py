"""Detect drift between committed rulesets and the CI that satisfies them.

Shape only -- this never diffs against live GitHub state. Reading a
repository's rulesets needs `administration:read`, which the default
GITHUB_TOKEN does not have, so a drift detector would require a long-lived
PAT or fail open. See .github/rulesets/RULESETS.md for the operator command.
"""

from __future__ import annotations

import json

from governance import repo
from governance.policies.rulesets import violations as v
from governance.reporting import Report

RULESET_DIR = ".github/rulesets"
WORKFLOW = ".github/workflows/validate.yaml"

REQUIRED_KEYS = ("name", "target", "enforcement", "rules")

#: CI jobs deliberately not required to pass before merge, and why.
ADVISORY_JOBS: dict[str, str] = {}


def _ci_job_names() -> list[str]:
    workflow = repo.read_yaml(WORKFLOW) or {}
    names = []
    for job_id, body in (workflow.get("jobs") or {}).items():
        names.append(str(body.get("name", job_id)) if isinstance(body, dict) else job_id)
    return sorted(names)


def _required_contexts(ruleset: dict) -> set[str]:
    contexts: set[str] = set()
    for rule in ruleset.get("rules", []) or []:
        if not isinstance(rule, dict) or rule.get("type") != "required_status_checks":
            continue
        params = rule.get("parameters") or {}
        for check in params.get("required_status_checks", []) or []:
            if isinstance(check, dict) and "context" in check:
                contexts.add(str(check["context"]))
    return contexts


def run() -> Report:
    report = Report(policy="rulesets")

    paths = repo.glob(f"{RULESET_DIR}/*.json")
    if not paths:
        return report

    known = _ci_job_names()

    for path in paths:
        name = path.name
        try:
            ruleset = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            report.add(v.invalid_json(name, f"line {exc.lineno}: {exc.msg}"))
            continue

        for key in REQUIRED_KEYS:
            if key not in ruleset:
                report.add(v.missing_key(name, key))

        contexts = _required_contexts(ruleset)
        if not contexts:
            continue

        for context in sorted(contexts - set(known)):
            report.add(v.unknown_status_check(name, context, known))

        for job in known:
            if job not in contexts and job not in ADVISORY_JOBS:
                report.add(v.unguarded_ci_job(name, job))

    return report
