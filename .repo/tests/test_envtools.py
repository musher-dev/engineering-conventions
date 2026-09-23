"""The developer-facing half: rendering, profile-aware requiredness, sync."""

from __future__ import annotations

import argparse
import json

import pytest

from conftest import codes
from governance import dotenv, envtools, repo
from governance.policies.env import run as env_check

SCHEMA = """
service: devcontainer
runtime: docker-compose
bindings:
  COMPOSE_PROFILES:
    type: list
    values: [redis]
    local_default: ""
    sensitivity: public
    description: Stacks to start.
  REDIS_PASSWORD:
    type: string
    required: true
    sensitivity: internal
    consumers: [redis]
    description: Password for the redis stack.
"""

REDIS_COMPOSE = (
    "services:\n  redis:\n    image: redis:8\n    profiles: [redis]\n"
    "    environment:\n      PASS: ${REDIS_PASSWORD}\n"
)
PG_COMPOSE = "services:\n  postgres:\n    image: postgres:18\n"


def _repo(make_repo, env: str = "", schema: str = SCHEMA, **extra):
    files = {
        ".devcontainer/env.schema.yaml": schema,
        ".devcontainer/stacks/redis/compose.yaml": REDIS_COMPOSE,
        ".devcontainer/stacks/postgres/compose.yaml": PG_COMPOSE,
        ".devcontainer/devcontainer.json": json.dumps({"mounts": []}),
        **extra,
    }
    path = make_repo(files)
    (path / ".devcontainer/.env").write_text(env, encoding="utf-8")
    return path


def test_stack_profiles_and_activation(make_repo):
    _repo(make_repo)
    assert envtools.stack_profiles() == {"redis": {"redis"}, "postgres": set()}
    assert envtools.active_stacks([]) == {"postgres"}
    assert envtools.active_stacks(["redis"]) == {"postgres", "redis"}


def test_requirement_follows_enabled_profiles(make_repo):
    _repo(make_repo, env="COMPOSE_PROFILES=\nREDIS_PASSWORD=\n")
    assert envtools.diagnose() == ([], set())


def test_enabled_stack_demands_its_value(make_repo):
    _repo(make_repo, env="COMPOSE_PROFILES=redis\nREDIS_PASSWORD=\n")
    problems, blocked = envtools.diagnose()
    assert problems == [("REDIS_PASSWORD", "needs a value")]
    assert blocked == {"redis"}


def test_invalid_profile_is_reported(make_repo):
    _repo(make_repo, env="COMPOSE_PROFILES=redis,typo\nREDIS_PASSWORD=x\n")
    problems, _ = envtools.diagnose()
    assert problems == [("COMPOSE_PROFILES", "unknown value(s) typo")]


def test_compose_profiles_output_drops_blocked_stacks(make_repo, capsys):
    _repo(make_repo, env="COMPOSE_PROFILES=redis\nREDIS_PASSWORD=\n")
    args = argparse.Namespace(quiet=False, motd=False, compose_profiles=True)
    assert envtools.doctor(args) == 0
    assert capsys.readouterr().out.strip() == ""


def test_render_round_trips_through_the_parser(make_repo):
    _repo(make_repo)
    rendered = dotenv.render(envtools.schema(), envtools.HEADER)
    assert dotenv.parse(rendered) == {"COMPOSE_PROFILES": "", "REDIS_PASSWORD": ""}


def test_render_check_reports_drift(make_repo, capsys):
    _repo(make_repo, **{".devcontainer/.env.example": "COMPOSE_PROFILES=\n"})
    assert envtools.render(argparse.Namespace(check=True)) == 1
    assert "drifted" in capsys.readouterr().out


def test_sync_adds_new_bindings_and_keeps_live_values(make_repo):
    path = _repo(make_repo, env="COMPOSE_PROFILES=redis\n")
    envtools.sync(argparse.Namespace())
    written = dotenv.parse((path / ".devcontainer/.env").read_text())
    assert written["COMPOSE_PROFILES"] == "redis"
    assert "REDIS_PASSWORD" in written


def test_sync_mints_generated_secrets_once(make_repo):
    schema = SCHEMA.replace("    required: true\n", "    local_generate: hex:16\n")
    path = _repo(make_repo, env="", schema=schema)
    envtools.sync(argparse.Namespace())
    first = dotenv.parse((path / ".devcontainer/.env").read_text())["REDIS_PASSWORD"]
    envtools.sync(argparse.Namespace())
    assert dotenv.parse((path / ".devcontainer/.env").read_text())["REDIS_PASSWORD"] == first
    assert len(first) == 32


@pytest.mark.parametrize(
    ("kind", "value", "ok"),
    [("list", "redis", True), ("list", "nope", False), ("int", "12", True), ("int", "x", False),
     ("bool", "true", True), ("bool", "maybe", False), ("url", "http://a", True), ("url", "a", False)],
)
def test_value_validation(kind, value, ok):
    binding = {"type": kind, "values": ["redis"] if kind == "list" else None}
    assert (envtools.invalid(binding, value) is None) is ok


def test_policy_accepts_the_matching_pair(make_repo):
    _repo(make_repo)
    rendered = dotenv.render(envtools.schema(), envtools.HEADER)
    (repo.repo_root() / ".devcontainer/.env.example").write_text(rendered, encoding="utf-8")
    repo.tracked_files.cache_clear()
    assert env_check().violations == []


def test_policy_flags_undeclared_compose_reference(make_repo):
    compose = REDIS_COMPOSE.replace("${REDIS_PASSWORD}", "${REDIS_SECRET}")
    _repo(make_repo, **{".devcontainer/stacks/redis/compose.yaml": compose})
    assert "ENV-03" in codes(env_check())


def test_policy_flags_unknown_consumer(make_repo):
    _repo(make_repo, schema=SCHEMA.replace("consumers: [redis]", "consumers: [nope]"))
    assert "ENV-04" in codes(env_check())


def test_policy_flags_mirror_drift(make_repo):
    schema = SCHEMA.replace(
        "    required: true\n",
        "    local_default: hunter2\n    mirrored_in: [stacks/redis/redis.conf]\n",
    )
    _repo(make_repo, schema=schema, **{".devcontainer/stacks/redis/redis.conf": "requirepass other\n"})
    assert "ENV-05" in codes(env_check())


def test_policy_flags_missing_codespaces_secret(make_repo):
    _repo(make_repo, schema=SCHEMA.replace("    required: true\n", "    required: true\n    source: host\n"))
    assert "ENV-06" in codes(env_check())


def test_policy_flags_committed_secret_default(make_repo):
    schema = SCHEMA.replace(
        "    required: true\n    sensitivity: internal\n",
        "    local_default: hunter2\n    sensitivity: secret\n",
    )
    _repo(make_repo, schema=schema)
    assert "ENV-07" in codes(env_check())


def test_policy_allows_loopback_secret_default(make_repo):
    schema = SCHEMA.replace(
        "    required: true\n    sensitivity: internal\n",
        "    local_default: postgres://localhost:5432\n    sensitivity: secret\n",
    )
    _repo(make_repo, schema=schema)
    assert "ENV-07" not in codes(env_check())
