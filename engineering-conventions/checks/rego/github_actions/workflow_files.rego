# METADATA
# title: Workflow files
# description: >-
#   A workflow file is named for the responsibility it owns, and its display
#   name is derived from that filename.
# scope: package
# custom:
#   convention: EC-0002
package conventions.checks.github_actions.workflow_files

import data.conventions.lib.filenames
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.names

# GHA-01 to GHA-05 judge the filename through lib/filenames.rego, which is
# also what decides the one filename suggested and which checks wait for a
# rename.

# GHA-01
findings contains lib.finding("GHA-01", path, message) if {
	some path, workflow in files.workflows
	not filenames.grammar_ok(files.basename(path))
	message := sprintf(
		concat(" ", [
			"filename %q does not follow [reusable-]<responsibility>[-<scope>].yml, lowercase",
			"kebab-case starting with a letter: %s",
		]),
		[files.basename(path), rename_hint(path, workflow)],
	)
}

# GHA-02
findings contains lib.finding("GHA-02", path, message) if {
	some path, _ in files.workflows
	filenames.grammar_ok(files.basename(path))
	stem := files.stem(path)
	not names.is_reusable_name(stem)
	filenames.slot_unknown(stem)
	message := sprintf(
		"first filename token %q is not a responsibility; start the filename with one of %s",
		[filenames.slot(stem), names.quoted_list(names.responsibility_tokens)],
	)
}

# GHA-03
findings contains lib.finding("GHA-03", path, message) if {
	some path, workflow in files.workflows
	filenames.grammar_ok(files.basename(path))
	names.is_reusable_name(files.stem(path))
	not files.is_reusable(workflow)
	message := sprintf(
		concat(" ", [
			"the reusable- prefix promises the workflow is triggered only by workflow_call, but it is",
			"also triggered by %s; %s, or make workflow_call its only trigger",
		]),
		[names.quoted_list(files.triggers(workflow) - {"workflow_call"}), drop_prefix_hint(path, workflow)],
	)
}

findings contains lib.finding("GHA-03", path, message) if {
	some path, workflow in files.workflows
	filenames.grammar_ok(files.basename(path))
	not names.is_reusable_name(files.stem(path))
	files.is_reusable(workflow)
	message := sprintf(
		"the workflow is triggered only by workflow_call, so it is never an entry point; %s",
		[add_prefix_hint(path, workflow)],
	)
}

# GHA-04
findings contains lib.finding("GHA-04", path, message) if {
	some path, _ in files.workflows
	filenames.grammar_ok(files.basename(path))
	stem := files.stem(path)
	names.is_reusable_name(stem)
	filenames.slot_unknown(stem)
	message := sprintf(
		"reusable workflow token %q is neither a responsibility nor a capability; use one of %s after reusable-",
		[filenames.slot(stem), names.quoted_list(names.responsibility_tokens | names.capability_tokens)],
	)
}

# GHA-05. One finding per file, naming every offending token.
findings contains lib.finding("GHA-05", path, message) if {
	some path, workflow in files.workflows
	filenames.grammar_ok(files.basename(path))
	offending := filenames.offending_tokens(files.stem(path))
	count(offending) > 0
	message := sprintf(
		"filename %s a trigger, schedule, tool or synonym rather than a responsibility; %s%s",
		[offending_subject(offending), concat("; ", [token_fix(token) | some token in offending]), example(path, workflow)],
	)
}

findings contains lib.finding("GHA-06", path, message) if {
	extension_counts.yml > 0
	extension_counts.yaml > 0
	some path, _ in files.workflows
	lower(files.extension(path)) != kept_extension
	message := sprintf(
		"this repository's workflows mix .yml and .yaml and most use .%s; rename this file to %q",
		[kept_extension, concat(".", [files.stem(path), kept_extension])],
	)
}

findings contains lib.finding("GHA-07", path, message) if {
	some path, workflow in files.workflows
	not path in filenames.renaming
	expected := names.title_case(files.stem(path))
	workflow.name != expected
	message := sprintf(
		"name %q should be %q: a workflow's name is its filename stem in Title Case",
		[workflow.name, expected],
	)
}

