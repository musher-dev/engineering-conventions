# METADATA
# title: Taskfiles
# description: >-
#   The repository's Taskfiles as Task reads them: each file's tasks, the
#   includes that join the files into one graph, the directories each file's
#   relative paths resolve from, and the task names the root Taskfile
#   exposes once its includes are merged (EC-0015, EC-0016).
package conventions.lib.taskfiles

import data.conventions.lib.files

# The names Task looks for, in the order it looks for them
# (https://taskfile.dev/docs/guide#supported-file-names).
default_names := [
	"Taskfile.yml", "taskfile.yml", "Taskfile.yaml", "taskfile.yaml",
	"Taskfile.dist.yml", "taskfile.dist.yml", "Taskfile.dist.yaml", "taskfile.dist.yaml",
]

# The Taskfiles bin/conventions passes to conftest that this library reads:
# one at the root or up to two directories deep, and the YAML files in a
# taskfiles/ directory at those depths.
path_pattern := `^([^/]+/){0,2}([Tt]askfile(\.dist)?\.ya?ml|taskfiles/[^/]+\.ya?ml)$`

# Every Taskfile outside the fixtures. A YAML file under taskfiles/ counts
# only when it has a Taskfile's top-level keys.
documents[doc.path] := doc.contents if {
	some doc in files.own_documents
	regex.match(path_pattern, doc.path)
	is_object(doc.contents)
	some key in ["version", "tasks", "includes"]
	key in object.keys(doc.contents)
}

# The root Taskfile: the first default name at the repository root.
root_path := [name | some name in default_names; name in files.repository_files][0]

default tasks(_) := {}

tasks(path) := documents[path].tasks if is_object(documents[path].tasks)

default vars(_) := {}

vars(value) := value.vars if is_object(value.vars)

default env(_) := {}

env(value) := value.env if is_object(value.env)

# The directory a path sits in; "" for the repository root.
dir(path) := regex.replace(path, `/?[^/]*$`, "")

# base joined with a relative path, with `.` and `..` segments resolved.
# Undefined when the result would leave the repository.
join(base, rel) := clean(concat("/", [base, rel]))

clean(path) := result if {
	flat := regex.replace(concat("", ["/", path, "/"]), `/(\.?/)+`, "/")
	up := `/([^/.][^/]*|\.[^/.][^/]*|\.\.[^/]+)/\.\./`
	once := regex.replace(regex.replace(flat, up, "/"), up, "/")
	result := trim(regex.replace(regex.replace(once, up, "/"), up, "/"), "/")
	not regex.match(`(^|/)\.\.(/|$)`, result)
}

# A path the repository holds, as a file or a directory; "" is its root.
exists("") := true

exists(path) if path in files.repository_files

exists(path) if path in files.directories

# An include as {"taskfile": ...}, whichever form it was written in.
entry(spec) := {"taskfile": spec} if is_string(spec)

entry(spec) := spec if is_object(spec)

# A path Task resolves from the repository: no template, URL, home or
# absolute path.
local_path(value) if {
	is_string(value)
	value != ""
	not contains(value, "{{")
	not regex.match(`^([A-Za-z][A-Za-z0-9+.-]*://|git@|~|/)`, value)
}

# Every include, as {from, namespace, entry, path}: path is where the entry's
# taskfile points, resolved from the including file's directory.
includes contains {"from": from, "namespace": namespace, "entry": included, "path": path} if {
	some from, taskfile in documents
	is_object(taskfile.includes)
	some namespace, spec in taskfile.includes
	included := entry(spec)
	local_path(included.taskfile)
	path := join(dir(from), included.taskfile)
}

# The Taskfile an include loads: the file it names, or the default Taskfile
# in the directory it names.
target(include) := loads[include.path]

loads[path] := path if {
	some include in includes
	path := include.path
	path in files.repository_files
}

loads[path] := file if {
	some include in includes
	path := include.path
	not path in files.repository_files
	candidates := [name |
		some default_name in default_names
		name := concat("/", [path, default_name])
		name in files.repository_files
	]
	file := candidates[0]
}

edges[path] := {target(include) |
	some include in includes
	include.from == path
} if {
	some path, _ in documents
}

reverse_edges[path] := {include.from |
	some include in includes
	target(include) == path
} if {
	some path, _ in documents
}

# A Taskfile no other Taskfile includes: Task is run from it.
entry_points contains path if {
	some path, _ in documents
	count(reverse_edges[path]) == 0
}

# An include written as a bare string, such as `lint: taskfiles/lint.yml`.
string_form(include) if is_string(documents[include.from].includes[include.namespace])

# The includes whose tasks keep running where the including file's tasks
# run: those written as a bare string. A map without a dir: sets one.
plain_edges[path] := {target(include) |
	some include in includes
	include.from == path
	string_form(include)
} if {
	some path, _ in documents
}

