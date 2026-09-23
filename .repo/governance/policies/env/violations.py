"""What can go wrong with an env schema and what it renders, and why.

The dev-environment schema (.devcontainer/env.schema.yaml) is the source of
truth for a file two other tools read as dotenv, and for values a handful of
configs repeat literally. Each rule below is one of those joins.
"""

from __future__ import annotations

from governance.reporting import Violation

SHAPE = "LAYOUT.md#the-env-contract"
DEV = "CONFIGURATION.md#environment-variables"


def malformed(path: str, problem: str) -> Violation:
    return Violation(
        code="ENV-01",
        summary=f"{path}: {problem}",
        reason=(
            "The schema is the contract other tools read -- the renderer, the "
            "parity checks, `repo env doctor`. One shape across every Musher "
            "repo is what lets them read any repo's schema without a special case."
        ),
        fix="Give every binding a `type`, a `sensitivity` (public|internal|secret) and a `description`.",
        where=path,
        docs=SHAPE,
    )


def example_drift(example: str) -> Violation:
    return Violation(
        code="ENV-02",
        summary=f"{example} is not what the schema renders",
        reason=(
            "The host seeds .env by copying this file with bash, which cannot "
            "read YAML -- so the rendering is the artifact, and a hand-edit to "
            "it is a second source of truth that the schema will silently outlive."
        ),
        fix="Run `task env:render` (never edit the rendered file by hand).",
        where=example,
        docs=DEV,
    )


def undeclared_reference(name: str, where: str) -> Violation:
    return Violation(
        code="ENV-03",
        summary=f"compose reads ${{{name}}}, which the schema does not declare",
        reason=(
            "An undeclared variable is invisible to the template, the renderer "
            "and `repo env doctor`, so it silently takes its `:-default` and "
            "nobody is ever told a value was expected."
        ),
        fix=f"Declare {name} in .devcontainer/env.schema.yaml, or stop reading it.",
        where=where,
        docs=DEV,
    )


def unread_binding(name: str, stack: str) -> Violation:
    return Violation(
        code="ENV-03",
        summary=f"{name} lists consumer '{stack}', which never reads it",
        reason=(
            "`consumers` is what makes a requirement conditional on the stacks "
            "that are running. A consumer that does not read the value makes "
            "`repo env doctor` demand it for no reason."
        ),
        fix=f"Remove '{stack}' from {name}'s consumers, or read it in that stack's compose file.",
        where=".devcontainer/env.schema.yaml",
        docs=DEV,
    )


def unknown_stack(name: str, stack: str) -> Violation:
    return Violation(
        code="ENV-04",
        summary=f"{name} names consumer '{stack}', which is not a stack",
        reason="A consumer that does not exist can never be active, so the binding is never required.",
        fix=f"Use a directory name under .devcontainer/stacks/, or drop '{stack}'.",
        where=".devcontainer/env.schema.yaml",
        docs=DEV,
    )


def mirror_drift(name: str, path: str, value: str) -> Violation:
    return Violation(
        code="ENV-05",
        summary=f"{path} does not contain {name}'s value ({value!r})",
        reason=(
            "That file is native YAML with no env interpolation, so it repeats "
            "the credential literally. Changing one side alone leaves a stack "
            "that starts and then fails to authenticate."
        ),
        fix=f"Update {path} to match, or correct {name}'s mirrored_in list.",
        where=path,
        docs=DEV,
    )


def secrets_mismatch(missing: set[str], extra: set[str]) -> Violation:
    detail = ", ".join(sorted(f"+{name}" for name in missing) + sorted(f"-{name}" for name in extra))
    return Violation(
        code="ENV-06",
        summary=f"devcontainer.json `secrets` does not match the host-sourced bindings ({detail})",
        reason=(
            "`secrets` is how Codespaces knows to prompt for a value at creation "
            "time. A host-sourced binding missing from it silently arrives empty "
            "for anyone who is not on a machine with it exported."
        ),
        fix="Match the `secrets` block to the bindings declaring `source: host`.",
        where=".devcontainer/devcontainer.json",
        docs=DEV,
    )


def secret_default(name: str, value: str) -> Violation:
    return Violation(
        code="ENV-07",
        summary=f"{name} is a secret with a committed local_default ({value!r})",
        reason=(
            "local_default lives in tracked YAML and is rendered uncommented, so "
            "a real credential there is a shared secret in version control."
        ),
        fix=f"Leave {name}'s local_default empty, point it at a loopback host, or use local_generate.",
        where=".devcontainer/env.schema.yaml",
        docs=DEV,
    )
