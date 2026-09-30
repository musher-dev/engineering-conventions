# METADATA
# title: OpenTofu state
# description: >-
#   An OpenTofu root's state key is tfstate/<repository>/<root>/terraform.tfstate,
#   with the environment before the file for a root split by environment
#   (TOFU-01). Keys are read from the Taskfile variables that pass them to
#   `tofu init -backend-config="key=..."`.
# scope: package
# custom:
#   convention: EC-0029
package conventions.checks.opentofu.state

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.repository
import data.conventions.lib.taskfiles

# A Taskfile at any depth; the runner passes one up to two directories deep,
# and at any depth under an OpenTofu directory.
taskfile_pattern := `(^|/)([Tt]askfile(\.dist)?\.ya?ml|taskfiles/[^/]+\.ya?ml)$`

# A variable that holds a state key: TOFU_STATE_KEY, or <ROOT>_STATE_KEY
# beside <ROOT>_DIR in a Taskfile that drives several roots.
key_variable := `(^|_)STATE_KEY$`

documents contains doc if {
	some doc in files.own_documents
	regex.match(taskfile_pattern, doc.path)
	is_object(doc.contents)
	some key in ["version", "tasks", "includes"]
	key in object.keys(doc.contents)
}

# Each block of variables a Taskfile sets: its own, and each include's.
blocks contains {"path": doc.path, "vars": doc.contents.vars} if {
	some doc in documents
	is_object(doc.contents.vars)
}

blocks contains {"path": doc.path, "vars": spec.vars} if {
	some doc in documents
	is_object(doc.contents.includes)
	some spec in doc.contents.includes
	is_object(spec)
	is_object(spec.vars)
}

# Every state key a Taskfile states. A key that starts with a template is
# built at run time, and is not judged.
keys contains {"path": block.path, "variable": name, "value": value, "root": root_name(block, name)} if {
	some block in blocks
	some name, value in block.vars
	regex.match(key_variable, name)
	literal_key(value)
}

keys contains {"path": block.path, "variable": name, "value": value, "root": ""} if {
	some block in blocks
	some name, value in block.vars
	regex.match(key_variable, name)
	literal_key(value)
	not root_name(block, name)
}

literal_key(value) if {
	is_string(value)
	value != ""
	not templated(substring(value, 0, 2))
}

templated(text) if contains(text, "{{")

templated(text) if contains(text, "${")

# The key's segments, with each template reduced to a marker first, so a
# slash inside a template does not split it.
segments(value) := split(regex.replace(regex.replace(value, `\{\{.*?\}\}`, "{{}}"), `\$\{[^}]*\}`, "${}"), "/")

# The root's directory name, where the Taskfile says which directory the key
# belongs to: <PREFIX>DIR beside <PREFIX>STATE_KEY names it, and `.` names
# the directory of a Taskfile kept in the root itself.
root_name(block, name) := last if {
	directory := directory_of(block, name)
	last := regex.replace(directory, `^.*/`, "")
	not last in {"", ".", ".."}
}

root_name(block, name) := regex.replace(taskfiles.dir(block.path), `^.*/`, "") if {
	directory_of(block, name) == "."
	not contains(block.path, "taskfiles/")
	taskfiles.dir(block.path) != ""
}

directory_of(block, name) := directory if {
	value := block.vars[concat("", [trim_suffix(name, "STATE_KEY"), "DIR"])]
	taskfiles.literal(value)
	directory := plain(value)
}

plain(value) := "." if {
	value in {".", "./"}
} else := trim_suffix(regex.replace(value, `^(\./)+`, ""), "/")

# A segment matches what it should hold, or is built at run time.
matches(segment, _) if templated(segment)

matches(segment, want) if segment == want

file := "terraform.tfstate"

# What is wrong with a key, the first thing only.
problem(key) := "is outside tfstate/, so the bucket's lifecycle rule and every tool that scans tfstate/ miss it" if {
	not startswith(key.value, "tfstate/")
} else := sprintf("does not end in /%s", [file]) if {
	not endswith(key.value, concat("/", ["", file]))
} else := "names no repository after tfstate/, so it is unique only by luck and says nothing of its owner" if {
	name := repository.judged_name
	not matches(segments(key.value)[1], name)
} else := "names no root, so a second root in the repository has nowhere to go" if {
	count(segments(key.value)) < 4
} else := "has more segments than a root and an environment" if {
	count(segments(key.value)) > 5
} else := sprintf("names the root %s, but the root's directory is %s", [segments(key.value)[2], key.root]) if {
	key.root != ""
	not root_matches(key)
}

root_matches(key) if matches(segments(key.value)[2], key.root)

# A variable naming the environment's own directory, for a root split into
# one directory per environment.
root_matches(key) if {
	count(segments(key.value)) == 5
	matches(segments(key.value)[3], key.root)
}

default repository_segment := "<repository>"

repository_segment := repository.judged_name

root_segment(key) := key.root if key.root != ""

root_segment(key) := "<root>" if key.root == ""

# TOFU-01
findings contains lib.finding("TOFU-01", key.path, message) if {
	some key in keys
	reason := problem(key)
	base := concat("/", ["tfstate", repository_segment, root_segment(key)])
	message := sprintf(
		concat("", [
			"%s %q %s; name the state key %s/%s, or %s/<env>/%s for a root split by environment, ",
			"and migrate a used key rather than edit it",
		]),
		[key.variable, key.value, reason, base, file, base, file],
	)
}
