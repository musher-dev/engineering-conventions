import os
from collections.abc import Iterator
from pathlib import Path

import pytest

from conventions_tools.content import Content, load_content
from conventions_tools.paths import product_dir

# Git exports these to a hook it runs, and in a linked worktree GIT_DIR among
# them. Inherited by the tests' own git calls, they make every temporary
# directory look like the top of this repository's work tree, so the tests
# must not see them when a pre-push hook runs the suite.
GIT_HOOK_ENVIRONMENT = (
    "GIT_DIR",
    "GIT_WORK_TREE",
    "GIT_INDEX_FILE",
    "GIT_COMMON_DIR",
    "GIT_PREFIX",
    "GIT_OBJECT_DIRECTORY",
    "GIT_ALTERNATE_OBJECT_DIRECTORIES",
)


@pytest.fixture(scope="session", autouse=True)
def _without_git_hook_environment() -> Iterator[None]:
    saved = {key: os.environ.pop(key) for key in GIT_HOOK_ENVIRONMENT if key in os.environ}
    yield
    os.environ.update(saved)


@pytest.fixture(scope="session")
def product() -> Path:
    return product_dir()


@pytest.fixture(scope="session")
def fixtures(product: Path) -> Path:
    return product / "tests" / "fixtures"


@pytest.fixture(scope="session")
def content(product: Path) -> Content:
    return load_content(product)
