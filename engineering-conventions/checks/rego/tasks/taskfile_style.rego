# METADATA
# title: Taskfile style
# description: >-
#   Every Taskfile declares version '3' (TASK-01), names its variables in
#   UPPER_SNAKE (TASK-02) and its tasks in kebab-case with `:` namespaces
#   (TASK-03), writes templates without inner spaces (TASK-04), describes
#   every public task (TASK-05), calls every internal task (TASK-06), sets
#   prefix only where output is prefixed (TASK-07), and names only paths,
#   includes and sources that exist (TASK-08, TASK-09, TASK-14).
# scope: package
# custom:
#   convention: EC-0015
package conventions.checks.tasks.taskfile_style

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.taskfiles

# TASK-01
findings contains lib.finding("TASK-01", path, message) if {
	some path, taskfile in taskfiles.documents
	not taskfile.version == "3"
	message := version_message(taskfile)
}

# TASK-02. The variables a Taskfile defines: its global vars and env, and
# each task's.
findings contains lib.finding("TASK-02", path, message) if {
	some path, taskfile in taskfiles.documents
	some [where, name] in defined_names(path, taskfile)
	not regex.match(var_name_pattern, name)
	message := sprintf("%s %q is not UPPER_SNAKE; rename it %q and every reference to it", [
		where, name, upper_snake(name),
	])
}

# TASK-03. Names and aliases have the same form; a leading `_` marks a
# helper, which is then internal.
findings contains lib.finding("TASK-03", path, message) if {
	some path, _ in taskfiles.documents
	some task_name, task in taskfiles.tasks(path)
	some name in array.concat([task_name], taskfiles.aliases(task))
	is_string(name)
	not regex.match(task_name_pattern, name)
	message := sprintf(
		concat(" ", [
			"task name %q is not kebab-case; use lowercase words joined by hyphens, with `:`",
			"between a namespace and a name, such as %q",
		]),
		[name, kebab(name)],
	)
}

findings contains lib.finding("TASK-03", path, message) if {
	some path, _ in taskfiles.documents
	some name, task in taskfiles.tasks(path)
	startswith(name, "_")
	not taskfiles.is_internal(task)
	message := sprintf(
		"task %q starts with _, which marks an internal helper; add internal: true, or drop the _ if it is public",
		[name],
	)
}

# TASK-04. A trim marker ({{- and -}}) is not whitespace inside the delimiters.
findings contains lib.finding("TASK-04", path, message) if {
	some path, taskfile in taskfiles.documents
	some expression in spaced_templates(taskfile)
	message := sprintf("template %s has spaces inside its delimiters; write %s", [
		expression, tight(expression),
	])
}

# TASK-05. A `_` task without internal: true is TASK-03's.
findings contains lib.finding("TASK-05", path, message) if {
	some path, _ in taskfiles.documents
	some name, task in taskfiles.tasks(path)
	not startswith(name, "_")
	not taskfiles.is_internal(task)
	not described(task)
	message := sprintf("task %q has no desc; add a one-line desc so task --list shows what it does", [name])
}

# TASK-06
findings contains lib.finding("TASK-06", path, message) if {
	some path, _ in taskfiles.documents
	some name, task in taskfiles.tasks(path)
	taskfiles.is_internal(task)
	not taskfiles.called_name(name)
	message := sprintf(
		"internal task %q is called by no task; an internal task cannot be run on its own, so delete it or call it",
		[name],
	)
}

# TASK-07
findings contains lib.finding("TASK-07", path, message) if {
	some path, _ in taskfiles.documents
	some name, task in taskfiles.tasks(path)
	is_object(task)
	"prefix" in object.keys(task)
	not prefixed(path)
	message := sprintf(
		concat(" ", [
			"task %q sets prefix, but no Taskfile that loads it sets output: prefixed, the only",
			"mode that prints it; set output: prefixed, or remove the prefix",
		]),
		[name],
	)
}

# TASK-08
findings contains lib.finding("TASK-08", path, message) if {
	some path, taskfile in taskfiles.documents
	some [where, name, value] in path_vars(path, taskfile)
	not endswith(name, "_FILE")
	taskfiles.missing(path, value)
	message := sprintf(
		"%s %s is %q, which names no file or directory in the repository; %s",
		[where, name, value, missing_remedy(name)],
	)
}

# TASK-08. A file variable may name a file a task writes, so only its
# directory has to exist.
findings contains lib.finding("TASK-08", path, message) if {
	some path, taskfile in taskfiles.documents
	some [where, name, value] in path_vars(path, taskfile)
	endswith(name, "_FILE")
	taskfiles.missing_directory(path, value)
	message := sprintf(
		"%s %s is %q, whose directory the repository does not hold; correct the path, or delete the variable",
		[where, name, value],
	)
}

