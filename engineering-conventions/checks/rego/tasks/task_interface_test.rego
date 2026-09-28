package conventions.checks.tasks.task_interface_test

import data.conventions.checks.tasks.task_interface as interface
import data.conventions.lib.testdata_test as td

messages(found, id) := {f.message | some f in found; f.id == id}

task(desc) := {"desc": desc}

full := {
	"version": "3",
	"includes": {
		"lint": {"taskfile": "taskfiles/lint.Taskfile.yml", "flatten": true},
		"app": "./app",
	},
	"tasks": {
		"setup": task("Setup."),
		"verify": {"desc": "Check.", "aliases": ["check"]},
		"build": task("Build."),
		"dev": {"desc": "Run.", "cmds": [{"task": "app:serve"}]},
	},
}

repository(root) := [
	td.inventory(["Taskfile.yml", "taskfiles/lint.Taskfile.yml", "app/Taskfile.yml"]),
	td.file("Taskfile.yml", root),
	td.file("taskfiles/lint.Taskfile.yml", {"version": "3", "tasks": {"lint": task("Lint.")}}),
	td.file("app/Taskfile.yml", {"version": "3", "tasks": {"serve": task("Serve.")}}),
]

test_every_verb_defined_through_aliases_and_includes if {
	with_test := object.union(full, {"tasks": object.union(full.tasks, {"test": task("Test.")})})
	count(interface.findings) == 0 with input as repository(with_test)
}

test_task_11_missing_test if {
	found := interface.findings with input as repository(full)
	td.pairs(found) == {["TASK-11", "Taskfile.yml"]}
	messages(found, "TASK-11") == {concat("", [
		`the root Taskfile does not define "test"; add that task, or an alias of an existing task, `,
		"so `task <verb>` works the same in every repository",
	])}
}

test_task_10_and_12_missing_verbs if {
	tasks := {"verify": task("Check."), "test": task("Test."), "build": task("Build.")}
	root := object.union(object.remove(full, ["tasks"]), {"tasks": tasks})
	found := interface.findings with input as repository(root)
	td.pairs(found) == {["TASK-10", "Taskfile.yml"], ["TASK-12", "Taskfile.yml"]}
	messages(found, "TASK-10") == {concat("", [
		`the root Taskfile does not define "setup", "check"; add those tasks, or an alias of an existing `,
		"task, so `task <verb>` works the same in every repository",
	])}
}

test_internal_tasks_do_not_count if {
	root := object.union(full, {"tasks": object.union(full.tasks, {"test": {"internal": true}})})
	found := interface.findings with input as repository(root)
	td.pairs(found) == {["TASK-11", "Taskfile.yml"]}
}

test_no_root_taskfile if {
	found := interface.findings with input as [td.inventory(["docs/Taskfile.yml"])]
	td.pairs(found) == {["TASK-10", "Taskfile.yml"], ["TASK-11", "Taskfile.yml"], ["TASK-12", "Taskfile.yml"]}
	messages(found, "TASK-12") == {concat("", [
		`the repository has no root Taskfile; add Taskfile.yml defining "dev", so `,
		"`task <verb>` works the same in every repository",
	])}
}
