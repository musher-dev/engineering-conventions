# METADATA
# title: OpenAPI documents
# description: >-
#   A repository that declares an openapi interface keeps a Spectral ruleset
#   that extends Spectral's own OpenAPI ruleset and the OWASP API security
#   ruleset at an exact version (OAS-02), and lints its documents with it in
#   a validate workflow, directly or through a task (OAS-03).
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

# Where `conventions openapi` looks for the repository's ruleset.
ruleset_paths := [".config/openapi/spectral.yaml", ".config/openapi/spectral.yml"]

owasp_package := "@stoplight/spectral-owasp-ruleset"

owasp_example := concat("", ["https://unpkg.com/", owasp_package, "@2.0.1/dist/ruleset.mjs"])

# The OWASP ruleset by a URL that names one exact release.
owasp_pinned := `^https://unpkg\.com/@stoplight/spectral-owasp-ruleset@[0-9]+\.[0-9]+\.[0-9]+/dist/ruleset\.mjs$`

# OAS-02: no ruleset at all.
findings contains lib.finding("OAS-02", ruleset_paths[0], message) if {
	declares_openapi
	count(rulesets) == 0
	message := sprintf(
		concat(" ", [
			"the repository declares an openapi interface in %s but has no Spectral ruleset; add %s with",
			"`extends: [spectral:oas, %s]`, so its documents are linted with Spectral's OpenAPI and OWASP rules",
		]),
		[files.outputs_path, ruleset_paths[0], owasp_example],
	)
}

# OAS-02: a ruleset that does not extend spectral:oas. A ruleset too large to
# embed is not judged.
findings contains lib.finding("OAS-02", path, message) if {
	declares_openapi
	some path in rulesets
	refs := extended_refs(path)
	not "spectral:oas" in refs
	message := sprintf(
		concat(" ", [
			"%s does not extend spectral:oas; add it to extends, and turn off a rule there, with its",
			"reason, rather than leaving the ruleset out",
		]),
		[path],
	)
}

# OAS-02: a ruleset that does not extend the OWASP ruleset at an exact version.
findings contains lib.finding("OAS-02", path, message) if {
	declares_openapi
	some path in rulesets
	refs := extended_refs(path)
	not owasp_extended(refs)
	floating := [ref | some ref in refs; contains(ref, owasp_package)]
	message := sprintf(
		"%s %s; extend %s, which names one exact release",
		[path, owasp_problem(floating), owasp_example],
	)
}

# OAS-03
findings contains lib.finding("OAS-03", files.outputs_path, message) if {
	declares_openapi
	not validated
	message := concat(" ", [
		"the repository declares an openapi interface but no validate workflow lints it; run",
		"`conventions openapi`, or `spectral lint --ruleset .config/openapi/spectral.yaml`, in a validate",
		"workflow, directly or through a task, so a document that breaks the ruleset cannot merge",
	])
}

declares_openapi if {
	some entry in contracts.interfaces
	entry.format == "openapi"
}

rulesets contains path if {
	some path in ruleset_paths
	path in files.repository_files
}

# What a ruleset extends, each entry a ruleset or a [ruleset, mode] pair. A
# pair whose mode is "off" extends nothing. A ruleset that does not parse
# extends nothing; one too large to embed has no value here.
extended_refs(path) := {ref |
	some item in extended(object.get(ruleset, "extends", []))
	ref := entry_ref(item)
} if {
	text := files.texts[path]
	yaml.is_valid(text)
	ruleset := yaml.unmarshal(text)
	is_object(ruleset)
}

extended_refs(path) := set() if {
	text := files.texts[path]
	not parsed_object(text)
}

parsed_object(text) if {
	yaml.is_valid(text)
	is_object(yaml.unmarshal(text))
}

owasp_extended(refs) if {
	some ref in refs
	regex.match(owasp_pinned, ref)
}

extended(value) := [value] if is_string(value)

extended(value) := value if is_array(value)

entry_ref(item) := item if is_string(item)

entry_ref(item) := item[0] if {
	is_array(item)
	is_string(item[0])
	not off(item)
}

off(item) if item[1] == "off"

owasp_problem(floating) := "does not extend the OWASP API security ruleset" if count(floating) == 0

owasp_problem(floating) := sprintf(
	"extends the OWASP API security ruleset as %s, which names no exact release",
	[floating[0]],
) if {
	count(floating) > 0
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

# `spectral lint` with the repository's ruleset, also through a runner such as
# `mise exec`.
runs_directly(text) if {
	regex.match(
		`(?m)(^|[\s;&|(/])spectral\s+lint\s[^;&|\n]*(--ruleset|-r)[=\s]+(\./)?\.config/openapi/spectral\.ya?ml(\s|$)`,
		text,
	)
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
