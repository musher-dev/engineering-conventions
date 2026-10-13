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
    read_json,
    read_yaml,
    split_frontmatter,
)
from conventions_tools.paths import (
    conventions_dir,
    copy_style_file,
    env_grammar_file,
    families_file,
    profiles_dir,
    terminology_dir,
    vendor_data_dir,
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
    style: str | None
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
    note: str | None


@dataclass(frozen=True)
class Term:
    id: str
    display_name: str
    token: str | None
    tags: tuple[str, ...]
    aliases: tuple[Alias, ...]
    deprecated: bool
    slug: str | None = None
    values: tuple[str, ...] = ()


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
class Toggle:
    rule: str
    reason: str


@dataclass(frozen=True)
class AdoptedPackage:
    """A published Vale package the MusherProse package installs, pinned to one release."""

    style: str
    version: str
    license: str
    source: str
    package: str
    use: str
    disable: tuple[Toggle, ...]
    enable: tuple[Toggle, ...]


@dataclass(frozen=True)
class CopyRule:
    """One rule of the MusherCopy style; `settings` are its Vale keys after extends and level."""

    name: str
    extends: str
    level: str
    message: str
    note: str | None
    settings: tuple[tuple[str, object], ...]


@dataclass(frozen=True)
class CopyStyle:
    path: str
    package: str
    style: str
    native_formats: tuple[str, ...]
    template_formats: tuple[tuple[str, str], ...]
    adopted: tuple[AdoptedPackage, ...]
    rules: tuple[CopyRule, ...]


@dataclass(frozen=True)
class EnvGrammar:
    """The naming grammar of environment schemas, as index.json publishes it (env_grammar)."""

    path: str
    published: dict[str, object]


@dataclass(frozen=True)
class Content:
    product: Path
    families: tuple[Family, ...]
    conventions: tuple[Convention, ...]
    terminology: Terminology
    profiles: tuple[Profile, ...]
    copy_style: CopyStyle
    env_grammar: EnvGrammar

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
        style=get_opt_str(validation, "style"),
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
        note=get_opt_str(data, "note"),
    )


