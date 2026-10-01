package conventions.lib.taskfiles_test

import data.conventions.lib.taskfiles
import data.conventions.lib.testdata_test as td

root := {
	"version": "3",
	"includes": {
		"lint": {"taskfile": "taskfiles/lint.Taskfile.yml", "flatten": true},
		"docs": {"taskfile": "./docs", "aliases": ["d"], "excludes": ["hidden"]},
		"secret": {"taskfile": "taskfiles/secret.yml", "internal": true},
		"remote": "https://example.com/Taskfile.yml",
	},
	"tasks": {
		"check": {"desc": "Check.", "aliases": ["c"], "cmds": [{"task": "lint"}]},
		"_helper": {"internal": true},
	},
}

lint := {"version": "3", "tasks": {"lint": {"desc": "Lint.", "deps": ["_fmt", {"task": ":docs:build"}]}}}

docs := {
	"version": "3",
	"includes": {"api": "../api"},
	"tasks": {"build": {"desc": "Build."}, "hidden": {"desc": "Hidden."}},
}

api := {"version": "3", "tasks": {"serve": {"desc": "Serve.", "cmds": [{"defer": {"task": "stop"}}]}}}

repository := [
	td.inventory([
		"Taskfile.yml", "taskfiles/lint.Taskfile.yml", "taskfiles/secret.yml",
		"docs/Taskfile.yml", "api/Taskfile.yaml", "README.md",
	]),
	td.file("Taskfile.yml", root),
	td.file("taskfiles/lint.Taskfile.yml", lint),
	td.file("taskfiles/secret.yml", {"version": "3", "tasks": {"reveal": {"desc": "Reveal."}}}),
	td.file("taskfiles/data.yml", {"items": []}),
	td.file("docs/Taskfile.yml", docs),
	td.file("api/Taskfile.yaml", api),
]

test_documents_are_taskfiles_only if {
	object.keys(taskfiles.documents) == {
		"Taskfile.yml", "taskfiles/lint.Taskfile.yml", "taskfiles/secret.yml",
		"docs/Taskfile.yml", "api/Taskfile.yaml",
	} with input as repository
}

test_root_path_follows_task_order if {
	taskfiles.root_path == "Taskfile.yml" with input as [td.inventory(["taskfile.yaml", "Taskfile.yml"])]
	taskfiles.root_path == "taskfile.yaml" with input as [td.inventory(["taskfile.yaml"])]
	not taskfiles.root_path with input as [td.inventory(["docs/Taskfile.yml"])]
}

test_paths_join_and_clean if {
	taskfiles.dir("a/b/Taskfile.yml") == "a/b"
	taskfiles.dir("Taskfile.yml") == ""
	taskfiles.join("docs", "../api") == "api"
	taskfiles.join("", "./taskfiles/x.yml") == "taskfiles/x.yml"
	taskfiles.join("a/b", "../../c") == "c"
	not taskfiles.join("", "../outside")
}

test_includes_resolve_files_and_directories if {
	targets := {[include.namespace, taskfiles.target(include)] |
		some include in taskfiles.includes
	} with input as repository
	targets == {
		["lint", "taskfiles/lint.Taskfile.yml"],
		["docs", "docs/Taskfile.yml"],
		["secret", "taskfiles/secret.yml"],
		["api", "api/Taskfile.yaml"],
	}
}

test_entry_points_and_contexts if {
	taskfiles.entry_points == {"Taskfile.yml"} with input as repository
	taskfiles.contexts["api/Taskfile.yaml"] == {{"root": "", "work": ""}} with input as repository
	ancestors := {"api/Taskfile.yaml", "docs/Taskfile.yml", "Taskfile.yml"}
	taskfiles.ancestors("api/Taskfile.yaml") == ancestors with input as repository
}

# The root includes x/Taskfile.yml with dir: x, and it includes a fragment
# without a dir: of its own, so both run in x/.
dir_include(dir) := nested_include(dir, "taskfiles/fragment.yml")

