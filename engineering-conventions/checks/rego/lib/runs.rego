# METADATA
# title: What a validate workflow runs
# description: >-
#   Whether a validate workflow runs a command, directly on a step's command
#   line or through a task that runs it or calls one that does. A check names
#   the command by the patterns that match it, such as `conventions openapi`
#   (OAS-03) or hadolint with the repository's config (IMAGE-10).
package conventions.lib.runs

import data.conventions.lib.filenames
import data.conventions.lib.files
import data.conventions.lib.steps
import data.conventions.lib.taskfiles

# Whether a validate workflow runs a command the patterns match.
validated(patterns) if {
	some path, workflow in files.workflows
	filenames.slot(lower(files.stem(path))) == "validate"
	some job in files.jobs(workflow)
	some step in files.steps(job)
	some line in steps.command_lines(step)
	line_runs(patterns, line)
}

# Whether a command line runs the command, itself or through a task.
line_runs(patterns, line) if matches(patterns, line)

line_runs(patterns, line) if {
	some name in task_arguments(line)
	some task in reaching(patterns)
	called_as(name, task)
}

matches(patterns, text) if {
	some pattern in patterns
	regex.match(pattern, text)
}

# The words after `task` on a command line that are not flags or variables.
task_arguments(line) := {word |
	some match in regex.find_all_string_submatch_n(`(?:^|[\s;&|(])task\s+([^;&|]*)`, line, -1)
	some word in split(trim_space(match[1]), " ")
	word != ""
	not startswith(word, "-")
	not contains(word, "=")
}

# A name on a command line or in a call reaches a task by its own name, or
# through the namespace an include gives it.
called_as(name, task) if trim_prefix(name, ":") == task

called_as(name, task) if endswith(name, concat("", [":", task]))

# Every task, by its own name, with what it runs and calls.
tasks contains {"name": name, "task": task} if {
	some path, _ in taskfiles.documents
	some name, task in taskfiles.tasks(path)
}

default commands(_) := []

commands(task) := [task] if is_string(task)

commands(task) := [command | some item in task; command := item_command(item)] if is_array(task)

commands(task) := [command | some item in task.cmds; command := item_command(item)] if is_array(task.cmds)

item_command(item) := item if is_string(item)

item_command(item) := item.cmd if is_string(item.cmd)

default task_calls(_) := set()

task_calls(task) := {name |
	some item in object.get(task, "cmds", [])
	is_object(item)
	name := taskfiles.called(item)
} | {name |
	some item in object.get(task, "deps", [])
	name := taskfiles.called_dep(item)
} if {
	is_object(task)
}

task_names contains entry.name if some entry in tasks

# The tasks each task is called by. Every task is a key, even one nothing
# calls, because graph.reachable follows only the nodes it finds as keys.
callers[task] := {caller.name |
	some caller in tasks
	some name in task_calls(caller.task)
	called_as(name, task)
} if {
	some task in task_names
}

# The tasks that run the command themselves.
direct(patterns) := {entry.name |
	some entry in tasks
	some command in commands(entry.task)
	matches(patterns, command)
}

# The tasks that run the command, directly or through the tasks they call.
reaching(patterns) := graph.reachable(callers, direct(patterns))
