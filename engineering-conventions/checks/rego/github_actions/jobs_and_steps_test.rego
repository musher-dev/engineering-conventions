package conventions.checks.github_actions.jobs_and_steps_test

import data.conventions.checks.github_actions.jobs_and_steps
import data.conventions.lib.testdata_test as td

wf(name, contents) := td.file(concat("", [".github/workflows/", name]), contents)

messages(found, id) := {f.message | some f in found; f.id == id}

rules(contexts) := td.file(".github/rulesets/main-branch.json", td.ruleset(contexts))

reads_twice(job_id, name, suggestion) := concat(" ", [
	sprintf("job %q is named %q, but GitHub already shows the workflow name before the job's, so it", [job_id, name]),
	sprintf("reads twice; rename it to %q (only a required-check job leads with its workflow's name)", [suggestion]),
])

unprefixed_required(job_id, name, suggestion) := concat(" ", [
	sprintf("job %q emits the required context %q, and a ruleset matches the job name alone, so a", [job_id, name]),
	"required-check job leads with its workflow's name to stay unique across the repository;",
	sprintf("rename it to %q and update the ruleset", [suggestion]),
])

test_conforming_repository_has_no_findings if {
	docs := [
		wf("validate.yml", td.validate),
		wf("reusable-build.yml", td.reusable_build),
		rules(["Validate / Required"]),
	]
	count(jobs_and_steps.findings) == 0 with input as docs with data.conventions.index as td.index
}

test_gha_10_job_and_step_ids if {
	workflow := {"name": "Validate", "on": "push", "jobs": {"build-image": {
		"name": "Validate / Image",
		"steps": [{"id": "pushTag", "name": "Push", "uses": "./x"}],
	}}}
	action := {"runs": {"steps": [{"id": "attempt-1", "name": "Try", "run": "x"}]}}
	docs := [wf("validate.yml", workflow), td.file(".github/actions/setup-x/action.yml", action)]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	messages(found, "GHA-10") == {
		`job id "build-image" is not snake_case; rename it to "build_image" and update every needs: that names it`,
		concat(" ", [
			`step id "pushTag" in job "build-image" is not snake_case;`,
			`rename it to "push_tag" and update every steps.pushTag reference`,
		]),
		`step id "attempt-1" is not snake_case; rename it to "attempt_1" and update every steps.attempt-1 reference`,
	}
}

test_gha_11_job_name if {
	entry := {"name": "Validate", "on": "push", "jobs": {"unit_tests": {"runs-on": "x"}, "required": {"runs-on": "x"}}}
	called := {"name": "Reusable Build", "on": "workflow_call", "jobs": {"build_image": {"name": " "}}}
	docs := [wf("validate.yml", entry), wf("reusable-build.yml", called)]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	prefix := "has no name, so its check reports as the bare id; add name:"
	messages(found, "GHA-11") == {
		sprintf(`job "unit_tests" %s "Unit Tests"`, [prefix]),
		sprintf(`job "required" %s "Validate / Required"`, [prefix]),
		sprintf(`job "build_image" %s "Build Image"`, [prefix]),
	}
}

test_gha_11_names_unique_within_a_workflow if {
	workflow := {"name": "Validate", "on": "push", "jobs": {
		"docs": {"name": "Docs / Quality"},
		"apps": {
			"name": "${{ matrix.app.name }} / Quality",
			"strategy": {"matrix": {"app": [{"name": "Docs"}, {"name": "API"}]}},
		},
		"lint": {"name": "Lint ${{ matrix.tool }}", "strategy": {"matrix": {"tool": ["a", "b"]}}},
		"lint_a": {"name": "Lint a"},
		"test": {"name": "Test", "strategy": {"matrix": {"os": ["linux", "macos"], "include": [{"os": "windows"}]}}},
		"one": {"name": "One", "strategy": {"matrix": {"os": ["linux"]}}},
		"legs": {"name": "Legs", "strategy": {"matrix": {"include": [{"a": 1}, {"a": 2}]}}},
		"expr": {"name": "E ${{ inputs.x }}", "strategy": {"matrix": "${{ fromJSON(inputs.m) }}"}},
		"other": {"name": "Other"},
		"other_again": {"name": "Other"},
	}}
	found := jobs_and_steps.findings with input as [wf("validate.yml", workflow)] with data.conventions.index as td.index
	duplicate := "so a failure cannot say which one it was; give each job its own name"
	messages(found, "GHA-11") == {
		sprintf(`jobs "apps", "docs" all report as "Docs / Quality", %s`, [duplicate]),
		sprintf(`jobs "lint", "lint_a" all report as "Lint a", %s`, [duplicate]),
		sprintf(`jobs "other", "other_again" all report as "Other", %s`, [duplicate]),
	}
}

