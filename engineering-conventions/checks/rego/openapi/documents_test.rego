package conventions.checks.openapi.documents_test

import data.conventions.checks.openapi.documents
import data.conventions.lib.testdata_test as td

ids(found) := {f.id | some f in found}

messages(found, id) := {f.message | some f in found; f.id == id}

public := {
	"id": "public-http",
	"format": "openapi",
	"definitions": ["api/contracts/openapi/public.json"],
	"delivered_by": "contracts",
	"compatibility": "gated",
}

events := object.union(public, {"id": "events", "format": "json-schema"})

outputs(interfaces) := td.file(".repo/outputs.toml", {"schema_version": 2, "interfaces": interfaces})

extends_link := "extends:\n  - ../../.conventions/openapi.spectral.yaml\n"

run(command) := {"jobs": {"main": {"steps": [{"run": command}]}}}

task_runs := {"version": "3", "tasks": {
	"openapi": {"cmds": ["conventions openapi --ruleset .config/openapi/spectral.yaml"]},
	"check": {"cmds": [{"task": "lint"}, {"task": "openapi"}]},
	"lint": {"cmds": ["actionlint"]},
}}

# A repository with the given interfaces, ruleset texts, Taskfile and
# validate workflow.
repo(interfaces, rulesets, taskfile, validate) := array.concat(
	[
		td.file("/tmp/inventory.json", {"conventions_inventory": {
			"files": array.concat(
				["Taskfile.yml", ".github/workflows/validate.yml", ".repo/outputs.toml"],
				[path | some path, _ in rulesets],
			),
			"texts": rulesets,
		}}),
		td.file("Taskfile.yml", taskfile),
		td.file(".github/workflows/validate.yml", validate),
	],
	[outputs(interfaces)],
)

conforming := repo([public], {".config/openapi/spectral.yaml": extends_link}, task_runs, run("task check"))

test_conforming_repository if {
	found := documents.findings with input as conforming
		with data.conventions.index as td.index
	count(found) == 0
}

