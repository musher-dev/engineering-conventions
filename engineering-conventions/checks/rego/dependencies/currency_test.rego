package conventions.checks.dependencies.currency_test

import data.conventions.checks.dependencies.currency
import data.conventions.lib.testdata_test as td

messages(found, id) := {f.message | some f in found; f.id == id}

deps := td.file(".repo/dependencies.toml", {"dependencies": [
	{"repository": "platform-api", "output": "contracts", "version": "0.36.1"},
]})

run(command) := {"jobs": {"main": {"steps": [{"run": command}]}}}

tasks := {"version": "3", "tasks": {"deps:check": {"desc": "Check."}, "deps:sync": {"desc": "Sync."}}}

badges := {"jobs": {"badges": {"uses": concat("@", [
	currency.reusable_workflow,
	"0123456789abcdef0123456789abcdef01234567",
])}}}

maintain := object.union(badges, {"true": {
	"schedule": [{"cron": "0 6 * * 1"}],
	"repository_dispatch": {"types": ["dependency-released"]},
	"workflow_dispatch": null,
}})

workflow_paths := [".github/workflows/validate.yml", ".github/workflows/maintain-dependency-badges.yml"]

readme_with(text) := {"conventions_inventory": {
	"files": array.concat(["Taskfile.yml", "README.md"], workflow_paths),
	"texts": {"README.md": text},
}}

badge_readme := concat("", [
	"# API\n\n",
	"![platform-api contracts](https://github.com/musher-dev/web/raw/badges/platform-api-contracts.svg)\n",
])

repo(taskfile, validate, maintained) := repo_with(taskfile, validate, maintained, badge_readme)

repo_with(taskfile, validate, maintained, text) := [
	td.file("/tmp/inventory.json", readme_with(text)),
	deps,
	td.file("Taskfile.yml", taskfile),
	td.file(".github/workflows/validate.yml", validate),
	td.file(".github/workflows/maintain-dependency-badges.yml", maintained),
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

test_deps_15_badge_missing if {
	given := repo_with(tasks, run("task deps:check"), maintain, "# API\n")
	found := currency.findings with input as given
		with data.conventions.index as td.index
	messages(found, "DEPS-15") == {concat(" ", [
		".repo/dependencies.toml pins platform-api contracts but README.md shows no currency badge for it; add",
		"![platform-api contracts](https://github.com/musher-dev/<this-repository>/raw/badges/platform-api-contracts.svg),",
		"so a reader sees when the pin falls behind",
	])}
	td.pairs(found) == {["DEPS-15", "README.md"]}
}

test_deps_15_conventions_pin if {
	given := [
		td.file("/tmp/inventory.json", {"conventions_inventory": {
			"files": [".config/mise/config.toml", "README.md", ".github/workflows/maintain-dependency-badges.yml"],
			"texts": {"README.md": badge_readme},
		}}),
		td.file(".config/mise/config.toml", {"tools": {"github:musher-dev/engineering-conventions": "0.9.4"}}),
		td.file(".github/workflows/maintain-dependency-badges.yml", maintain),
	]
	found := currency.findings with input as given
		with data.conventions.index as td.index
	td.pairs(found) == {["DEPS-15", "README.md"]}
	some message in messages(found, "DEPS-15")
	contains(message, "raw/badges/engineering-conventions.svg")
	startswith(message, ".config/mise/config.toml pins engineering-conventions but")
}

test_deps_15_pin_outside_project_config if {
	given := [td.inventory(["mise.toml", "README.md"]), td.pin]
	count(currency.findings) == 0 with input as given
		with data.conventions.index as td.index
}

test_deps_16_no_workflow if {
	found := currency.findings with input as [
		td.file("/tmp/inventory.json", {"conventions_inventory": {
			"files": ["Taskfile.yml", "README.md", ".github/workflows/validate.yml"],
			"texts": {"README.md": badge_readme},
		}}),
		deps,
		td.file("Taskfile.yml", tasks),
		td.file(".github/workflows/validate.yml", run("task deps:check")),
	]
		with data.conventions.index as td.index
	messages(found, "DEPS-16") == {concat(" ", [
		"the repository pins platform-api contracts but has no maintain-dependency-badges.yml; add it, on a",
		"schedule and on a dependency-released repository_dispatch, calling",
		"musher-dev/engineering-conventions/.github/workflows/reusable-maintain-dependency-badges.yml, so its",
		"currency badges stay fresh",
	])}
	td.pairs(found) == {["DEPS-16", ".repo/dependencies.toml"]}
}

test_deps_16_dispatch_only_and_no_badges if {
	dispatched := object.union(run("./sync.sh"), {"true": {"repository_dispatch": {"types": ["other"]}}})
	given := repo(tasks, run("task deps:check"), dispatched)
	found := currency.findings with input as given
		with data.conventions.index as td.index
	td.pairs(found) == {["DEPS-16", ".github/workflows/maintain-dependency-badges.yml"]}
	count(messages(found, "DEPS-16")) == 3
}

test_deps_16_command_renders if {
	commanded := object.union(run("conventions dependencies badges --out badges"), {"true": {
		"schedule": [{"cron": "0 6 * * 1"}],
		"repository_dispatch": {"types": "dependency-released"},
	}})
	found := currency.findings with input as repo(tasks, run("task deps:check"), commanded)
		with data.conventions.index as td.index
	count(found) == 0
}
