"""Building the committed, generated artifacts from the authored content.

Outputs are deterministic (sorted keys, fixed formatting) so `--check` can
compare them byte for byte against what is committed.
"""

import difflib
import json
import re
import textwrap
from dataclasses import dataclass
from pathlib import Path

from conventions_tools import schemas, vocabulary
from conventions_tools.content import (
    Content,
    Convention,
    CopyRule,
    CopyStyle,
    Requirement,
    requirement_sort_key,
)
from conventions_tools.loading import ContentError, as_list
from conventions_tools.paths import (
    PRODUCT_DIR_NAME,
    REPOSITORY_URL,
    conventions_dir,
    index_file,
    vale_dir,
    vale_style_dir,
)
from conventions_tools.profiles import resolve_all

SCHEMA_VERSION = 1
NOT_WAIVABLE_FAMILIES = frozenset({"ADOPT"})
TERMINOLOGY_URL = f"{REPOSITORY_URL}/blob/main/{PRODUCT_DIR_NAME}/definitions/terminology/README.md"
# Where a release's assets are downloaded from; the package is <this>/v<version>/<package>.zip.
RELEASE_DOWNLOAD_URL = f"{REPOSITORY_URL}/releases/download"


@dataclass(frozen=True)
class Output:
    path: Path
    text: str


def _requirement_entry(req: Requirement) -> dict[str, object]:
    entry: dict[str, object] = {
        "aliases": list(req.aliases),
        "anchor": req.anchor,
        "convention": req.convention,
        "engine": req.engine,
        "path": req.path,
        "severity": req.severity,
        "since": req.since,
        "status": req.status,
        "title": req.title,
        "waivable": req.family not in NOT_WAIVABLE_FAMILIES,
    }
    if req.package is not None:
        entry["package"] = req.package
    if req.schema is not None:
        entry["schema"] = req.schema
    if req.style is not None:
        entry["style"] = req.style
    if req.replaced_by:
        entry["replaced_by"] = list(req.replaced_by)
    return entry


def _convention_entry(convention: Convention) -> dict[str, object]:
    return {
        "authority": convention.authority,
        "path": convention.path,
        "status": convention.status,
        "title": convention.title,
        "topic": convention.topic,
    }


def build_index(content: Content) -> dict[str, object]:
    resolved = resolve_all(
        content.profiles,
        content.requirements,
        {family.prefix for family in content.families},
    )
    index: dict[str, object] = {
        "schema_version": SCHEMA_VERSION,
        "repository": REPOSITORY_URL,
        "product_dir": PRODUCT_DIR_NAME,
        "conventions": {
            convention.id: _convention_entry(convention) for convention in content.conventions
        },
        "requirements": {req.id: _requirement_entry(req) for req in content.requirements},
        "profiles": {
            profile.id: {
                "display_name": profile.display_name,
                "requirements": list(profile.requirements),
                "severity": profile.severity,
            }
            for profile in resolved.values()
        },
        "vocabulary": vocabulary.project(content.terminology),
        # ADOPT-02 validates the declaration in Rego, which reads one
        # self-contained schema rather than resolving sibling files.
        "declaration_schema": schemas.self_contained(content.product, schemas.DECLARATION),
        # OUT-02 validates the outputs declaration the same way.
        "outputs_schema": schemas.self_contained(content.product, schemas.OUTPUTS),
        # DEPS-02 validates the dependencies declaration the same way, and
        # DEPS-05 each vendored release record.
        "dependencies_schema": schemas.self_contained(content.product, schemas.DEPENDENCIES),
        "release_record_schema": schemas.self_contained(content.product, schemas.RELEASE_RECORD),
        # REPO-02 validates the identity declaration the same way.
        "repository_schema": schemas.self_contained(content.product, schemas.REPOSITORY),
        # ENVS-03 validates every env.schema.yaml the same way.
        "env_schema": schemas.self_contained(content.product, schemas.ENV_SCHEMA),
        # DEC-02 validates each decision record's frontmatter the same way.
        "decision_schema": schemas.self_contained(content.product, schemas.DECISION),
        # AGENT-10 and AGENT-12 validate each skill's and subagent's frontmatter
        # the same way.
        "skill_frontmatter_schema": schemas.self_contained(content.product, schemas.SKILL),
        "subagent_frontmatter_schema": schemas.self_contained(content.product, schemas.SUBAGENT),
        # COMM-01, COMM-02 and COMM-07 validate GitHub's community
        # files against the vendored SchemaStore schemas.
        "issue_forms_schema": schemas.vendored(content.product, schemas.ISSUE_FORMS),
        "issue_config_schema": schemas.vendored(content.product, schemas.ISSUE_CONFIG),
        "discussion_forms_schema": schemas.vendored(content.product, schemas.DISCUSSION_FORMS),
        # COPY-02..COPY-04 read what a consumer's Vale config must name.
        "copy": copy_index(content.copy_style),
    }
    return {"conventions": {"index": index}}


