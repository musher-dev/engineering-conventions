"""`repo env render|doctor|sync|setup` -- the developer's side of the env schema.

These are local commands, not policy checks: they read the developer's own
`.env`, which is gitignored and expected to differ. The blocking half of the
contract (schema shape, `.env.example` freshness, compose parity) is the `env`
policy, which CI and pre-commit run.

The rule they share: the container always starts. A missing value stops the
stack that needs it, never the environment you would fix it from.
"""

from __future__ import annotations

import argparse
import difflib
import getpass
import re
import secrets
import sys
from pathlib import Path

from governance import dotenv, repo

SCHEMA = ".devcontainer/env.schema.yaml"
EXAMPLE = ".devcontainer/.env.example"
ENV = ".devcontainer/.env"
STACKS = ".devcontainer/stacks"
PROFILES_KEY = "COMPOSE_PROFILES"

HEADER = """
# ============================================================
# Dev Container Environment — GENERATED. Do not edit.
# ============================================================
# Rendered from .devcontainer/env.schema.yaml by `task env:render`.
# `repo env check` fails when the two disagree, so edit the schema.
#
# On first build the host-side initializeCommand copies this file to
# .devcontainer/.env (gitignored), which feeds both Docker Compose and the
# container itself. `task env:setup` fills in what is missing;
# `task env:doctor` says what that is.
#
# Three states: `VAR=value` is a local default, `VAR=` must be filled in,
# and `# VAR=value` is an optional override — uncomment to enable.
# ============================================================
"""


def schema() -> dict:
    return repo.read_yaml(SCHEMA) or {}


def bindings() -> dict[str, dict]:
    return schema().get("bindings") or {}


def stack_profiles() -> dict[str, set[str]]:
    """Each stack, and the profiles that enable it. An empty set means always on."""
    found: dict[str, set[str]] = {}
    for path in repo.glob(f"{STACKS}/*/compose.yaml"):
        services = (repo.read_yaml(repo.rel(path)) or {}).get("services") or {}
        profiles: set[str] = set()
        always_on = False
        for service in services.values():
            names = (service or {}).get("profiles") or []
            profiles.update(names)
            always_on = always_on or not names
        found[path.parent.name] = set() if always_on else profiles
    return found


def active_stacks(enabled: list[str]) -> set[str]:
    return {
        stack for stack, profiles in stack_profiles().items()
        if not profiles or profiles & set(enabled)
    }


def _env_text() -> str:
    return repo.read_text(ENV) if repo.exists(ENV) else ""


def enabled_profiles(values: dict[str, str | None]) -> list[str]:
    raw = values.get(PROFILES_KEY) or ""
    return [item.strip() for item in raw.split(",") if item.strip()]


def invalid(binding: dict, value: str) -> str | None:
    """Why `value` does not satisfy `binding`, or None if it does."""
    allowed = [str(v) for v in binding.get("values") or []]
    kind = binding.get("type", "string")
    if kind == "list":
        unknown = [item.strip() for item in value.split(",") if item.strip()]
        bad = [item for item in unknown if allowed and item not in allowed]
        return f"unknown value(s) {', '.join(bad)}" if bad else None
    if allowed and value not in allowed:
        return f"not one of {', '.join(allowed)}"
    if kind in ("int", "port") and not value.isdigit():
        return "not a number"
    if kind == "bool" and value.lower() not in ("true", "false", "1", "0"):
        return "not a boolean"
    if kind == "url" and not re.match(r"[a-z][a-z0-9+.-]*://", value):
        return "not a URL"
    return None


def _needed(name: str, binding: dict, active: set[str]) -> bool:
    """Whether a value must exist: required, and read by a stack that is running."""
    if not (binding.get("required") or binding.get("local_generate")):
        return False
    consumers = binding.get("consumers")
    return not consumers or bool(set(consumers) & active)