test_nothing_without_an_openapi_interface if {
	given := repo([events], {}, {"version": "3"}, run("task lint"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	count(found) == 0
}

test_oas_02_no_ruleset if {
	given := repo([public], {}, task_runs, run("task check"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	messages(found, "OAS-02") == {concat(" ", [
		"the repository declares an openapi interface in .repo/outputs.toml but has no Spectral ruleset; add",
		".config/openapi/spectral.yaml with `extends: [../../.conventions/openapi.spectral.yaml]`, so its",
		"documents are linted with the conventions' rules",
	])}
	{f.path | some f in found} == {".config/openapi/spectral.yaml"}
}

test_oas_02_ruleset_without_the_conventions if {
	rulesets := {".config/openapi/spectral.yaml": "extends: [[spectral:oas, recommended]]\n"}
	given := repo([public], rulesets, task_runs, run("task check"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	messages(found, "OAS-02") == {concat(" ", [
		".config/openapi/spectral.yaml does not extend the conventions' OpenAPI ruleset; add",
		"../../.conventions/openapi.spectral.yaml to its extends, and turn off a rule there, with its",
		"reason, rather than leaving the ruleset out",
	])}
}

test_oas_02_a_ruleset_that_does_not_parse if {
	rulesets := {".config/openapi/spectral.yaml": "extends: [unclosed\n"}
	given := repo([public], rulesets, task_runs, run("task check"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	ids(found) == {"OAS-02"}
}

test_oas_02_a_ruleset_too_large_to_embed_is_not_judged if {
	given := array.concat(
		[td.file("/tmp/inventory.json", {"conventions_inventory": {"files": [
			"Taskfile.yml", ".github/workflows/validate.yml", ".repo/outputs.toml", ".config/openapi/spectral.yaml",
		]}})],
		[td.file("Taskfile.yml", task_runs), td.file(".github/workflows/validate.yml", run("task check")), outputs([public])],
	)
	found := documents.findings with input as given
		with data.conventions.index as td.index
	count(found) == 0
}

test_oas_02_accepts_a_pair_in_a_yml_ruleset if {
	rulesets := {".config/openapi/spectral.yml": "extends:\n  - [../../.conventions/openapi.spectral.yaml, all]\n"}
	given := repo([public], rulesets, task_runs, run("task check"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	count(found) == 0
}

test_oas_02_accepts_a_single_string if {
	rulesets := {".config/openapi/spectral.yaml": "extends: ../../.conventions/openapi.spectral.yaml\n"}
	given := repo([public], rulesets, task_runs, run("task check"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	count(found) == 0
}

test_oas_02_a_path_from_elsewhere_does_not_count if {
	rulesets := {".config/openapi/spectral.yaml": "extends: [.conventions/openapi.spectral.yaml]\n"}
	given := repo([public], rulesets, task_runs, run("task check"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	ids(found) == {"OAS-02"}
}

test_oas_03_validate_does_not_run_it if {
	given := repo([public], {".config/openapi/spectral.yaml": extends_link}, task_runs, run("task lint"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	messages(found, "OAS-03") == {concat(" ", [
		"the repository declares an openapi interface but no validate workflow runs `conventions openapi`;",
		"run it in a validate workflow, directly or through a task, so a document that breaks the ruleset",
		"cannot merge",
	])}
}

test_oas_03_a_step_runs_it_directly if {
	given := repo(
		[public], {".config/openapi/spectral.yaml": extends_link}, {"version": "3"},
		run("mise install --locked\nconventions openapi --ruleset .config/openapi/spectral.yaml"),
	)
	found := documents.findings with input as given
		with data.conventions.index as td.index
	count(found) == 0
}

test_oas_03_a_step_runs_the_launcher_by_path if {
	given := repo(
		[public], {".config/openapi/spectral.yaml": extends_link}, {"version": "3"},
		run("engineering-conventions/bin/conventions openapi"),
	)
	found := documents.findings with input as given
		with data.conventions.index as td.index
	count(found) == 0
}

test_oas_03_a_namespaced_task_reaches_it if {
	taskfile := {"version": "3", "tasks": {
		"check": {"deps": [":lint:openapi"]},
		"openapi": {"cmds": [{"cmd": "conventions openapi"}]},
	}}
	given := repo([public], {".config/openapi/spectral.yaml": extends_link}, taskfile, run("task --output prefixed check"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	count(found) == 0
}

test_oas_03_a_shorthand_task_runs_it if {
	taskfile := {"version": "3", "tasks": {"openapi": ["conventions openapi"]}}
	given := repo([public], {".config/openapi/spectral.yaml": extends_link}, taskfile, run("task openapi VERBOSE=1"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	count(found) == 0
}

test_oas_03_printing_the_command_does_not_run_it if {
	given := repo(
		[public], {".config/openapi/spectral.yaml": extends_link}, {"version": "3"},
		run("echo run conventions openapi locally"),
	)
	found := documents.findings with input as given
		with data.conventions.index as td.index
	ids(found) == {"OAS-03"}
}

test_oas_03_only_a_validate_workflow_counts if {
	given := [
		td.file("/tmp/inventory.json", {"conventions_inventory": {
			"files": [".github/workflows/monitor-openapi.yml", ".repo/outputs.toml", ".config/openapi/spectral.yaml"],
			"texts": {".config/openapi/spectral.yaml": extends_link},
		}}),
		td.file(".github/workflows/monitor-openapi.yml", run("conventions openapi")),
		outputs([public]),
	]
	found := documents.findings with input as given
		with data.conventions.index as td.index
	ids(found) == {"OAS-03"}
}

test_oas_04_a_link_in_the_repository if {
	given := [td.inventory([".conventions/openapi.spectral.yaml", "README.md"])]
	found := documents.findings with input as given
		with data.conventions.index as td.index
	messages(found, "OAS-04") == {concat(" ", [
		".conventions/openapi.spectral.yaml is part of the repository; add .conventions/ to .gitignore and",
		"remove it from the index, because `conventions openapi` writes it on every run to point at the",
		"release it runs",
	])}
}

test_oas_04_a_nested_directory_of_that_name_is_not_the_link if {
	given := [td.inventory(["api/.conventions/notes.md", ".conventions.md"])]
	found := documents.findings with input as given
		with data.conventions.index as td.index
	count(found) == 0
}
