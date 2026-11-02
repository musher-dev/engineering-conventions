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
		include_message(
			"ops", "ops", "internal",
			"every task in it is hidden and cannot be run; only a tool wrapper under taskfiles/tools/ is included internal",
		),
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

# A root that flattens the lint fragment and includes the yamllint wrapper,
# with the wrapper given as a document and as its raw text.
wrapper_text := "version: '3'\n\n# yamllint: how yamllint runs.\n\ntasks:\n"

wrapper := {"version": "3", "tasks": {"tool:yamllint": {
	"desc": "Lint YAML with yamllint.",
	"cmds": ["yamllint --strict {{.FILES | default \".\"}}"],
}}}

wrapper_include := {"taskfile": "taskfiles/tools/yamllint.Taskfile.yml", "flatten": true, "internal": true}

wrapped_repo(root_tasks, include, wrapper_doc, lint_doc) := texts_repo(
	root_tasks, include, wrapper_doc, lint_doc,
	wrapper_text,
)

texts_repo(root_tasks, include, wrapper_doc, lint_doc, text) := [
	td.file("/tmp/inventory.json", {"conventions_inventory": {
		"files": array.concat(paths, ["taskfiles/tools/yamllint.Taskfile.yml"]),
		"texts": {"taskfiles/lint.Taskfile.yml": lint_text, "taskfiles/tools/yamllint.Taskfile.yml": text},
	}}),
	td.file("Taskfile.yml", object.union(conforming, {
		"includes": object.union(conforming.includes, {"tool-yamllint": include}),
		"tasks": object.union(conforming.tasks, root_tasks),
	})),
	td.file("taskfiles/lint.Taskfile.yml", lint_doc),
	td.file("taskfiles/tools/yamllint.Taskfile.yml", wrapper_doc),
]

calls_wrapper := {"version": "3", "tasks": {"lint": {"desc": "Lint.", "cmds": [{"task": "tool:yamllint"}]}}}

test_wrapped_layout_conforms if {
	count(fragments.findings) == 0 with input as wrapped_repo({}, wrapper_include, wrapper, calls_wrapper)
}

test_task_20_leaves_wrappers_to_task_25 if {
	found := fragments.findings with input as wrapped_repo({}, wrapper_include, wrapper, calls_wrapper)
	not "TASK-20" in td.ids(found)
}

test_task_21_and_22_hold_wrappers if {
	doc := object.union(wrapper, {"vars": {"CONFIG": ".config/yaml/yamllint.yaml"}})
	found := fragments.findings with input as texts_repo({}, wrapper_include, doc, calls_wrapper, "tasks:\n")
	{f.path | some f in found; f.id in {"TASK-21", "TASK-22"}} == {"taskfiles/tools/yamllint.Taskfile.yml"}
	count({f | some f in found; f.id == "TASK-21"}) == 1
	count({f | some f in found; f.id == "TASK-22"}) == 1
}

test_task_25_include_flags if {
	include := {"taskfile": "taskfiles/tools/yamllint.Taskfile.yml", "optional": true}
	found := fragments.findings with input as wrapped_repo({}, include, wrapper, calls_wrapper)
	messages(found, "TASK-25") == {
		concat("", [
			`include "tool-yamllint" loads tool wrapper "taskfiles/tools/yamllint.Taskfile.yml" without flatten: true, `,
			"so its tasks answer to a namespace on top of the tool: name they already carry; set flatten: true",
		]),
		concat("", [
			`include "tool-yamllint" loads tool wrapper "taskfiles/tools/yamllint.Taskfile.yml" without internal: true, `,
			"so its tasks are listed and can be run around the area tasks that should call them; set internal: true",
		]),
		concat("", [
			`include "tool-yamllint" of tool wrapper "taskfiles/tools/yamllint.Taskfile.yml" sets optional:, `,
			"so a fragment that goes missing drops its tasks without a word; remove it",
		]),
	}
}

