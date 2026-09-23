"""Reading and writing the dotenv files the dev container needs.

The schema is the source of truth, but `docker run --env-file` and Compose
read dotenv and nothing else, and the host-side hook that seeds `.env` has only
bash. So the schema is *rendered* to `.env.example`, and that rendering is what
the host copies. `repo env check` fails when the two drift.
"""

from __future__ import annotations

import re
import textwrap

#: Marks the next key as filled from the host environment by initialize.sh.
#: Bash reads this line, so its exact text is an interface -- see
#: .devcontainer/scripts/initialize.sh.
HOST_MARKER = "# @host"

WIDTH = 76
_ASSIGNMENT = re.compile(r"^(?P<comment>#\s*)?(?P<key>[A-Z][A-Z0-9_]*)=(?P<value>.*)$")


def parse(text: str) -> dict[str, str | None]:
    """Keys in a dotenv file: a live value, or None when only commented out."""
    found: dict[str, str | None] = {}
    for line in text.splitlines():
        match = _ASSIGNMENT.match(line.strip())
        if not match:
            continue
        key, value = match["key"], match["value"]
        if match["comment"]:
            found.setdefault(key, None)
        else:
            found[key] = value
    return found


def _wrap(text: str) -> list[str]:
    paragraph = " ".join(str(text).split())
    return [f"# {line}" for line in textwrap.wrap(paragraph, WIDTH - 2)] if paragraph else []


def render_binding(name: str, binding: dict) -> list[str]:
    """One binding as dotenv lines: its description, markers, then its state.

    Three states, the grammar this template has always used:
    a local value is live, a required binding with none is an empty key to
    fill in, and everything else is commented out with its default inlined.
    """
    lines = _wrap(binding.get("description", ""))
    if binding.get("values"):
        lines.extend(_wrap("Allowed: " + ", ".join(str(v) for v in binding["values"])))
    if binding.get("local_generate"):
        lines.append("# Minted per developer by `task env:sync`; never commit it.")
    if binding.get("source") == "host":
        lines.append("# Taken from the host environment when set there.")
        lines.append(HOST_MARKER)

    if "local_default" in binding:
        lines.append(f"{name}={binding['local_default']}")
    elif binding.get("required") or binding.get("local_generate"):
        lines.append(f"{name}=")
    else:
        lines.append(f"# {name}={binding.get('default', '')}")
    return lines


def render(schema: dict, header: str) -> str:
    """The whole schema as a dotenv template, grouped by each binding's `group`."""
    out = [line.rstrip() for line in header.strip().splitlines()]
    group = None
    for name, binding in (schema.get("bindings") or {}).items():
        if binding.get("group") != group:
            group = binding.get("group")
            out.extend(["", ""])
            if group:
                out.append(f"# === {group} ".ljust(WIDTH, "="))
        else:
            out.append("")
        out.extend(render_binding(name, binding))
    return "\n".join(out).rstrip() + "\n"


def upsert(text: str, key: str, value: str) -> str:
    """Set `key` to `value`, reusing its existing line, commented or not."""
    lines = text.splitlines()
    for index, line in enumerate(lines):
        match = _ASSIGNMENT.match(line.strip())
        if match and match["key"] == key:
            lines[index] = f"{key}={value}"
            return "\n".join(lines) + "\n"
    lines.extend(["", f"{key}={value}"])
    return "\n".join(lines) + "\n"


def append_missing(text: str, schema: dict, keys: list[str]) -> str:
    """Append `keys` (in schema order) with their rendered block, for `env sync`."""
    bindings = schema.get("bindings") or {}
    blocks = [render_binding(key, bindings[key]) for key in keys if key in bindings]
    if not blocks:
        return text
    out = text.rstrip().splitlines()
    out.extend(["", "", "# === Added by `task env:sync` ".ljust(WIDTH, "=")])
    for block in blocks:
        out.append("")
        out.extend(block)
    return "\n".join(out) + "\n"