findings contains lib.finding("GHA-07", path, message) if {
	some path, workflow in files.workflows
	not path in filenames.renaming
	not "name" in object.keys(workflow)
	message := sprintf(
		"the workflow has no name; add name: %q, its filename stem in Title Case",
		[names.title_case(files.stem(path))],
	)
}

# GHA-08
findings contains lib.finding("GHA-08", path, message) if {
	some path, workflow in files.workflows
	is_string(workflow.name)
	others := [other |
		some other, candidate in files.workflows
		other != path
		candidate.name == workflow.name
	]
	count(others) > 0
	message := sprintf(
		"name %q is also used by %s; %s",
		[workflow.name, names.quoted_list(others), unique_name_hint(path)],
	)
}

# GHA-09
findings contains lib.finding("GHA-09", path, message) if {
	some path, workflow in files.workflows
	config := files.trigger_config(workflow, "workflow_run")
	some target in files.as_list(config.workflows)
	not target in workflow_names
	message := sprintf(
		"workflow_run names %q, which is not the name of any workflow in this repository; %s",
		[target, workflow_run_hint(target)],
	)
}

unique_name_hint(path) := sprintf(
	"give each workflow the Title-Cased stem of its own filename (%q)",
	[names.title_case(files.stem(path))],
) if {
	not path in filenames.renaming
}

# While the filename must change, the name it would derive is not known yet.
unique_name_hint(path) := "give each workflow its own name" if path in filenames.renaming

default rename_hint(_, _) := "rename it to [reusable-]<responsibility>[-<scope>].yml for the responsibility it owns"

rename_hint(path, workflow) := sprintf("rename it to %q", [filenames.suggestion(path, workflow)])

default drop_prefix_hint(_, _) := "drop the prefix and name the workflow for the responsibility it owns"

drop_prefix_hint(path, workflow) := sprintf("drop the prefix (rename to %q)", [filenames.suggestion(path, workflow)])

default add_prefix_hint(_, _) := "add the reusable- prefix"

add_prefix_hint(path, workflow) := sprintf("rename it to %q", [filenames.suggestion(path, workflow)])

default example(_, _) := ""

example(path, workflow) := sprintf(" (e.g. %q)", [filenames.suggestion(path, workflow)])

offending_subject(offending) := sprintf("token %q names", offending) if count(offending) == 1

offending_subject(offending) := sprintf("tokens %s name", [names.quoted_list(offending)]) if count(offending) > 1

token_fix(token) := sprintf(
	"drop %q: a schedule is not a responsibility, so name what it serves (%s)",
	[token, names.banned_tokens[token]],
) if {
	token in names.schedule_tokens
}

token_fix(token) := sprintf("replace %q with %q", [token, names.banned_tokens[token]]) if {
	not token in names.schedule_tokens
}

# GHA-06. The majority extension is the one "already in use"; on a tie the
# shorter .yml wins because it is what GitHub's own templates create.
extension_counts[extension] := count([path |
	some path, _ in files.workflows
	lower(files.extension(path)) == extension
]) if {
	some extension in {"yml", "yaml"}
}

default kept_extension := "yml"

kept_extension := "yaml" if extension_counts.yaml > extension_counts.yml

workflow_names contains workflow.name if {
	some workflow in files.workflows
	is_string(workflow.name)
}

# A workflow_run entry that names a file rather than a display name is the
# common mistake, so the file's name is offered when it resolves.
workflow_run_hint(target) := sprintf("use its name %q", [workflow.name]) if {
	some path, workflow in files.workflows
	target in {files.basename(path), files.stem(path)}
	is_string(workflow.name)
}

workflow_run_hint(target) := sprintf("use one of %s", [names.quoted_list(workflow_names)]) if {
	not target_is_a_file(target)
}

target_is_a_file(target) if {
	some path, workflow in files.workflows
	target in {files.basename(path), files.stem(path)}
	is_string(workflow.name)
}
