from __future__ import annotations

import pytest

from conftest import codes
from governance import globs
from governance.policies.paths import run

LEFTHOOK = ".config/lefthook.yml"


def test_clean_repo(make_repo):
    make_repo({LEFTHOOK: "pre-commit:\n  jobs:\n    - name: md\n      glob: '*.md'\n", "README.md": ""})
    assert run().violations == []


@pytest.mark.parametrize(
    ("pattern", "files", "expected"),
    [
        ("*.{yml,yaml}", ["a.yaml"], True),
        ("{docs/**,README.md}", ["docs/x.md"], False),
        ("{docs/**,README.md}", ["docs/x.md", "README.md"], True),
        (".github/workflows/*.yml", [".github/workflows/v.yaml"], False),
        ("**/*.rs", ["demo/src/main.rs"], True),
    ],
)
def test_matches(pattern, files, expected):
    assert globs.matches(pattern, files) is expected


def test_gitignore_style_anchors_anywhere():
    assert globs.matches("*.sh", ["a/b/c.sh"], gitignore_style=True)
    assert not globs.matches(".env", [".devcontainer/.env.example"], gitignore_style=True)


def test_stale_lefthook_glob(make_repo):
    make_repo({LEFTHOOK: "pre-commit:\n  jobs:\n    - name: g\n      glob: '{.config/**,GONE.md}'\n"})
    assert "PATH-01" in codes(run())


def test_gitattributes_pattern_for_untracked_file(make_repo):
    make_repo({".gitattributes": "* text=auto eol=lf\n.env text eol=lf\n"})
    assert codes(run()) == {"PATH-01"}


def test_paths_filter(make_repo):
    workflow = (
        "on: push\njobs:\n  a:\n    runs-on: x\n    steps:\n"
        "      - uses: dorny/paths-filter@v3\n        with:\n"
        "          filters: |\n            rust:\n              - 'crates/**'\n"
    )
    make_repo({".github/workflows/ci.yml": workflow})
    assert "PATH-01" in codes(run())


def test_missing_working_directory(make_repo):
    workflow = "on: push\njobs:\n  a:\n    runs-on: x\n    steps:\n      - run: ls\n        working-directory: demo\n"
    make_repo({".github/workflows/ci.yml": workflow})
    assert codes(run()) == {"PATH-02"}


def test_expression_working_directory_is_skipped(make_repo):
    workflow = (
        "on: push\njobs:\n  a:\n    runs-on: x\n    steps:\n"
        "      - run: ls\n        working-directory: ${{ matrix.dir }}\n"
    )
    make_repo({".github/workflows/ci.yml": workflow})
    assert run().violations == []


@pytest.mark.parametrize(
    ("directory", "expected"),
    [("/", set()), ("/demo", {"PATH-02"}), ("/.devcontainer/**", set()), ("/nope/**", {"PATH-02"})],
)
def test_dependabot_directories(make_repo, directory, expected):
    key = "directories" if "*" in directory else "directory"
    value = f"['{directory}']" if key == "directories" else f"'{directory}'"
    dependabot = f"version: 2\nupdates:\n  - package-ecosystem: docker\n    {key}: {value}\n"
    make_repo({".github/dependabot.yml": dependabot, ".devcontainer/stacks/x/compose.yaml": ""})
    assert codes(run()) == expected


def test_dead_task_var(make_repo):
    make_repo({"Taskfile.yml": "version: '3'\nvars:\n  SCHEMA: '{{.ROOT_DIR}}/gone.json'\n"})
    assert codes(run()) == {"PATH-03"}


def test_product_dir_task_var_resolves_against_declaration(make_repo):
    make_repo({
        ".repo/layout.toml": 'product = "demo"\n',
        "demo/Cargo.toml": "",
        "Taskfile.yml": "version: '3'\nvars:\n  M: '{{.PRODUCT_DIR}}/Cargo.toml'\n  N: '{{.PRODUCT_DIR}}/nope'\n",
    })
    report = run()
    assert [v.summary for v in report.violations] == ["var N names `{{.PRODUCT_DIR}}/nope`, which does not exist"]


def test_stale_allowance(make_repo, monkeypatch):
    from governance.policies.paths import check

    monkeypatch.setattr(check, "UNTRACKED_OK", {"target/**": "build output"})
    make_repo({})
    assert codes(run()) == {"PATH-04"}