nested_include(dir, fragment) := [
	td.inventory([
		"Taskfile.yml", "x/Taskfile.yml", "x/taskfiles/fragment.yml",
		"x/.config/foo.yml", ".config/bar.yml",
	]),
	td.file("Taskfile.yml", {"version": "3", "includes": {"x": {"taskfile": "./x", "dir": dir}}}),
	td.file("x/Taskfile.yml", {"version": "3", "includes": {"fragment": fragment}}),
	td.file("x/taskfiles/fragment.yml", {"version": "3", "vars": {"FOO_CONFIG": ".config/foo.yml"}}),
]

test_an_include_with_a_dir_moves_its_fragments if {
	context := {"root": "", "work": "x"}
	taskfiles.contexts["x/Taskfile.yml"] == {context} with input as dir_include("x")
	taskfiles.contexts["x/taskfiles/fragment.yml"] == {context} with input as dir_include("x")
	fragment := "x/taskfiles/fragment.yml"
	taskfiles.resolutions(fragment, ".config/foo.yml") == {"x/.config/foo.yml"} with input as dir_include("x")
	taskfiles.resolutions(fragment, "{{.ROOT_DIR}}/.config/bar.yml") == {".config/bar.yml"}
		with input as dir_include("x")
	taskfiles.resolutions(fragment, "{{.TASKFILE_DIR}}/a.yml") == {"x/taskfiles/a.yml"}
		with input as dir_include("x")
	not taskfiles.missing(fragment, ".config/foo.yml") with input as dir_include("x")
	taskfiles.missing(fragment, ".config/bar.yml") with input as dir_include("x")
}

test_a_dir_resolves_from_the_including_file if {
	taskfiles.contexts["x/taskfiles/fragment.yml"] == {{"root": "", "work": ""}} with input as dir_include(".")
	taskfiles.contexts["x/taskfiles/fragment.yml"] == {{"root": "", "work": "x/sub"}} with input as dir_include("x/sub")
}

test_a_nested_dir_resolves_from_its_own_includer if {
	nested := nested_include("x", {"taskfile": "taskfiles/fragment.yml", "dir": "taskfiles"})
	context := {"root": "", "work": "x/taskfiles"}
	taskfiles.contexts["x/taskfiles/fragment.yml"] == {context} with input as nested
}

# Under dir: y, a bare string include runs where its includer's tasks run,
# and a map include without dir: runs in its includer's own directory.
test_a_map_include_runs_in_its_includers_directory if {
	string_form := nested_include("y", "taskfiles/fragment.yml")
	taskfiles.contexts["x/taskfiles/fragment.yml"] == {{"root": "", "work": "y"}} with input as string_form
	map_form := nested_include("y", {"taskfile": "taskfiles/fragment.yml"})
	taskfiles.contexts["x/taskfiles/fragment.yml"] == {{"root": "", "work": "x"}} with input as map_form
}

top_level_include(fragment) := [
	td.inventory(["Taskfile.yml", "a/Taskfile.yml", "a/taskfiles/f.yml"]),
	td.file("Taskfile.yml", {"version": "3", "includes": {"a": "a/Taskfile.yml"}}),
	td.file("a/Taskfile.yml", {"version": "3", "includes": {"f": fragment}}),
	td.file("a/taskfiles/f.yml", {"version": "3", "tasks": {}}),
]

test_a_map_include_without_dir_below_the_root if {
	string_form := top_level_include("taskfiles/f.yml")
	taskfiles.contexts["a/Taskfile.yml"] == {{"root": "", "work": ""}} with input as string_form
	taskfiles.contexts["a/taskfiles/f.yml"] == {{"root": "", "work": ""}} with input as string_form
	map_form := top_level_include({"taskfile": "taskfiles/f.yml"})
	taskfiles.contexts["a/taskfiles/f.yml"] == {{"root": "", "work": "a"}} with input as map_form
}

test_a_templated_dir_is_not_resolved if {
	templated := dir_include("{{.ROOT_DIR}}/x")
	not taskfiles.contexts["x/Taskfile.yml"] with input as templated
	not taskfiles.contexts["x/taskfiles/fragment.yml"] with input as templated
	taskfiles.resolutions("x/taskfiles/fragment.yml", ".config/foo.yml") == set() with input as templated
	not taskfiles.missing("x/taskfiles/fragment.yml", "nowhere.yml") with input as templated
}

