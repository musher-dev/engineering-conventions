package conventions.checks.github_actions.workflow_files_test

import data.conventions.checks.github_actions.workflow_files
import data.conventions.lib.testdata_test as td

wf(name, contents) := td.file(concat("", [".github/workflows/", name]), contents)

entry(name) := {"name": name, "on": "push", "jobs": {}}

messages(found, id) := {f.message | some f in found; f.id == id}

test_conforming_workflows_have_no_findings if {
	docs := [
		wf("validate.yml", td.validate),
		wf("reusable-build.yml", td.reusable_build),
		wf("deploy-production-api.yml", entry("Deploy Production API")),
	]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	count(found) == 0
}

test_gha_01_grammar if {
	docs := [wf("Deploy_API.yml", entry("A")), wf("2-deploy.yml", entry("B"))]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	td.pairs(found) == {["GHA-01", ".github/workflows/Deploy_API.yml"], ["GHA-01", ".github/workflows/2-deploy.yml"]}
	some renamed in messages(found, "GHA-01")
	endswith(renamed, `rename it to "deploy-api.yml"`)
	some generic in messages(found, "GHA-01")
	endswith(generic, "rename it to [reusable-]<responsibility>[-<scope>].yml for the responsibility it owns")
}

test_gha_01_uppercase_extension if {
	docs := [wf("validate.YML", entry("Validate"))]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	td.pairs(found) == {["GHA-01", ".github/workflows/validate.YML"]}
	some message in messages(found, "GHA-01")
	endswith(message, `rename it to "validate.yml"`)
}

test_gha_01_suggestion_satisfies_every_filename_requirement if {
	# `Build.yml` normalises to `build.yml`, which GHA-02 would reject, and a
	# callable-only workflow gets the reusable- prefix it needs.
	docs := [wf("Build.yml", entry("x")), wf("Build_Image.yml", {"name": "x", "on": "workflow_call"})]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	messages(found, "GHA-01") == {
		concat(" ", [
			`filename "Build.yml" does not follow [reusable-]<responsibility>[-<scope>].yml, lowercase kebab-case`,
			"starting with a letter: rename it to [reusable-]<responsibility>[-<scope>].yml for the",
			"responsibility it owns",
		]),
		concat(" ", [
			`filename "Build_Image.yml" does not follow [reusable-]<responsibility>[-<scope>].yml, lowercase`,
			`kebab-case starting with a letter: rename it to "reusable-build-image.yml"`,
		]),
	}
}

test_gha_01_suggestion_never_collides if {
	docs := [wf("Validate.yml", entry("x")), wf("validate.yml", td.validate)]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	some message in messages(found, "GHA-01")
	not contains(message, `"validate.yml"`)
}

test_gha_02_first_token_is_a_responsibility if {
	bad := [wf("add-to-project.yml", entry("Add To Project"))]
	td.ids(workflow_files.findings) == {"GHA-02"} with input as bad with data.conventions.index as td.index
	good := [wf("repository-labels.yml", entry("Repository Labels"))]
	count(workflow_files.findings) == 0 with input as good with data.conventions.index as td.index
}

test_gha_02_leaves_banned_first_token_to_gha_05 if {
	docs := [wf("ci.yml", entry("CI"))]
	td.ids(workflow_files.findings) == {"GHA-05"} with input as docs with data.conventions.index as td.index
}

test_gha_03_prefix_without_workflow_call_only if {
	docs := [
		wf("reusable-build.yml", {"name": "Reusable Build", "on": ["workflow_call", "push"]}),
		wf("reusable-deploy.yml", {"name": "Reusable Deploy", "on": ["workflow_call", "workflow_dispatch"]}),
	]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	td.ids(found) == {"GHA-03"}
	messages(found, "GHA-03") == {
		concat(" ", [
			"the reusable- prefix promises the workflow is triggered only by workflow_call, but it is also",
			`triggered by "push"; drop the prefix and name the workflow for the responsibility it owns, or`,
			"make workflow_call its only trigger",
		]),
		concat(" ", [
			"the reusable- prefix promises the workflow is triggered only by workflow_call, but it is also",
			`triggered by "workflow_dispatch"; drop the prefix (rename to "deploy.yml"), or make`,
			"workflow_call its only trigger",
		]),
	}
}

