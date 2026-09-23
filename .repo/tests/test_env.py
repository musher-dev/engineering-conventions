from __future__ import annotations

import pytest

from conftest import HOST_AGENT, codes
from governance import envschema
from governance.policies.env import run

VALID = HOST_AGENT["demo/env.schema.yaml"]


def test_valid_schema(make_repo):
    make_repo({"demo/env.schema.yaml": VALID})
    assert run().violations == []


@pytest.mark.parametrize(
    ("schema", "fragment"),
    [
        ("runtime: rust\nbindings: {}\n", "`service` is missing"),
        ("service: a\nruntime: b\nbindings: []\n", "`bindings` is not a mapping"),
        (VALID.replace("    sensitivity: internal\n", ""), "has no `sensitivity`"),
        (VALID.replace("internal", "private"), "is not one of"),
        (VALID.replace("required: true", "required: yes-please"), "is not true/false"),
        (VALID.replace("HOST_ID", "host_id"), "UPPER_SNAKE_CASE"),
    ],
)
def test_shape_problems(schema, fragment):
    import yaml

    assert any(fragment in problem for problem in envschema.problems(yaml.safe_load(schema)))


def test_malformed_schema_is_reported_wherever_it_is(make_repo):
    make_repo({"somewhere/env.schema.yaml": "service: a\n"})
    assert codes(run()) == {"ENV-01"}