test_root_names_merge_includes if {
	taskfiles.root_names == {
		"check", "c", "lint",
		"docs:build", "d:build",
		"docs:api:serve", "d:api:serve",
	} with input as repository
}

test_root_names_empty_without_a_root if {
	taskfiles.root_names == set() with input as [td.inventory([])]
}

test_calls_from_cmds_deps_and_defer if {
	taskfiles.calls == {"lint", "_fmt", "docs:build", "stop"} with input as repository
	taskfiles.called_name("build") with input as repository
	not taskfiles.called_name("_helper") with input as repository
}

test_path_resolution if {
	taskfiles.resolutions("docs/Taskfile.yml", "{{.ROOT_DIR}}/README.md") == {"README.md"} with input as repository
	taskfiles.resolutions("docs/Taskfile.yml", "{{.TASKFILE_DIR}}/Taskfile.yml") == {"docs/Taskfile.yml"}
		with input as repository
	taskfiles.resolutions("docs/Taskfile.yml", "{{.ROOT_DIR}}") == {""} with input as repository
	taskfiles.resolutions("docs/Taskfile.yml", "{{.TASKFILE_DIR}}") == {"docs"} with input as repository
	taskfiles.resolutions("docs/Taskfile.yml", "{{.OTHER}}/x") == set() with input as repository
	taskfiles.resolutions("docs/Taskfile.yml", "src/**/*.go") == set() with input as repository
	not taskfiles.missing("docs/Taskfile.yml", "api") with input as repository
	taskfiles.missing("docs/Taskfile.yml", "nowhere.txt") with input as repository
	not taskfiles.missing("docs/Taskfile.yml", "{{.VAR}}") with input as repository
}

test_command_lines_drop_comments_and_printed_text if {
	task := {"cmds": [
		"# a note\ngo build \\\n  ./...",
		{"cmd": "echo \"done; see docs\""},
		"echo hi && rm -rf x",
		{"task": "lint"},
	]}
	taskfiles.command_lines(task) == ["go build ./...", "echo hi && rm -rf x"]
	taskfiles.command_lines("go vet ./...") == ["go vet ./..."]
	taskfiles.command_lines(["a", 1]) == ["a"]
	taskfiles.command_lines({"cmd": "make"}) == ["make"]
}

test_called_by if {
	taskfiles.called_by({"cmds": [{"task": ":lint"}, "x"], "deps": ["setup", {"task": "b"}]}) == {"lint", "setup", "b"}
}

test_fragments_are_included_area_files if {
	taskfiles.fragments == {"taskfiles/lint.Taskfile.yml": "lint"} with input as repository
	{include.namespace | some include in taskfiles.fragment_includes} == {"lint"} with input as repository
}

test_shell_lines_and_echoes if {
	task := {"cmds": ["# note", "echo 'start' \\\n  now", {"task": "x"}, {"cmd": "go build"}]}
	taskfiles.shell_lines(task) == ["echo 'start' now", "go build"]
	taskfiles.echoes(task)
	not taskfiles.echoes({"cmds": ["go build"]})
}

test_silent_from_the_task_or_its_taskfile if {
	taskfiles.silent("x", {"silent": true})
	quiet := [td.inventory(["Taskfile.yml"]), td.file("Taskfile.yml", {"version": "3", "silent": true, "tasks": {}})]
	taskfiles.silent("Taskfile.yml", {"cmds": ["go build"]}) with input as quiet
	taskfiles.silent("Taskfile.yml", "go build") with input as quiet
	not taskfiles.silent("Taskfile.yml", {"silent": false}) with input as quiet
	not taskfiles.silent("Taskfile.yml", {"cmds": ["go build"]}) with input as repository
}

test_flattened_fragments if {
	taskfiles.flattened_fragments == {"taskfiles/lint.Taskfile.yml": "lint"} with input as repository
	taskfiles.flattens_fragments("Taskfile.yml") with input as repository
	not taskfiles.flattens_fragments("docs/Taskfile.yml") with input as repository
}
