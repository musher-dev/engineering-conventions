# METADATA
# title: Dev container specification
# description: >-
#   A devcontainer.json is valid against the Dev Container specification's
#   schema (DEVC-17), and uses only the variables the specification defines,
#   where it resolves them (DEVC-18).
# scope: package
# custom:
#   convention: EC-0027
package conventions.checks.dev_containers.specification

import data.conventions.lib.findings as lib
import data.conventions.lib.mise
import data.conventions.lib.schema

devcontainers := mise.devcontainers

# DEVC-17. The specification's schema, rewritten for OPA's draft-07
# validator by `task generate`.
findings contains lib.finding("DEVC-17", path, message) if {
	some path, devcontainer in devcontainers
	found := schema_problems(devcontainer)
	count(found) > 0
	message := sprintf(
		"the Dev Container specification's schema rejects this file, so a tool ignores the setting or refuses the file: %s",
		[schema.summary_of(found, "the file")],
	)
}

# DEVC-18. A tool's customizations may hold the tool's own variables, such
# as VS Code's ${workspaceFolder} in a setting.
findings contains lib.finding("DEVC-18", path, message) if {
	some path, devcontainer in devcontainers
	some [property, name] in variables(devcontainer)
	property != "customizations"
	not defined_variable(name)
	not shell_expansion(property, name)
	message := sprintf(
		concat(" ", [
			"%s uses ${%s}, which is not a variable the Dev Container specification defines, so it",
			"is left as literal text; %s",
		]),
		[property, name, variable_remedy(name)],
	)
}

findings contains lib.finding("DEVC-18", path, message) if {
	some path, devcontainer in devcontainers
	some [property, name] in variables(devcontainer)
	startswith(name, "containerEnv:")
	property != "remoteEnv"
	message := sprintf(
		concat(" ", [
			"%s uses ${%s}, which the specification resolves only in remoteEnv; set the value in",
			"remoteEnv, or read a host variable with ${localEnv:...}",
		]),
		[property, name],
	)
}

findings contains lib.finding("DEVC-18", path, message) if {
	some path, devcontainer in devcontainers
	some [property, "devcontainerId"] in variables(devcontainer)
	not property in devcontainer_id_properties
	message := sprintf(
		concat(" ", [
			"%s uses ${devcontainerId}, which the specification resolves only in %s; move the value",
			"to one of them",
		]),
		[property, concat(", ", sort(devcontainer_id_properties))],
	)
}

# The schema's problems with a configuration, each once. propertyNames
# reports an unknown property twice, by its name and as the list of every
# name allowed; only the first is kept, and it names the property.
schema_problems(devcontainer) := schema.unique([problem(error) |
	[_, errors] := json.match_schema(devcontainer, data.conventions.index.devcontainer_schema)
	narrowed := schema.specific(errors)
	some error in schema.sorted(narrowed)
	not allowed_names(error, narrowed)
])

allowed_names(error, errors) if {
	error.type == "enum"
	some other in errors
	other.type == "invalid_property_name"
	other.field == error.field
}

problem(error) := sprintf("%s has the property %s, which the specification does not define.", [
	subject(error.field), property,
]) if {
	error.type == "invalid_property_name"
	property := regex.find_all_string_submatch_n(`"(.*)"`, error.desc, 1)[0][1]
} else := schema.message(error, "the file")

subject("(Root)") := "the file"

subject(field) := sprintf("`%s`", [field]) if field != "(Root)"

# Every ${...} in a configuration, as [the top-level property it is in, the
# text between the braces].
variables(devcontainer) := {[property, match[1]] |
	some property, value in devcontainer
	walk(value, [_, text])
	is_string(text)
	some match in regex.find_all_string_submatch_n(`\$\{([^}]*)\}`, text, -1)
}

# The variables of https://containers.dev/implementors/json_reference/#variables-in-devcontainerjson.
# An environment variable may carry a default after a second colon.
defined_variable(name) if regex.match(`^(localEnv|containerEnv):[^:]+(:.*)?$`, name)

defined_variable(name) if name in {
	"localWorkspaceFolder", "containerWorkspaceFolder",
	"localWorkspaceFolderBasename", "containerWorkspaceFolderBasename",
	"devcontainerId",
}

# A lifecycle command is shell, where ${NAME} or ${NAME:-default} is the
# shell's own expansion, which the tools pass through. A name that is a
# specification variable spelt in another case is still a mistake.
shell_expansion(property, name) if {
	property in lifecycle_hooks
	regex.match(`^[A-Za-z_][A-Za-z0-9_]*([:#%/^,].*)?$`, name)
	not misspelt(name)
}

misspelt(name) if {
	some variable in variable_names
	lower(regex.replace(name, `:.*$`, "")) == lower(variable)
}

variable_names := {
	"localEnv", "containerEnv", "localWorkspaceFolder", "containerWorkspaceFolder",
	"localWorkspaceFolderBasename", "containerWorkspaceFolderBasename", "devcontainerId",
}

variable_remedy(name) := sprintf("write ${%s}", [corrected]) if {
	prefix := regex.replace(name, `:.*$`, "")
	some variable in variable_names
	lower(prefix) == lower(variable)
	corrected := concat("", [variable, trim_prefix(name, prefix)])
} else := sprintf("write ${localEnv:%s}", [trim_prefix(name, "env:")]) if {
	startswith(name, "env:")
} else := concat(" ", [
	"use ${localEnv:NAME}, ${containerEnv:NAME}, ${localWorkspaceFolder}, ${containerWorkspaceFolder},",
	"their Basename forms or ${devcontainerId}",
])

# The properties in which the specification resolves ${devcontainerId}.
devcontainer_id_properties := {
	"name", "runArgs", "initializeCommand", "onCreateCommand", "updateContentCommand", "postCreateCommand",
	"postStartCommand", "postAttachCommand", "workspaceFolder", "workspaceMount", "mounts", "containerEnv",
	"remoteEnv", "containerUser", "remoteUser", "customizations",
}

# The lifecycle commands, each run by a shell.
lifecycle_hooks := {
	"initializeCommand", "onCreateCommand", "updateContentCommand",
	"postCreateCommand", "postStartCommand", "postAttachCommand",
}
