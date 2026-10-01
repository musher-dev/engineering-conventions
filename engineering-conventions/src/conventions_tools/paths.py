"""Where the product directory is, and the fixed locations inside it."""

import os
from pathlib import Path

REPOSITORY_URL = "https://github.com/musher-dev/engineering-conventions"
PRODUCT_DIR_NAME = "engineering-conventions"
HOME_ENV = "CONVENTIONS_HOME"


def product_dir() -> Path:
    """The product directory: $CONVENTIONS_HOME, else the checkout this package runs from.

    The package is only ever run from a checkout (uv installs it editable), so
    src/conventions_tools/ sits two levels below the product directory.
    """
    override = os.environ.get(HOME_ENV)
    if override:
        return Path(override).resolve()
    return Path(__file__).resolve().parents[2]


def definitions_dir(product: Path) -> Path:
    """What is decided: conventions, terminology and profiles. checks/ holds what validates it."""
    return product / "definitions"


def conventions_dir(product: Path) -> Path:
    return definitions_dir(product) / "conventions"


def families_file(product: Path) -> Path:
    return conventions_dir(product) / "families.yml"


def schemas_dir(product: Path) -> Path:
    return product / "checks" / "schemas"


def rego_dir(product: Path) -> Path:
    return product / "checks" / "rego"


def launcher_file(product: Path) -> Path:
    """bin/conventions, whose file patterns both runners use (decision 0015)."""
    return product / "bin" / "conventions"


def index_file(product: Path) -> Path:
    return product / "checks" / "data" / "index.json"


def release_file(product: Path) -> Path:
    return product / "checks" / "data" / "release.json"


def vale_dir(product: Path) -> Path:
    """The Vale StylesPath the bundle ships: one directory per style."""
    return product / "checks" / "vale"


def vale_style_dir(product: Path) -> Path:
    return vale_dir(product) / "MusherConventions"


def copy_style_file(product: Path) -> Path:
    """The source of the MusherCopy style and the MusherProse package (EC-0038)."""
    return definitions_dir(product) / "copy" / "style.yml"


def terminology_dir(product: Path) -> Path:
    return definitions_dir(product) / "terminology"


def profiles_dir(product: Path) -> Path:
    return definitions_dir(product) / "profiles"


def fixture_repos_dir(product: Path) -> Path:
    return product / "tests" / "fixtures" / "repos"