# TASK-09
findings contains lib.finding("TASK-09", include.from, message) if {
	some include in taskfiles.includes
	not include.entry.optional == true
	not taskfiles.target(include)
	message := sprintf(
		"include %q loads %q, which does not exist; Task refuses to run any task until it does, so correct the path",
		[include.namespace, include.entry.taskfile],
	)
}

# TASK-14. Globs match nothing legitimately before a first build; only a
# literal entry is judged.
findings contains lib.finding("TASK-14", path, message) if {
	some path, _ in taskfiles.documents
	some name, task in taskfiles.tasks(path)
	is_object(task)
	not "dir" in object.keys(task)
	some source in object.get(task, "sources", [])
	is_string(source)
	taskfiles.missing(path, source)
	message := sprintf(
		concat(" ", [
			"task %q lists source %q, which does not exist; Task ignores a source that matches",
			"nothing, so the task stops noticing changes to it; correct the path or remove it",
		]),
		[name, source],
	)
}

# TASK-15. `task` with no arguments runs the root Taskfile's default task, or
# the task that takes default as an alias.
findings contains lib.finding("TASK-15", path, message) if {
	path := taskfiles.root_path
	some name, task in taskfiles.tasks(path)
	answers_default(name, task)
	some offence in default_offences(task)
	message := sprintf(
		concat(" ", [
			"the default task %s, so a bare `task` does work; make default only list the tasks",
			"(task --list) or run a help task that does, and give that work a name of its own",
		]),
		[offence],
	)
}

# TASK-16. Counted in the Taskfile that declares the name; an include's
# namespace is the includer's choice and is not counted.
findings contains lib.finding("TASK-16", path, message) if {
	some path, _ in taskfiles.documents
	some task_name, task in taskfiles.tasks(path)
	some name in array.concat([task_name], taskfiles.aliases(task))
	is_string(name)
	segments := split(name, ":")
	count(segments) > max_segments
	message := sprintf(
		concat(" ", [
			"task name %q nests %d namespaces; a name has at most three namespaces before it,",
			"so join words with hyphens instead, such as %q",
		]),
		[name, count(segments) - 1, shallower(segments)],
	)
}

# TASK-17
findings contains lib.finding("TASK-17", path, message) if {
	some path, taskfile in taskfiles.documents
	some [where, value] in path_values(path, taskfile)
	some host_path in host_paths(value)
	message := sprintf(
		concat(" ", [
			"%s names %q, a path on one machine, so the task breaks in any other checkout,",
			"container or CI runner; write it from {{.ROOT_DIR}} or {{.TASKFILE_DIR}}",
		]),
		[where, host_path],
	)
}

# TASK-18. An internal task may leave the prompt to the task that calls it.
findings contains lib.finding("TASK-18", path, message) if {
	some path, _ in taskfiles.documents
	some name, task in taskfiles.tasks(path)
	not taskfiles.prompted(task)
	not prompted_caller(name, task)
	some loss in losses(name, task)
	message := sprintf(
		concat(" ", [
			"task %q %s and declares no prompt:, so one mistyped command loses what nothing in",
			"the repository can restore; add a prompt naming what is lost (a workflow passes --yes)",
		]),
		[name, loss],
	)
}

version_message(taskfile) := "the Taskfile has no version; add version: '3' as its first key" if {
	not "version" in object.keys(taskfile)
}

version_message(taskfile) := "version is the number 3; quote it as version: '3', the schema version Task reads" if {
	taskfile.version == 3
}

version_message(taskfile) := sprintf("version is %v; use version: '3', the only Taskfile schema Task supports", [
	taskfile.version,
]) if {
	"version" in object.keys(taskfile)
	not taskfile.version == 3
	not taskfile.version == "3"
}

var_name_pattern := `^[A-Z][A-Z0-9_]*$`

defined_names(path, taskfile) := {[where, name] |
	some block in ["vars", "env"]
	some name, _ in section(taskfile, block)
	where := sprintf("%s variable", [block_label(block)])
} | {[where, name] |
	some task_name, task in taskfiles.tasks(path)
	is_object(task)
	some block in ["vars", "env"]
	some name, _ in section(task, block)
	where := sprintf("task %q %s variable", [task_name, block_label(block)])
}

default section(_, _) := {}

section(value, key) := value[key] if is_object(value[key])

block_label("vars") := "global"

block_label("env") := "environment"

