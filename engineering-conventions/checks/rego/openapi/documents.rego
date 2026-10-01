# METADATA
# title: OpenAPI documents
# description: >-
#   A repository that declares an openapi interface keeps a Spectral ruleset
#   that extends the one the conventions ship (OAS-02) and runs
#   `conventions openapi` in a validate workflow, directly or through a task
#   (OAS-03); the link to the shipped ruleset is never part of the
#   repository (OAS-04).
# scope: package
# custom:
#   convention: EC-0037
package conventions.checks.openapi.documents

import data.conventions.lib.contracts
import data.conventions.lib.filenames
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.steps
import data.conventions.lib.taskfiles

# Where `conventions openapi` looks for the repository's ruleset, and the link
# it writes to the ruleset this release ships.
ruleset_paths := [".config/openapi/spectral.yaml", ".config/openapi/spectral.yml"]

link_dir := ".conventions"

link_path := concat("/", [link_dir, "openapi.spectral.yaml"])

# OAS-02: no ruleset at all.
findings contains lib.finding("OAS-02", ruleset_paths[0], message) if {
	declares_openapi
	count(rulesets) == 0
	message := sprintf(
		concat(" ", [
			"the repository declares an openapi interface in %s but has no Spectral ruleset; add %s with",
			"`extends: [../../%s]`, so its documents are linted with the conventions' rules",
		]),
		[files.outputs_path, ruleset_paths[0], link_path],
	)
}

# OAS-02: a ruleset that does not extend the shipped one. A ruleset too large
# to embed is not judged.
findings contains lib.finding("OAS-02", path, message) if {
	declares_openapi
	some path in rulesets
	text := files.texts[path]
	not extends_conventions(path, text)
	message := sprintf(
		concat(" ", [
			"%s does not extend the conventions' OpenAPI ruleset; add ../../%s to its extends, and turn",
			"off a rule there, with its reason, rather than leaving the ruleset out",
		]),
		[path, link_path],
	)
}

# OAS-03
findings contains lib.finding("OAS-03", files.outputs_path, message) if {
	declares_openapi
	not validated
	message := concat(" ", [
		"the repository declares an openapi interface but no validate workflow runs `conventions openapi`;",
		"run it in a validate workflow, directly or through a task, so a document that breaks the ruleset",
		"cannot merge",
	])
}

# OAS-04. Only a file git does not ignore is listed, so an ignored link is
# never reported.
findings contains lib.finding("OAS-04", path, message) if {
	some path in files.repository_files
	startswith(path, concat("", [link_dir, "/"]))
	message := sprintf(
		concat(" ", [
			"%s is part of the repository; add %s/ to .gitignore and remove it from the index, because",
			"`conventions openapi` writes it on every run to point at the release it runs",
		]),
		[path, link_dir],
	)
}

declares_openapi if {
	some entry in contracts.interfaces
	entry.format == "openapi"
}

rulesets contains path if {
	some path in ruleset_paths
	path in files.repository_files
}

# An extends entry is a ruleset, or a [ruleset, mode] pair. A relative one
# resolves from the ruleset's own directory, as Spectral resolves it.
extends_conventions(path, text) if {
	yaml.is_valid(text)
	ruleset := yaml.unmarshal(text)
	some ref in extended(object.get(ruleset, "extends", []))
	taskfiles.join(taskfiles.dir(path), ref) == link_path
}

extended(value) := [value] if is_string(value)

extended(value) := [ref | some item in value; ref := entry_ref(item)] if is_array(value)

entry_ref(item) := item if is_string(item)

entry_ref(item) := item[0] if {
	is_array(item)
	is_string(item[0])
}

validated if {
	some path, workflow in files.workflows
	filenames.slot(lower(files.stem(path))) == "validate"
	some job in files.jobs(workflow)
	some step in files.steps(job)
	some line in steps.command_lines(step)
	runs_openapi(line)
}

runs_openapi(line) if runs_directly(line)

runs_openapi(line) if {
	some name in task_arguments(line)
	some task in reaching
	called_as(name, task)
}

# `conventions openapi`, also as a path to the launcher.
runs_directly(text) if regex.match(`(?m)(^|[\s;&|(/])conventions\s+openapi(\s|$)`, text)

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

# The tasks that run `conventions openapi` themselves.
direct contains entry.name if {
	some entry in tasks
	some command in commands(entry.task)
	runs_directly(command)
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

# The tasks that run `conventions openapi`, directly or through the tasks
# they call.
reaching := graph.reachable(callers, direct)
