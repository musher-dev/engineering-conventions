package conventions.checks.tasks.taskfile_style_test

import data.conventions.checks.tasks.taskfile_style as style
import data.conventions.lib.testdata_test as td

messages(found, id) := {f.message | some f in found; f.id == id}

conforming := {
	"version": "3",
	"output": "prefixed",
	"includes": {"lint": {"taskfile": "taskfiles/lint.Taskfile.yml", "flatten": true}},
	"vars": {
		"PRODUCT_DIR": "{{.ROOT_DIR}}/app", "VALE_CONFIG": ".config/vale.ini",
		"OUT": "dist", "ENV_FILE": ".env.local",
	},
	"env": {"GOFLAGS": "-mod=mod"},
	"tasks": {
		"setup": {"desc": "Install.", "deps": ["_deps"], "sources": ["go.mod", "src/**/*.go"]},
		"check": {"desc": "Check.", "cmds": [{"task": "lint"}], "prefix": "check"},
		"_deps": {"internal": true, "cmds": ["go mod download {{.GOFLAGS}}", "echo {{- .X -}}"]},
		"db:migrate:*": {"desc": "Migrate.", "vars": {"TARGET_DIR": "app"}},
	},
}

lint := {"version": "3", "tasks": {"lint": {
	"desc": "Lint.",
	"vars": {"LINT_CONFIG": "{{.TASKFILE_DIR}}/../.config/vale.ini"},
}}}

paths := ["Taskfile.yml", "taskfiles/lint.Taskfile.yml", "go.mod", "app/main.go", ".config/vale.ini"]

repository(root) := [
	td.inventory(paths),
	td.file("Taskfile.yml", root),
	td.file("taskfiles/lint.Taskfile.yml", lint),
]

with_root(fields) := repository(object.union(conforming, fields))

with_task(name, task) := with_root({"tasks": object.union(conforming.tasks, {name: task})})

test_conforming_taskfiles if {
	count(style.findings) == 0 with input as repository(conforming)
}

test_task_01_version if {
	found := style.findings with input as repository(object.remove(conforming, ["version"]))
	messages(found, "TASK-01") == {"the Taskfile has no version; add version: '3' as its first key"}

	number := style.findings with input as with_root({"version": 3})
	messages(number, "TASK-01") == {"version is the number 3; quote it as version: '3', the schema version Task reads"}

	two := style.findings with input as with_root({"version": "2"})
	messages(two, "TASK-01") == {"version is 2; use version: '3', the only Taskfile schema Task supports"}
}

test_task_02_variable_names if {
	found := style.findings with input as with_root({
		"vars": {"productDir": "x"},
		"env": {"http-proxy": "y"},
		"tasks": object.union(conforming.tasks, {"build": {"desc": "Build.", "env": {"lower": "1"}}}),
	})
	messages(found, "TASK-02") == {
		`global variable "productDir" is not UPPER_SNAKE; rename it "PRODUCT_DIR" and every reference to it`,
		`environment variable "http-proxy" is not UPPER_SNAKE; rename it "HTTP_PROXY" and every reference to it`,
		`task "build" environment variable "lower" is not UPPER_SNAKE; rename it "LOWER" and every reference to it`,
	}
}

test_task_03_names_and_aliases if {
	found := style.findings with input as with_task("buildImage", {"desc": "Build.", "aliases": ["build_image"]})
	messages(found, "TASK-03") == {
		concat("", [
			`task name "buildImage" is not kebab-case; use lowercase words joined by hyphens, `,
			"with `:` between a namespace and a name, such as \"build-image\"",
		]),
		concat("", [
			`task name "build_image" is not kebab-case; use lowercase words joined by hyphens, `,
			"with `:` between a namespace and a name, such as \"build-image\"",
		]),
	}
}

test_task_03_underscore_needs_internal if {
	found := style.findings with input as with_task("_tidy", {"cmds": ["go mod tidy"]})
	messages(found, "TASK-03") == {concat("", [
		`task "_tidy" starts with _, which marks an internal helper; add internal: true, `,
		"or drop the _ if it is public",
	])}
	not "TASK-05" in td.ids(found)
}

test_task_04_template_spaces if {
	found := style.findings with input as with_task("fmt", {"desc": "Format.", "cmds": ["gofmt {{ .SRC }} {{.A }}"]})
	messages(found, "TASK-04") == {
		"template {{ .SRC }} has spaces inside its delimiters; write {{.SRC}}",
		"template {{.A }} has spaces inside its delimiters; write {{.A}}",
	}
}