upper_snake(name) := upper(regex.replace(regex.replace(name, `([a-z0-9])([A-Z])`, "${1}_${2}"), `[^A-Za-z0-9]+`, "_"))

task_name_pattern := `^_?[a-z][a-z0-9-]*(:([a-z][a-z0-9-]*|\*))*$`

kebab(name) := lower(trim(regex.replace(regex.replace(name, `([a-z0-9])([A-Z])`, "${1}-${2}"), `[_. ]+`, "-"), "-"))

spaced_templates(taskfile) := {expression |
	walk(taskfile, [_, value])
	is_string(value)
	some expression in regex.find_n(`\{\{[^{}]*\}\}`, value, -1)
	regex.match(`^\{\{[ \t]|[ \t]\}\}$`, expression)
}

tight(expression) := regex.replace(regex.replace(expression, `^\{\{[ \t]+`, "{{"), `[ \t]+\}\}$`, "}}")

described(task) if {
	is_string(task.desc)
	trim_space(task.desc) != ""
}

prefixed(path) if {
	some ancestor in taskfiles.ancestors(path)
	taskfiles.documents[ancestor].output == "prefixed"
}

path_var_pattern := `_(DIR|FILE|CONFIG)$`

# TASK-08's remedy for a variable naming nothing.
default missing_remedy(_) := "correct the path, or delete the variable"

# A _DIR variable may name a directory a task creates, such as build output.
# The name then promises a directory the repository does not hold, so the
# remedy is a name for what the directory holds.
missing_remedy(name) := sprintf(
	"correct the path, delete the variable, or, if a task creates the directory, rename the variable %s",
	[trim_suffix(name, "_DIR")],
) if {
	endswith(name, "_DIR")
}

path_vars(path, taskfile) := {["variable", name, value] |
	some name, value in taskfiles.vars(taskfile)
	regex.match(path_var_pattern, name)
	is_string(value)
} | {[sprintf("task %q variable", [task_name]), name, value] |
	some task_name, task in taskfiles.tasks(path)
	is_object(task)
	not "dir" in object.keys(task)
	some name, value in taskfiles.vars(task)
	regex.match(path_var_pattern, name)
	is_string(value)
}

answers_default("default", _)

answers_default(name, task) if {
	name != "default"
	"default" in taskfiles.aliases(task)
}

# What a default task does beyond listing: each a phrase for the message.
default_offences(task) := (dep_offences(task) | line_offences(task)) | call_offences(task)

dep_offences(task) := {sprintf("has deps (%s)", [listed_deps]) |
	is_object(task)
	is_array(task.deps)
	count(task.deps) > 0
	listed_deps := concat(", ", [sprintf("%v", [dep]) | some dep in task.deps])
}

line_offences(task) := {sprintf("runs %q", [line]) |
	some line in taskfiles.command_lines(task)
	not listing_line(line)
	not listing_help_call(line)
}

listing_help_call(line) if listing_help(root_tasks, help_call(line))

call_offences(task) := {sprintf("calls task %q", [called]) |
	is_object(task)
	some item in object.get(task, "cmds", [])
	is_object(item)
	called := taskfiles.called(item)
	not listing_help(root_tasks, called)
}

root_tasks := taskfiles.tasks(taskfiles.root_path)

task_executables := {"task", "{{.TASK_EXE}}"}

# A Task invocation with flags only, one of which lists the tasks.
listing_line(line) if {
	tokens := regex.split(`\s+`, line)
	tokens[0] in task_executables
	flags := array.slice(tokens, 1, count(tokens))
	every i, token in flags {
		flag_or_value(flags, i, token)
	}
	some token in flags
	regex.match(`^(-l|-a|--list|--list-all|-[a-zA-Z]*[la][a-zA-Z]*)$`, token)
}

flag_or_value(_, _, token) if startswith(token, "-")

flag_or_value(flags, i, _) if {
	i > 0
	flags[i - 1] == "--sort"
}

# `task help` or `task list` on its own: the name of the task it runs.
help_call(line) := name if {
	tokens := regex.split(`\s+`, line)
	count(tokens) == 2
	tokens[0] in task_executables
	name := tokens[1]
	name in help_names
}

help_names := {"help", "list"}

# A help task that itself only lists or prints.
listing_help(tasks, name) if {
	name in help_names
	helper := tasks[name]
	is_object(helper)
	count(object.get(helper, "deps", [])) == 0
	every line in taskfiles.command_lines(helper) {
		listing_line(line)
	}
	not calls_a_task(helper)
}

calls_a_task(task) if {
	some item in task.cmds
	is_object(item)
	"task" in object.keys(item)
}

