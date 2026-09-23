"""Detect product content outside the declared product directory, and drift from it."""

from __future__ import annotations

import tomllib
from dataclasses import dataclass, field

from governance import repo
from governance.policies.layout import violations as v
from governance.reporting import Report

DEVCONTAINER = ".devcontainer/devcontainer.json"
DEPENDABOT = ".github/dependabot.yml"
TASKFILE = "Taskfile.yml"
DEV_ENV_SCHEMA = ".devcontainer/env.schema.yaml"
WORKSPACE_PREFIX = "/workspaces/${localWorkspaceFolderBasename}/"

#: Names a product may not take: they are repository-level homes already.
RESERVED = {"docs", "scripts", "taskfiles"}


@dataclass(frozen=True)
class Ecosystem:
    manifests: tuple[str, ...]
    """Any one of these at the top of the product dir marks it as this ecosystem."""

    root_files: tuple[str, ...]
    """Top-level names that are product content and never belong at the repo root."""

    dependabot: tuple[str, ...] = ()
    """Dependabot `package-ecosystem` values that must scan the product dir."""

    editor_links: dict[str, str] = field(default_factory=dict)
    """VS Code list settings that must name the product, `{product}` substituted."""


#: Only Rust's editor link is enforced: it is the adapter proven in the org
#: (host-agent). The rest are "verify on first adoption" in LAYOUT.md.
ECOSYSTEMS = {
    "rust": Ecosystem(
        manifests=("Cargo.toml",),
        root_files=(
            "Cargo.toml", "Cargo.lock", "rust-toolchain", "rust-toolchain.toml",
            ".cargo", "rustfmt.toml", ".rustfmt.toml", "clippy.toml",
            ".clippy.toml", "deny.toml", ".deny.toml",
        ),
        dependabot=("cargo",),
        editor_links={"rust-analyzer.linkedProjects": "{product}/Cargo.toml"},
    ),
    "node": Ecosystem(
        manifests=("package.json",),
        root_files=(
            "package.json", "package-lock.json", "npm-shrinkwrap.json",
            "pnpm-lock.yaml", "pnpm-workspace.yaml", "yarn.lock", "bun.lock",
            "bun.lockb", "tsconfig.json", ".nvmrc", ".node-version",
        ),
        dependabot=("npm", "bun"),
    ),
    "python": Ecosystem(
        manifests=("pyproject.toml",),
        root_files=(
            "pyproject.toml", "uv.lock", "poetry.lock", "setup.py", "setup.cfg",
            ".python-version", "ruff.toml", ".ruff.toml", "pytest.ini", "tox.ini",
        ),
        dependabot=("pip", "uv"),
    ),
    "go": Ecosystem(
        manifests=("go.mod",),
        root_files=("go.mod", "go.sum", "go.work", "go.work.sum"),
        dependabot=("gomod",),
    ),
    "deno": Ecosystem(
        manifests=("deno.json", "deno.jsonc"),
        root_files=("deno.json", "deno.jsonc", "deno.lock"),
    ),
    "java": Ecosystem(
        manifests=(
            "pom.xml", "build.gradle", "build.gradle.kts",
            "settings.gradle", "settings.gradle.kts",
        ),
        root_files=(
            "pom.xml", "build.gradle", "build.gradle.kts", "settings.gradle",
            "settings.gradle.kts", "gradlew", "mvnw",
        ),
        dependabot=("maven", "gradle"),
    ),
}

#: Source trees: product content by name, whatever the ecosystem.
ROOT_SOURCE_DIRS = ("src", "crates", "cmd", "internal", "pkg", "lib", "tests", "apps", "packages")


def _declaration(report: Report) -> tuple[str | None, dict[str, object]]:
    """The declared product (None when none) and the root exceptions."""
    try:
        data = repo.read_toml(repo.LAYOUT_FILE)
    except OSError:
        report.add(v.bad_declaration("the file does not exist"))
        return None, {}
    except tomllib.TOMLDecodeError as error:
        report.add(v.bad_declaration(f"it is not valid TOML ({error})"))
        return None, {}

    exceptions = data.get("root-exceptions", {})
    if not isinstance(exceptions, dict):
        report.add(v.bad_declaration("[root-exceptions] is not a table"))
        exceptions = {}

    if "product" not in data:
        report.add(v.bad_declaration("the `product` key is absent"))
        return None, exceptions
    value = data["product"]
    if not isinstance(value, str):
        report.add(v.bad_declaration("`product` is not a string"))
        return None, exceptions
    if value == "":
        return None, exceptions
    if not repo.PRODUCT_NAME.fullmatch(value) or value in RESERVED:
        report.add(v.bad_declaration(f"'{value}' is not a single, unreserved path segment"))
        return None, exceptions
    return value, exceptions


def _detected(product: str) -> list[Ecosystem]:
    return [
        eco for eco in ECOSYSTEMS.values()
        if any(repo.exists(f"{product}/{m}") for m in eco.manifests)
    ]


