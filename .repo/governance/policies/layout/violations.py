"""What can go wrong with the two-level layout, and why each rule exists."""

from __future__ import annotations

from governance.reporting import Violation

DECLARING = "LAYOUT.md#declaring-the-product"
INVARIANTS = "LAYOUT.md#invariants"
ADAPTERS = "LAYOUT.md#ecosystem-adapters"
ENV_CONTRACT = "LAYOUT.md#the-env-contract"
EXCEPTIONS = "LAYOUT.md#root-exceptions"

_SILENT = (
    "Tools that name the product by path do not fail when the path is wrong: "
    "the mount lands on the bind mount, the update scans nothing, the task "
    "runs from the wrong directory. Agreement with the one declaration is the "
    "only thing that catches it."
)


def bad_declaration(detail: str) -> Violation:
    return Violation(
        code="LAYOUT-01",
        summary=f".repo/layout.toml is not a valid product declaration: {detail}",
        reason=(
            "Every layout rule keys off this one declaration. A missing file must "
            "not read as 'no product', or deleting it would silently switch the "
            "rules off."
        ),
        fix=(
            'Set `product = ""` (no product) or `product = "<repo-name>"` -- a '
            "single path segment -- in .repo/layout.toml."
        ),
        where=".repo/layout.toml",
        docs=DECLARING,
    )


def missing_product_dir(product: str) -> Violation:
    return Violation(
        code="LAYOUT-02",
        summary=f"declared product directory {product}/ does not exist",
        reason="The declaration is what every other path is checked against; it has to be true.",
        fix=f"Create {product}/ (git mv the workspace into it), or correct the declaration.",
        where=".repo/layout.toml",
        docs=DECLARING,
    )


def product_not_repo_name(product: str, name: str) -> Violation:
    return Violation(
        code="LAYOUT-03",
        summary=f"product directory {product}/ is not named after the repository ({name})",
        reason=(
            "The convention is <repo>/<repo>/: a reader, a grep, and every Musher "
            "repo agree on where the product is without looking it up."
        ),
        fix=f"Rename the directory to {name}/ and update .repo/layout.toml.",
        where=".repo/layout.toml",
        docs=DECLARING,
    )


def no_manifest(product: str) -> Violation:
    return Violation(
        code="LAYOUT-04",
        summary=f"{product}/ contains no recognised build manifest",
        reason=(
            "The product directory is the ecosystem-native build root. Without a "
            "manifest there, the build still starts from somewhere else."
        ),
        fix=(
            f"Move the manifest (Cargo.toml, package.json, pyproject.toml, go.mod, "
            f"...) into {product}/, or add the ecosystem to ECOSYSTEMS in "
            ".repo/governance/policies/layout/check.py."
        ),
        where=f"{product}/",
        docs=INVARIANTS,
    )


def product_content_at_root(name: str, product: str | None) -> Violation:
    home = f"{product}/" if product else "<repo-name>/ (declared in .repo/layout.toml)"
    return Violation(
        code="LAYOUT-05",
        summary=f"{name} is product content sitting at the repository root",
        reason=(
            "Manifests, lockfiles, toolchain files and source trees are what the "
            "product is built from. At the root they merge the product back into "
            "the machinery that acts on it -- and tools that walk up from the "
            "product would find them from the wrong level."
        ),
        fix=f"Move {name} into {home}, or record it in [root-exceptions] with a reason.",
        where=name,
        docs=INVARIANTS,
    )


def bad_exception(name: str, detail: str) -> Violation:
    return Violation(
        code="LAYOUT-06",
        summary=f"[root-exceptions] entry '{name}' {detail}",
        reason=(
            "An exception is a standing hole in the rule. It must say why it "
            "exists, and must go when the thing it excused does."
        ),
        fix=f"Give '{name}' a reason string, or delete the entry.",
        where=".repo/layout.toml",
        docs=EXCEPTIONS,
    )


def stray_workspace_mount(target: str, product: str | None) -> Violation:
    home = f"{product}/" if product else "a declared product directory"
    return Violation(
        code="LAYOUT-07",
        summary=f"devcontainer mount {target} is not under {home}",
        reason=_SILENT + " Build-output volumes belong to the product they cache.",
        fix=f"Point the mount inside {home}, or remove it.",
        where=".devcontainer/devcontainer.json",
        docs=ADAPTERS,
    )


def missing_editor_link(setting: str, entry: str) -> Violation:
    return Violation(
        code="LAYOUT-07",
        summary=f"devcontainer setting {setting} does not list {entry}",
        reason=(
            "The editor opens the repository root, one level above the product, "
            "so its language server finds no project unless it is linked."
        ),
        fix=f'Add "{entry}" to customizations.vscode.settings["{setting}"].',
        where=".devcontainer/devcontainer.json",
        docs=ADAPTERS,
    )


def stray_dependabot(ecosystem: str, directory: str, product: str | None) -> Violation:
    home = f"/{product}" if product else "a declared product directory"
    return Violation(
        code="LAYOUT-08",
        summary=f"Dependabot {ecosystem} update scans {directory}, not {home}",
        reason=(
            "The repository root holds no manifest, so the update finds nothing "
            "and opens no PRs -- which looks exactly like having nothing to update."
        ),
        fix=f"Set the {ecosystem} update's directory to {home}.",
        where=".github/dependabot.yml",
        docs=ADAPTERS,
    )


def product_dir_var(detail: str, expected: str | None) -> Violation:
    fix = (
        f"Set `PRODUCT_DIR: '{expected}'` under vars: in Taskfile.yml."
        if expected
        else "Remove PRODUCT_DIR from Taskfile.yml, or declare the product."
    )
    return Violation(
        code="LAYOUT-09",
        summary=f"Taskfile PRODUCT_DIR {detail}",
        reason=_SILENT + " Tasks reach the product's toolchain through `dir: '{{.PRODUCT_DIR}}'`.",
        fix=fix,
        where="Taskfile.yml",
        docs=ADAPTERS,
    )


def missing_env_schema(product: str) -> Violation:
    return Violation(
        code="LAYOUT-10",
        summary=f"{product}/env.schema.yaml is missing",
        reason=(
            "The environment a product reads at runtime is part of its interface. "
            "Declared beside the manifest, it is reviewed, versioned and checked "
            "with the code that reads it."
        ),
        fix=f"Add {product}/env.schema.yaml declaring every variable the product reads.",
        where=f"{product}/",
        docs=ENV_CONTRACT,
    )


def misplaced_env_schema(path: str, expected: str) -> Violation:
    return Violation(
        code="LAYOUT-11",
        summary=f"{path} is not at a sanctioned env-schema location",
        reason=(
            "Two env schemas exist, one per level: the product's at its root, and "
            "the dev environment's in .devcontainer/. Anywhere else -- a config/ "
            "folder included -- is a third place to look."
        ),
        fix=f"Move it to {expected}.",
        where=path,
        docs=ENV_CONTRACT,
    )
