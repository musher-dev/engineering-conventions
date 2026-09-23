"""Policy modules and the registry of them.

Each policy is a package with two files: `violations.py` declares the
failures it can report (including why each rule exists), and `check.py`
detects them. `run()` returns a `Report`.

Registering a policy here is the only wiring it needs -- the CLI derives
`repo check` and the per-policy `repo <name> check` subcommands from this
mapping.
"""

from __future__ import annotations

from collections.abc import Callable

from governance.policies import (
    comments,
    config,
    env,
    hooks,
    layout,
    paths,
    ports,
    rulesets,
    toolchain,
)
from governance.reporting import Report

POLICIES: dict[str, Callable[[], Report]] = {
    "config": config.run,
    "layout": layout.run,
    "paths": paths.run,
    "env": env.run,
    "ports": ports.run,
    "hooks": hooks.run,
    "rulesets": rulesets.run,
    "toolchain": toolchain.run,
    "comments": comments.run,
}

__all__ = ["POLICIES"]