test_gha_12_entry_point_job_names if {
	workflow := {"name": "Validate", "on": "push", "jobs": {
		"a": {"name": "Validate / Repository / Lint"},
		"b": {"name": "Checks / Types"},
		"c": {"name": "Validate / "},
		"d": {"name": "Docs / Links"},
		"e": {"name": "Validate /"},
	}}
	found := jobs_and_steps.findings with input as [wf("validate.yml", workflow)] with data.conventions.index as td.index
	messages(found, "GHA-12") == {
		reads_twice("a", "Validate / Repository / Lint", "Repository / Lint"),
		`job "c" is named "Validate / ", which has an empty subject; name the result it reports, e.g. "C"`,
		`job "e" is named "Validate /", which has an empty subject; name the result it reports, e.g. "E"`,
	}
}

test_gha_12_required_check_jobs_lead_with_the_workflow_name if {
	workflow := {"name": "Validate", "on": "push", "jobs": {
		"title": {"name": "Validate PR Title"},
		"required": {"name": "Validate / Required", "if": "always()", "needs": ["title"]},
	}}
	single := {"name": "Deploy", "on": "push", "jobs": {"ship": {"name": "Ship"}}}
	docs := [
		wf("validate.yml", workflow),
		wf("deploy.yml", single),
		rules(["Validate / Required", "Ship", "Validate PR Title"]),
	]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	messages(found, "GHA-12") == {unprefixed_required("ship", "Ship", "Deploy / Ship")}
}

test_gha_12_unrequired_aggregate_is_allowed_only_without_rulesets if {
	docs := [wf("validate.yml", td.validate)]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	not "GHA-12" in td.ids(found)
	with_rules := array.concat(docs, [rules(["Other"])])
	found_with_rules := jobs_and_steps.findings with input as with_rules with data.conventions.index as td.index
	reads_twice("required", "Validate / Required", "Required") in messages(found_with_rules, "GHA-12")
}

test_gha_12_repeats_either_workflow_name if {
	workflow := {"name": "CI", "on": "push", "jobs": {"a": {"name": "CI / Lint"}, "b": {"name": "Validate / Types"}}}
	found := jobs_and_steps.findings with input as [wf("validate.yml", workflow)] with data.conventions.index as td.index
	messages(found, "GHA-12") == {reads_twice("a", "CI / Lint", "Lint"), reads_twice("b", "Validate / Types", "Types")}
}

test_gha_13_called_job_names_are_bare if {
	called := {
		"name": "Reusable Build",
		"on": ["workflow_call", "workflow_dispatch"],
		"jobs": {"build": {"name": "Build / Image"}},
	}
	docs := [wf("reusable-build.yml", called)]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	some message in messages(found, "GHA-13")
	startswith(message, `job "build" is named "Build / Image" in a workflow callable through workflow_call;`)
	endswith(message, `so use a bare name such as "Image"`)
}

test_gha_11_12_dual_trigger_jobs_are_bare if {
	dual := {"name": "Deploy", "on": ["workflow_call", "workflow_dispatch"], "jobs": {
		"ship_it": {"runs-on": "x"},
		"api": {"name": "API"},
	}}
	found := jobs_and_steps.findings with input as [wf("deploy.yml", dual)] with data.conventions.index as td.index
	messages(found, "GHA-11") == {`job "ship_it" has no name, so its check reports as the bare id; add name: "Ship It"`}
	not "GHA-12" in td.ids(found)
}

test_gha_11_untriggered_workflow_suggests_a_bare_name if {
	workflow := {"name": "Validate", "jobs": {"lint": {"runs-on": "x"}}}
	found := jobs_and_steps.findings with input as [wf("validate.yml", workflow)] with data.conventions.index as td.index
	messages(found, "GHA-11") == {`job "lint" has no name, so its check reports as the bare id; add name: "Lint"`}
}

test_gha_12_strips_a_repeated_workflow_name_from_a_suggestion if {
	workflow := {"name": "Validate", "on": "push", "jobs": {
		"a": {"name": "Validate PR Title"},
		"required": {"name": "Validate / Required", "if": "always()", "needs": ["a"]},
	}}
	pull_request := {"name": "Deploy", "on": "push", "jobs": {"t": {"name": "Deploy Title"}}}
	docs := [wf("validate.yml", workflow), wf("deploy.yml", pull_request), rules(["Validate / Required", "Deploy Title"])]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	messages(found, "GHA-12") == {unprefixed_required("t", "Deploy Title", "Deploy / Title")}
}

