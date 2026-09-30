package conventions.checks.interfaces.publishing_test

import data.conventions.checks.interfaces.publishing
import data.conventions.lib.testdata_test as td

messages(found, id) := {f.message | some f in found; f.id == id}

bundle := {
	"id": "contracts",
	"kind": "bundle",
	"source": "api/contracts/",
	"publish_workflow": "release.yml",
	"location": "https://github.com/example/api/releases",
	"docs": "api/contracts/README.md",
}

public := {
	"id": "public-http",
	"format": "openapi",
	"definitions": ["api/contracts/openapi/public.json"],
	"delivered_by": "contracts",
	"compatibility": "gated",
	"generated": true,
}

outputs(interfaces) := td.file(".repo/outputs.toml", {
	"schema_version": 2,
	"outputs": [bundle],
	"interfaces": interfaces,
})

run(command) := {"jobs": {"main": {"steps": [{"run": command}]}}}

all_tasks := {"version": "3", "tasks": {
	"contracts:generate": {"desc": "Generate."},
	"contracts:check": {"desc": "Check."},
	"contracts:breaking": {"desc": "Compare."},
	"contracts:bundle": {"desc": "Bundle."},
}}

repo(taskfile, validate, release) := [
	td.inventory(["Taskfile.yml", ".github/workflows/validate.yml", ".github/workflows/release.yml"]),
	td.file("Taskfile.yml", taskfile),
	td.file(".github/workflows/validate.yml", validate),
	td.file(".github/workflows/release.yml", release),
	outputs([public]),
]

test_conforming_producer if {
	given := repo(all_tasks, run("task contracts:check contracts:breaking"), run("task contracts:bundle"))
	found := publishing.findings with input as given
		with data.conventions.index as td.index
	count(found) == 0
}

test_nothing_without_interfaces if {
	given := [td.inventory(["Taskfile.yml"]), td.file("Taskfile.yml", {"version": "3"})]
	found := publishing.findings with input as given
		with data.conventions.index as td.index
	count(found) == 0
}

test_iface_11_missing_tasks if {
	only_check := {"version": "3", "tasks": {"contracts:check": {"desc": "Check."}}}
	given := repo(only_check, run("task contracts:check contracts:breaking"), run("task contracts:bundle"))
	found := publishing.findings with input as given
		with data.conventions.index as td.index
	messages(found, "IFACE-11") == {concat(" ", [
		`the repository declares interfaces in .repo/outputs.toml but its root Taskfile does not define`,
		`"contracts:breaking", "contracts:bundle", "contracts:generate"; add them, so every producer`,
		"regenerates, checks, compares and bundles its interfaces the same way",
	])}
}

test_iface_12_validate_skips_a_task if {
	given := repo(all_tasks, run("task contracts:check"), run("task contracts:bundle"))
	found := publishing.findings with input as given
		with data.conventions.index as td.index
	messages(found, "IFACE-12") == {concat(" ", [
		"the repository declares interfaces but no validate workflow runs `task contracts:breaking`; run it",
		"in a validate workflow, so a change that drifts from or breaks an interface cannot merge",
	])}
}

test_iface_12_an_echoed_command_is_not_run if {
	given := repo(all_tasks, run("echo 'run task contracts:check contracts:breaking'"), run("task contracts:bundle"))
	found := publishing.findings with input as given
		with data.conventions.index as td.index
	count(messages(found, "IFACE-12")) == 2
}

test_iface_13_release_does_not_bundle if {
	given := repo(all_tasks, run("task contracts:check contracts:breaking"), run("tar -czf c.tgz api/contracts"))
	found := publishing.findings with input as given
		with data.conventions.index as td.index
	td.pairs(found) == {["IFACE-13", ".github/workflows/release.yml"]}
	messages(found, "IFACE-13") == {concat(" ", [
		"release.yml publishes bundle \"contracts\", which delivers interfaces, but does not run",
		"`task contracts:bundle`;",
		"build the bundle and its release.json with that task in the workflow that publishes it",
	])}
}
