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

owasp := "https://unpkg.com/@stoplight/spectral-owasp-ruleset@2.0.1/dist/ruleset.mjs"

extends_link := concat("", ["extends:\n  - spectral:oas\n  - ", owasp, "\n"])
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
		".config/openapi/spectral.yaml with `extends: [spectral:oas,",
		"https://unpkg.com/@stoplight/spectral-owasp-ruleset@2.0.1/dist/ruleset.mjs]`, so its documents are",
		"linted with Spectral's OpenAPI and OWASP rules",
	])}
	{f.path | some f in found} == {".config/openapi/spectral.yaml"}
}

test_oas_02_ruleset_without_owasp if {
	rulesets := {".config/openapi/spectral.yaml": "extends: [[spectral:oas, recommended]]\n"}
	given := repo([public], rulesets, task_runs, run("task check"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	messages(found, "OAS-02") == {concat(" ", [
		".config/openapi/spectral.yaml does not extend the OWASP API security ruleset; extend",
		"https://unpkg.com/@stoplight/spectral-owasp-ruleset@2.0.1/dist/ruleset.mjs, which names one exact",
		"release",
	])}
}

test_oas_02_ruleset_without_spectral_oas if {
	rulesets := {".config/openapi/spectral.yaml": concat("", ["extends: [", owasp, "]\n"])}
	given := repo([public], rulesets, task_runs, run("task check"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	messages(found, "OAS-02") == {concat(" ", [
		".config/openapi/spectral.yaml does not extend spectral:oas; add it to extends, and turn off a rule",
		"there, with its reason, rather than leaving the ruleset out",
	])}
}

test_oas_02_spectral_oas_turned_off if {
	rulesets := {".config/openapi/spectral.yaml": concat("", ["extends: [[spectral:oas, \"off\"], ", owasp, "]\n"])}
	given := repo([public], rulesets, task_runs, run("task check"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	count(messages(found, "OAS-02")) == 1
}

test_oas_02_floating_owasp_versions if {
	every ref in [
		"https://unpkg.com/@stoplight/spectral-owasp-ruleset/dist/ruleset.mjs",
		"https://unpkg.com/@stoplight/spectral-owasp-ruleset@latest/dist/ruleset.mjs",
		"https://unpkg.com/@stoplight/spectral-owasp-ruleset@2/dist/ruleset.mjs",
		"https://unpkg.com/@stoplight/spectral-owasp-ruleset@^2.0.1/dist/ruleset.mjs",
		"@stoplight/spectral-owasp-ruleset",
	] {
		rulesets := {".config/openapi/spectral.yaml": concat("", ["extends: [spectral:oas, \"", ref, "\"]\n"])}
		found := documents.findings with input as repo([public], rulesets, task_runs, run("task check"))
			with data.conventions.index as td.index
		messages(found, "OAS-02") == {sprintf(
			concat(" ", [
				".config/openapi/spectral.yaml extends the OWASP API security ruleset as %s, which names no exact",
				"release; extend https://unpkg.com/@stoplight/spectral-owasp-ruleset@2.0.1/dist/ruleset.mjs, which",
				"names one exact release",
			]),
			[ref],
		)}
	}
}

test_oas_02_a_ruleset_that_does_not_parse if {
	rulesets := {".config/openapi/spectral.yaml": "extends: [unclosed\n"}
	given := repo([public], rulesets, task_runs, run("task check"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	count(messages(found, "OAS-02")) == 2
}

test_oas_02_a_ruleset_that_is_not_a_mapping if {
	rulesets := {".config/openapi/spectral.yaml": "- spectral:oas\n"}
	given := repo([public], rulesets, task_runs, run("task check"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	count(messages(found, "OAS-02")) == 2
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

test_oas_02_accepts_pairs_in_a_yml_ruleset if {
	rulesets := {".config/openapi/spectral.yml": concat("", [
		"extends:\n  - [spectral:oas, all]\n  - [", owasp, ", recommended]\n",
	])}
	given := repo([public], rulesets, task_runs, run("task check"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	count(found) == 0
}

test_oas_02_a_single_string_misses_the_other if {
	rulesets := {".config/openapi/spectral.yaml": "extends: spectral:oas\n"}
	given := repo([public], rulesets, task_runs, run("task check"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	count(messages(found, "OAS-02")) == 1
}

test_oas_03_validate_does_not_run_it if {
	given := repo([public], {".config/openapi/spectral.yaml": extends_link}, task_runs, run("task lint"))
	found := documents.findings with input as given
		with data.conventions.index as td.index
	messages(found, "OAS-03") == {concat(" ", [
		"the repository declares an openapi interface but no validate workflow lints it; run",
		"`conventions openapi`, or `spectral lint --ruleset .config/openapi/spectral.yaml`, in a validate",
		"workflow, directly or through a task, so a document that breaks the ruleset cannot merge",
	])}
}

test_oas_03_a_spectral_step_with_the_ruleset if {
	every command in [
		"spectral lint --ruleset .config/openapi/spectral.yaml api/public.json",
		"mise exec -- spectral lint api/public.json -r ./.config/openapi/spectral.yml",
		"npx spectral lint --ruleset=.config/openapi/spectral.yaml api/public.json",
	] {
		given := repo([public], {".config/openapi/spectral.yaml": extends_link}, {"version": "3"}, run(command))
		found := documents.findings with input as given
			with data.conventions.index as td.index
		count(found) == 0
	}
}

test_oas_03_a_spectral_step_without_the_ruleset if {
	every command in [
		"spectral lint api/public.json",
		"spectral lint --ruleset other.yaml api/public.json",
		"spectral lint api/public.json; echo --ruleset .config/openapi/spectral.yaml",
	] {
		given := repo([public], {".config/openapi/spectral.yaml": extends_link}, {"version": "3"}, run(command))
		found := documents.findings with input as given
			with data.conventions.index as td.index
		ids(found) == {"OAS-03"}
	}
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
