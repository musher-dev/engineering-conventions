# METADATA
# title: Composite actions
# description: >-
#   A local action is named for the capability it provides, lives one level
#   below .github/actions in action.yml, and describes itself and every input;
#   the inputs and outputs of actions and reusable workflows are kebab-case.
# scope: package
# custom:
#   convention: EC-0004
package conventions.checks.github_actions.composite_actions

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.names

# GHA-20
findings contains lib.finding("GHA-20", concat("", [actions_root, directory]), message) if {
	some directory in misnamed_directories
	message := sprintf(
		concat(" ", [
			"action directory %q is not <action-token>-<object> in lowercase kebab-case; start it with",
			"one of %s followed by what it acts on%s",
		]),
		[directory, names.quoted_list(names.action_tokens), directory_example(directory)],
	)
}

# GHA-21
findings contains lib.finding("GHA-21", file, message) if {
	some file in metadata_files
	parts := split(trim_prefix(file, actions_root), "/")
	count(parts) != 2
	message := sprintf(
		concat(" ", [
			"action metadata is nested %d levels below .github/actions; move the action to %q so uses:",
			"./.github/actions/<name> reaches it",
		]),
		[count(parts) - 1, concat("", [actions_root, parts[count(parts) - 2], "/action.yml"])],
	)
}

findings contains lib.finding("GHA-21", file, message) if {
	some file in metadata_files
	parts := split(trim_prefix(file, actions_root), "/")
	count(parts) == 2
	parts[1] == "action.yaml"
	message := sprintf(
		"rename %q to %q: an action's metadata file is action.yml",
		[file, concat("", [actions_root, parts[0], "/action.yml"])],
	)
}

findings contains lib.finding("GHA-21", directory_path, message) if {
	some directory in action_directories
	directory_path := concat("", [actions_root, directory])
	not has_metadata(directory_path)
	message := sprintf(
		"directory %q holds no action.yml; add one or move the files out of .github/actions",
		[directory_path],
	)
}

# GHA-22. An action's display name follows the directory holding its
# metadata, so it is not judged while GHA-20 asks for that directory to change.
findings contains lib.finding("GHA-22", path, message) if {
	some path, action in files.actions
	not split(trim_prefix(path, actions_root), "/")[0] in misnamed_directories
	parts := split(path, "/")
	expected := names.title_case(parts[count(parts) - 2])
	object.get(action, "name", null) != expected
	message := sprintf(
		"name %q should be %q: an action's name is its directory name in Title Case",
		[object.get(action, "name", ""), expected],
	)
}

# GHA-23
findings contains lib.finding("GHA-23", path, missing_description) if {
	some path, action in files.actions
	not described(action)
}

findings contains lib.finding("GHA-23", path, message) if {
	some path, action in files.actions
	is_object(action.inputs)
	some input_name, declared_input in action.inputs
	not described(declared_input)
	message := sprintf("input %q has no description; add description: saying what the caller passes", [input_name])
}

# GHA-38
findings contains lib.finding("GHA-38", entry.path, message) if {
	some entry in interface_keys
	not regex.match(names.kebab_pattern, entry.key)
	message := sprintf(
		"%s %q is not kebab-case; rename it to %q and update every %s.%s reference",
		[entry.kind, entry.key, names.kebab_identifier(entry.key), entry.context, entry.key],
	)
}

actions_root := ".github/actions/"

# The names a caller passes or reads: an action's inputs and outputs, and a
# callable workflow's workflow_call inputs, outputs and secrets.
interface_keys contains {"path": path, "kind": kind, "context": section, "key": key} if {
	some path, action in files.actions
	some [section, kind] in [["inputs", "input"], ["outputs", "output"]]
	is_object(action[section])
	some key, _ in action[section]
}

interface_keys contains {"path": path, "kind": kind, "context": section, "key": key} if {
	some path, workflow in files.workflows
	config := files.trigger_config(workflow, "workflow_call")
	some [section, kind] in [["inputs", "input"], ["outputs", "output"], ["secrets", "secret"]]
	is_object(config[section])
	some key, _ in config[section]
}

# The inventory sees directories whose metadata was never passed (a nested
# action, an action.yaml, or none at all), so the directory set comes from it.
action_directories contains parts[0] if {
	some file in files.repository_files
	startswith(file, actions_root)
	parts := split(trim_prefix(file, actions_root), "/")
	count(parts) > 1
}

metadata_files contains file if {
	some file in files.repository_files
	regex.match(`^\.github/actions/.+/action\.ya?ml$`, file)
}

directory_ok(directory) if {
	regex.match(names.kebab_pattern, directory)
	parts := names.tokens(directory)
	count(parts) >= 2
	parts[0] in names.action_tokens
}

misnamed_directories contains directory if {
	some directory in action_directories
	not directory_ok(directory)
}

# Words that stand in for an action token. A directory that starts with
# anything else gets no suggestion: guessing the action is the author's call.
action_synonyms := {"auth": "authenticate", "validate": "check", "verify": "check"}

leading_action(token) := token if token in names.action_tokens

leading_action(token) := action_synonyms[token]

default directory_example(_) := ""

directory_example(directory) := sprintf(", e.g. %q", [suggestion]) if {
	parts := names.tokens(names.kebab_case(directory))
	count(parts) >= 2
	suggestion := concat("-", array.concat([leading_action(parts[0])], array.slice(parts, 1, count(parts))))
	directory_ok(suggestion)
}

has_metadata(directory_path) if {
	some file in metadata_files
	startswith(file, concat("", [directory_path, "/"]))
}

missing_description := "the action has no description; add description: saying what capability it provides"

described(value) if {
	is_string(value.description)
	trim_space(value.description) != ""
}