def _term(data: dict[str, object]) -> Term:
    return Term(
        id=get_str(data, "id"),
        display_name=get_str(data, "display_name"),
        token=get_opt_str(data, "token"),
        tags=get_str_list(data, "tags"),
        aliases=tuple(_alias(as_map(item)) for item in as_list(data.get("aliases"))),
        deprecated="deprecated" in data,
        slug=get_opt_str(data, "slug"),
        values=get_str_list(data, "values"),
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


def _toggles(data: dict[str, object], key: str) -> tuple[Toggle, ...]:
    return tuple(
        Toggle(rule=get_str(item, "rule"), reason=get_str(item, "reason"))
        for item in map(as_map, as_list(data.get(key)))
    )


# The keys every rule has; the rest are the Vale settings its `extends` takes.
_RULE_KEYS = frozenset({"name", "extends", "level", "message", "note"})


def _copy_rule(data: dict[str, object]) -> CopyRule:
    return CopyRule(
        name=get_str(data, "name"),
        extends=get_str(data, "extends"),
        level=get_str(data, "level"),
        message=get_str(data, "message"),
        note=get_opt_str(data, "note"),
        settings=tuple((key, value) for key, value in data.items() if key not in _RULE_KEYS),
    )


def load_copy_style(product: Path, path: Path | None = None) -> CopyStyle:
    path = path or copy_style_file(product)
    data = _validated(product, schemas.COPY_STYLE, read_yaml(path), path)
    formats = as_map(data.get("formats"))
    return CopyStyle(
        path=_relative(product, path),
        package=get_str(data, "package"),
        style=get_str(data, "style"),
        native_formats=get_str_list(formats, "native"),
        template_formats=tuple(
            (key, value)
            for key, value in sorted(as_map(formats.get("templates")).items())
            if isinstance(value, str)
        ),
        adopted=tuple(
            AdoptedPackage(
                style=get_str(item, "style"),
                version=get_str(item, "version"),
                license=get_str(item, "license"),
                source=get_str(item, "source"),
                package=get_str(item, "package"),
                use=get_str(item, "use"),
                disable=_toggles(item, "disable"),
                enable=_toggles(item, "enable"),
            )
            for item in map(as_map, as_list(data.get("adopted")))
        ),
        rules=tuple(_copy_rule(as_map(item)) for item in as_list(data.get("rules"))),
    )


def _vendor_names(product: Path, source: str, name: str) -> dict[str, object]:
    """A vendored list of variable names: every name, its sources and when they were read."""
    path = vendor_data_dir(product) / name
    if not path.is_file():
        raise ContentError(
            [f"{source}: reserved prefix names {name}, which is not in checks/data/vendor/"]
        )
    data = as_map(read_json(path))
    names = get_str_list(data, "names")
    sources = [as_map(item) for item in as_list(data.get("sources"))]
    retrieved = get_str(data, "retrieved")
    if not names or not sources or not retrieved:
        raise ContentError(
            [f"{_relative(product, path)}: needs names, sources and the date they were retrieved"]
        )
    return {
        "names": sorted(set(names)),
        "retrieved": retrieved,
        "sources": [
            {"title": get_str(item, "title"), "url": get_str(item, "url")} for item in sources
        ],
    }


def _reserved_prefix(product: Path, source: str, data: dict[str, object]) -> dict[str, object]:
    vendored = _vendor_names(product, source, get_str(data, "names"))
    names = set(get_str_list(vendored, "names"))
    suggest = {
        key: value for key, value in as_map(data.get("suggest")).items() if isinstance(value, str)
    }
    undefined = sorted(value for value in suggest.values() if value not in names)
    if undefined:
        vendor = get_str(data, "vendor")
        raise ContentError(
            [f"{source}: {vendor} suggests {', '.join(undefined)}, which it does not define"]
        )
    return {
        "vendor": get_str(data, "vendor"),
        "prefixes": list(get_str_list(data, "prefixes")),
        "runner_only": data.get("runner_only") is True,
        "suggest": suggest,
        **vendored,
    }


def load_env_grammar(product: Path, path: Path | None = None) -> EnvGrammar:
    path = path or env_grammar_file(product)
    data = _validated(product, schemas.ENV_GRAMMAR, read_yaml(path), path)
    source = _relative(product, path)
    tier = as_map(data.get("deployment_environment"))
    return EnvGrammar(
        path=source,
        published={
            "units": {
                get_str(unit, "unit"): list(get_str_list(unit, "long_forms"))
                for unit in map(as_map, as_list(data.get("units")))
            },
            "boolean_prefixes": list(get_str_list(data, "boolean_prefixes")),
            "boolean_suffixes": list(get_str_list(data, "boolean_suffixes")),
            "client_prefixes": list(get_str_list(data, "client_prefixes")),
            "deployment_environment": {
                "variable": get_str(tier, "variable"),
                "carriers": list(get_str_list(tier, "carriers")),
                "carrier_suffixes": list(get_str_list(tier, "carrier_suffixes")),
                "vendor_modes": list(get_str_list(tier, "vendor_modes")),
                "name_words_allowed": list(get_str_list(tier, "name_words_allowed")),
            },
            "reserved_prefixes": [
                _reserved_prefix(product, source, item)
                for item in map(as_map, as_list(data.get("reserved_prefixes")))
            ],
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
    copy_style: CopyStyle | None = None
    env_grammar: EnvGrammar | None = None
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
    try:
        copy_style = load_copy_style(product)
    except ContentError as error:
        found.extend(error.problems)
    try:
        env_grammar = load_env_grammar(product)
    except ContentError as error:
        found.extend(error.problems)
    if found or terminology is None or copy_style is None or env_grammar is None:
        raise ContentError(found)
    return Content(
        product=product,
        families=families,
        conventions=conventions,
        terminology=terminology,
        profiles=profiles,
        copy_style=copy_style,
        env_grammar=env_grammar,
    )