test_dual_trigger_workflow_needs_no_prefix if {
	docs := [wf("deploy.yml", {"name": "Deploy", "on": ["workflow_call", "workflow_dispatch"]})]
	count(workflow_files.findings) == 0 with input as docs with data.conventions.index as td.index
}

test_gha_03_workflow_call_only_without_prefix if {
	docs := [
		wf("build.yml", {"name": "Build", "true": {"workflow_call": null}}),
		wf("frobnicate.yml", {"name": "Frobnicate", "on": "workflow_call"}),
	]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	prefix := "the workflow is triggered only by workflow_call, so it is never an entry point;"
	messages(found, "GHA-03") == {
		sprintf(`%s rename it to "reusable-build.yml"`, [prefix]),
		sprintf("%s add the reusable- prefix", [prefix]),
	}
}

test_gha_04_reusable_token if {
	bad := [wf("reusable-frobnicate.yml", {"name": "Reusable Frobnicate", "on": "workflow_call"})]
	td.ids(workflow_files.findings) == {"GHA-04"} with input as bad with data.conventions.index as td.index
	good := [wf("reusable-promote-image.yml", {"name": "Reusable Promote Image", "on": "workflow_call"})]
	count(workflow_files.findings) == 0 with input as good with data.conventions.index as td.index
}

test_gha_05_suggests_replacement_and_filename if {
	docs := [
		wf("lint-pr.yml", entry("x")),
		wf("ci.yml", entry("x")),
		wf("drift-telemetry.yml", entry("x")),
		wf("reusable-lint.yml", {"name": "x", "on": "workflow_call"}),
		wf("nightly-audit.yml", entry("x")),
	]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	suggestions := {regex.find_n(`\(e\.g\. "[^"]+"\)`, m, 1)[0] | some m in messages(found, "GHA-05")}
	suggestions == {
		`(e.g. "validate-pr.yml")`,
		`(e.g. "validate.yml")`,
		`(e.g. "monitor-telemetry.yml")`,
		`(e.g. "reusable-validate.yml")`,
		`(e.g. "audit.yml")`,
	}
	concat(" ", [
		`filename token "lint" names a trigger, schedule, tool or synonym rather than a responsibility;`,
		`replace "lint" with "validate" (e.g. "validate-pr.yml")`,
	]) in messages(found, "GHA-05")
}

test_gha_05_synonyms_only_in_the_responsibility_slot if {
	docs := [wf("release-pr.yml", entry("Release PR")), wf("deploy-pr.yml", entry("Deploy PR"))]
	count(workflow_files.findings) == 0 with input as docs with data.conventions.index as td.index
}

test_gha_05_schedule_tokens_anywhere_one_finding_per_file if {
	docs := [wf("lint-nightly-scheduled.yml", entry("x"))]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	messages(found, "GHA-05") == {concat(" ", [
		`filename tokens "lint", "nightly", "scheduled" name a trigger, schedule, tool or synonym rather`,
		`than a responsibility; replace "lint" with "validate"; drop "nightly": a schedule is not a`,
		"responsibility, so name what it serves (audit, monitor or maintain); drop \"scheduled\": a",
		"schedule is not a responsibility, so name what it serves (audit, monitor or maintain)",
		`(e.g. "validate.yml")`,
	])}
}

test_gha_05_no_filename_for_a_choice if {
	docs := [wf("mutants-scheduled.yml", entry("M")), wf("scheduled.yml", entry("S"))]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	every message in messages(found, "GHA-05") {
		endswith(message, "name what it serves (audit, monitor or maintain)")
	}
	td.pairs(found) == {
		["GHA-02", ".github/workflows/mutants-scheduled.yml"],
		["GHA-05", ".github/workflows/mutants-scheduled.yml"],
		["GHA-05", ".github/workflows/scheduled.yml"],
	}
}

