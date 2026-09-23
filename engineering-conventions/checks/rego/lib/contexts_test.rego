package conventions.lib.contexts_test

import data.conventions.lib.contexts
import data.conventions.lib.testdata_test as td

caller := {
	"name": "Validate",
	"on": "pull_request",
	"jobs": {
		"image": {"name": "Validate / Image", "uses": "./.github/workflows/reusable-build.yml"},
		"matrix": {"name": "Validate / Test", "strategy": {"matrix": {"os": ["a"]}}},
		"expr": {"name": "Validate / ${{ inputs.x }}"},
		"bare": {"runs-on": "x"},
		"remote": {"name": "Validate / Remote", "uses": "org/repo/.github/workflows/x.yml@main"},
	},
}

docs := [
	td.file(".github/workflows/validate.yml", caller),
	td.file(".github/workflows/reusable-build.yml", td.reusable_build),
	td.file(".github/rulesets/main.json", td.ruleset(["Validate / Image / Build", "Nope"])),
	td.file(".github/rulesets/other.json", {"rules": [{
		"type": "required_status_checks",
		"parameters": {"required_status_checks": [{"context": 1}]},
	}]}),
]

test_emitted_contexts if {
	contexts.emitted_names == {"Validate / Image / Build", "bare"} with input as docs
	patterns := {entry.pattern | some entry in contexts.patterned} with input as docs
	patterns == {`^Validate / Test \(.+\)$`, `^Validate / .+$`}
	contexts.unverifiable == {`^Validate / Remote / .+$`} with input as docs
	contexts.matches_pattern("Validate / Test (a)") with input as docs
	not contexts.matches_pattern("Other / Test") with input as docs
	contexts.unverified("Validate / Remote / Anything") with input as docs
	not contexts.unverified("Validate / Image / Build") with input as docs
}

workflow_path(stem) := sprintf(".github/workflows/%s.yml", [stem])

# An entry point whose one job, named `name`, calls the workflow `callee`.
entry_calling(name, callee) := td.file(workflow_path("validate"), {"on": "push", "jobs": {"root": {
	"name": name,
	"uses": sprintf("./%s", [workflow_path(callee)]),
}}})

# A reusable workflow `stem` whose one job, named `name`, calls `callee`.
reusable_calling(stem, name, callee) := td.file(workflow_path(stem), {"on": "workflow_call", "jobs": {"call": {
	"name": name,
	"uses": sprintf("./%s", [workflow_path(callee)]),
}}})

reusable_leaf(stem, name) := td.file(workflow_path(stem), {"on": "workflow_call", "jobs": {"leaf": {"name": name}}})

test_nested_callers_resolve_recursively if {
	nesting := [
		entry_calling("A", "reusable-b"),
		reusable_calling("reusable-b", "B", "reusable-c"),
		reusable_leaf("reusable-c", "C"),
	]
	contexts.emitted_names == {"A / B / C"} with input as nesting
}

test_dual_trigger_callee_reports_bare_and_prefixed if {
	dual := {"on": ["workflow_call", "workflow_dispatch"], "jobs": {"build": {"name": "Build"}}}
	docs := [entry_calling("A", "build"), td.file(workflow_path("build"), dual)]
	contexts.emitted_names == {"A / Build", "Build"} with input as docs
}

test_calls_stop_at_ten_levels_and_at_cycles if {
	# validate -> reusable-l1 -> ... -> reusable-l8 calls reusable-l9.
	middle := [reusable_calling(sprintf("reusable-l%d", [n]), sprintf("L%d", [n]), sprintf("reusable-l%d", [n + 1])) |
		some n in numbers.range(1, 8)
	]
	deep := array.concat([entry_calling("R", "reusable-l1")], middle)
	nine := array.concat(deep, [reusable_leaf("reusable-l9", "Leaf")])
	contexts.emitted_names == {"R / L1 / L2 / L3 / L4 / L5 / L6 / L7 / L8 / Leaf"} with input as nine
	ten := array.concat(deep, [
		reusable_calling("reusable-l9", "L9", "reusable-l10"),
		reusable_leaf("reusable-l10", "Leaf"),
	])
	count(contexts.emitted_names) == 0 with input as ten
	loop := [entry_calling("A", "reusable-x"), reusable_calling("reusable-x", "X", "reusable-x")]
	count(contexts.emitted_names) == 0 with input as loop
}

test_only_github_actions_checks_are_required if {
	ruleset := {"rules": [{"type": "required_status_checks", "parameters": {"required_status_checks": [
		{"context": "Mine"},
		{"context": "Also mine", "integration_id": 15368},
		{"context": "codecov/patch", "integration_id": 254},
	]}}]}
	docs := [td.file(".github/rulesets/r.json", ruleset)]
	{entry.context | some entry in contexts.required} == {"Mine", "Also mine"} with input as docs
}

test_aggregates_by_id_or_name_in_any_case if {
	workflow := {"name": "CI", "jobs": {
		"required": {"runs-on": "x"},
		"gate": {"name": "validate / REQUIRED"},
		"ci_gate": {"name": "CI / Required"},
		"other": {"name": "Validate / Lint"},
	}}
	ids := {job_id | some [job_id, _] in contexts.aggregates(".github/workflows/validate.yml", workflow)}
	ids == {"required", "gate", "ci_gate"}
}

test_required_contexts if {
	contexts.required == {
		{"context": "Validate / Image / Build", "path": ".github/rulesets/main.json"},
		{"context": "Nope", "path": ".github/rulesets/main.json"},
	} with input as docs
}

test_required_workflows if {
	contexts.required_workflows == {".github/workflows/validate.yml"} with input as docs
}

test_aggregate_names if {
	contexts.aggregate_names(".github/workflows/validate.yml", {"name": "CI"}) == {"CI / Required", "Validate / Required"}
}
