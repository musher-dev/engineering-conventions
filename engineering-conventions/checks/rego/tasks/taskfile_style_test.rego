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

test_task_15_default_lists_the_tasks if {
	for_list := with_task("default", {"desc": "List the tasks.", "silent": true, "cmds": ["task --list"]})
	count(style.findings) == 0 with input as for_list

	exe := with_task("default", {"desc": "List.", "cmds": ["{{.TASK_EXE}} --list-all --sort none", "echo hi"]})
	count(style.findings) == 0 with input as exe

	help := {"desc": "Show workflows.", "cmds": ["echo 'task check runs every gate'", "task -l"]}
	through_help := with_root({"tasks": object.union(conforming.tasks, {
		"default": {"desc": "Help.", "cmds": [{"task": "help"}, "task help"]},
		"help": help,
	})})
	count(style.findings) == 0 with input as through_help
}

test_task_15_default_that_does_work if {
	found := style.findings with input as with_task("default", {
		"desc": "Build.",
		"deps": ["setup"],
		"cmds": ["go build ./...", {"task": "check"}, "task lint", "task --list build"],
	})
	messages(found, "TASK-15") == {
		default_message(`has deps (setup)`),
		default_message(`runs "go build ./..."`),
		default_message(`calls task "check"`),
		default_message(`runs "task lint"`),
		default_message(`runs "task --list build"`),
	}
}

test_task_15_alias_and_help_that_does_work if {
	found := style.findings with input as with_root({"tasks": object.union(conforming.tasks, {
		"build": {"desc": "Build.", "aliases": ["default"], "cmds": ["go build ./..."]},
		"help": {"desc": "Help.", "cmds": ["task --list", {"task": "build"}]},
		"list": {"desc": "List.", "deps": ["setup"], "cmds": ["task -l"]},
	})})
	messages(found, "TASK-15") == {default_message(`runs "go build ./..."`)}

	via_help := style.findings with input as with_root({"tasks": object.union(conforming.tasks, {
		"default": {"desc": "Help.", "cmds": [{"task": "help"}, "task list"]},
		"help": {"desc": "Help.", "cmds": ["task --list", {"task": "build"}]},
		"list": {"desc": "List.", "deps": ["setup"], "cmds": ["task -l"]},
		"build": {"desc": "Build."},
	})})
	messages(via_help, "TASK-15") == {default_message(`calls task "help"`), default_message(`runs "task list"`)}
}

test_task_15_only_the_root_taskfile if {
	lint_default := {"version": "3", "tasks": {
		"lint": {"desc": "Lint.", "vars": {"LINT_CONFIG": "{{.TASKFILE_DIR}}/../.config/vale.ini"}},
		"default": {"desc": "Lint.", "cmds": [{"task": "lint"}]},
	}}
	docs := [
		td.inventory(paths),
		td.file("Taskfile.yml", conforming),
		td.file("taskfiles/lint.Taskfile.yml", lint_default),
	]
	not "TASK-15" in td.ids(style.findings) with input as docs
}

default_message(offence) := sprintf(
	concat("", [
		"the default task %s, so a bare `task` does work; make default only list the tasks ",
		"(task --list) or run a help task that does, and give that work a name of its own",
	]),
	[offence],
)

test_task_16_namespace_depth if {
	four := with_task("test:contract:openapi:public", {"desc": "Test.", "aliases": ["t:c:o:p"]})
	not "TASK-16" in td.ids(style.findings) with input as four

	found := style.findings with input as with_task("check:biome:fix:unsafe:all", {
		"desc": "Fix.",
		"aliases": ["a:b:c:d:e:f"],
	})
	messages(found, "TASK-16") == {
		concat("", [
			`task name "check:biome:fix:unsafe:all" nests 4 namespaces; a name has at most three namespaces `,
			`before it, so join words with hyphens instead, such as "check:biome:fix:unsafe-all"`,
		]),
		concat("", [
			`task name "a:b:c:d:e:f" nests 5 namespaces; a name has at most three namespaces `,
			`before it, so join words with hyphens instead, such as "a:b:c:d-e-f"`,
		]),
	}
}

