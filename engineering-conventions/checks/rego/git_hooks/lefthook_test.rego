package conventions.checks.git_hooks.lefthook_test

import data.conventions.checks.git_hooks.lefthook
import data.conventions.lib.testdata_test as td

config_path := ".config/lefthook.yml"

repository := [
	"README.md",
	"docs/guide.md",
	".github/workflows/validate.yml",
	"scripts/setup.sh",
]

markdown_job := {
	"name": "markdown",
	"glob": "**/*.md",
	"run": "markdownlint-cli2 --fix {staged_files}",
	"stage_fixed": true,
	"fail_text": "Markdown lint failed. Run 'task lint:md'.",
}

conforming := {
	"assert_lefthook_installed": true,
	"min_version": "2.1.14",
	"glob_matcher": "doublestar",
	"output": ["failure", "summary"],
	"pre-commit": {"parallel": true, "jobs": [markdown_job]},
	"pre-push": {"jobs": [{
		"name": "test",
		"run": "task test",
		"fail_text": "Tests failed. Run 'task test'.",
	}]},
}

mise := td.file(".config/mise/config.toml", {"tools": {"aqua:evilmartians/lefthook": "2.1.14"}})

docs(config) := [
	td.inventory(["README.md", "docs/guide.md", ".github/workflows/validate.yml", "scripts/setup.sh"]),
	td.file(".config/lefthook.yml", config),
	td.file(".config/mise/config.toml", {"tools": {"aqua:evilmartians/lefthook": "2.1.14"}}),
]

with_config(fields) := docs(object.union(conforming, fields))

pre_commit(job) := with_config({"pre-commit": {"jobs": [object.union(markdown_job, job)]}})

messages(found, id) := {f.message | some f in found; f.id == id}

test_conforming_configuration if {
	count(lefthook.findings) == 0 with input as docs(conforming)
}

test_no_configuration_no_findings if {
	count(lefthook.findings) == 0 with input as [td.inventory(repository), mise]
}

test_root_and_hidden_configurations_are_read if {
	found := lefthook.findings with input as [
		td.inventory(repository),
		td.file("lefthook.yml", {}),
		td.file(".lefthook.yaml", {}),
		td.file(".config/lefthook-local.yml", {}),
	]
	{f.path | some f in found} == {"lefthook.yml", ".lefthook.yaml"}
}

test_hooks_01_assert_installed if {
	found := lefthook.findings with input as with_config({"assert_lefthook_installed": false})
	td.pairs(found) == {["HOOKS-01", config_path]}
}

test_hooks_02_min_version_missing if {
	found := lefthook.findings with input as docs(object.remove(conforming, ["min_version"]))
	td.pairs(found) == {["HOOKS-02", config_path]}
}

test_hooks_02_min_version_differs_from_mise if {
	found := lefthook.findings with input as with_config({"min_version": "2.1.4"})
	messages(found, "HOOKS-02") == {concat("", [
		`min_version is "2.1.4" but .config/mise/config.toml installs lefthook 2.1.14; `,
		`set min_version to "2.1.14" so the floor is the version everyone runs`,
	])}
}

test_hooks_02_reads_a_table_pin_and_a_v_prefix if {
	table := td.file("mise.toml", {"tools": {"npm:lefthook": {"version": "v2.1.14"}}})
	count(lefthook.findings) == 0 with input as [td.inventory(repository), td.file(config_path, conforming), table]
}

test_hooks_02_quiet_without_a_mise_pin if {
	config := object.union(conforming, {"min_version": "1.0.0"})
	count(lefthook.findings) == 0 with input as [td.inventory(repository), td.file(config_path, config)]
}

test_hooks_03_glob_matcher if {
	found := lefthook.findings with input as docs(object.remove(conforming, ["glob_matcher"]))
	td.pairs(found) == {["HOOKS-03", config_path]}
}

test_hooks_04_unanchored_glob if {
	found := lefthook.findings with input as pre_commit({"glob": "*.{md,sh}"})
	rest := "matches only files at the repository root under doublestar"
	messages(found, "HOOKS-04") == {
		sprintf(`pre-commit job "markdown": glob "*.md" %s; write "**/*.md" to match at any depth`, [rest]),
		sprintf(`pre-commit job "markdown": glob "*.sh" %s; write "**/*.sh" to match at any depth`, [rest]),
	}
}

test_hooks_04_accepts_paths_and_plain_names if {
	found := lefthook.findings with input as pre_commit({"glob": ["README.md", "docs/*.md", "{docs,.github}/**/*.md"]})
	not "HOOKS-04" in td.ids(found)
}

test_hooks_04_reads_a_group_glob if {
	group := {"name": "lint", "glob": "*.md", "group": {"jobs": [object.remove(markdown_job, ["glob"])]}}
	found := lefthook.findings with input as with_config({"pre-commit": {"jobs": [group]}})
	td.pairs(found) == {["HOOKS-04", config_path]}
}