test_task_05_desc if {
	found := style.findings with input as with_task("fmt", {"desc": " ", "cmds": ["gofmt ."]})
	messages(found, "TASK-05") == {`task "fmt" has no desc; add a one-line desc so task --list shows what it does`}

	shorthand := style.findings with input as with_task("fmt", ["gofmt ."])
	"TASK-05" in td.ids(shorthand)
}

test_task_06_uncalled_internal_task if {
	found := style.findings with input as with_task("_unused", {"internal": true, "cmds": ["true"]})
	messages(found, "TASK-06") == {concat("", [
		`internal task "_unused" is called by no task; an internal task cannot be run on its own, `,
		"so delete it or call it",
	])}
}

test_task_07_prefix_without_prefixed_output if {
	found := style.findings with input as repository(object.remove(conforming, ["output"]))
	td.pairs(found) == {["TASK-07", "Taskfile.yml"]}
}

test_task_07_prefixed_output_in_an_including_file if {
	child := {"version": "3", "tasks": {"lint": {"desc": "Lint.", "prefix": "lint"}}}
	docs := [td.inventory(paths), td.file("Taskfile.yml", conforming), td.file("taskfiles/lint.Taskfile.yml", child)]
	count(style.findings) == 0 with input as docs
}

test_task_08_path_variables if {
	found := style.findings with input as with_root({
		"vars": {"DOCS_DIR": "docs", "REPORT_FILE": "{{.ROOT_DIR}}/reports/today.txt", "OUT_DIR": "{{.DIST}}"},
		"tasks": object.union(conforming.tasks, {"build": {"desc": "Build.", "vars": {"SRC_DIR": "source"}}}),
	})
	messages(found, "TASK-08") == {
		concat("", [
			`variable DOCS_DIR is "docs", which names no file or directory in the repository; `,
			"correct the path, delete the variable, or, if a task creates the directory, rename the variable DOCS",
		]),
		concat("", [
			`variable REPORT_FILE is "{{.ROOT_DIR}}/reports/today.txt", whose directory the repository does not hold; `,
			"correct the path, or delete the variable",
		]),
		concat("", [
			`task "build" variable SRC_DIR is "source", which names no file or directory in the repository; `,
			"correct the path, delete the variable, or, if a task creates the directory, rename the variable SRC",
		]),
	}
}

test_task_08_a_config_variable_keeps_the_short_remedy if {
	found := style.findings with input as with_root({"vars": {"LINT_CONFIG": ".golangci.yml"}})
	messages(found, "TASK-08") == {concat("", [
		`variable LINT_CONFIG is ".golangci.yml", which names no file or directory in the repository; `,
		"correct the path, or delete the variable",
	])}
}

test_task_08_build_output_named_for_what_it_holds if {
	found := style.findings with input as with_root({"vars": {"SITE": "site", "DIST": "{{.ROOT_DIR}}/dist"}})
	not "TASK-08" in {finding.id | some finding in found}
}

test_task_08_skips_a_task_with_its_own_dir if {
	task := {"desc": "Build.", "dir": "app", "vars": {"SRC_DIR": "source"}}
	count(style.findings) == 0 with input as with_task("build", task)
}

test_task_09_missing_include if {
	found := style.findings with input as with_root({"includes": {
		"lint": {"taskfile": "taskfiles/lint.Taskfile.yml", "flatten": true},
		"docs": "./docs",
		"extra": {"taskfile": "extra.yml", "optional": true},
	}})
	td.pairs(found) == {["TASK-09", "Taskfile.yml"]}
	messages(found, "TASK-09") == {concat("", [
		`include "docs" loads "./docs", which does not exist; Task refuses to run any task until it does, `,
		"so correct the path",
	])}
}

test_task_14_missing_source if {
	sources := ["bun.lock", "**/*.ts", {"exclude": "x"}]
	found := style.findings with input as with_task("build", {"desc": "Build.", "sources": sources})
	messages(found, "TASK-14") == {concat("", [
		`task "build" lists source "bun.lock", which does not exist; Task ignores a source that matches `,
		"nothing, so the task stops noticing changes to it; correct the path or remove it",
	])}
}

test_task_14_skips_a_task_with_its_own_dir if {
	count(style.findings) == 0 with input as with_task("build", {"desc": "Build.", "dir": "app", "sources": ["x.go"]})
}
