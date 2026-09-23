"""What can go wrong with port declarations, and why each rule exists."""

from __future__ import annotations

from governance.reporting import Violation

DOCS = "CONFIGURATION.md#port-allocation"

_WHY_DRIFT = (
    "A port is declared in three places -- the CONFIGURATION.md table, "
    "devcontainer.json, and the stack's compose.yaml. Nothing links them, so "
    "they drift silently and the symptom is a service that starts but is "
    "unreachable from the host."
)


def attributes_mismatch(missing: set[int], extra: set[int]) -> Violation:
    parts = []
    if missing:
        parts.append(f"missing from portsAttributes: {sorted(missing)}")
    if extra:
        parts.append(f"in portsAttributes but not forwardPorts: {sorted(extra)}")
    return Violation(
        code="PORT-01",
        summary="forwardPorts and portsAttributes disagree; " + "; ".join(parts),
        reason=(
            "A forwarded port with no attributes gets a bare number in the "
            "editor's port list and defaults to a notification popup, which "
            "is why every entry here sets a label and onAutoForward."
        ),
        fix="Add or remove the entries so both lists hold the same ports.",
        where=".devcontainer/devcontainer.json",
        docs=DOCS,
    )


def not_forwarded(port: int, source: str) -> Violation:
    return Violation(
        code="PORT-02",
        summary=f"port {port} is published by compose but never forwarded",
        reason=_WHY_DRIFT + " A published port that is not forwarded is "
        "reachable inside the container and invisible outside it.",
        fix=f"Add {port} to forwardPorts and portsAttributes in devcontainer.json.",
        where=source,
        docs=DOCS,
    )


def undocumented(port: int) -> Violation:
    return Violation(
        code="PORT-03",
        summary=f"port {port} is forwarded but absent from the port table",
        reason=_WHY_DRIFT + " The table is the only place a human looks to "
        "find a free port before claiming one.",
        fix=f"Add a row for {port} to the Port Allocation table in CONFIGURATION.md.",
        where="CONFIGURATION.md",
        docs=DOCS,
    )


def documented_but_unused(port: int) -> Violation:
    return Violation(
        code="PORT-04",
        summary=f"port {port} is in the port table but nothing forwards it",
        reason=_WHY_DRIFT + " A phantom row makes the range look more "
        "crowded than it is and the next service skips a free number.",
        fix=f"Remove the {port} row from CONFIGURATION.md, or forward it.",
        where="CONFIGURATION.md",
        docs=DOCS,
    )


def out_of_range(port: int, low: int, high: int, source: str) -> Violation:
    return Violation(
        code="PORT-05",
        summary=f"port {port} is outside the reserved {low}-{high} range",
        reason=(
            "The template reserves one contiguous block so a consuming "
            "project can allocate its own ports without checking for "
            "collisions against every stack."
        ),
        fix=f"Move it into {low}-{high}, or widen the range in CONFIGURATION.md.",
        where=source,
        docs=DOCS,
    )
