# METADATA
# title: Environment schema and dev container stacks
# description: >-
#   Every variable a dev container's compose file reads is a binding in
#   .devcontainer/env.schema.yaml (ENVS-32), every stack a binding names in
#   consumers exists and reads it (ENVS-33), and every file a binding is
#   mirrored_in exists and repeats its local_default (ENVS-34).
# scope: package
# custom:
#   convention: EC-0020
package conventions.checks.environment.env_stacks

import data.conventions.lib.env
import data.conventions.lib.files
import data.conventions.lib.findings as lib

dev_schema := ".devcontainer/env.schema.yaml"

# The compose files EC-0028 checks (dev_containers/stacks.rego): any under
# .devcontainer/, at any depth.
compose_pattern := `^\.devcontainer/(.+/)?(docker-)?compose(\.[^/]+)?\.ya?ml$`

# Compose sets the project's name for interpolation itself, so no schema
# declares it.
compose_supplied := {"COMPOSE_PROJECT_NAME"}

# ENVS-32
findings contains lib.finding("ENVS-32", ref.path, message) if {
	dev_schema in object.keys(env.documents)
	some ref in references
	not declared(ref.name)
	message := sprintf(
		"this file reads ${%s}, which %s does not declare; add it as a binding there, or stop reading it",
		[ref.name, dev_schema],
	)
}

# ENVS-33. A consumer that names no stack.
findings contains lib.finding("ENVS-33", dev_schema, message) if {
	some [name, stack] in consumers
	not stack in stack_names
	message := sprintf(
		concat(" ", [
			"%s lists the consumer %s, but no compose file under .devcontainer/ is in a directory named %s;",
			"name the stack that reads it, or remove the entry",
		]),
		[name, stack, stack],
	)
}

# ENVS-33. A stack that does not read the variable.
findings contains lib.finding("ENVS-33", dev_schema, message) if {
	some [name, stack] in consumers
	stack in stack_names
	not stack_reads(stack, name)
	message := sprintf(
		"%s lists the stack %s as a consumer, but its compose file does not read ${%s}; read it there, or remove %s",
		[name, stack, name, stack],
	)
}

# ENVS-34. A path that leaves the schema's directory.
findings contains lib.finding("ENVS-34", mirror.schema, message) if {
	some mirror in mirrors
	not mirror.file
	message := sprintf(
		"%s is mirrored_in %q, which is not a path inside the schema's directory; name the file relative to it, without ..",
		[mirror.name, mirror.entry],
	)
}

# ENVS-34. Nothing to mirror.
findings contains lib.finding("ENVS-34", mirror.schema, message) if {
	some mirror in mirrors
	is_string(mirror.file)
	not "local_default" in object.keys(mirror.binding)
	message := sprintf(
		"%s lists mirrored_in but has no local_default for %s to repeat; add the local_default, or remove mirrored_in",
		[mirror.name, mirror.file],
	)
}

# ENVS-34. A file that is not there.
findings contains lib.finding("ENVS-34", mirror.schema, message) if {
	some mirror in mirrors
	is_string(mirror.file)
	"local_default" in object.keys(mirror.binding)
	not mirror.file in files.all_files
	message := sprintf(
		"%s is mirrored_in %s, which does not exist; correct the path, or remove it from mirrored_in",
		[mirror.name, mirror.file],
	)
}

# ENVS-34. A file that no longer repeats the value. A file whose text the
# runner does not embed, because it is over the size limit, is not compared.
findings contains lib.finding("ENVS-34", mirror.file, message) if {
	some mirror in mirrors
	is_string(mirror.file)
	value := text(mirror.binding.local_default)
	not contains(files.texts[mirror.file], value)
	message := sprintf(
		"%s has local_default %q in %s, but this file does not contain it; make the two agree",
		[mirror.name, value, mirror.schema],
	)
}

# Every ${NAME} a dev container's compose file reads, in any string value of
# the document: in ${NAME}, ${NAME:-default}, ${NAME-default},
# ${NAME:?error}, ${NAME?error}, ${NAME:+value} and ${NAME+value}, and inside
# another's default. $$ is a literal dollar sign, never a reference.
references contains {"path": doc.path, "name": name} if {
	some doc in compose_documents
	walk(doc.contents, [_, value])
	is_string(value)
	contains(value, "${")
	unescaped := replace(value, "$$", " ")
	some match in regex.find_all_string_submatch_n(`\$\{([A-Za-z_][A-Za-z0-9_]*)`, unescaped, -1)
	name := match[1]
}

compose_documents contains doc if {
	some doc in files.own_documents
	regex.match(compose_pattern, doc.path)
}

# Declared: a binding of the dev container's schema, a name its
# vendor_passthrough lets through, or one Compose supplies.
declared(name) if env.bindings_of(dev_schema)[name]

declared(name) if {
	some entry in object.get(env.documents[dev_schema], "vendor_passthrough", [])
	is_string(entry)
	env.passes(entry, name)
}

declared(name) if name in compose_supplied

# A stack's name is the name of the directory that holds its compose file:
# .devcontainer/stacks/postgres/compose.yaml is the stack postgres.
stack_name(path) := parts[count(parts) - 2] if parts := split(path, "/")

stack_names contains stack_name(path) if {
	some path in files.repository_files
	regex.match(compose_pattern, path)
}

stack_reads(stack, name) if {
	some ref in references
	stack_name(ref.path) == stack
	ref.name == name
}

# Each binding of the dev container's schema, with every stack it lists in
# consumers.
consumers contains [name, stack] if {
	some name, binding in env.bindings_of(dev_schema)
	is_array(binding.consumers)
	some stack in binding.consumers
	is_string(stack)
}

# Each file a binding is mirrored_in, resolved against its schema's
# directory; file is false when the path leaves that directory.
mirrors contains {"schema": entry.path, "name": entry.name, "binding": entry.binding, "entry": m, "file": file} if {
	some entry in env.bindings
	is_array(entry.binding.mirrored_in)
	some m in entry.binding.mirrored_in
	is_string(m)
	file := resolve(directory(entry.path), m)
}

directory(path) := concat("/", array.slice(parts, 0, count(parts) - 1)) if parts := split(path, "/")

# A path relative to dir, with . and empty segments dropped; false when it is
# absolute or has a .. segment. bin/mirrors.jq resolves it the same way.
resolve(_, relative) := false if startswith(relative, "/")

resolve(_, relative) := false if {
	not startswith(relative, "/")
	".." in split(relative, "/")
}

resolve(dir, relative) := concat("/", [s |
	some s in array.concat(split(dir, "/"), split(relative, "/"))
	not s in {"", "."}
]) if {
	not startswith(relative, "/")
	not ".." in split(relative, "/")
}

# A local_default as the generated .env writes it before quoting
# (bin/env-contract.jq): a string as it is, anything else as JSON.
text(value) := value if is_string(value)

text(value) := json.marshal(value) if not is_string(value)
