# METADATA
# title: Taskfile fragments and output
# description: >-
#   A fragment's tasks say what they do (TASK-18, TASK-19); a Taskfile that
#   flattens its fragments includes them alike, and each keeps to itself and
#   names its area (TASK-20 to TASK-22). Where a Taskfile opts into prefixed
#   output, silent tasks are labeled and long-running ones are silent
#   (TASK-23, TASK-24). A tool wrapper is included flattened and internal and
#   names its tasks for its tool (TASK-25), a wrapped tool runs only in its
#   wrapper (TASK-26), and a flattened fragment's public tasks are named
#   under its area (TASK-27).
# scope: package
# custom:
#   convention: EC-0015
package conventions.checks.tasks.taskfile_fragments

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.taskfile_layers as layers
import data.conventions.lib.taskfiles

# TASK-18. A silent task with commands of its own says what it does.
findings contains lib.finding("TASK-18", path, message) if {
	some path, _ in layers.all_fragments
	some name, task in taskfiles.tasks(path)
	taskfiles.silent(path, task)
	count(taskfiles.command_lines(task)) > 0
	not taskfiles.echoes(task)
	message := sprintf(
		concat(" ", [
			"task %q is silent, so Task prints none of its commands, and it echoes nothing either;",
			"add an echo line saying what it is doing",
		]),
		[name],
	)
}

# TASK-18. An internal task that runs commands of its own is silent.
findings contains lib.finding("TASK-18", path, message) if {
	some path, _ in layers.all_fragments
	some name, task in taskfiles.tasks(path)
	taskfiles.is_internal(task)
	count(taskfiles.shell_lines(task)) > 0
	not taskfiles.silent(path, task)
	message := sprintf(
		concat(" ", [
			"internal task %q runs commands of its own but is not silent, so Task prints each command",
			"line it runs; set silent: true and echo what it is doing",
		]),
		[name],
	)
}

# TASK-19. A composite: every command a task: call or a line that only
# prints, with at least one call.
findings contains lib.finding("TASK-19", path, message) if {
	some path, _ in layers.all_fragments
	some name, task in taskfiles.tasks(path)
	composite(task)
	some item in task.cmds
	text := taskfiles.command_text(item)
	message := sprintf(
		concat(" ", [
			"task %q only calls other tasks, yet adds %q; the tasks it calls say what they do,",
			"so remove the echo",
		]),
		[name, trim_space(text)],
	)
}

# TASK-20. Only a Taskfile that flattens one fragment is held to flattening
# them all.
findings contains lib.finding("TASK-20", include.from, message) if {
	some include in taskfiles.fragment_includes
	taskfiles.flattens_fragments(include.from)
	not include.entry.flatten == true
	message := sprintf(
		concat(" ", [
			"include %q loads fragment %q without flatten: true, while this Taskfile flattens its",
			"other fragments; set flatten: true, so each task is called by the name its fragment gives it",
		]),
		[include.namespace, include.entry.taskfile],
	)
}

findings contains lib.finding("TASK-20", include.from, message) if {
	some include in taskfiles.fragment_includes
	taskfiles.flattens_fragments(include.from)
	some key, consequence in include_keys
	key in object.keys(include.entry)
	message := sprintf("include %q of fragment %q sets %s:, so %s; remove it", [
		include.namespace, include.entry.taskfile, key, consequence,
	])
}

# TASK-21
findings contains lib.finding("TASK-21", path, message) if {
	some path, _ in layers.layout_fragments
	some key, consequence in fragment_keys
	key in object.keys(taskfiles.documents[path])
	message := sprintf("the fragment declares a top-level %s:, %s", [key, consequence])
}

# TASK-22. Read from the raw text: a comment before the tasks: key.
findings contains lib.finding("TASK-22", path, message) if {
	some path, area in layers.layout_fragments
	text := files.texts[path]
	not names_area(header_comment(text), area)
	message := sprintf(
		concat(" ", [
			"the fragment has no comment above its tasks that names its area, %q; open it with one",
			"saying what the %s tasks are for",
		]),
		[area, area],
	)
}

# TASK-23
findings contains lib.finding("TASK-23", path, message) if {
	some path, _ in taskfiles.documents
	taskfiles.prefixed(path)
	some name, task in taskfiles.tasks(path)
	taskfiles.silent(path, task)
	not "prefix" in object.keys(task)
	message := sprintf(
		"task %q is silent in prefixed output and sets no prefix; add a kebab-case prefix, such as %q",
		[name, suggested_prefix(name)],
	)
}

findings contains lib.finding("TASK-23", path, message) if {
	some path, _ in taskfiles.documents
	taskfiles.prefixed(path)
	some name, task in taskfiles.tasks(path)
	taskfiles.silent(path, task)
	is_string(task.prefix)
	not contains(task.prefix, "{{")
	not regex.match(prefix_pattern, task.prefix)
	message := sprintf(
		"task %q has prefix %q, which is not kebab-case; use lowercase words joined by hyphens, such as %q",
		[name, task.prefix, taskfiles.kebab(task.prefix)],
	)
}

# TASK-24
findings contains lib.finding("TASK-24", path, message) if {
	some path, _ in taskfiles.documents
	taskfiles.prefixed(path)
	some name, task in taskfiles.tasks(path)
	long_running(name, task)
	count(taskfiles.command_lines(task)) > 0
	not taskfiles.silent(path, task)
	message := sprintf(
		concat(" ", [
			"task %q starts a long-running process in prefixed output but is not silent, so Task",
			"prints its whole command line ahead of the process's own output; set silent: true and",
			"echo what it starts",
		]),
		[name],
	)
}