def _check_root(report: Report, product: str | None, exceptions: dict[str, object]) -> None:
    top_level = {path.split("/", 1)[0] for path in repo.tracked_files()}
    forbidden = {name for eco in ECOSYSTEMS.values() for name in eco.root_files}
    forbidden.update(ROOT_SOURCE_DIRS)
    for name in sorted(top_level & forbidden):
        if name not in exceptions:
            report.add(v.product_content_at_root(name, product))
    for name, reason in sorted(exceptions.items()):
        if not isinstance(reason, str) or not reason.strip():
            report.add(v.bad_exception(name, "has no reason"))
        elif name not in top_level:
            report.add(v.bad_exception(name, "names nothing at the repository root"))


def _mount_targets(devcontainer: dict) -> list[str]:
    targets = []
    for mount in devcontainer.get("mounts", []):
        if isinstance(mount, dict):
            target = mount.get("target", "")
        else:
            parts = dict(p.split("=", 1) for p in str(mount).split(",") if "=" in p)
            target = parts.get("target", parts.get("destination", parts.get("dst", "")))
        if target.startswith(WORKSPACE_PREFIX):
            targets.append(target)
    return targets


def _check_devcontainer(report: Report, product: str | None, ecosystems: list[Ecosystem]) -> None:
    if not repo.exists(DEVCONTAINER):
        return
    devcontainer = repo.read_jsonc(DEVCONTAINER)
    for target in _mount_targets(devcontainer):
        inside = target.removeprefix(WORKSPACE_PREFIX)
        if product is None or not (inside == product or inside.startswith(f"{product}/")):
            report.add(v.stray_workspace_mount(target, product))
    if product is None:
        return
    settings = devcontainer.get("customizations", {}).get("vscode", {}).get("settings", {})
    for eco in ecosystems:
        for setting, template in eco.editor_links.items():
            entry = template.format(product=product)
            if entry not in settings.get(setting, []):
                report.add(v.missing_editor_link(setting, entry))


def _check_dependabot(report: Report, product: str | None, exceptions: dict[str, object]) -> None:
    """A product ecosystem scanning `/` finds nothing: the root holds no manifest.

    Other directories are fine -- repo-level tooling may carry its own manifest
    (a release script's uv project) -- and a directory that does not exist is
    PATH-02's to report.
    """
    if not repo.exists(DEPENDABOT):
        return
    for update in (repo.read_yaml(DEPENDABOT) or {}).get("updates", []):
        ecosystem = update.get("package-ecosystem")
        eco = next((e for e in ECOSYSTEMS.values() if ecosystem in e.dependabot), None)
        if eco is None or any(m in exceptions for m in eco.manifests):
            continue
        for directory in update.get("directories") or [update.get("directory", "/")]:
            if str(directory).strip().strip("/") == "":
                report.add(v.stray_dependabot(ecosystem, str(directory), product))


def _check_taskfile(report: Report, product: str | None) -> None:
    if not repo.exists(TASKFILE):
        return
    value = ((repo.read_yaml(TASKFILE) or {}).get("vars") or {}).get("PRODUCT_DIR")
    if product is None:
        if value is not None:
            report.add(v.product_dir_var("is set, but no product is declared", None))
        return
    expected = "{{.ROOT_DIR}}/" + product
    if value is None:
        report.add(v.product_dir_var("is missing", expected))
    elif value != expected:
        report.add(v.product_dir_var(f"is '{value}'", expected))


def _check_env_schemas(report: Report, product: str | None) -> None:
    allowed = {DEV_ENV_SCHEMA}
    if product:
        allowed.add(f"{product}/env.schema.yaml")
        if not repo.exists(f"{product}/env.schema.yaml"):
            report.add(v.missing_env_schema(product))
    for path in repo.tracked_files():
        if path.rsplit("/", 1)[-1] != "env.schema.yaml" or path in allowed:
            continue
        expected = f"{product}/env.schema.yaml" if product else "<product>/env.schema.yaml"
        if path.startswith(".devcontainer/"):
            expected = DEV_ENV_SCHEMA
        report.add(v.misplaced_env_schema(path, expected))


def run() -> Report:
    report = Report(policy="layout")
    product, exceptions = _declaration(report)

    ecosystems: list[Ecosystem] = []
    if product is not None:
        if not repo.exists(product) or not (repo.repo_root() / product).is_dir():
            report.add(v.missing_product_dir(product))
        else:
            ecosystems = _detected(product)
            if not ecosystems:
                report.add(v.no_manifest(product))
        name = repo.repo_name()
        if name and name != product:
            report.add(v.product_not_repo_name(product, name))

    _check_root(report, product, exceptions)
    _check_devcontainer(report, product, ecosystems)
    _check_dependabot(report, product, exceptions)
    _check_taskfile(report, product)
    _check_env_schemas(report, product)
    return report
