"""The shared violation record and its rendering.

A violation is not just "this is wrong". It carries the *reason* the rule
exists and the action that resolves it, because this repo enforces its
layout mechanically instead of in prose -- the checker has to be able to
explain itself.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass, field


@dataclass(frozen=True)
class Violation:
    """One failed expectation."""

    code: str
    """Stable identifier, e.g. "CFG-03". Referenceable in review."""

    summary: str
    """One line: what is wrong."""

    reason: str
    """Why the rule exists. Without this the check is cargo cult."""

    fix: str
    """The concrete action that resolves it."""

    where: str = ""
    """Repo-relative path (and optional :line) the violation attaches to."""

    docs: str = "CONFIGURATION.md#where-configuration-lives"
    """Pointer to the human-facing policy."""

    def render(self) -> str:
        head = f"{self.code}  {self.summary}"
        if self.where:
            head = f"{self.code}  {self.where}: {self.summary}"
        return "\n".join(
            (
                head,
                f"      why: {self.reason}",
                f"      fix: {self.fix}",
                f"      doc: {self.docs}",
            )
        )


@dataclass
class Report:
    """The result of running one policy."""

    policy: str
    violations: list[Violation] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.violations

    def add(self, violation: Violation) -> None:
        self.violations.append(violation)


def render_reports(reports: list[Report], stream=sys.stdout) -> int:
    """Print every report. Return a process exit code."""
    failed = [r for r in reports if not r.ok]
    for report in reports:
        mark = "ok  " if report.ok else "FAIL"
        count = "" if report.ok else f"  ({len(report.violations)})"
        print(f"[{mark}] {report.policy}{count}", file=stream)
    if not failed:
        return 0
    print("", file=stream)
    for report in failed:
        for violation in report.violations:
            print(f"  {violation.render()}", file=stream)
            print("", file=stream)
    total = sum(len(r.violations) for r in failed)
    plural = "s" if total != 1 else ""
    print(f"{total} violation{plural} across {len(failed)} policy check(s).", file=stream)
    return 1
