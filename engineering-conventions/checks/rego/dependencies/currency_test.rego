package conventions.checks.dependencies.currency_test

import data.conventions.checks.dependencies.currency
import data.conventions.lib.testdata_test as td

messages(found, id) := {f.message | some f in found; f.id == id}

deps := td.file(".repo/dependencies.toml", {"schema_version": 1, "dependencies": [
	{"repository": "platform-api", "output": "contracts", "version": "0.36.1"},
]})

run(command) := {"jobs": {"main": {"steps": [{"run": command}]}}}

tasks := {"version": "3", "tasks": {"deps:check": {"desc": "Check."}, "deps:sync": {"desc": "Sync."}}}

maintain := object.union(run("task deps:sync"), {"true": {
	"schedule": [{"cron": "0 6 * * 1"}],
	"workflow_dispatch": null,
}})

workflow_paths := [".github/workflows/validate.yml", ".github/workflows/maintain-dependencies.yml"]

repo(taskfile, validate, maintained) := [
	td.inventory(array.concat(["Taskfile.yml"], workflow_paths)),
	deps,
	td.file("Taskfile.yml", taskfile),
	td.file(".github/workflows/validate.yml", validate),
	td.file(".github/workflows/maintain-dependencies.yml", maintained),
]

test_conforming_consumer if {
	found := currency.findings with input as repo(tasks, run("task lint deps:check"), maintain)
		with data.conventions.index as td.index
	count(found) == 0
}

test_nothing_without_dependencies if {
	found := currency.findings with input as [td.inventory(["Taskfile.yml"])]
		with data.conventions.index as td.index
	count(found) == 0
}

test_deps_08_missing_tasks if {
	given := repo({"version": "3", "tasks": {"deps:check": {"desc": "Check."}}}, run("task deps:check"), maintain)
	found := currency.findings with input as given
		with data.conventions.index as td.index
	messages(found, "DEPS-08") == {concat(" ", [
		`the repository declares dependencies in .repo/dependencies.toml but its root Taskfile does not define`,
		`"deps:sync"; add them, so every consumer verifies and updates its vendored copies the same way`,
	])}
}

test_deps_09_validate_does_not_check if {
	found := currency.findings with input as repo(tasks, run("task test"), maintain)
		with data.conventions.index as td.index
	td.pairs(found) == {["DEPS-09", ".repo/dependencies.toml"]}
}

test_deps_10_no_workflow if {
	found := currency.findings with input as [
		td.inventory(["Taskfile.yml", ".github/workflows/validate.yml"]),
		deps,
		td.file("Taskfile.yml", tasks),
		td.file(".github/workflows/validate.yml", run("task deps:check")),
	]
		with data.conventions.index as td.index
	messages(found, "DEPS-10") == {concat(" ", [
		"the repository vendors dependencies but has no maintain-dependencies.yml; add it, on a schedule, to",
		"run `task deps:sync` and open a pull request for each new release",
	])}
}

test_deps_10_dispatch_only_and_no_sync if {
	dispatched := object.union(run("./sync.sh"), {"true": {"repository_dispatch": null}})
	given := repo(tasks, run("task deps:check"), dispatched)
	found := currency.findings with input as given
		with data.conventions.index as td.index
	td.pairs(found) == {["DEPS-10", ".github/workflows/maintain-dependencies.yml"]}
	count(messages(found, "DEPS-10")) == 2
}
