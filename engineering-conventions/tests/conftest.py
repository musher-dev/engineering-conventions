from pathlib import Path

import pytest

from conventions_tools.content import Content, load_content
from conventions_tools.paths import product_dir

# Git exports these to a hook it runs, such as the pre-push hook that runs this
# suite. Inherited, they point every git call a test makes, including those in
# a fixture repository materialized under tmp_path, at the pushing repository.
GIT_LOCATION = (
    "GIT_DIR",
    "GIT_WORK_TREE",
    "GIT_INDEX_FILE",
    "GIT_COMMON_DIR",
    "GIT_OBJECT_DIRECTORY",
    "GIT_ALTERNATE_OBJECT_DIRECTORIES",
    "GIT_PREFIX",
)


@pytest.fixture(autouse=True)
def _outside_any_git_hook(monkeypatch: pytest.MonkeyPatch) -> None:
    for variable in GIT_LOCATION:
        monkeypatch.delenv(variable, raising=False)


@pytest.fixture(scope="session")
def product() -> Path:
    return product_dir()


@pytest.fixture(scope="session")
def fixtures(product: Path) -> Path:
    return product / "tests" / "fixtures"


@pytest.fixture(scope="session")
def content(product: Path) -> Content:
    return load_content(product)