def diagnose() -> tuple[list[tuple[str, str]], set[str]]:
    """(problems, blocked stacks) for the developer's current .env."""
    values = dotenv.parse(_env_text())
    active = active_stacks(enabled_profiles(values))
    problems: list[tuple[str, str]] = []
    blocked: set[str] = set()

    for name, binding in bindings().items():
        value = values.get(name)
        if value:
            reason = invalid(binding, value)
            if reason is None:
                continue
            problems.append((name, reason))
        elif _needed(name, binding, active):
            problems.append((name, "needs a value"))
        else:
            continue
        blocked.update(set(binding.get("consumers") or []) & active)

    return problems, blocked


def undeclared() -> list[str]:
    """Keys in .env the schema does not declare. A note, never a failure: a
    developer's own scratch variable is their business."""
    return [name for name in dotenv.parse(_env_text()) if name not in bindings()]


def _mint(kind: str) -> str:
    size = int(kind.partition(":")[2] or 32)
    return secrets.token_hex(size) if kind.startswith("hex") else secrets.token_urlsafe(size)


def _write(rel: str, text: str) -> None:
    path = repo.repo_root() / rel
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(text, encoding="utf-8")
    temp.replace(path)


def render(args: argparse.Namespace) -> int:
    """Rewrite .env.example from the schema, or report that it has drifted."""
    rendered = dotenv.render(schema(), HEADER)
    current = repo.read_text(EXAMPLE) if repo.exists(EXAMPLE) else ""
    if args.check:
        if rendered == current:
            print(f"{EXAMPLE} matches the schema.")
            return 0
        print(f"{EXAMPLE} has drifted from {SCHEMA}. Run `task env:render`.\n")
        sys.stdout.writelines(difflib.unified_diff(
            current.splitlines(keepends=True), rendered.splitlines(keepends=True),
            fromfile=EXAMPLE, tofile="rendered from schema",
        ))
        return 1
    _write(EXAMPLE, rendered)
    print(f"Wrote {EXAMPLE} from {SCHEMA}.")
    return 0


def doctor(args: argparse.Namespace) -> int:
    """Report what the enabled stacks still need. Never touches any file."""
    problems, blocked = diagnose()
    values = dotenv.parse(_env_text())

    if args.compose_profiles:
        # Printed for startup.sh, which exports it so .env wins over the stale
        # copy `runArgs --env-file` froze into the container's environment.
        keep = [p for p in enabled_profiles(values) if p not in blocked]
        print(",".join(keep))
        return 0

    missing_keys = [name for name in bindings() if name not in values]
    if not problems and not missing_keys:
        if not args.quiet:
            print(f"{ENV}: every binding the enabled stacks need has a value.")
        return 0

    if args.motd:
        summary = f"{len(problems)} value(s) need attention" if problems else ""
        drift = f"{len(missing_keys)} new binding(s) since this .env was written" if missing_keys else ""
        print("; ".join(part for part in (summary, drift) if part))
        if blocked:
            print("not started: " + ", ".join(sorted(blocked)))
        return 1

    for name, reason in problems:
        binding = bindings().get(name, {})
        print(f"  {name}: {reason}")
        if binding.get("description"):
            print(f"      {' '.join(str(binding['description']).split())}")
    if missing_keys:
        print(f"  {len(missing_keys)} binding(s) not in {ENV} yet: {', '.join(missing_keys)}")
        print("      run `task env:sync` to add them without touching your values")
    if undeclared():
        print(f"\nNot in the schema (yours to keep): {', '.join(undeclared())}")
    if blocked:
        print(f"\nStacks that will not start: {', '.join(sorted(blocked))}")
    print("\nRun `task env:setup` to fill these in.")
    return 1


def sync(args: argparse.Namespace) -> int:
    """Add bindings new to the schema, and mint local secrets. Never overwrites."""
    text = _env_text()
    if not text and repo.exists(EXAMPLE):
        text = repo.read_text(EXAMPLE)
    values = dotenv.parse(text)

    added = [name for name in bindings() if name not in values]
    text = dotenv.append_missing(text, schema(), added)

    minted = []
    for name, binding in bindings().items():
        kind = binding.get("local_generate")
        if kind and not dotenv.parse(text).get(name):
            text = dotenv.upsert(text, name, _mint(str(kind)))
            minted.append(name)

    _write(ENV, text)
    report = [f"added {len(added)}" if added else "", f"minted {len(minted)}" if minted else ""]
    print(f"{ENV}: " + (", ".join(p for p in report if p) or "already in step with the schema") + ".")
    return 0