test_hooks_05_commands_and_scripts if {
	hook := {"commands": {"lint": {"run": "lint"}}, "scripts": {"check.sh": {"runner": "bash"}}}
	found := lefthook.findings with input as with_config({"pre-commit": hook})
	messages(found, "HOOKS-05") == {
		"pre-commit defines commands:, the form lefthook replaced; move each entry into jobs:, as run: or script:",
		"pre-commit defines scripts:, the form lefthook replaced; move each entry into jobs:, as run: or script:",
	}
}

test_hooks_06_fail_text_on_leaf_jobs_only if {
	leaf := {"run": "lint {staged_files}", "glob": "**/*.md"}
	group := {"name": "chain", "group": {"piped": true, "jobs": [leaf, {"script": "check.sh", "fail_text": " "}]}}
	found := lefthook.findings with input as with_config({"pre-commit": {"jobs": [group]}})
	rest := "has no fail_text; add one sentence saying what to run or change when it fails"
	messages(found, "HOOKS-06") == {
		sprintf("pre-commit job at jobs[0].group.jobs[0] %s", [rest]),
		sprintf("pre-commit job at jobs[0].group.jobs[1] %s", [rest]),
	}
}

test_hooks_07_stage_fixed_on_a_check if {
	found := lefthook.findings with input as pre_commit({"run": "prettier --check {staged_files}"})
	td.pairs(found) == {["HOOKS-07", config_path]}
}

test_hooks_07_task_check_and_dry_run if {
	count(messages(lefthook.findings, "HOOKS-07")) == 1 with input as pre_commit({"run": "task fmt:check"})
	count(messages(lefthook.findings, "HOOKS-07")) == 1 with input as pre_commit({"run": "ruff format --dry-run"})
}

test_hooks_07_quiet_on_a_fixer if {
	count(lefthook.findings) == 0 with input as pre_commit({"run": "taplo fmt --check-only-not-a-flag {staged_files}"})
}

test_hooks_08_test_runners_in_pre_commit if {
	runs := ["uv run pytest -q", "npx jest", "go test ./...", "cargo nextest run", "bun test", "task lint checks:test"]
	every run in runs {
		"HOOKS-08" in td.ids(lefthook.findings) with input as pre_commit({"run": run, "stage_fixed": false})
	}
}

test_hooks_08_quiet_on_lookalikes if {
	runs := ["markdownlint --config jest.config.js", "task checks:lint", "cat tests/pytest.ini", "task test-fixtures"]
	every run in runs {
		not "HOOKS-08" in td.ids(lefthook.findings) with input as pre_commit({"run": run, "stage_fixed": false})
	}
}

test_hooks_08_allows_tests_in_pre_push if {
	not "HOOKS-08" in td.ids(lefthook.findings) with input as docs(conforming)
}

test_hooks_09_remotes_and_extends if {
	config := object.union(conforming, {"remotes": [{"git_url": "https://example.com/hooks"}], "extends": ["x.yml"]})
	found := lefthook.findings with input as docs(config)
	messages(found, "HOOKS-09") == {
		"remotes: merges configuration from elsewhere into the hooks; write the jobs in this file",
		"extends: merges configuration from elsewhere into the hooks; write the jobs in this file",
	}
}

test_hooks_10_swallowed_exit_codes if {
	runs := ["lint || true", "lint || :", "lint || exit 0", "lint || echo skipped", "set +e\nlint"]
	every run in runs {
		"HOOKS-10" in td.ids(lefthook.findings) with input as pre_commit({"run": run, "stage_fixed": false})
	}
}

test_hooks_10_ignores_comments_and_lookalikes if {
	runs := ["lint # no longer || true", "lint || exit 1", "lint || { echo failed; exit 1; }", "set -e"]
	every run in runs {
		not "HOOKS-10" in td.ids(lefthook.findings) with input as pre_commit({"run": run, "stage_fixed": false})
	}
}

test_hooks_11_glob_matches_nothing if {
	found := lefthook.findings with input as pre_commit({"glob": ["**/*.md", "src/**/*.py"]})
	messages(found, "HOOKS-11") == {concat("", [
		`pre-commit job "markdown": glob "src/**/*.py" matches no file in the repository, `,
		"so the job never runs; correct the pattern or remove the job",
	])}
}

test_hooks_11_ignores_fixture_files if {
	declaration := td.declaration({"paths": {"fixtures": ["tests/fixtures/**"]}})
	inventory := td.inventory(array.concat(repository, ["tests/fixtures/a.py"]))
	config := object.union(conforming, {"pre-commit": {"jobs": [object.union(markdown_job, {"glob": "**/*.py"})]}})
	found := lefthook.findings with input as [inventory, declaration, td.file(config_path, config), mise]
	td.pairs(found) == {["HOOKS-11", config_path]}
}

test_fixture_configurations_are_not_checked if {
	declaration := td.declaration({"paths": {"fixtures": ["tests/**"]}})
	docs := [td.inventory(repository), declaration, td.file("tests/lefthook.yml", {})]
	count(lefthook.findings) == 0 with input as docs
}
