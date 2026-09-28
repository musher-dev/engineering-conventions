package conventions.lib.steps_test

import data.conventions.lib.steps
import data.conventions.lib.testdata_test as td

test_entries_cover_workflows_and_actions if {
	workflow := {"jobs": {"build": {"steps": [{"id": "make", "run": "make"}]}}}
	action := {"runs": {"steps": [{"name": "Install", "run": "npm ci"}]}}
	docs := [
		td.file(".github/workflows/validate.yml", workflow),
		td.file(".github/actions/setup-x/action.yml", action),
	]
	found := {[entry.path, entry.where, entry.label] | some entry in steps.entries} with input as docs
	found == {
		[".github/workflows/validate.yml", `job "build"`, `step "make"`],
		[".github/actions/setup-x/action.yml", "the action", `step "Install"`],
	}
}

test_action_strips_the_version if {
	steps.action({"uses": "dorny/paths-filter@abc"}) == "dorny/paths-filter"
	steps.action({"uses": "./.github/actions/setup-tools"}) == "./.github/actions/setup-tools"
	not steps.action({"run": "x"})
}

test_inputs_default_to_empty if {
	steps.inputs({"uses": "x"}) == {}
	steps.inputs({"uses": "x", "with": {"a": 1}}) == {"a": 1}
}

test_code_drops_comments_and_joins_continuations if {
	step := {"run": "# say why || true\necho a \\\n  --flag\n\n  # indented comment\necho b"}
	steps.lines(step) == ["echo a --flag", "echo b"]
	not steps.code({"uses": "x"})
}

test_literal if {
	steps.literal("ubuntu-24.04")
	steps.literal(15)
	steps.literal(true)
	not steps.literal("${{ matrix.os }}")
	not steps.literal({"a": 1})
}
