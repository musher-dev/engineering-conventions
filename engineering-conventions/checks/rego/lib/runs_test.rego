package conventions.lib.runs_test

import data.conventions.lib.runs
import data.conventions.lib.testdata_test as td

validate := ".github/workflows/validate.yml"

patterns := [`(^|\s)conventions\s+openapi(\s|$)`]

workflow(path, line) := td.file(path, {
	"on": "pull_request",
	"jobs": {"check": {"runs-on": "ubuntu-24.04", "steps": [{"name": "Check", "run": line}]}},
})

taskfile(tasks) := td.file("Taskfile.yml", {"version": "3", "tasks": tasks})

tasks := {
	"check": {"cmds": [{"task": "lint"}]},
	"lint": {"deps": ["openapi"]},
	"openapi": {"cmds": ["conventions openapi --ruleset .config/openapi/spectral.yaml"]},
	"unrelated": "echo hello",
}

test_a_validate_workflow_runs_the_command_directly if {
	docs := [workflow(validate, "conventions openapi")]
	runs.validated(patterns) with input as docs with data.conventions.index as td.index
}

test_a_validate_workflow_runs_the_command_through_tasks if {
	through_calls := [workflow(validate, "task check"), taskfile(tasks)]
	runs.validated(patterns) with input as through_calls with data.conventions.index as td.index
	with_flags := [workflow(validate, "task --yes openapi"), taskfile(tasks)]
	runs.validated(patterns) with input as with_flags with data.conventions.index as td.index
}

test_only_a_validate_workflow_counts if {
	docs := [workflow(".github/workflows/publish.yml", "conventions openapi")]
	not runs.validated(patterns) with input as docs with data.conventions.index as td.index
}

test_a_task_that_never_runs_the_command_does_not_count if {
	docs := [workflow(validate, "task unrelated"), taskfile(tasks)]
	not runs.validated(patterns) with input as docs with data.conventions.index as td.index
}

test_task_arguments_skip_flags_and_variables if {
	runs.task_arguments("task --yes lint FOO=1 check && echo done") == {"lint", "check"}
	runs.task_arguments("echo task") == set()
}

test_called_as_matches_a_name_or_a_namespace if {
	runs.called_as(":lint", "lint")
	runs.called_as("docs:lint", "lint")
	not runs.called_as("lint-docs", "lint")
}

test_commands_of_every_task_shape if {
	runs.commands("echo one") == ["echo one"]
	runs.commands(["echo one", {"cmd": "echo two"}, {"task": "other"}]) == ["echo one", "echo two"]
	runs.commands({"cmds": ["echo one"]}) == ["echo one"]
	runs.commands({"desc": "nothing"}) == []
}

test_reaching_follows_calls_and_deps if {
	reached := runs.reaching(patterns) with input as [taskfile(tasks)]
	reached == {"openapi", "lint", "check"}
}
