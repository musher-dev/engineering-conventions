"""The authored content: families, conventions, terminology and profiles.

Every file is validated against its schema as it is loaded, so the typed
records below only ever hold schema-valid data.
"""

from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from conventions_tools import schemas
from conventions_tools.loading import (
    ContentError,
    as_list,
    as_map,
    get_opt_str,
    get_str,
    get_str_list,
    read_yaml,
    split_frontmatter,
)
from conventions_tools.paths import (
    conventions_dir,
    families_file,
    profiles_dir,
    terminology_dir,
)

SEVERITY_RANK = {"warning": 1, "error": 2}


@dataclass(frozen=True)
class Family:
    prefix: str
    title: str
    topic: str


@dataclass(frozen=True)
class Requirement:
    id: str
    title: str
    status: str
    severity: str
    since: str
    engine: str
    package: str | None
    schema: str | None
    aliases: tuple[str, ...]
    replaced_by: tuple[str, ...]
    convention: str
    path: str

    @property
    def family(self) -> str:
        return self.id.rsplit("-", 1)[0]

    @property
    def anchor(self) -> str:
        return self.id.lower()


@dataclass(frozen=True)
class Convention:
    id: str
    title: str
    status: str
    topic: str
    path: str
    authority: str | dict[str, str]
    requirements: tuple[Requirement, ...]
    supersedes: tuple[str, ...]
    superseded_by: tuple[str, ...]
    body: str


@dataclass(frozen=True)
class Alias:
    text: str
    status: str
    scope: tuple[str, ...]
    suggest: str | None


@dataclass(frozen=True)
class Term:
    id: str
    display_name: str
    token: str | None
    tags: tuple[str, ...]
    aliases: tuple[Alias, ...]
    deprecated: bool


@dataclass(frozen=True)
class Terminology:
    path: str
    terms: tuple[Term, ...]
    display_forms: tuple[tuple[str, str], ...]


@dataclass(frozen=True)
class Profile:
    id: str
    path: str
    display_name: str
    inherits: tuple[str, ...]
    include_families: tuple[str, ...]
    include_conventions: tuple[str, ...]
    include_requirements: tuple[str, ...]
    exclude_requirements: tuple[str, ...]
    include_proposed: bool | None
    severity: dict[str, str]


@dataclass(frozen=True)
class Content:
    product: Path
    families: tuple[Family, ...]
    conventions: tuple[Convention, ...]
    terminology: Terminology
    profiles: tuple[Profile, ...]

    @property
    def requirements(self) -> tuple[Requirement, ...]:
        return tuple(req for convention in self.conventions for req in convention.requirements)


def requirement_sort_key(requirement_id: str) -> tuple[str, int]:
    """Order IDs by family, then numerically, so GHA-100 follows GHA-99."""
    family, _, number = requirement_id.rpartition("-")
    return family, int(number)


def _relative(product: Path, path: Path) -> str:
    return path.relative_to(product).as_posix() if path.is_relative_to(product) else str(path)


def _validated(product: Path, schema: str, data: object, path: Path) -> dict[str, object]:
    found = schemas.problems(product, schema, data, _relative(product, path))
    if found:
        raise ContentError(found)
    return as_map(data)


def load_families(product: Path) -> tuple[Family, ...]:
    path = families_file(product)
    data = _validated(product, schemas.FAMILIES, read_yaml(path), path)
    return tuple(
        Family(
            prefix=get_str(item, "prefix"),
            title=get_str(item, "title"),
            topic=get_str(item, "topic"),
        )
        for item in map(as_map, as_list(data.get("families")))
    )


def _requirement(data: dict[str, object], convention: str, path: str) -> Requirement:
    validation = as_map(data.get("validation"))
    return Requirement(
        id=get_str(data, "id"),
        title=get_str(data, "title"),
        status=get_str(data, "status"),
        severity=get_str(data, "severity"),
        since=get_str(data, "since"),
        engine=get_str(validation, "engine"),
        package=get_opt_str(validation, "package"),
        schema=get_opt_str(validation, "schema"),
        aliases=get_str_list(data, "aliases"),
        replaced_by=get_str_list(data, "replaced_by"),
        convention=convention,
        path=path,
    )


def _authority(value: object) -> str | dict[str, str]:
    if isinstance(value, str):
        return value
    return {key: item for key, item in as_map(value).items() if isinstance(item, str)}


