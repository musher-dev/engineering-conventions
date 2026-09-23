"""Detect drift in the tools the container image bakes itself.

Three tools (bun, uv, task) are installed by .devcontainer/Dockerfile rather
than by a Feature, for a reason that is easy to lose: their Features fail on
rate-limited build hosts. This policy keeps that decision from being quietly
undone, and keeps the pins that replaced them honest.
"""

from __future__ import annotations

import re

from governance import repo
from governance.policies.toolchain import violations as v
from governance.reporting import Report

DOCKERFILE = ".devcontainer/Dockerfile"
DEVCONTAINER = ".devcontainer/devcontainer.json"
WORKFLOW = ".github/workflows/validate.yaml"

#: Feature ref (without the version suffix) -> the tool it would install.
#: Only Features whose installers were read and confirmed to call
#: api.github.com belong here; deno, shellcheck and postgresql-client were
#: checked and are clean. See CONFIGURATION.md -> "Runtimes & Tools".
BANNED_FEATURES = {
    "ghcr.io/devcontainers-extra/features/bun": "bun",
    "ghcr.io/devcontainers-extra/features/uv": "uv",
    "ghcr.io/devcontainers-extra/features/go-task": "task",
}

#: ARG name -> the tool it pins. Every one of these must exist and be exact.
REQUIRED_ARGS = {
    "BUN_VERSION": "bun",
    "UV_VERSION": "uv",
    "TASK_VERSION": "task",
    "MISE_VERSION": "mise",
}

#: Values that are a moving target rather than a pin.
FLOATING = {"latest", "stable", "main", "master", ""}

_ARG = re.compile(r"^ARG\s+([A-Z0-9_]+)=(.*)$", re.MULTILINE)


def _dockerfile_args() -> dict[str, str]:
    """The ARG defaults declared by the Dockerfile."""
    return {m.group(1): m.group(2).strip() for m in _ARG.finditer(repo.read_text(DOCKERFILE))}


def _ci_task_version() -> str | None:
    """The version arduino/setup-task is pinned to in CI, if it is used."""
    workflow = repo.read_yaml(WORKFLOW) or {}
    for job in (workflow.get("jobs") or {}).values():
        for step in (job or {}).get("steps", []) or []:
            uses = str((step or {}).get("uses", ""))
            if uses.startswith("arduino/setup-task@"):
                version = ((step or {}).get("with") or {}).get("version")
                if version is not None:
                    return str(version)
    return None


def run() -> Report:
    report = Report(policy="toolchain")

    features = repo.read_jsonc(DEVCONTAINER).get("features", {})
    for ref in features:
        # Feature refs carry a version suffix (`...:1`); compare the name only.
        name = ref.rsplit(":", 1)[0]
        tool = BANNED_FEATURES.get(name)
        if tool:
            report.add(v.feature_reintroduced(ref, tool))

    args = _dockerfile_args()
    for name, tool in REQUIRED_ARGS.items():
        if name not in args:
            report.add(v.missing_arg(name, tool))
        elif args[name].lower().lstrip("v") in FLOATING:
            report.add(v.floating_arg(name, args[name]))

    baked_task = args.get("TASK_VERSION")
    ci_task = _ci_task_version()
    if baked_task and ci_task and baked_task.lstrip("v") != ci_task.lstrip("v"):
        report.add(v.task_version_drift(baked_task, ci_task, WORKFLOW))

    return report