def _ask(name: str, binding: dict, current: str | None) -> str | None:
    """Prompt for one binding. None means "leave it alone"."""
    print(f"\n{name}")
    if binding.get("description"):
        print(f"  {' '.join(str(binding['description']).split())}")
    if binding.get("docs_url"):
        print(f"  docs: {binding['docs_url']}")
    allowed = [str(v) for v in binding.get("values") or []]
    if allowed:
        print("  options: " + ", ".join(f"{i + 1}) {v}" for i, v in enumerate(allowed)))
        if binding.get("type") == "list":
            print("  choose any number of them, comma-separated (numbers or names); blank for none")
    shown = "" if binding.get("sensitivity") == "secret" else (current or "")
    prompt = f"  value{f' [{shown}]' if shown else ''}: "
    hidden = binding.get("sensitivity") == "secret" and sys.stdin.isatty()
    raw = getpass.getpass(prompt) if hidden else input(prompt)
    raw = raw.strip()
    if not raw:
        return None if current else ""
    if allowed:
        picked = [item.strip() for item in raw.split(",") if item.strip()]
        raw = ",".join(allowed[int(p) - 1] if p.isdigit() and 0 < int(p) <= len(allowed) else p for p in picked)
    return raw


def _prompt_into(text: str, name: str, values: dict[str, str | None]) -> str:
    """Ask for one binding and fold the answer into `text`, or leave it as is."""
    binding = bindings()[name]
    try:
        answer = _ask(name, binding, values.get(name))
    except (EOFError, KeyboardInterrupt):
        return text
    if answer is None or invalid(binding, answer) and answer:
        if answer:
            print(f"  ! {invalid(binding, answer)} -- left unchanged")
        return text
    return dotenv.upsert(text, name, answer)


def setup(args: argparse.Namespace) -> int:
    """Interactive fill: asks only for what is missing or invalid, unless --all."""
    sync(argparse.Namespace())
    text = _env_text()
    values = dotenv.parse(text)

    # Which stacks are on decides what else is required, so that question comes
    # first and the rest of the list is computed from the answer.
    if PROFILES_KEY in bindings() and not args.all:
        text = _prompt_into(text, PROFILES_KEY, values)
        _write(ENV, text)
        values = dotenv.parse(text)

    problems = dict(diagnose()[0])
    todo = [n for n in bindings() if (args.all or n in problems) and n != PROFILES_KEY]
    if not todo:
        print("\nNothing else to fill in. `task env:doctor` agrees.")
        return 0

    print(f"\nFilling in {len(todo)} binding(s). Enter keeps the current value.")
    changed = []
    for name in todo:
        binding = bindings()[name]
        try:
            answer = _ask(name, binding, values.get(name))
        except (EOFError, KeyboardInterrupt):
            print("\nAborted; nothing written.")
            return 1
        if answer is None:
            continue
        reason = invalid(binding, answer) if answer else None
        if reason:
            print(f"  ! {reason} -- left unchanged")
            continue
        text = dotenv.upsert(text, name, answer)
        changed.append(name)

    _write(ENV, text)
    print(f"\nWrote {ENV} ({len(changed)} changed).")
    if changed:
        print("New terminals pick these up. Run `task stacks:restart` to apply them to running stacks.")
    return 0


ACTIONS = {
    "render": (render, "rewrite .devcontainer/.env.example from the schema"),
    "doctor": (doctor, "report what the enabled stacks still need"),
    "sync": (sync, "add new bindings to .env and mint local secrets"),
    "setup": (setup, "fill in what is missing, interactively"),
}

FLAGS = {
    "render": [("--check", "report drift instead of writing")],
    "doctor": [
        ("--quiet", "say nothing when healthy"),
        ("--motd", "one-line summary for the startup banner"),
        ("--compose-profiles", "print the profiles that can actually start"),
    ],
    "setup": [("--all", "review every binding, not just the ones needing attention")],
}