max_segments := 4

shallower(segments) := concat(":", array.concat(
	array.slice(segments, 0, max_segments - 1),
	[concat("-", array.slice(segments, max_segments - 1, count(segments)))],
))

# Every value of a Taskfile that a task reads as a path or runs: each
# command line, each task's dir, sources and generates, every variable, and
# each include's taskfile and dir.
path_values(path, taskfile) := ((({[sprintf("task %q", [name]), line] |
	some name, task in taskfiles.tasks(path)
	some line in taskfiles.command_lines(task)
	not container_command(line)
} | {[sprintf("task %q %s", [name, key]), value] |
	some name, task in taskfiles.tasks(path)
	is_object(task)
	some key in ["dir", "sources", "generates", "dotenv"]
	some value in files.as_list(task[key])
	is_string(value)
}) | {[sprintf("variable %s", [name]), value] |
	some name, value in object.union(taskfiles.vars(taskfile), taskfiles.env(taskfile))
	is_string(value)
}) | {[sprintf("task %q variable %s", [task_name, name]), value] |
	some task_name, task in taskfiles.tasks(path)
	is_object(task)
	some name, value in object.union(taskfiles.vars(task), taskfiles.env(task))
	is_string(value)
}) | {[sprintf("include %q %s", [namespace, key]), value] |
	is_object(taskfile.includes)
	some namespace, spec in taskfile.includes
	some key in ["taskfile", "dir"]
	value := taskfiles.entry(spec)[key]
	is_string(value)
}

# A line that runs a container tool: its paths may be the container's own,
# such as a mount target or a working directory inside the image.
container_command(line) if regex.match(`(^|[\s;&|(])(docker|podman|nerdctl|kubectl|devcontainer)\s`, line)

# A path into a home directory, a dev container or Codespaces checkout, or a
# Windows drive. A path after `:` is not one: it is the target of a mount or
# part of a URL.
host_path_pattern := concat("", [
	`(^|[\s"'=(,])`,
	`(/(home|Users)/[^/\s"']+|/root/|/workspaces?(/[^\s"';)]*|[\s"';)]|$)|[A-Za-z]:\\)`,
])

host_paths(value) := {trim_space(trim(match[2], `"';)`)) |
	some match in regex.find_all_string_submatch_n(host_path_pattern, value, -1)
}

# An internal task that a prompted task calls.
prompted_caller(name, task) if {
	taskfiles.is_internal(task)
	some path, _ in taskfiles.documents
	some caller in taskfiles.tasks(path)
	taskfiles.prompted(caller)
	some called in taskfiles.called_by(caller)
	taskfiles.called_as(called, name)
}

# What a task destroys, each a phrase for the message: the commands that
# lose data no build or checkout restores, or else a name that promises it.
losses(_, task) := command_losses(task) if count(command_losses(task)) > 0

losses(name, task) := {"is named for destroying data"} if {
	count(command_losses(task)) == 0
	regex.match(destructive_name_pattern, name)
}

command_losses(task) := {loss |
	some line in taskfiles.command_lines(task)
	some pattern, loss in destructive_patterns
	regex.match(pattern, line)
} | {"applies infrastructure changes with -auto-approve and no saved plan" |
	some line in taskfiles.command_lines(task)
	regex.match(`(^|[\s;&|(])(tofu|terraform)\s(.*\s)?apply\s(.*\s)?-auto-approve`, line)
	not regex.match(`(?i)\s[^-\s]\S*plan\S*(\s|$)`, line)
}

destructive_patterns := {
	`(^|[\s;&|(])(docker|podman)\s+volume\s+(rm|prune)(\s|$)`: "removes container volumes",
	`(^|[\s;&|(])(docker|podman)\s+system\s+prune(\s.*)?\s--volumes(\s|=|$)`: "prunes container volumes",
	`(compose|\}\})(\s+\S+)*\s+down(\s+\S+)*\s+(-v|--volumes)(\s|$)`: "takes a compose stack down with its volumes",
	`(^|[\s;&|(])(tofu|terraform)\s(.*\s)?destroy\s(.*\s)?-auto-approve`: "destroys infrastructure with -auto-approve",
	`(^|[\s;&|(])git\s+clean(\s+\S+)*\s+(-[A-Za-z]*f[A-Za-z]*|--force)(\s|$)`: "deletes untracked files with git clean",
	`(^|[\s;&|(])git\s+reset(\s+\S+)*\s+--hard(\s|$)`: "discards uncommitted changes with git reset --hard",
}

destructive_name_pattern := `(^|:)((destroy|drop|wipe)|(db|database):reset)$`
