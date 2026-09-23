"""Detect env schemas that depart from the shape, and drift in what they feed."""

from __future__ import annotations

import re

import yaml

from governance import dotenv, envschema, envtools, repo
from governance.policies.env import violations as v
from governance.reporting import Report

#: `${VAR}`, `${VAR:-default}`, `${VAR:?err}` in a compose file.
_REFERENCE = re.compile(r"\$\{([A-Z][A-Z0-9_]*)[:?}-]")

#: A secret's local_default may only be empty or address the local machine.
_LOOPBACK = re.compile(r"^\w+://(localhost|127\.0\.0\.1|\[::1\]|host\.docker\.internal)(:|/|$)")

#: Minting kinds `repo env sync` can produce.
_GENERATORS = ("hex", "base64")


def _shape(report: Report) -> None:
    for path in repo.tracked_files():
        if path.rsplit("/", 1)[-1] != "env.schema.yaml" or not repo.exists(path):
            continue
        try:
            schema = repo.read_yaml(path)
        except yaml.YAMLError as error:
            report.add(v.malformed(path, f"not valid YAML ({error.__class__.__name__})"))
            continue
        for problem in envschema.problems(schema):
            report.add(v.malformed(path, problem))
        for name, binding in ((schema or {}).get("bindings") or {}).items():
            if not isinstance(binding, dict):
                continue
            kind = binding.get("local_generate")
            if kind is not None and str(kind).partition(":")[0] not in _GENERATORS:
                report.add(v.malformed(path, f"binding `{name}` local_generate `{kind}` is not hex:N or base64:N"))
            if "source" in binding and binding["source"] != "host":
                report.add(v.malformed(path, f"binding `{name}` source `{binding['source']}` is not `host`"))


def _compose_references() -> dict[str, set[str]]:
    """Variables each stack's compose file reads, keyed by stack name."""
    found: dict[str, set[str]] = {}
    for path in repo.glob(f"{envtools.STACKS}/*/compose.yaml"):
        found[path.parent.name] = set(_REFERENCE.findall(path.read_text(encoding="utf-8")))
    return found


def run() -> Report:
    report = Report(policy="env")
    _shape(report)

    if not repo.exists(envtools.SCHEMA):
        return report

    schema = envtools.schema()
    bindings = schema.get("bindings") or {}
    references = _compose_references()
    stacks = set(envtools.stack_profiles())

    if dotenv.render(schema, envtools.HEADER) != (
        repo.read_text(envtools.EXAMPLE) if repo.exists(envtools.EXAMPLE) else ""
    ):
        report.add(v.example_drift(envtools.EXAMPLE))

    for stack, names in sorted(references.items()):
        for name in sorted(names - set(bindings)):
            report.add(v.undeclared_reference(name, f"{envtools.STACKS}/{stack}/compose.yaml"))

    host_sourced = set()
    for name, binding in bindings.items():
        if not isinstance(binding, dict):
            continue
        if binding.get("source") == "host":
            host_sourced.add(name)
        for stack in binding.get("consumers") or []:
            if stack not in stacks:
                report.add(v.unknown_stack(name, stack))
            elif name not in references.get(stack, set()):
                report.add(v.unread_binding(name, stack))
        local_default = binding.get("local_default")
        if binding.get("sensitivity") == "secret" and local_default:
            if not _LOOPBACK.match(str(local_default)):
                report.add(v.secret_default(name, str(local_default)))
        for mirror in binding.get("mirrored_in") or []:
            rel = f".devcontainer/{mirror}"
            if not repo.exists(rel) or str(local_default) not in repo.read_text(rel):
                report.add(v.mirror_drift(name, rel, str(local_default)))

    declared = set(repo.read_jsonc(".devcontainer/devcontainer.json").get("secrets", {}))
    if declared != host_sourced:
        report.add(v.secrets_mismatch(host_sourced - declared, declared - host_sourced))

    return report