test_gha_05_no_suggestion_on_collision if {
	docs := [wf("ci.yml", entry("x")), wf("validate.yaml", entry("Validate"))]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	messages(found, "GHA-05") == {concat(" ", [
		`filename token "ci" names a trigger, schedule, tool or synonym rather than a responsibility;`,
		`replace "ci" with "validate"`,
	])}
}

test_gha_06_flags_minority_extension if {
	docs := [wf("validate.yml", td.validate), wf("deploy.yml", entry("Deploy")), wf("release.yaml", entry("Release"))]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	td.pairs(found) == {["GHA-06", ".github/workflows/release.yaml"]}
}

test_gha_06_tie_keeps_yml if {
	docs := [wf("deploy.yml", entry("Deploy")), wf("release.yaml", entry("Release"))]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	td.pairs(found) == {["GHA-06", ".github/workflows/release.yaml"]}
}

test_gha_06_majority_yaml if {
	docs := [wf("deploy.yml", entry("Deploy")), wf("release.yaml", entry("Release")), wf("audit.yaml", entry("Audit"))]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	td.pairs(found) == {["GHA-06", ".github/workflows/deploy.yml"]}
	some message in messages(found, "GHA-06")
	contains(message, `rename this file to "deploy.yaml"`)
}

test_gha_07_display_name if {
	docs := [wf("validate-pull-request.yml", entry("Validate PR")), wf("deploy-api.yml", {"on": "push"})]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	messages(found, "GHA-07") == {
		`name "Validate PR" should be "Validate Pull Request": a workflow's name is its filename stem in Title Case`,
		`the workflow has no name; add name: "Deploy API", its filename stem in Title Case`,
	}
}

test_gha_07_waits_for_the_rename if {
	docs := [
		wf("ci.yml", entry("CI")),
		wf("CI.yml", entry("CI")),
		wf("add-to-project.yml", entry("Add to Project")),
		wf("reusable-frobnicate.yml", {"name": "x", "on": "workflow_call"}),
		wf("deploy.yml", {"name": "x", "on": "workflow_call"}),
	]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	not "GHA-07" in td.ids(found)
}

test_gha_08_duplicate_names if {
	docs := [wf("deploy.yml", entry("Deploy")), wf("deploy-api.yml", entry("Deploy"))]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	pairs := td.pairs(found)
	["GHA-08", ".github/workflows/deploy.yml"] in pairs
	["GHA-08", ".github/workflows/deploy-api.yml"] in pairs
}

test_gha_08_suggests_no_name_while_the_filename_changes if {
	docs := [wf("ci.yml", entry("Deploy")), wf("deploy.yml", entry("Deploy"))]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	messages(found, "GHA-08") == {
		`name "Deploy" is also used by ".github/workflows/deploy.yml"; give each workflow its own name`,
		concat(" ", [
			`name "Deploy" is also used by ".github/workflows/ci.yml"; give each workflow the Title-Cased`,
			`stem of its own filename ("Deploy")`,
		]),
	}
}

test_gha_08_unique_names if {
	docs := [wf("deploy.yml", entry("Deploy")), wf("audit.yml", entry("Audit"))]
	count(workflow_files.findings) == 0 with input as docs with data.conventions.index as td.index
}

test_gha_09_workflow_run_targets if {
	follower := {"name": "Deploy", "on": {"workflow_run": {"workflows": ["Validate", "validate.yml", "Nope"]}}}
	docs := [wf("validate.yml", td.validate), wf("deploy.yml", follower)]
	found := workflow_files.findings with input as docs with data.conventions.index as td.index
	prefix := "which is not the name of any workflow in this repository;"
	messages(found, "GHA-09") == {
		sprintf(`workflow_run names "validate.yml", %s use its name "Validate"`, [prefix]),
		sprintf(`workflow_run names "Nope", %s use one of "Deploy", "Validate"`, [prefix]),
	}
}

test_gha_09_string_form_resolves if {
	follower := {"name": "Deploy", "on": {"workflow_run": {"workflows": "Validate"}}}
	docs := [wf("validate.yml", td.validate), wf("deploy.yml", follower)]
	count(workflow_files.findings) == 0 with input as docs with data.conventions.index as td.index
}