def load_convention(product: Path, path: Path) -> Convention:
    relative = _relative(product, path)
    frontmatter, body = split_frontmatter(path.read_text(encoding="utf-8"), relative)
    data = _validated(product, schemas.CONVENTION, frontmatter, path)
    convention_id = get_str(data, "id")
    return Convention(
        id=convention_id,
        title=get_str(data, "title"),
        status=get_str(data, "status"),
        topic=get_str(data, "topic"),
        path=relative,
        authority=_authority(data.get("authority")),
        requirements=tuple(
            _requirement(as_map(item), convention_id, relative)
            for item in as_list(data.get("requirements"))
        ),
        supersedes=get_str_list(data, "supersedes"),
        superseded_by=get_str_list(data, "superseded_by"),
        body=body,
    )


def convention_files(product: Path) -> list[Path]:
    """Every convention document: definitions/conventions/<topic>/*.md except topic READMEs."""
    return sorted(
        path for path in conventions_dir(product).glob("*/*.md") if path.name != "README.md"
    )


def _alias(data: dict[str, object]) -> Alias:
    return Alias(
        text=get_str(data, "text"),
        status=get_str(data, "status"),
        scope=get_str_list(data, "scope"),
        suggest=get_opt_str(data, "suggest"),
    )


def _term(data: dict[str, object]) -> Term:
    return Term(
        id=get_str(data, "id"),
        display_name=get_str(data, "display_name"),
        token=get_opt_str(data, "token"),
        tags=get_str_list(data, "tags"),
        aliases=tuple(_alias(as_map(item)) for item in as_list(data.get("aliases"))),
        deprecated="deprecated" in data,
    )


def load_terminology(product: Path, path: Path) -> Terminology:
    data = _validated(product, schemas.TERMINOLOGY, read_yaml(path), path)
    return Terminology(
        path=_relative(product, path),
        terms=tuple(_term(as_map(item)) for item in as_list(data.get("terms"))),
        display_forms=tuple(
            (get_str(entry, "token"), get_str(entry, "display"))
            for entry in map(as_map, as_list(data.get("display_forms")))
        ),
    )


def load_profile(product: Path, path: Path) -> Profile:
    data = _validated(product, schemas.PROFILE, read_yaml(path), path)
    include = as_map(data.get("include"))
    exclude = as_map(data.get("exclude"))
    include_proposed = data.get("include_proposed")
    return Profile(
        id=get_str(data, "id"),
        path=_relative(product, path),
        display_name=get_str(data, "display_name"),
        inherits=get_str_list(data, "inherits"),
        include_families=get_str_list(include, "families"),
        include_conventions=get_str_list(include, "conventions"),
        include_requirements=get_str_list(include, "requirements"),
        exclude_requirements=get_str_list(exclude, "requirements"),
        include_proposed=include_proposed if isinstance(include_proposed, bool) else None,
        severity={
            key: value
            for key, value in as_map(data.get("severity")).items()
            if isinstance(value, str)
        },
    )


def profile_files(directory: Path) -> list[Path]:
    return sorted(directory.glob("*.yml"))


def _collect[T](
    loader: Callable[[Path, Path], T], product: Path, paths: list[Path]
) -> tuple[T, ...]:
    """Load every path, reporting every invalid file rather than only the first."""
    loaded: list[T] = []
    found: list[str] = []
    for path in paths:
        try:
            loaded.append(loader(product, path))
        except ContentError as error:
            found.extend(error.problems)
    if found:
        raise ContentError(found)
    return tuple(loaded)


def load_profiles(product: Path, directory: Path | None = None) -> tuple[Profile, ...]:
    return _collect(load_profile, product, profile_files(directory or profiles_dir(product)))


def load_content(product: Path) -> Content:
    found: list[str] = []
    families: tuple[Family, ...] = ()
    conventions: tuple[Convention, ...] = ()
    terminology: Terminology | None = None
    profiles: tuple[Profile, ...] = ()
    try:
        families = load_families(product)
    except ContentError as error:
        found.extend(error.problems)
    try:
        conventions = _collect(load_convention, product, convention_files(product))
    except ContentError as error:
        found.extend(error.problems)
    try:
        terminology = load_terminology(product, terminology_dir(product) / "global.yml")
    except ContentError as error:
        found.extend(error.problems)
    try:
        profiles = load_profiles(product)
    except ContentError as error:
        found.extend(error.problems)
    if found or terminology is None:
        raise ContentError(found)
    return Content(
        product=product,
        families=families,
        conventions=conventions,
        terminology=terminology,
        profiles=profiles,
    )
