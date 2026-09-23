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
DECISION = "decision-frontmatter.schema.json"
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