test_task_17_host_paths if {
	found := style.findings with input as with_root({
		"includes": object.union(conforming.includes, {"far": {"taskfile": "/Users/ana/shared/Taskfile.yml"}}),
		"vars": object.union(conforming.vars, {"CACHE": "/home/ana/.cache/tool"}),
		"tasks": object.union(conforming.tasks, {"build": {
			"desc": "Build.",
			"dir": "/workspaces/app",
			"env": {"OUT": `C:\build`},
			"cmds": ["cd /workspace && go build ./...", "cp x '/root/.config/tool'"],
		}}),
	})
	messages(found, "TASK-17") == {
		host_message(`include "far" taskfile`, "/Users/ana"),
		host_message("variable CACHE", "/home/ana"),
		host_message(`task "build" dir`, "/workspaces/app"),
		host_message(`task "build" variable OUT`, `C:\`),
		host_message(`task "build"`, "/workspace"),
		host_message(`task "build"`, "/root/"),
	}
}

test_task_17_near_misses if {
	task := {
		"desc": "Build.",
		"sources": ["go.mod"],
		"cmds": [
			"go build -o /tmp/app ./... 2>/dev/null",
			"/usr/bin/env bash -c true",
			`docker run -v "{{.ROOT_DIR}}:/workspace" -w /workspace image`,
			"echo 'open /home/you/project in your editor'",
			"# cd /workspace",
			"cp a {{.ROOT_DIR}}/workspace/x",
			"curl https://example.com/home/page",
			"ls /workspace-cache /opt/tool",
		],
	}
	not "TASK-17" in td.ids(style.findings) with input as with_task("build", task)
}

host_message(where, path) := sprintf(
	concat("", [
		"%s names %q, a path on one machine, so the task breaks in any other checkout, ",
		"container or CI runner; write it from {{.ROOT_DIR}} or {{.TASKFILE_DIR}}",
	]),
	[where, path],
)

test_task_18_destructive_commands if {
	found := style.findings with input as with_root({"tasks": object.union(conforming.tasks, {
		"volumes": {"desc": "Wipe.", "cmds": ["docker volume rm app_data"]},
		"prune": {"desc": "Prune.", "cmds": ["podman system prune -a --volumes"]},
		"down": {"desc": "Down.", "cmds": ["{{.COMPOSE}} down -v"]},
		"compose": {"desc": "Down.", "cmds": ["docker compose -p x down --remove-orphans --volumes"]},
		"infra:destroy": {"desc": "Destroy.", "cmds": ["tofu -chdir=infra destroy -auto-approve"]},
		"infra:apply": {"desc": "Apply.", "cmd": "terraform apply -auto-approve"},
		"scrub": {"desc": "Scrub.", "cmds": ["git clean -fdx"]},
		"discard": {"desc": "Discard.", "cmds": ["git reset -q --hard HEAD"]},
		"db:reset": {"desc": "Reset.", "cmds": ["psql -c 'drop database app'"]},
	})})
	messages(found, "TASK-18") == {
		loss_message("volumes", "removes container volumes"),
		loss_message("prune", "prunes container volumes"),
		loss_message("down", "takes a compose stack down with its volumes"),
		loss_message("compose", "takes a compose stack down with its volumes"),
		loss_message("infra:destroy", "destroys infrastructure with -auto-approve"),
		loss_message("infra:destroy", "is named for destroying data"),
		loss_message("infra:apply", "applies infrastructure changes with -auto-approve and no saved plan"),
		loss_message("scrub", "deletes untracked files with git clean"),
		loss_message("discard", "discards uncommitted changes with git reset --hard"),
		loss_message("db:reset", "is named for destroying data"),
	} - {loss_message("infra:destroy", "is named for destroying data")}
}

test_task_18_prompted_and_safe_tasks if {
	tasks := object.union(conforming.tasks, {
		"clean": {"desc": "Clean.", "cmds": ["rm -rf dist build node_modules", "git clean -n"]},
		"db:reset": {"desc": "Reset.", "prompt": "This drops the local database. Continue?", "cmds": [{"task": "_drop"}]},
		"_drop": {"internal": true, "cmds": ["docker volume rm db_data"]},
		"stop": {"desc": "Stop.", "cmds": ["docker compose down", "echo 'run docker volume rm x to wipe'"]},
		"apply": {"desc": "Apply.", "prompt": ["Apply?", "Really?"], "cmds": ["tofu apply -auto-approve"]},
		"apply:plan": {"desc": "Apply the plan.", "cmds": ["tofu apply -auto-approve tfplan"]},
		"plan": {"desc": "Plan.", "cmds": ["tofu plan -out tfplan", "git reset --soft HEAD~1"]},
	})
	not "TASK-18" in td.ids(style.findings) with input as with_root({"tasks": tasks})
}

test_task_18_internal_task_without_a_prompted_caller if {
	tasks := object.union(conforming.tasks, {
		"setup": {"desc": "Install.", "deps": ["_deps", "_wipe"]},
		"_wipe": {"internal": true, "cmds": ["docker volume prune -f"]},
	})
	found := style.findings with input as with_root({"tasks": tasks})
	messages(found, "TASK-18") == {loss_message("_wipe", "removes container volumes")}
}

loss_message(name, loss) := sprintf(
	concat("", [
		"task %q %s and declares no prompt:, so one mistyped command loses what nothing in ",
		"the repository can restore; add a prompt naming what is lost (a workflow passes --yes)",
	]),
	[name, loss],
)
