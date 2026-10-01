package conventions.checks.tasks.taskfile_fragments_test

import data.conventions.checks.tasks.taskfile_fragments as fragments
import data.conventions.lib.testdata_test as td

messages(found, id) := {f.message | some f in found; f.id == id}

conforming := {
	"version": "3",
	"output": "prefixed",
	"includes": {"lint": {"taskfile": "taskfiles/lint.Taskfile.yml", "flatten": true}},
	"tasks": {
		"setup": {"desc": "Install.", "cmds": ["mise install"]},
		"check": {"desc": "Check.", "cmds": [{"task": "lint"}], "prefix": "check"},
	},
}

lint := {"version": "3", "tasks": {"lint": {"desc": "Lint."}}}

paths := ["Taskfile.yml", "taskfiles/lint.Taskfile.yml"]

repository(root) := [
	td.inventory(paths),
	td.file("Taskfile.yml", root),
	td.file("taskfiles/lint.Taskfile.yml", lint),
]

with_root(fields) := repository(object.union(conforming, fields))

with_task(name, task) := with_root({"tasks": object.union(conforming.tasks, {name: task})})

test_conforming_taskfiles if {
	count(fragments.findings) == 0 with input as repository(conforming)
}

# A repository whose root flattens the lint fragment, given as a document and
# as the raw text the runner embeds.
with_fragment(fragment, text) := fragment_repo(conforming.includes, fragment, text, {})

fragment_repo(includes, fragment, text, extra) := array.concat(
	[
		td.file("/tmp/inventory.json", {"conventions_inventory": {
			"files": array.concat(paths, [path | some path, _ in extra]),
			"texts": {"taskfiles/lint.Taskfile.yml": text},
		}}),
		td.file("Taskfile.yml", object.union(conforming, {"includes": includes})),
		td.file("taskfiles/lint.Taskfile.yml", fragment),
	],
	[td.file(path, doc) | some path, doc in extra],
)

lint_text := "version: '3'\n\n# Lint: the linters and their configuration.\n\ntasks:\n"

fragment_tasks(tasks) := {"version": "3", "tasks": tasks}

test_fragment_conforms if {
	tasks := {
		"lint": {"desc": "Lint.", "cmds": [{"task": "lint:md"}, {"task": "_vale"}]},
		"lint:md": {
			"desc": "Lint Markdown.", "silent": true, "prefix": "md",
			"cmds": ["echo 'Linting Markdown'", "markdownlint ."],
		},
		"_vale": {"internal": true, "silent": true, "prefix": "vale", "cmds": [{"cmd": "printf 'vale\\n'"}, "vale ."]},
		"lint:all": {"desc": "Lint all.", "silent": true, "prefix": "lint-all", "cmds": [{"task": "lint"}]},
	}
	count(fragments.findings) == 0 with input as with_fragment(fragment_tasks(tasks), lint_text)
}

test_task_18_silent_and_internal_tasks if {
	tasks := {
		"lint": {"desc": "Lint.", "silent": true, "cmds": ["markdownlint ."], "deps": ["_vale", "_yaml"]},
		"_vale": {"internal": true, "cmds": ["vale ."]},
		"_yaml": {"internal": true, "cmd": "yamllint ."},
	}
	found := fragments.findings with input as with_fragment(fragment_tasks(tasks), lint_text)
	messages(found, "TASK-18") == {
		silent_message("lint"),
		internal_message("_vale"),
		internal_message("_yaml"),
	}

	file_silent := object.union(fragment_tasks(tasks), {"silent": true})
	everywhere := fragments.findings with input as with_fragment(file_silent, lint_text)
	messages(everywhere, "TASK-18") == {silent_message("lint"), silent_message("_vale"), silent_message("_yaml")}
}

test_task_18_only_fragments if {
	not "TASK-18" in td.ids(fragments.findings) with input as with_task("_quiet", {"internal": true, "cmds": ["true"]})
}

silent_message(name) := sprintf(
	concat("", [
		"task %q is silent, so Task prints none of its commands, and it echoes nothing either; ",
		"add an echo line saying what it is doing",
	]),
	[name],
)

internal_message(name) := sprintf(
	concat("", [
		"internal task %q runs commands of its own but is not silent, so Task prints each command ",
		"line it runs; set silent: true and echo what it is doing",
	]),
	[name],
)

