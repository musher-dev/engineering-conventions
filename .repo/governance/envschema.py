"""The org's env.schema.yaml shape, shared by the product and dev-environment schemas.

Minimal on purpose: the fields every Musher schema already carries, so a
product that adopts the template validates without rewriting its schema. The
richer vocabulary (formats, generators, naming grammar) stays in
musher-dev/platform, which owns it.
"""

from __future__ import annotations

import re

SENSITIVITIES = ("public", "internal", "secret")
REQUIRED_TOP_LEVEL = ("service", "runtime", "bindings")
_NAME = re.compile(r"[A-Z][A-Z0-9_]*")


def problems(schema: object) -> list[str]:
    """Every way `schema` departs from the shape, as short phrases. Empty = valid."""
    if not isinstance(schema, dict):
        return ["the document is not a mapping"]
    found = [f"top-level `{key}` is missing" for key in REQUIRED_TOP_LEVEL if key not in schema]
    bindings = schema.get("bindings")
    if "bindings" in schema and not isinstance(bindings, dict):
        return [*found, "`bindings` is not a mapping"]
    for name, binding in (bindings or {}).items():
        if not _NAME.fullmatch(str(name)):
            found.append(f"binding `{name}` is not an UPPER_SNAKE_CASE name")
        if not isinstance(binding, dict):
            found.append(f"binding `{name}` is not a mapping")
            continue
        for key in ("type", "sensitivity", "description"):
            if key not in binding:
                found.append(f"binding `{name}` has no `{key}`")
        sensitivity = binding.get("sensitivity")
        if sensitivity is not None and sensitivity not in SENSITIVITIES:
            found.append(f"binding `{name}` sensitivity `{sensitivity}` is not one of {SENSITIVITIES}")
        if "required" in binding and not isinstance(binding["required"], bool):
            found.append(f"binding `{name}` `required` is not true/false")
    return found