test_gha_11_12_while_the_filename_changes if {
	workflow := {"name": "CI", "on": "push", "jobs": {
		"lint": {"name": "CI / Lint"},
		"types": {"name": "Validate / Types"},
		"unit": {"runs-on": "x"},
		"required": {"runs-on": "x"},
	}}
	single := {"name": "CI Deploy", "on": "push", "jobs": {"ship": {"name": "Ship"}}}
	docs := [wf("ci.yml", workflow), wf("ci-deploy.yml", single), rules(["Ship"])]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	messages(found, "GHA-12") == {reads_twice("lint", "CI / Lint", "Lint")}
	messages(found, "GHA-11") == {
		`job "unit" has no name, so its check reports as the bare id; add name: "Unit"`,
		`job "required" has no name, so its check reports as the bare id; add name: "Required"`,
	}
}

test_gha_14_aggregate_needs_always_and_every_job if {
	workflow := {"name": "Validate", "on": "push", "jobs": {
		"lint": {"name": "Validate / Lint"},
		"types": {"name": "Validate / Types"},
		"required": {"name": "Validate / Required", "needs": "lint"},
	}}
	found := jobs_and_steps.findings with input as [wf("validate.yml", workflow)] with data.conventions.index as td.index
	count(messages(found, "GHA-14")) == 2
	some always in messages(found, "GHA-14")
	startswith(always, `aggregate job "required" has no if: always() (or !cancelled())`)
	some needs in messages(found, "GHA-14")
	startswith(needs, `aggregate job "required" does not need "types";`)
}

test_gha_14_recognises_aggregates_by_id_and_any_case if {
	workflow := {"name": "CI", "on": "push", "jobs": {
		"lint": {"name": "CI / Lint"},
		"gate": {"name": "ci / required", "needs": ["lint", "all", "required"]},
		"all": {"name": "Everything", "needs": ["lint", "gate"]},
		"required": {"runs-on": "x", "if": "${{ !cancelled() }}", "needs": ["lint", "gate", "all"]},
	}}
	found := jobs_and_steps.findings with input as [wf("ci.yml", workflow)] with data.conventions.index as td.index
	messages(found, "GHA-14") == {concat(" ", [
		`aggregate job "gate" has no if: always() (or !cancelled()), so it is skipped when a job it needs`,
		"fails and the required check never reports; add if: always() and fail on any result but success",
	])}
}

test_gha_14_conforming_aggregate if {
	docs := [wf("validate.yml", td.validate)]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	not "GHA-14" in td.ids(found)
}

test_gha_15_required_context_is_emitted if {
	caller := {
		"name": "Validate",
		"on": "pull_request",
		"jobs": {"image": {"name": "Validate / Image", "uses": "./.github/workflows/reusable-build.yml"}},
	}
	docs := [
		wf("validate.yml", caller),
		wf("reusable-build.yml", td.reusable_build),
		rules(["Validate / Image / Build", "validate / image / build", "Validate / Gone"]),
	]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	count(messages(found, "GHA-15")) == 2
	some case_variant in messages(found, "GHA-15")
	endswith(case_variant, `the job is named "Validate / Image / Build"; match the case exactly`)
	some missing in messages(found, "GHA-15")
	startswith(missing, `requires context "Validate / Gone", which no job emits`)
}

test_gha_15_skips_remote_callers_and_other_apps if {
	caller := {"name": "Validate", "on": "pull_request", "jobs": {
		"remote": {"name": "Validate / Remote", "uses": "org/repo/.github/workflows/x.yml@0123"},
	}}
	ruleset := {"rules": [{"type": "required_status_checks", "parameters": {"required_status_checks": [
		{"context": "Validate / Remote / Anything"},
		{"context": "codecov/patch", "integration_id": 254},
		{"context": "Validate / Missing", "integration_id": 15368},
	]}}]}
	docs := [wf("validate.yml", caller), td.file(".github/rulesets/main-branch.json", ruleset)]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	{m | some m in messages(found, "GHA-15")} == {concat(" ", [
		`requires context "Validate / Missing", which no job emits, so every pull request waits on it forever;`,
		"rename the job to this context or require the context an existing job emits (names built from ${{ }}",
		"or a matrix never match)",
	])}
}

