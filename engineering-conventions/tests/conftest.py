from pathlib import Path

import pytest

from conventions_tools.content import Content, load_content
from conventions_tools.paths import product_dir


@pytest.fixture(scope="session")
def product() -> Path:
    return product_dir()


@pytest.fixture(scope="session")
def fixtures(product: Path) -> Path:
    return product / "tests" / "fixtures"


@pytest.fixture(scope="session")
def content(product: Path) -> Content:
    return load_content(product)
