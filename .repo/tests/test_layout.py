from __future__ import annotations

import json

import pytest

from conftest import HOST_AGENT, codes
from governance.policies.layout import run

EMPTY = {".repo/layout.toml": 'product = ""\n'}


def test_adapted_product_repo_is_clean(make_repo):
    make_repo(HOST_AGENT)
    assert run().violations == []


def test_template_state_is_clean(make_repo):
    make_repo(EMPTY)
    assert run().violations == []


@pytest.mark.parametrize(
    "layout",
    [None, "", "product = 3\n", 'product = "a/b"\n', 'product = "docs"\n', "product = [\n"],
    ids=["missing-file", "missing-key", "not-a-string", "two-segments", "reserved", "bad-toml"],
)
def test_bad_declaration(make_repo, layout):
    files = {} if layout is None else {".repo/layout.toml": layout}
    make_repo(files)
    assert "LAYOUT-01" in codes(run())


def test_declared_dir_missing(make_repo):
    make_repo({".repo/layout.toml": 'product = "demo"\n'})
    assert "LAYOUT-02" in codes(run())


def test_product_not_named_after_repo(make_repo):
    files = {k.replace("demo", "other"): v.replace("demo", "other") for k, v in HOST_AGENT.items()}
    make_repo(files)
    assert codes(run()) == {"LAYOUT-03"}


def test_product_without_manifest(make_repo):
    files = {k: v for k, v in HOST_AGENT.items() if k != "demo/Cargo.toml"}
    make_repo(files)
    assert "LAYOUT-04" in codes(run())


@pytest.mark.parametrize("name", ["Cargo.toml", "package.json", "go.mod", "src/main.rs", ".cargo/config.toml"])
def test_product_content_at_root(make_repo, name):
    make_repo({**EMPTY, name: ""})
    assert "LAYOUT-05" in codes(run())


def test_root_exception_accepted_with_reason(make_repo):
    make_repo({".repo/layout.toml": 'product = ""\n[root-exceptions]\n"package.json" = "commitlint only"\n',
               "package.json": "{}"})
    assert run().violations == []


@pytest.mark.parametrize(
    "entry",
    ['"package.json" = ""\n', '"gone.toml" = "nothing here"\n'],
    ids=["no-reason", "stale"],
)
def test_bad_root_exception(make_repo, entry):
    make_repo({".repo/layout.toml": 'product = ""\n[root-exceptions]\n' + entry, "package.json": "{}"})
    assert "LAYOUT-06" in codes(run())


def test_mount_outside_product(make_repo):
    devcontainer = json.loads(HOST_AGENT[".devcontainer/devcontainer.json"])
    devcontainer["mounts"] = ["source=x,target=/workspaces/${localWorkspaceFolderBasename}/target,type=volume"]
    make_repo({**HOST_AGENT, ".devcontainer/devcontainer.json": json.dumps(devcontainer)})
    assert codes(run()) == {"LAYOUT-07"}


def test_workspace_mount_without_product(make_repo):
    devcontainer = {"mounts": ["source=x,target=/workspaces/${localWorkspaceFolderBasename}/target,type=volume"]}
    make_repo({**EMPTY, ".devcontainer/devcontainer.json": json.dumps(devcontainer)})
    assert "LAYOUT-07" in codes(run())


def test_commented_mount_example_is_ignored(make_repo):
    devcontainer = (
        '{\n  "mounts": [\n'
        '    // "source=x,target=/workspaces/${localWorkspaceFolderBasename}/<product>/target,type=volume"\n'
        "  ]\n}\n"
    )
    make_repo({**EMPTY, ".devcontainer/devcontainer.json": devcontainer})
    assert run().violations == []


def test_missing_editor_link(make_repo):
    devcontainer = json.loads(HOST_AGENT[".devcontainer/devcontainer.json"])
    devcontainer["customizations"] = {}
    make_repo({**HOST_AGENT, ".devcontainer/devcontainer.json": json.dumps(devcontainer)})
    assert codes(run()) == {"LAYOUT-07"}


def test_dependabot_scans_root(make_repo):
    dependabot = HOST_AGENT[".github/dependabot.yml"].replace("/demo", "/")
    make_repo({**HOST_AGENT, ".github/dependabot.yml": dependabot})
    assert codes(run()) == {"LAYOUT-08"}


def test_repo_level_tooling_may_carry_its_own_manifest(make_repo):
    dependabot = HOST_AGENT[".github/dependabot.yml"] + (
        "  - package-ecosystem: uv\n    directory: /scripts/release\n    schedule: {interval: weekly}\n"
    )
    make_repo({**HOST_AGENT, ".github/dependabot.yml": dependabot, "scripts/release/pyproject.toml": ""})
    assert run().violations == []


def test_root_exception_manifest_may_be_scanned(make_repo):
    dependabot = "version: 2\nupdates:\n  - package-ecosystem: npm\n    directory: /\n"
    make_repo({".repo/layout.toml": 'product = ""\n[root-exceptions]\n"package.json" = "commitlint"\n',
               "package.json": "{}", ".github/dependabot.yml": dependabot})
    assert run().violations == []


def test_non_product_ecosystems_may_scan_root(make_repo):
    dependabot = "version: 2\nupdates:\n  - package-ecosystem: github-actions\n    directory: /\n"
    make_repo({**EMPTY, ".github/dependabot.yml": dependabot})
    assert run().violations == []


@pytest.mark.parametrize(
    "taskfile",
    ["version: '3'\n", "version: '3'\nvars:\n  PRODUCT_DIR: '{{.ROOT_DIR}}/other'\n"],
    ids=["missing", "wrong"],
)
def test_product_dir_var(make_repo, taskfile):
    make_repo({**HOST_AGENT, "Taskfile.yml": taskfile})
    assert codes(run()) == {"LAYOUT-09"}


def test_product_dir_var_without_product(make_repo):
    make_repo({**EMPTY, "Taskfile.yml": "version: '3'\nvars:\n  PRODUCT_DIR: '{{.ROOT_DIR}}/demo'\n"})
    assert "LAYOUT-09" in codes(run())


def test_missing_env_schema(make_repo):
    files = {k: v for k, v in HOST_AGENT.items() if k != "demo/env.schema.yaml"}
    make_repo(files)
    assert codes(run()) == {"LAYOUT-10"}


@pytest.mark.parametrize("path", ["demo/config/env.schema.yaml", "env.schema.yaml", "docs/env.schema.yaml"])
def test_misplaced_env_schema(make_repo, path):
    make_repo({**HOST_AGENT, path: HOST_AGENT["demo/env.schema.yaml"]})
    assert codes(run()) == {"LAYOUT-11"}


def test_config_folder_schema_points_at_product_root(make_repo):
    make_repo({**HOST_AGENT, "demo/config/env.schema.yaml": ""})
    (violation,) = run().violations
    assert "demo/env.schema.yaml" in violation.fix


def test_dev_environment_schema_is_sanctioned(make_repo):
    make_repo({**EMPTY, ".devcontainer/env.schema.yaml": HOST_AGENT["demo/env.schema.yaml"]})
    assert run().violations == []