def render_json(data: object) -> str:
    return json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def _yaml_string(text: str) -> str:
    # A JSON string literal is a valid YAML double-quoted scalar.
    return json.dumps(text, ensure_ascii=False)


def _regex_literal(text: str) -> str:
    # Swap keys are regular expressions. The terminology schema limits alias
    # text to letters, digits, spaces, '.', '_' and '-', of which only '.' is
    # special outside a character class.
    return text.replace(".", r"\.")


def render_vale_style(swaps: list[vocabulary.ProseSwap], *, level: str, message: str) -> str:
    """A Vale substitution style mapping each alias to what to write instead."""
    lines = [
        "# Generated by `conventions generate` from definitions/terminology/global.yml.",
        "# Do not edit: change the prose-scope aliases there and regenerate.",
        "extends: substitution",
        f"message: {_yaml_string(message)}",
        f"link: {_yaml_string(TERMINOLOGY_URL)}",
        f"level: {level}",
        "ignorecase: true",
    ]
    if swaps:
        lines.append("swap:")
        lines.extend(
            f"  {_yaml_string(_regex_literal(swap.text))}: {_yaml_string(swap.suggest)}"
            for swap in swaps
        )
    else:
        lines.append("swap: {}")
    return "\n".join(lines) + "\n"


def copy_index(style: CopyStyle) -> dict[str, object]:
    """What the COPY checks need to judge a consumer's Vale config."""
    return {
        "package": style.package,
        "release_url": RELEASE_DOWNLOAD_URL,
        "style": style.style,
        "based_on": [style.style, *(item.style for item in style.adopted if item.use == "whole")],
        "template_formats": dict(style.template_formats),
    }


def copy_extensions(style: CopyStyle) -> list[str]:
    """Every extension copy is written in, native and template, sorted."""
    return sorted({*style.native_formats, *(ext for ext, _ in style.template_formats)})


_GENERATED_FROM = "# Generated by `conventions generate` from definitions/copy/style.yml."


def _requirement_link(content: Content, check: str) -> str:
    """The diagnostic URL of the one requirement whose validation names `check`.

    It links to main, as the MusherConventions style does: the style is
    committed before the release that ships it is tagged (decision 0004).
    """
    found = [req for req in content.requirements if req.style == check]
    if len(found) != 1:
        raise ContentError(
            [
                f"{content.copy_style.path}: {check} needs exactly one requirement whose "
                f"validation is engine: vale, style: {check}; found {len(found)}"
            ]
        )
    req = found[0]
    return f"{REPOSITORY_URL}/blob/main/{PRODUCT_DIR_NAME}/{req.path}#{req.anchor}"


def _yaml_value(value: object) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    return _yaml_string(str(value))


def render_copy_rule(rule: CopyRule, link: str) -> str:
    """One MusherCopy rule as a Vale rule file."""
    lines = [_GENERATED_FROM, "# Do not edit: change the rule there and regenerate."]
    if rule.note:
        lines.extend(f"# {line}" for line in textwrap.wrap(rule.note, width=78))
    lines += [
        f"extends: {rule.extends}",
        f"message: {_yaml_string(rule.message)}",
        f"link: {_yaml_string(link)}",
        f"level: {rule.level}",
    ]
    if rule.extends == "existence":
        lines.append("ignorecase: true")
    for key, value in rule.settings:
        items = as_list(value)
        if items:
            lines.append(f"{key}:")
            lines.extend(f"  - {_yaml_value(item)}" for item in items)
        else:
            lines.append(f"{key}: {_yaml_value(value)}")
    return "\n".join(lines) + "\n"


def render_package_config(style: CopyStyle) -> str:
    """The .vale.ini at the root of the package: the adopted packages and their toggles.

    The consumer's own config applies the styles to its files (COPY-03); this
    file only installs the adopted packages, pinned, and turns their rules off
    or on. Its section matches every copy extension in every directory the
    consumer lints, which is why it holds toggles and never BasedOnStyles, and
    why it names no code extension, whose comments Vale would otherwise read.
    """
    lines = [
        "# Generated by `conventions generate` from definitions/copy/style.yml.",
        "# Do not edit: change the source there and regenerate.",
        f"# The .vale.ini of the {style.package} Vale package (EC-0038). `vale sync`",
        "# installs the packages below beside its own styles, and Vale merges the",
        "# toggles into the config that names the package.",
        f"Packages = {', '.join(item.package for item in style.adopted)}",
        "",
        f"[*.{{{','.join(copy_extensions(style))}}}]",
    ]
    for item in style.adopted:
        for toggle in item.disable:
            lines += [f"# {toggle.reason}", f"{item.style}.{toggle.rule} = NO"]
        for toggle in item.enable:
            lines += [f"# {toggle.reason}", f"{item.style}.{toggle.rule} = YES"]
    return "\n".join(lines) + "\n"