# The directories a Taskfile's paths resolve from, as {root, work}: root is
# its ROOT_DIR, the directory of the Taskfile Task is run from, and work is
# the directory its tasks run in. A file reached from several entry points,
# or through several includes, has several.
#
# An included file written as a bare string runs where the including file's
# tasks run, which at the top is the entry Taskfile's directory.
contexts[path] contains {"root": dir(root), "work": dir(root)} if {
	some path, _ in documents
	some root in entry_points
	path in graph.reachable(plain_edges, {root})
}

# An include written as a map runs the file it loads, and every file that
# file includes as a bare string, in its own directory: its dir: resolved
# from the including file's directory, or without one the including file's
# directory itself. A templated dir: is not resolved, so the files under it
# get no context from that include.
contexts[path] contains {"root": dir(root), "work": work} if {
	some include in includes
	work := map_work(include)
	some path in graph.reachable(plain_edges, {target(include)})
	documents[path]
	some root in entry_points
	include.from in graph.reachable(edges, {root})
}

map_work(include) := join(dir(include.from), include.entry.dir) if {
	not string_form(include)
	local_path(include.entry.dir)
}

map_work(include) := dir(include.from) if {
	not string_form(include)
	not "dir" in object.keys(include.entry)
}

# The Taskfiles that include path, directly or not, and path itself.
ancestors(path) := graph.reachable(reverse_edges, {path})

# Where a literal path in a Taskfile points, for each directory it may run
# from. Empty for a value that is not a plain path.
resolutions(path, value) := {resolved |
	some context in object.get(contexts, path, set())
	resolved := anchored(path, context, value)
}

anchored(_, context, "{{.ROOT_DIR}}") := context.root

anchored(path, _, "{{.TASKFILE_DIR}}") := dir(path)

anchored(_, context, value) := join(context.root, rest) if {
	rest := trim_prefix(value, "{{.ROOT_DIR}}/")
	rest != value
	literal(rest)
}

anchored(path, _, value) := join(dir(path), rest) if {
	rest := trim_prefix(value, "{{.TASKFILE_DIR}}/")
	rest != value
	literal(rest)
}

anchored(_, context, value) := join(context.work, value) if literal(value)

# A relative path with no template, glob, variable or space in it.
literal(value) if {
	regex.match(`^[A-Za-z0-9._@+-][A-Za-z0-9._/@+-]*$`, value)
}

# A path value that names nothing the repository holds, from every directory
# it may run from.
missing(path, value) if {
	candidates := resolutions(path, value)
	count(candidates) > 0
	every candidate in candidates {
		not exists(candidate)
	}
}

# A path value whose directory the repository does not hold, from every
# directory it may run from: for a file a task may write, such as an ignored
# local .env, only its directory can be checked.
missing_directory(path, value) if {
	candidates := resolutions(path, value)
	count(candidates) > 0
	every candidate in candidates {
		not exists(dir(candidate))
	}
}

# The task a cmds or deps item calls; a string deps item is a task name.
called(item) := item.task if is_string(item.task)

called(item) := item.defer.task if is_string(item.defer.task)

called_dep(item) := item if is_string(item)

called_dep(item) := called(item) if is_object(item)

# Every task name a task in any Taskfile calls, without a leading `:`.
calls contains trim_prefix(name, ":") if {
	some path, _ in documents
	some task in tasks(path)
	is_object(task)
	some item in object.get(task, "cmds", [])
	is_object(item)
	name := called(item)
}

calls contains trim_prefix(name, ":") if {
	some path, _ in documents
	some task in tasks(path)
	is_object(task)
	some item in object.get(task, "deps", [])
	name := called_dep(item)
}

# A task name that some call reaches, directly or through a namespace.
called_name(name) if name in calls

called_name(name) if {
	some call in calls
	endswith(call, concat("", [":", name]))
}

is_internal(task) if {
	is_object(task)
	task.internal == true
}

default aliases(_) := []

aliases(value) := value.aliases if is_array(value.aliases)

# The names a Taskfile's own public tasks answer to: each name and alias.
own_names(path) := {name |
	some task_name, task in tasks(path)
	not is_internal(task)
	some name in array.concat([task_name], aliases(task))
	is_string(name)
}

# The includes of path whose tasks can be called: not internal, and loading
# a Taskfile this check can read.
visible(path) := [include |
	some include in includes
	include.from == path
	not include.entry.internal == true
	documents[target(include)]
]

# The names a task gets once included: its own under flatten, else prefixed
# by the namespace and each of the include's aliases.
composed(include, name) := {name} if {
	include.entry.flatten == true
	not name in object.get(include.entry, "excludes", [])
}

composed(include, name) := {concat(":", [namespace, name]) |
	some namespace in array.concat([include.namespace], aliases(include.entry))
} if {
	not include.entry.flatten == true
	not name in object.get(include.entry, "excludes", [])
}

# The names a Taskfile exposes, through includes up to three levels deep.
names_1(path) := own_names(path) | {name |
	some include in visible(path)
	some own in own_names(target(include))
	some name in composed(include, own)
}

