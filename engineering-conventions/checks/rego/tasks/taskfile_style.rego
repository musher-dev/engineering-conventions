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