# TASK-25. A wrapper is included flattened and internal.
findings contains lib.finding("TASK-25", include.from, message) if {
	some include in layers.wrapper_includes
	some key, consequence in wrapper_flags
	not include.entry[key] == true
	message := sprintf("include %q loads tool wrapper %q without %s: true, so %s; set %s: true", [
		include.namespace, include.entry.taskfile, key, consequence, key,
	])
}

findings contains lib.finding("TASK-25", include.from, message) if {
	some include in layers.wrapper_includes
	some key, consequence in include_keys
	key != "internal"
	key in object.keys(include.entry)
	message := sprintf("include %q of tool wrapper %q sets %s:, so %s; remove it", [
		include.namespace, include.entry.taskfile, key, consequence,
	])
}

# TASK-25. A wrapper's tasks are named tool:<stem> or tool:<stem>:<detail>.
findings contains lib.finding("TASK-25", path, message) if {
	some path, stem in layers.wrappers
	some name, _ in taskfiles.tasks(path)
	not wrapper_task_name(name, stem)
	message := sprintf(
		concat(" ", [
			"task %q in the wrapper for %s is not named for its tool; name it %q, or",
			"%q for a second way to run it",
		]),
		[name, stem, concat(":", ["tool", stem]), concat(":", ["tool", stem, "<detail>"])],
	)
}

# TASK-26. Once a tool has a wrapper, no other Taskfile starts its binary.
findings contains lib.finding("TASK-26", path, message) if {
	some path, _ in taskfiles.documents
	some name, task in taskfiles.tasks(path)
	some line in taskfiles.shell_lines(task)
	tool := layers.program(line)
	wrapper := layers.wrapped_tools[tool]
	wrapper != path
	layers.callable_from(path, wrapper)
	message := sprintf(
		concat(" ", [
			"task %q runs %s directly, while %s holds how it runs; call task: %s instead, so its",
			"configuration, flags and cache sources stay in one place",
		]),
		[name, tool, wrapper, concat(":", ["tool", tool])],
	)
}

# TASK-27. A flattened area fragment's public tasks are named under its
# area; a namespaced one's names already carry its namespace.
findings contains lib.finding("TASK-27", path, message) if {
	some include in taskfiles.fragment_includes
	include.entry.flatten == true
	path := taskfiles.target(include)
	area := taskfiles.fragments[path]
	some name, task in taskfiles.tasks(path)
	not startswith(name, "_")
	not taskfiles.is_internal(task)
	not under_area(name, area)
	message := sprintf(
		concat(" ", [
			"task %q is in the %s fragment but not named under its area, so its name does not say",
			"which file holds it; rename it %q or %q, or move it to the fragment its name gives",
		]),
		[name, area, area, concat(":", [area, "<name>"])],
	)
}

wrapper_flags := {
	"flatten": "its tasks answer to a namespace on top of the tool: name they already carry",
	"internal": "its tasks are listed and can be run around the area tasks that should call them",
}

wrapper_task_name(name, stem) if name == concat(":", ["tool", stem])

wrapper_task_name(name, stem) if {
	startswith(name, concat("", ["tool:", stem, ":"]))
	count(name) > count(stem) + 6
}

under_area(name, area) if name == area

under_area(name, area) if startswith(name, concat("", [area, ":"]))

# A task that only calls other tasks and prints: every cmds item a task:
# call or text that only prints, at least one of each.
composite(task) if {
	is_object(task)
	is_array(task.cmds)
	some call in task.cmds
	taskfiles.called(call)
	some line in task.cmds
	only_prints(line)
	every item in task.cmds {
		calls_or_prints(item)
	}
}

calls_or_prints(item) if taskfiles.called(item)

calls_or_prints(item) if only_prints(item)

only_prints(item) if {
	text := taskfiles.command_text(item)
	lines := [line | some raw in split(text, "\n"); line := trim_space(raw); line != ""]
	count(lines) > 0
	every line in lines {
		taskfiles.printed(line)
	}
}

include_keys := {
	"optional": "a fragment that goes missing drops its tasks without a word",
	"dir": "its tasks run somewhere other than every other fragment's, from the same Taskfile",
	"internal": concat(" ", [
		"every task in it is hidden and cannot be run; only a tool wrapper under taskfiles/tools/",
		"is included internal",
	]),
}

fragment_keys := {
	"vars": concat(" ", [
		"which Task merges into the scope of every Taskfile, so a name here can change what a",
		"task elsewhere runs; move them to the including Taskfile or into the tasks that use them",
	]),
	"env": concat(" ", [
		"which Task merges into the environment of every Taskfile's tasks; move it to the",
		"including Taskfile or into the tasks that use it",
	]),
	"dotenv": "which Task refuses in an included Taskfile; move it to the including Taskfile",
	"includes": concat(" ", [
		"so where a task is defined, and the name it answers to, depend on a second level of",
		"includes; include each Taskfile from the including Taskfile instead",
	]),
}

# The comment lines before the tasks: key, joined.
header_comment(text) := concat("\n", [trim_space(trim_left(trim_space(line), "#")) |
	some line in split(regex.split(`(?m)^tasks:`, text)[0], "\n")
	startswith(trim_space(line), "#")
])

names_area(comment, area) if contains(lower(comment), lower(area))

names_area(comment, area) if contains(lower(comment), replace(lower(area), "-", " "))

prefix_pattern := `^[a-z0-9]+(-[a-z0-9]+)*$`

suggested_prefix(name) := taskfiles.kebab(replace(trim_prefix(name, "_"), ":", "-"))

# A task that runs until it is stopped: its last name segment, or an
# alias's, is dev, serve or watch.
long_running(name, task) if {
	some each in array.concat([name], taskfiles.aliases(task))
	is_string(each)
	regex.match(`(^|:)(dev|serve|watch)$`, each)
}