test_task_25_task_names if {
	doc := {"version": "3", "tasks": {
		"tool:yamllint": {"desc": "Lint."},
		"tool:yamllint:fix": {"desc": "Fix."},
		"tool:yamllint-extra": {"desc": "Other."},
		"yaml": {"desc": "Lint."},
	}}
	found := fragments.findings with input as wrapped_repo({}, wrapper_include, doc, calls_wrapper)
	messages(found, "TASK-25") == {wrapper_name_message("tool:yamllint-extra"), wrapper_name_message("yaml")}
}

wrapper_name_message(name) := sprintf(
	concat("", [
		"task %q in the wrapper for yamllint is not named for its tool; name it \"tool:yamllint\", ",
		"or \"tool:yamllint:<detail>\" for a second way to run it",
	]),
	[name],
)

test_task_26_binary_outside_its_wrapper if {
	root_tasks := {"lint:yaml": {"desc": "Lint YAML.", "cmds": [
		"NO_COLOR=1 yamllint --strict .",
		"uv run yamllint .",
		"{{.RUN}} yamllint .",
		"echo yamllint",
		"git ls-files | xargs yamllint",
	]}}
	found := fragments.findings with input as wrapped_repo(root_tasks, wrapper_include, wrapper, calls_wrapper)
	messages(found, "TASK-26") == {concat("", [
		`task "lint:yaml" runs yamllint directly, while taskfiles/tools/yamllint.Taskfile.yml holds how it runs; `,
		"call task: tool:yamllint instead, so its configuration, flags and cache sources stay in one place",
	])}
}

test_task_26_needs_a_wrapper if {
	lint_doc := {"version": "3", "tasks": {"lint": {"desc": "Lint.", "cmds": ["yamllint ."]}}}
	found := fragments.findings with input as fragment_repo(conforming.includes, lint_doc, lint_text, {})
	not "TASK-26" in td.ids(found)
}

test_task_27_tasks_named_for_their_area if {
	lint_doc := {"version": "3", "tasks": {
		"lint": {"desc": "Lint.", "cmds": [{"task": "tool:yamllint"}]},
		"lint:md": {"desc": "Lint Markdown."},
		"linter": {"desc": "Not under lint."},
		"secrets:scan": {"desc": "Scan."},
		"_helper": {"internal": true},
		"helper": {"internal": true},
	}}
	found := fragments.findings with input as wrapped_repo({}, wrapper_include, wrapper, lint_doc)
	messages(found, "TASK-27") == {area_message("linter"), area_message("secrets:scan")}
}

area_message(name) := sprintf(
	concat("", [
		"task %q is in the lint fragment but not named under its area, so its name does not say which file ",
		"holds it; rename it \"lint\" or \"lint:<name>\", or move it to the fragment its name gives",
	]),
	[name],
)

test_task_27_skips_a_namespaced_fragment_beside_flattened_ones if {
	lint_doc := {"version": "3", "tasks": {"lint": {"desc": "Lint."}}}
	includes := object.union(conforming.includes, {"docs": "taskfiles/docs.Taskfile.yml"})
	extra := {"taskfiles/docs.Taskfile.yml": {"version": "3", "tasks": {"build": {"desc": "Docs."}}}}
	found := fragments.findings with input as fragment_repo(includes, lint_doc, lint_text, extra)
	not "TASK-27" in td.ids(found)
}

test_task_27_only_flattened_fragments if {
	lint_doc := {"version": "3", "tasks": {"md": {"desc": "Lint Markdown."}}}
	namespaced := {"lint": "taskfiles/lint.Taskfile.yml"}
	found := fragments.findings with input as fragment_repo(namespaced, lint_doc, lint_text, {})
	not "TASK-27" in td.ids(found)
}

test_task_18_leaves_cached_wrapper_tasks_loud if {
	doc := {"version": "3", "tasks": {
		"tool:yamllint": {"desc": "Lint.", "cmds": [{"task": "tool:yamllint:all"}]},
		"tool:yamllint:all": {
			"desc": "Lint every YAML file.", "method": "checksum",
			"sources": ["**/*.yml"], "cmds": ["yamllint ."],
		},
	}}
	found := fragments.findings with input as wrapped_repo({}, wrapper_include, doc, calls_wrapper)
	not "TASK-18" in td.ids(found)
}