test_task_19_composite_echo if {
	tasks := {
		"lint": {"desc": "Lint.", "cmds": ["echo 'Linting'", {"task": "lint:md"}, {"cmd": "echo done"}]},
		"lint:md": {"desc": "Lint Markdown.", "cmds": ["echo 'Linting Markdown' && markdownlint ."]},
		"lint:yaml": {"desc": "Lint YAML.", "cmds": [{"task": "lint:md"}, "echo x", "yamllint ."]},
		"lint:help": {"desc": "Explain.", "cmds": ["echo 'run task lint'"]},
	}
	found := fragments.findings with input as with_fragment(fragment_tasks(tasks), lint_text)
	messages(found, "TASK-19") == {composite_message("lint", "echo 'Linting'"), composite_message("lint", "echo done")}
}

composite_message(name, echo) := sprintf(
	concat("", [
		"task %q only calls other tasks, yet adds %q; the tasks it calls say what they do, ",
		"so remove the echo",
	]),
	[name, echo],
)

test_task_20_fragment_includes if {
	includes := {
		"lint": {"taskfile": "taskfiles/lint.Taskfile.yml", "flatten": true, "optional": true, "dir": "x"},
		"docs": "taskfiles/docs.Taskfile.yml",
		"ops": {"taskfile": "taskfiles/ops.Taskfile.yml", "flatten": true, "internal": true},
	}
	extra := {
		"taskfiles/docs.Taskfile.yml": {"version": "3", "tasks": {"docs": {"desc": "Docs."}}},
		"taskfiles/ops.Taskfile.yml": {"version": "3", "tasks": {}},
	}
	found := fragments.findings with input as fragment_repo(includes, lint, lint_text, extra)
	messages(found, "TASK-20") == {
		concat("", [
			`include "docs" loads fragment "taskfiles/docs.Taskfile.yml" without flatten: true, while this Taskfile `,
			"flattens its other fragments; set flatten: true, so each task is called by the name its fragment gives it",
		]),
		include_message("lint", "lint", "optional", "a fragment that goes missing drops its tasks without a word"),
		include_message(
			"lint", "lint", "dir",
			"its tasks run somewhere other than every other fragment's, from the same Taskfile",
		),
		include_message("ops", "ops", "internal", "every task in it is hidden and cannot be run"),
	}

	namespaced := {
		"lint": "taskfiles/lint.Taskfile.yml",
		"docs": {"taskfile": "taskfiles/docs.Taskfile.yml", "optional": true},
	}
	not "TASK-20" in td.ids(fragments.findings) with input as fragment_repo(namespaced, lint, lint_text, extra)
}

include_message(namespace, area, key, consequence) := sprintf(
	"include %q of fragment \"taskfiles/%s.Taskfile.yml\" sets %s:, so %s; remove it",
	[namespace, area, key, consequence],
)

test_task_21_fragment_top_level_keys if {
	fragment := object.union(lint, {
		"vars": {"X": "1"}, "env": {"Y": "2"}, "dotenv": [".env"],
		"includes": {"more": "./more.yml"},
	})
	found := fragments.findings with input as with_fragment(fragment, lint_text)
	messages(found, "TASK-21") == {
		concat("", [
			"the fragment declares a top-level vars:, which Task merges into the scope of every Taskfile, ",
			"so a name here can change what a task elsewhere runs; move them to the including Taskfile ",
			"or into the tasks that use them",
		]),
		concat("", [
			"the fragment declares a top-level env:, which Task merges into the environment of every ",
			"Taskfile's tasks; move it to the including Taskfile or into the tasks that use it",
		]),
		concat("", [
			"the fragment declares a top-level dotenv:, which Task refuses in an included Taskfile; ",
			"move it to the including Taskfile",
		]),
		concat("", [
			"the fragment declares a top-level includes:, so where a task is defined, and the name it answers ",
			"to, depend on a second level of includes; include each Taskfile from the including Taskfile instead",
		]),
	}
}

test_task_21_and_22_only_flattened_fragments if {
	fragment := object.union(lint, {"vars": {"X": "1"}})
	namespaced := {"lint": "taskfiles/lint.Taskfile.yml"}
	found := fragments.findings with input as fragment_repo(namespaced, fragment, "version: '3'\ntasks:\n", {})
	not "TASK-21" in td.ids(found)
	not "TASK-22" in td.ids(found)
}

