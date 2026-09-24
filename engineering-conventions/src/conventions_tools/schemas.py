"""Validating content against the JSON Schemas in checks/schemas/."""

from collections.abc import Iterable
from functools import cache
from pathlib import Path
from typing import Protocol, cast

from jsonschema import Draft7Validator, ValidationError
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT7, Schema

from conventions_tools.loading import as_map, read_json
from conventions_tools.paths import schemas_dir

COMMON = "common.schema.json"
FAMILIES = "families.schema.json"
CONVENTION = "convention-frontmatter.schema.json"
TERMINOLOGY = "terminology.schema.json"
PROFILE = "profile.schema.json"
DECLARATION = "conventions-declaration.schema.json"


class Validator(Protocol):
    """The part of a jsonschema validator used here, typed for arbitrary parsed YAML."""

    def iter_errors(self, instance: object) -> Iterable[ValidationError]: ...


@cache
def _registry(directory: Path) -> Registry[Schema]:
    # The schemas carry no $id, so a relative $ref such as
    # "common.schema.json#/..." resolves against the bare filename; registering
    # each file under its filename mirrors how check-jsonschema resolves the
    # same refs from disk.
    resources = [
        (path.name, Resource[Schema].from_contents(_schema(path), default_specification=DRAFT7))
        for path in sorted(directory.glob("*.schema.json"))
    ]
    return Registry[Schema]().with_resources(resources)


def _schema(path: Path) -> Schema:
    return as_map(read_json(path))


@cache
def validator(product: Path, name: str) -> Validator:
    directory = schemas_dir(product)
    checker = Draft7Validator(
        _schema(directory / name),
        registry=_registry(directory),
        format_checker=Draft7Validator.FORMAT_CHECKER,
    )
    # jsonschema types `instance` as JSON-shaped; parsed YAML is `object` here
    # and validating arbitrary shapes is exactly the point.
    return cast("Validator", checker)


def location(error: ValidationError) -> str:
    """A readable path to the failing value, e.g. waivers[0].reason."""
    text = ""
    for part in error.absolute_path:
        text += f"[{part}]" if isinstance(part, int) else f".{part}"
    return text.lstrip(".") or "(top level)"


def iter_errors(product: Path, name: str, instance: object) -> Iterable[ValidationError]:
    errors = validator(product, name).iter_errors(instance)
    return sorted(errors, key=lambda error: (location(error), error.message))


def problems(product: Path, name: str, instance: object, source: str) -> list[str]:
    return [
        f"{source}: {location(error)}: {error.message}"
        for error in iter_errors(product, name, instance)
    ]


def description_of(error: ValidationError) -> str | None:
    description = as_map(cast("object", error.schema)).get("description")
    return description if isinstance(description, str) else None


_COMMON_REF = f"{COMMON}#/definitions/"
_LOCAL_REF = "#/definitions/"
_INLINED_PREFIX = "common_"


def _rewrite_refs(node: object, rename: dict[str, str]) -> object:
    """A copy of `node` with every $ref in `rename` replaced."""
    if isinstance(node, dict):
        mapping = cast("dict[str, object]", node)
        return {
            key: rename.get(value, value)
            if key == "$ref" and isinstance(value, str)
            else _rewrite_refs(value, rename)
            for key, value in mapping.items()
        }
    if isinstance(node, list):
        return [_rewrite_refs(item, rename) for item in cast("list[object]", node)]
    return node


def _refs(node: object) -> set[str]:
    if isinstance(node, dict):
        mapping = cast("dict[str, object]", node)
        found = {mapping["$ref"]} if isinstance(mapping.get("$ref"), str) else set[object]()
        return {str(ref) for ref in found} | {
            ref for value in mapping.values() for ref in _refs(value)
        }
    if isinstance(node, list):
        return {ref for item in cast("list[object]", node) for ref in _refs(item)}
    return set()


def self_contained(product: Path, name: str) -> dict[str, object]:
    """Schema `name` with the common definitions it reaches inlined.

    OPA's json.match_schema takes one schema and cannot resolve a $ref to a
    sibling file, so the checks read this form from the index.
    """
    directory = schemas_dir(product)
    schema = as_map(read_json(directory / name))
    common = as_map(as_map(read_json(directory / COMMON)).get("definitions"))
    # Common definitions refer to each other locally; after inlining they sit
    # beside the schema's own definitions, so both kinds of ref are renamed.
    local = {f"{_LOCAL_REF}{key}": f"{_LOCAL_REF}{_INLINED_PREFIX}{key}" for key in common}
    shared = {f"{_COMMON_REF}{key}": f"{_LOCAL_REF}{_INLINED_PREFIX}{key}" for key in common}
    reached: set[str] = set()
    pending = {ref.removeprefix(_COMMON_REF) for ref in _refs(schema) if ref in shared}
    while pending:
        key = pending.pop()
        reached.add(key)
        pending |= {ref.removeprefix(_LOCAL_REF) for ref in _refs(common[key]) if ref in local}
        pending -= reached
    schema = as_map(_rewrite_refs(schema, shared))
    definitions = dict(as_map(schema.get("definitions")))
    definitions |= {
        f"{_INLINED_PREFIX}{key}": _rewrite_refs(common[key], local) for key in sorted(reached)
    }
    return {**schema, "definitions": definitions}