names_2(path) := own_names(path) | {name |
	some include in visible(path)
	some inner in names_1(target(include))
	some name in composed(include, inner)
}

exposed(path) := own_names(path) | {name |
	some include in visible(path)
	some inner in names_2(target(include))
	some name in composed(include, inner)
}

# The task names `task <name>` runs from the repository root.
default root_names := set()

root_names := exposed(root_path)

# The shell a task runs: a task written as a string or a list of strings, or
# each string of its cmds, each cmds item's cmd, and its own cmd.
default commands(_) := []

commands(task) := [task] if is_string(task)

commands(task) := [item | some item in task; is_string(item)] if is_array(task)

commands(task) := array.concat(
	[text | some item in object.get(task, "cmds", []); text := command_text(item)],
	[task.cmd | is_string(task.cmd)],
) if {
	is_object(task)
}

command_text(item) := item if is_string(item)

command_text(item) := item.cmd if is_string(item.cmd)

# The lines a task's shell runs: comment lines dropped and backslash
# continuations joined.
shell_lines(task) := [line |
	some text in commands(task)
	joined := regex.replace(text, `[ \t]*\\\r?\n[ \t]*`, " ")
	some raw in split(joined, "\n")
	line := trim_space(raw)
	line != ""
	not startswith(line, "#")
]

# The lines a task's shell runs as commands: a line that only prints text
# (echo, printf) left out, since a command a task shows its reader is not
# one it runs.
command_lines(task) := [line |
	some line in shell_lines(task)
	not printed(line)
]

# A task that tells its reader what it does: one of its lines starts with
# echo or printf.
echoes(task) if {
	some line in shell_lines(task)
	regex.match(`^(echo|printf)(\s|$)`, line)
}

# A task whose commands Task does not print: it sets silent: true, or its
# Taskfile does and the task does not set silent: false.
silent(_, task) if {
	is_object(task)
	task.silent == true
}

silent(path, task) if {
	documents[path].silent == true
	not task.silent == false
}

# A fragment: a Taskfile named <area>.Taskfile.yml in a taskfiles/
# directory, which another Taskfile includes. Each is mapped to its area.
fragment_pattern := `^([^/]+/){0,2}taskfiles/([^/]+)\.Taskfile\.ya?ml$`

fragments[path] := area if {
	some include in includes
	path := target(include)
	documents[path]
	some match in regex.find_all_string_submatch_n(fragment_pattern, path, 1)
	area := match[2]
}

# The includes that load one of the includer's own fragments: one in the
# taskfiles/ directory beside it. A shared fragment elsewhere, included under
# a namespace, is not part of the set the includer flattens.
fragment_includes contains include if {
	some include in includes
	path := target(include)
	fragments[path]
	parent(path) == concat("/", array.concat(parent_parts(include.from), ["taskfiles"]))
}

parent_parts(path) := array.slice(parts, 0, count(parts) - 1) if parts := split(path, "/")

parent(path) := concat("/", parent_parts(path))

# A Taskfile that flattens at least one fragment into itself.
flattens_fragments(from) if {
	some include in fragment_includes
	include.from == from
	include.entry.flatten == true
}

# The fragments of a Taskfile that flattens fragments, each mapped to its
# area: the set the fragment layout requirements hold to one shape.
flattened_fragments[path] := fragments[path] if {
	some include in fragment_includes
	flattens_fragments(include.from)
	path := target(include)
}

printed(line) if {
	regex.match(`^(echo|printf)(\s|$)`, line)
	not regex.match(`(&&|\|\||;)`, regex.replace(line, `"[^"]*"|'[^']*'`, ""))
}

# The task names a task calls through task: items in cmds and deps.
called_by(task) := {trim_prefix(name, ":") |
	is_object(task)
	some item in object.get(task, "cmds", [])
	is_object(item)
	name := called(item)
} | {trim_prefix(name, ":") |
	is_object(task)
	some item in object.get(task, "deps", [])
	name := called_dep(item)
}

# A task's own prompt.
prompted(task) if {
	is_object(task)
	is_string(task.prompt)
	trim_space(task.prompt) != ""
}

prompted(task) if {
	is_object(task)
	is_array(task.prompt)
	count(task.prompt) > 0
}

# A call that reaches name, directly or through a namespace.
called_as(called, name) if called == name

called_as(called, name) if endswith(called, concat("", [":", name]))

# A Taskfile in the prefixed output mode: it, or a Taskfile that includes it,
# sets output: prefixed.
prefixed(path) if {
	some ancestor in ancestors(path)
	documents[ancestor].output == "prefixed"
}

# A name in kebab-case: camelCase split, and underscores, dots and spaces
# turned to hyphens.
kebab(name) := lower(trim(regex.replace(regex.replace(name, `([a-z0-9])([A-Z])`, "${1}-${2}"), `[_. ]+`, "-"), "-"))
