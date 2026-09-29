import os
import shutil
import subprocess
from collections.abc import Iterator
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


# The tools the suite runs as subprocesses, many times over. Through a mise
# shim each call re-resolves the toolchain, which costs more than the call.
TOOLS = ("conftest", "vale", "jq", "check-jsonschema")


@pytest.fixture(scope="session", autouse=True)
def _tools_resolved_once(product: Path) -> Iterator[None]:
    """Put each pinned tool's own directory on PATH, ahead of the mise shims."""
    mise = shutil.which("mise")
    if mise is None:
        yield
        return
    directories: list[str] = []
    for tool in TOOLS:
        found = subprocess.run(
            [mise, "which", tool],
            cwd=product.parent,
            capture_output=True,
            text=True,
            check=False,
        )
        if found.returncode == 0 and found.stdout.strip():
            directories.append(str(Path(found.stdout.strip()).parent))
    with pytest.MonkeyPatch.context() as patch:
        if directories:
            patch.setenv("PATH", os.pathsep.join([*directories, os.environ.get("PATH", "")]))
        yield


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