def _cell(text: str) -> str:
    return re.sub(r"([\\<>|*])", r"\\\1", text)


def _convention_link(convention: Convention, anchor: str = "") -> str:
    target = Path(convention.path).relative_to(conventions_dir(Path())).as_posix()
    return f"{target}#{anchor}" if anchor else target


def render_readme(content: Content) -> str:
    by_id = {convention.id: convention for convention in content.conventions}
    lines = [
        "# Conventions",
        "",
        "<!-- Generated by `conventions generate` from the convention frontmatter and",
        "families.yml. Do not edit: change the frontmatter and regenerate. -->",
        "",
        "Every convention and every requirement ID, retired ones included. A requirement",
        "ID is permanent: it is never renumbered or reused.",
        "",
        "## Conventions",
        "",
        "| ID | Title | Topic | Status |",
        "| --- | --- | --- | --- |",
    ]
    lines.extend(
        f"| [{convention.id}]({_convention_link(convention)}) | {_cell(convention.title)} "
        f"| {convention.topic} | {convention.status} |"
        for convention in sorted(content.conventions, key=lambda item: item.id)
    )
    lines += [
        "",
        "## Requirements",
        "",
        "| ID | Title | Convention | Status | Severity | Engine |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for req in sorted(content.requirements, key=lambda item: requirement_sort_key(item.id)):
        link = _convention_link(by_id[req.convention], req.anchor)
        lines.append(
            f"| [{req.id}]({link}) | {_cell(req.title)} | {req.convention} "
            f"| {req.status} | {req.severity} | {req.engine} |"
        )
    lines += [
        "",
        "## Families",
        "",
        "| Prefix | Title | Topic |",
        "| --- | --- | --- |",
    ]
    lines.extend(
        f"| {family.prefix} | {_cell(family.title)} | {family.topic} |"
        for family in content.families
    )
    return "\n".join(lines) + "\n"


def build_outputs(content: Content) -> list[Output]:
    product = content.product
    styles = vale_style_dir(product)
    terms = content.terminology
    return [
        Output(index_file(product), render_json(build_index(content))),
        Output(
            styles / "Terms.yml",
            render_vale_style(
                vocabulary.prose_swaps(terms, "banned"),
                level="error",
                message="Use '%s' instead of '%s'.",
            ),
        ),
        Output(
            styles / "Discouraged.yml",
            render_vale_style(
                vocabulary.prose_swaps(terms, "discouraged"),
                level="warning",
                message="Prefer '%s' over '%s'.",
            ),
        ),
        Output(conventions_dir(product) / "README.md", render_readme(content)),
        *copy_outputs(content),
    ]


def copy_outputs(content: Content) -> list[Output]:
    style = content.copy_style
    directory = vale_dir(content.product)
    return [
        *(
            Output(
                directory / style.style / f"{rule.name}.yml",
                render_copy_rule(rule, _requirement_link(content, f"{style.style}.{rule.name}")),
            )
            for rule in style.rules
        ),
        Output(directory / f"{style.package}.ini", render_package_config(style)),
    ]


def _style_dirs(outputs: list[Output], product: Path) -> set[Path]:
    """Every style directory under checks/vale/ that a generated rule is written to."""
    root = vale_dir(product)
    return {output.path.parent for output in outputs if output.path.parent.parent == root}


def stale(outputs: list[Output], product: Path) -> list[Path]:
    """Files in a generated style directory that no output writes: a rule since removed."""
    written = {output.path for output in outputs}
    return sorted(
        path
        for directory in _style_dirs(outputs, product)
        if directory.is_dir()
        for path in directory.iterdir()
        if path.is_file() and path not in written
    )


def drift(outputs: list[Output], product: Path) -> list[str]:
    """Unified diffs for every output that differs from the file on disk."""
    diffs: list[str] = []
    for output in outputs:
        current = output.path.read_text(encoding="utf-8") if output.path.exists() else ""
        if current == output.text:
            continue
        name = output.path.relative_to(product).as_posix()
        diffs.append(
            "".join(
                difflib.unified_diff(
                    current.splitlines(keepends=True),
                    output.text.splitlines(keepends=True),
                    fromfile=f"{name} (committed)",
                    tofile=f"{name} (generated)",
                )
            )
        )
    diffs += [
        f"{path.relative_to(product).as_posix()}: committed, but nothing generates it; delete it\n"
        for path in stale(outputs, product)
    ]
    return diffs


def write(outputs: list[Output], product: Path) -> list[Path]:
    """Write every output that changed and delete every stale one; return the paths touched."""
    written: list[Path] = []
    for path in stale(outputs, product):
        path.unlink()
        written.append(path)
    for output in outputs:
        if output.path.exists() and output.path.read_text(encoding="utf-8") == output.text:
            continue
        output.path.parent.mkdir(parents=True, exist_ok=True)
        output.path.write_text(output.text, encoding="utf-8")
        written.append(output.path)
    return written
