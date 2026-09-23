"""Detect disagreement between the three places a port is declared."""

from __future__ import annotations

import re

from governance import repo
from governance.policies.ports import violations as v
from governance.reporting import Report

RANGE_LOW, RANGE_HIGH = 15432, 15460

DEVCONTAINER = ".devcontainer/devcontainer.json"
DOC = "CONFIGURATION.md"

#: `| 15432 | PostgreSQL | TCP |` in the Port Allocation table.
_TABLE_ROW = re.compile(r"^\|\s*(\d{4,5})\s*\|")
#: `- "127.0.0.1:15432:5432"` in a stack compose file.
_PUBLISHED = re.compile(r"^\s*-\s*[\"']?(?:[\d.]+:)?(\d{4,5}):\d+")


def _documented_ports() -> set[int]:
    """Ports listed in the CONFIGURATION.md Port Allocation table."""
    ports: set[int] = set()
    in_section = False
    for line in repo.read_text(DOC).splitlines():
        if line.startswith("### Port Allocation"):
            in_section = True
            continue
        if in_section and line.startswith("### "):
            break
        if in_section:
            match = _TABLE_ROW.match(line)
            if match:
                ports.add(int(match.group(1)))
    return ports


def _published_ports() -> dict[int, str]:
    """Host ports published by the stack compose files, mapped to their file."""
    found: dict[int, str] = {}
    for path in repo.glob(".devcontainer/stacks/*/compose.yaml"):
        for line in path.read_text(encoding="utf-8").splitlines():
            match = _PUBLISHED.match(line)
            if match:
                found.setdefault(int(match.group(1)), repo.rel(path))
    return found


def run() -> Report:
    report = Report(policy="ports")

    devcontainer = repo.read_jsonc(DEVCONTAINER)
    forwarded = {int(p) for p in devcontainer.get("forwardPorts", [])}
    attributes = {int(p) for p in devcontainer.get("portsAttributes", {})}
    documented = _documented_ports()
    published = _published_ports()

    if forwarded != attributes:
        report.add(v.attributes_mismatch(forwarded - attributes, attributes - forwarded))

    for port, source in sorted(published.items()):
        if port not in forwarded:
            report.add(v.not_forwarded(port, source))

    for port in sorted(forwarded - documented):
        report.add(v.undocumented(port))

    for port in sorted(documented - forwarded):
        report.add(v.documented_but_unused(port))

    for port in sorted(forwarded):
        if not RANGE_LOW <= port <= RANGE_HIGH:
            report.add(v.out_of_range(port, RANGE_LOW, RANGE_HIGH, DEVCONTAINER))
    for port, source in sorted(published.items()):
        if not RANGE_LOW <= port <= RANGE_HIGH:
            report.add(v.out_of_range(port, RANGE_LOW, RANGE_HIGH, source))

    return report