test_gha_15_leaves_matrix_contexts_to_gha_16 if {
	workflow := {"name": "Validate", "on": "push", "jobs": {
		"test": {"name": "Validate / Test", "strategy": {"matrix": {"os": ["a", "b"]}}},
		"expr": {"name": "Validate / ${{ inputs.x }}"},
	}}
	docs := [wf("validate.yml", workflow), rules(["Validate / Test (a)", "Validate / Nope", "Other / x"])]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	{m | some m in messages(found, "GHA-15"); contains(m, "Other / x")} == messages(found, "GHA-15")
	messages(found, "GHA-16") == {concat(" ", [
		`requires "Validate / Nope", "Validate / Test (a)" from individual jobs of ".github/workflows/validate.yml"`,
		`("Validate / Nope", "Validate / Test (a)" expanded from a matrix or expression, so it changes whenever`,
		"they do); a workflow is required only through its aggregate, so add an aggregate job named",
		`"Validate / Required" that runs if: always() and needs every other job, and require that instead`,
	])}
}

test_gha_16_multi_job_workflow_requires_its_aggregate if {
	workflow := json.patch(td.validate, [{"op": "add", "path": "/jobs/types", "value": {"name": "Types"}}])
	docs := [wf("validate.yml", workflow), rules(["Lint", "Types"])]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	messages(found, "GHA-16") == {concat(" ", [
		`requires "Lint", "Types" from individual jobs of ".github/workflows/validate.yml";`,
		`a workflow is required only through its aggregate, so require its aggregate "Validate / Required" instead`,
	])}
	not "GHA-12" in td.ids(found)
}

test_gha_15_a_context_two_jobs_emit if {
	other := {"name": "Deploy", "on": "push", "jobs": {"lint": {"name": "Lint"}}}
	docs := [wf("validate.yml", td.validate), wf("deploy.yml", other), rules(["Lint"])]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	messages(found, "GHA-15") == {concat(" ", [
		`requires context "Lint", which 2 jobs emit (job "lint" in .github/workflows/deploy.yml, job "lint" in`,
		".github/workflows/validate.yml), so the ruleset cannot tell them apart; give each job its own name",
	])}
}

test_gha_16_without_an_aggregate if {
	workflow := {"name": "Validate", "on": "push", "jobs": {"a": {"name": "Validate / A"}, "b": {"name": "Validate / B"}}}
	docs := [wf("validate.yml", workflow), rules(["Validate / A"])]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	some message in messages(found, "GHA-16")
	contains(message, `add an aggregate job named "Validate / Required" that runs if: always()`)
}

test_gha_16_names_no_aggregate_while_the_filename_changes if {
	workflow := {"name": "CI", "on": "push", "jobs": {"a": {"name": "A"}, "b": {"name": "B"}}}
	docs := [wf("ci.yml", workflow), rules(["A", "B"])]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	count(messages(found, "GHA-16")) == 1
	some message in messages(found, "GHA-16")
	not contains(message, "CI / Required")
	contains(message, "rename the workflow file first")
}

test_gha_16_case_variant_aggregate_is_the_aggregate if {
	workflow := {"name": "CI", "on": "push", "jobs": {
		"a": {"name": "CI / A"},
		"required": {"name": "CI / required", "if": "always()", "needs": ["a"]},
	}}
	docs := [wf("ci.yml", workflow), rules(["CI / required"])]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	not "GHA-16" in td.ids(found)
	not "GHA-15" in td.ids(found)
}

test_gha_16_single_job_workflow_is_fine if {
	workflow := {
		"name": "Validate Pull Request",
		"on": "pull_request",
		"jobs": {"title": {"name": "Validate Pull Request / Title"}},
	}
	docs := [wf("validate-pull-request.yml", workflow), rules(["Validate Pull Request / Title"])]
	count(jobs_and_steps.findings) == 0 with input as docs with data.conventions.index as td.index
}

test_gha_17_run_steps_are_named if {
	workflow := {"name": "Validate", "on": "push", "jobs": {"lint": {"name": "Validate / Lint", "steps": [
		{"run": "a"},
		{"name": "", "run": "b"},
		{"uses": "./x"},
		{"name": "Lint", "run": "c"},
	]}}}
	action := {"runs": {"steps": [{"run": "x"}]}}
	docs := [wf("validate.yml", workflow), td.file(".github/actions/setup-x/action.yml", action)]
	found := jobs_and_steps.findings with input as docs with data.conventions.index as td.index
	rest := "runs a command but has no name; add name: with an imperative phrase saying what it does"
	messages(found, "GHA-17") == {
		sprintf(`step 1 of job "lint" %s`, [rest]),
		sprintf(`step 2 of job "lint" %s`, [rest]),
		sprintf(`step 1 %s`, [rest]),
	}
}