test_task_22_opening_comment if {
	message := concat("", [
		`the fragment has no comment above its tasks that names its area, "lint"; open it with one `,
		"saying what the lint tasks are for",
	])
	none := fragments.findings with input as with_fragment(lint, "version: '3'\ntasks:\n  # lint things\n")
	messages(none, "TASK-22") == {message}

	other := fragments.findings with input as with_fragment(lint, "# Checks for Markdown.\nversion: '3'\ntasks:\n")
	messages(other, "TASK-22") == {message}

	first := "# LINT tasks.\nversion: '3'\ntasks:\n"
	not "TASK-22" in td.ids(fragments.findings) with input as with_fragment(lint, first)

	unread := with_fragment(lint, "x")
	not "TASK-22" in td.ids(fragments.findings) with input as json.patch(unread, [{
		"op": "remove", "path": "/0/contents/conventions_inventory/texts",
	}])
}

test_task_22_hyphenated_area if {
	include := {"taskfile": "taskfiles/dev-stack.Taskfile.yml", "flatten": true}
	root := object.union(conforming, {"includes": {"dev": include}})
	repo := [
		td.file("/tmp/inventory.json", {"conventions_inventory": {
			"files": array.concat(paths, ["taskfiles/dev-stack.Taskfile.yml"]),
			"texts": {"taskfiles/dev-stack.Taskfile.yml": "# The dev stack: compose services.\nversion: '3'\ntasks:\n"},
		}}),
		td.file("Taskfile.yml", root),
		td.file("taskfiles/lint.Taskfile.yml", lint),
		td.file("taskfiles/dev-stack.Taskfile.yml", {"version": "3", "tasks": {}}),
	]
	not "TASK-22" in td.ids(fragments.findings) with input as repo
}

test_task_23_silent_prefixes if {
	found := fragments.findings with input as with_root({"tasks": object.union(conforming.tasks, {
		"db:migrate": {"desc": "Migrate.", "silent": true, "cmds": ["echo m", "migrate up"]},
		"docs:build": {"desc": "Docs.", "silent": true, "prefix": "Docs_Build", "cmds": ["echo d", "mkdocs build"]},
		"api:run": {"desc": "Run.", "silent": true, "prefix": "{{.SERVICE}}", "cmds": ["echo r", "go run ."]},
		"loud": {"desc": "Loud.", "cmds": ["make"]},
	})})
	messages(found, "TASK-23") == {
		`task "db:migrate" is silent in prefixed output and sets no prefix; add a kebab-case prefix, such as "db-migrate"`,
		concat("", [
			`task "docs:build" has prefix "Docs_Build", which is not kebab-case; use lowercase words joined `,
			`by hyphens, such as "docs-build"`,
		]),
	}

	unprefixed := object.remove(conforming, ["output"])
	quiet := object.union(unprefixed, {"tasks": {"x": {"desc": "X.", "silent": true, "cmds": ["echo x"]}}})
	not "TASK-23" in td.ids(fragments.findings) with input as repository(quiet)
}

test_task_24_long_running if {
	found := fragments.findings with input as with_root({"tasks": object.union(conforming.tasks, {
		"dev": {"desc": "Run.", "cmds": ["go run ."]},
		"docs:serve": {"desc": "Serve.", "cmds": ["mkdocs serve"]},
		"web:start": {"desc": "Start.", "aliases": ["web:watch"], "cmds": ["bun --watch ."]},
		"api:dev": {"desc": "Run.", "silent": true, "prefix": "api", "cmds": ["echo Starting", "go run ."]},
		"stack:dev": {"desc": "Run all.", "deps": ["dev", "docs:serve"]},
		"devtools": {"desc": "Tools.", "cmds": ["go install ./tools"]},
	})})
	messages(found, "TASK-24") == {long_message("dev"), long_message("docs:serve"), long_message("web:start")}

	unprefixed := object.remove(conforming, ["output"])
	plain := object.union(unprefixed, {"tasks": {"dev": {"desc": "Run.", "cmds": ["go run ."]}}})
	not "TASK-24" in td.ids(fragments.findings) with input as repository(plain)
}

long_message(name) := sprintf(
	concat("", [
		"task %q starts a long-running process in prefixed output but is not silent, so Task ",
		"prints its whole command line ahead of the process's own output; set silent: true and ",
		"echo what it starts",
	]),
	[name],
)
