import shutil
import subprocess
from pathlib import Path

import pytest
from jsonschema import Draft7Validator

from conventions_tools import schemas
from conventions_tools.content import convention_files
from conventions_tools.loading import as_list, as_map, read_json, read_yaml, split_frontmatter
from conventions_tools.paths import families_file, product_dir, schemas_dir

PRODUCT = product_dir()
FIXTURES = PRODUCT / "tests" / "fixtures"

KINDS = {
    "declarations": (schemas.DECLARATION, "valid", "invalid"),
    "outputs": (schemas.OUTPUTS, "valid", "invalid"),
    "profiles": (schemas.PROFILE, "valid", "invalid/schema"),
    "terminology": (schemas.TERMINOLOGY, "valid", "invalid/schema"),
    "conventions": (schemas.CONVENTION, "valid", "invalid"),
}


def _load(path: Path) -> object:
    if path.suffix == ".md":
        frontmatter, _ = split_frontmatter(path.read_text(encoding="utf-8"), str(path))
        return frontmatter
    return read_yaml(path)


def _cases(*, expect_valid: bool) -> list[tuple[str, Path]]:
    cases: list[tuple[str, Path]] = []
    for kind, (schema, valid, invalid) in KINDS.items():
        directory = FIXTURES / kind / (valid if expect_valid else invalid)
        cases += [(schema, path) for path in sorted(directory.glob("*.*"))]
    return cases


def _id(case: tuple[str, Path]) -> str:
    return case[1].relative_to(FIXTURES).as_posix()


@pytest.mark.parametrize("case", _cases(expect_valid=True), ids=_id)
def test_valid_fixture_passes(case: tuple[str, Path]) -> None:
    schema, path = case
    assert schemas.problems(PRODUCT, schema, _load(path), path.name) == []


@pytest.mark.parametrize("case", _cases(expect_valid=False), ids=_id)
def test_invalid_fixture_fails(case: tuple[str, Path]) -> None:
    schema, path = case
    assert schemas.problems(PRODUCT, schema, _load(path), path.name) != []


def test_every_kind_has_valid_and_invalid_fixtures() -> None:
    for kind, (schema, _, _) in KINDS.items():
        valid = [case for case in _cases(expect_valid=True) if case[0] == schema]
        invalid = [case for case in _cases(expect_valid=False) if case[0] == schema]
        assert valid, kind
        assert invalid, kind


@pytest.mark.parametrize("path", convention_files(PRODUCT), ids=lambda path: path.name)
def test_frozen_convention_frontmatter_is_valid(path: Path) -> None:
    assert schemas.problems(PRODUCT, schemas.CONVENTION, _load(path), path.name) == []


def test_families_file_is_valid() -> None:
    families = read_yaml(families_file(PRODUCT))
    assert schemas.problems(PRODUCT, schemas.FAMILIES, families, "families.yml") == []


def test_families_schema_rejects_bad_prefix() -> None:
    families = {
        "schema_version": 1,
        "families": [{"prefix": "gha", "title": "t", "topic": "x", "owner": "@o"}],
    }
    assert schemas.problems(PRODUCT, schemas.FAMILIES, families, "families") != []


def test_global_terminology_and_base_profile_are_valid() -> None:
    terminology = read_yaml(PRODUCT / "definitions" / "terminology" / "global.yml")
    profile = read_yaml(PRODUCT / "definitions" / "profiles" / "base-repo.yml")
    assert schemas.problems(PRODUCT, schemas.TERMINOLOGY, terminology, "global") == []
    assert schemas.problems(PRODUCT, schemas.PROFILE, profile, "base-repo") == []


def test_waiver_on_adopt_is_rejected_with_a_clear_path() -> None:
    declaration = read_yaml(FIXTURES / "declarations" / "invalid" / "adopt-waiver.yaml")
    errors = list(schemas.iter_errors(PRODUCT, schemas.DECLARATION, declaration))
    assert [schemas.location(error) for error in errors] == ["waivers[0].requirement"]


def _refs(node: object) -> list[str]:
    mapping = as_map(node)
    found = [ref] if isinstance(ref := mapping.get("$ref"), str) else []
    children = [*mapping.values(), *as_list(node)]
    return found + [item for child in children for item in _refs(child)]


@pytest.mark.parametrize(
    "path", sorted(schemas_dir(PRODUCT).glob("*.schema.json")), ids=lambda path: path.name
)
def test_schema_is_draft7_with_relative_refs_only(path: Path) -> None:
    schema = as_map(read_json(path))
    Draft7Validator.check_schema(schema)
    assert schema["$schema"] == "http://json-schema.org/draft-07/schema#"
    assert "$id" not in schema
    for ref in _refs(schema):
        assert ref.startswith(("#", "common.schema.json#")), ref


def test_check_jsonschema_resolves_refs_from_disk(tmp_path: Path) -> None:
    # check-jsonschema is how the repository and consumers validate files; it
    # must resolve the relative $refs from disk, whatever the working directory.
    executable = shutil.which("check-jsonschema")
    assert executable, "check-jsonschema must be on PATH (see .devcontainer/mise.toml)"
    completed = subprocess.run(
        [
            executable,
            "--schemafile",
            str(schemas_dir(PRODUCT) / schemas.DECLARATION),
            str(FIXTURES / "declarations" / "valid" / "full.yaml"),
        ],
        cwd=tmp_path,
        capture_output=True,
        text=True,
        check=False,
    )
    assert completed.returncode == 0, completed.stdout + completed.stderr
