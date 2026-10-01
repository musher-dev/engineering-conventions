# METADATA
# title: Environment schema
# description: >-
#   Every env.schema.yaml is valid against the published format (ENVS-03),
#   never declares a retired name again (ENVS-05), commits no secret value
#   (ENVS-06), keeps the invariants the format cannot express (ENVS-07),
#   agrees with the repository's other schemas on shared variables
#   (ENVS-08), names what a binding reaches as either a Musher
#   interface or a registered capability (ENVS-16 to ENVS-18), and reaches
#   a runtime through an instance declared under requires (ENVS-22,
#   ENVS-23).
# scope: package
# custom:
#   convention: EC-0020
package conventions.checks.environment.env_schema

import data.conventions.lib.env
import data.conventions.lib.findings as lib
import data.conventions.lib.repository
import data.conventions.lib.schema

# ENVS-03. One finding per schema: the first problem, and how many more.
findings contains lib.finding("ENVS-03", doc.path, schema.summary(problems)) if {
	some doc in env.schema_documents
	problems := schema.problems([doc.contents], data.conventions.index.env_schema)
	count(problems) > 0
}

# ENVS-05
findings contains lib.finding("ENVS-05", path, message) if {
	some path, contents in env.documents
	some entry in object.get(contents, "retired", [])
	is_object(entry)
	some place in live_places(contents, entry.name)
	retired_on := object.get(entry, "retired_on", "an unrecorded date")
	reason := trim_space(object.get(entry, "reason", ""))
	message := sprintf(
		"%s was retired on %s and is %s again: %s %s",
		[entry.name, retired_on, place, reason, revive],
	)
}

# ENVS-06
findings contains lib.finding("ENVS-06", path, message) if {
	some entry in env.bindings
	path := entry.path
	name := entry.name
	binding := entry.binding
	binding.sensitivity == "secret"
	some key in ["default", "local_default"]
	value := binding[key]
	value != null
	not local_value(value)
	message := sprintf(
		concat(" ", [
			"secret binding %s commits a %s; leave it empty or point it at a loopback host,",
			"and use local_generate for per-developer secret material",
		]),
		[name, key],
	)
}

# ENVS-07
findings contains lib.finding("ENVS-07", path, message) if {
	some entry in env.bindings
	path := entry.path
	name := entry.name
	binding := entry.binding
	some problem in binding_problems(binding)
	message := sprintf("binding %s: %s", [name, problem])
}

findings contains lib.finding("ENVS-07", path, problem) if {
	some path, contents in env.documents
	some problem in schema_problems(contents)
}

# ENVS-16
findings contains lib.finding("ENVS-16", entry.path, message) if {
	some entry in env.bindings
	files_has(entry.binding, "target")
	files_has(entry.binding, "capability")
	message := sprintf(
		"binding %s names both a target and a capability; a value reaches one thing, so keep the one it reaches",
		[entry.name],
	)
}

findings contains lib.finding("ENVS-16", entry.path, message) if {
	some entry in env.bindings
	files_has(entry.binding, "provider")
	not files_has(entry.binding, "capability")
	not files_has(entry.binding, "requires")
	message := sprintf(
		"binding %s names a provider but no capability; name the capability the provider offers, or drop the provider",
		[entry.name],
	)
}

findings contains lib.finding("ENVS-16", entry.path, message) if {
	some entry in env.bindings
	files_has(entry.binding, "requires")
	some field in ["target", "capability", "provider"]
	files_has(entry.binding, field)
	message := sprintf(
		"binding %s names both requires and %s; the instance %q already says what it reaches, so drop %s",
		[entry.name, field, entry.binding.requires, field],
	)
}

# ENVS-17
findings contains lib.finding("ENVS-17", entry.path, message) if {
	some entry in env.bindings
	is_string(entry.binding.target)
	not regex.match(target_pattern, entry.binding.target)
	message := sprintf(
		concat(" ", [
			"binding %s has target %q; write it as <repository>#<interface>, the repository's name and",
			"the interface it serves, such as platform-api#public-http",
		]),
		[entry.name, entry.binding.target],
	)
}

findings contains lib.finding("ENVS-17", entry.path, message) if {
	some entry in env.bindings
	is_string(entry.binding.target)
	regex.match(target_pattern, entry.binding.target)
	split(entry.binding.target, "#")[0] == repository.declared_name
	message := sprintf(
		concat(" ", [
			"binding %s targets %q in this repository; a target is another service, so leave a value",
			"that addresses the service itself without one",
		]),
		[entry.name, entry.binding.target],
	)
}

# ENVS-18
findings contains lib.finding("ENVS-18", entry.path, message) if {
	some entry in env.bindings
	is_string(entry.binding.capability)
	not entry.binding.capability in capabilities
	message := sprintf(
		"binding %s has capability %q, which is not a registered capability; use one of %s, or propose a new one",
		[entry.name, entry.binding.capability, concat(", ", sort([sprintf("%q", [c]) | some c in capabilities]))],
	)
}

# ENVS-22
findings contains lib.finding("ENVS-22", entry.path, message) if {
	some entry in env.bindings
	is_string(entry.binding.capability)
	message := sprintf(
		concat(" ", [
			"binding %s names capability %q inline; declare the instance under requires, with the versions",
			"the code works with, and write requires: <instance> on the binding",
		]),
		[entry.name, entry.binding.capability],
	)
}

# ENVS-23. A binding names an instance the schema does not declare.
findings contains lib.finding("ENVS-23", entry.path, message) if {
	some entry in env.bindings
	is_string(entry.binding.requires)
	not entry.binding.requires in object.keys(instances(entry.path))
	message := sprintf(
		"binding %s requires %q, which is not declared under requires; declare it, or name a declared instance",
		[entry.name, entry.binding.requires],
	)
}

# ENVS-23. An instance no binding reaches.
findings contains lib.finding("ENVS-23", path, message) if {
	some path, _ in env.documents
	some id, _ in instances(path)
	not reached(path, id)
	message := sprintf(
		"requires declares %s, which no binding reaches; name it with requires: %s on the binding that does, or remove it",
		[id, id],
	)
}

# ENVS-23. An instance whose capability is not a term.
findings contains lib.finding("ENVS-23", path, message) if {
	some path, _ in env.documents
	some id, instance in instances(path)
	is_string(instance.capability)
	not instance.capability in capabilities
	message := sprintf(
		"requires.%s has capability %q, which is not a registered capability; use one of %s, or propose a new one",
		[id, instance.capability, concat(", ", sort([sprintf("%q", [c]) | some c in capabilities]))],
	)
}

# ENVS-08. Each copy of a shared variable agrees with every other copy.
findings contains lib.finding("ENVS-08", path, message) if {
	some pair in sharing_pairs
	path := pair.path
	other := pair.other
	name := pair.name
	some field in ["type", "sensitivity"]
	here := object.get(env.bindings_of(path)[name], field, null)
	there := object.get(env.bindings_of(other)[name], field, null)
	here != there
	message := sprintf(
		"shared variable %s has %s %v here but %v in %s; make every copy agree",
		[name, field, here, there, other],
	)
}

# ENVS-08. A service the entry names, whose schema is in this repository,
# declares the entry too.
findings contains lib.finding("ENVS-08", path, message) if {
	some path, contents in env.documents
	some entry in object.get(contents, "shared_with", [])
	is_object(entry)
	some app in object.get(entry, "apps", [])
	some other, other_contents in env.documents
	other != path
	other_contents.service == app.service
	not declares_shared(other_contents, entry.name)
	message := sprintf(
		"shared variable %s names service %s, but %s declares no shared_with entry for it; add one there",
		[entry.name, app.service, other],
	)
}

revive := "Remove it, or delete its retired entry in the same change, deliberately"

# Where a retired name could live again.
live_places(contents, name) := {place |
	some place, names in {
		"declared in bindings": object.keys(object.get(contents, "bindings", {})),
		"listed in vendor_passthrough": object.get(contents, "vendor_passthrough", []),
		"listed in coolify_env": array.concat(
			object.get(object.get(contents, "coolify_env", {}), "required", []),
			object.get(object.get(contents, "coolify_env", {}), "optional", []),
		),
	}
	name in names
}

# Empty, or a URL whose host is the machine it runs on.
local_value("")

local_value(value) if {
	is_string(value)
	regex.match(loopback_pattern, value)
}

loopback_hosts := `(localhost|127\.0\.0\.1|\[::1\]|host\.docker\.internal)`

loopback_pattern := concat("", [`^[A-Za-z][A-Za-z0-9+.-]*://([^/@]*@)?`, loopback_hosts, `(:[0-9]+)?(/.*)?$`])

# The invariants between a binding's fields.
binding_problems(binding) := {problem |
	some check, problem in binding_checks
	violates(binding, check)
}

binding_checks := {
	"enum-values": "type enum needs a values list",
	"required-default": "required: true and a default contradict each other; drop one",
	"allow-empty": `allow_empty: true needs default: ""`,
	"exempt-reason": "grammar_exempt: true needs a grammar_exempt_reason saying why",
	"two-local-sources": "local_default and local_generate are both set; a binding has one local source",
	"generate-secret": "local_generate mints secret material, so the binding is sensitivity: secret",
	"generate-length": "local_generate yields fewer characters than constraints.min_length",
	"local-default-type": "local_default does not satisfy the binding's type",
}

has(binding, key) if {
	key in object.keys(binding)
	binding[key] != null
}

violates(binding, "enum-values") if {
	binding.type == "enum"
	count(object.get(binding, "values", [])) == 0
}

violates(binding, "required-default") if {
	binding.required == true
	has(binding, "default")
}

violates(binding, "allow-empty") if {
	binding.allow_empty == true
	object.get(binding, "default", null) != ""
}

violates(binding, "exempt-reason") if {
	binding.grammar_exempt == true
	trim_space(object.get(binding, "grammar_exempt_reason", "")) == ""
}

violates(binding, "two-local-sources") if {
	has(binding, "local_default")
	has(binding, "local_generate")
}

violates(binding, "generate-secret") if {
	has(binding, "local_generate")
	binding.sensitivity != "secret"
}

violates(binding, "generate-length") if {
	generated_length(binding.local_generate) < binding.constraints.min_length
}

violates(binding, "local-default-type") if {
	has(binding, "local_default")
	not matches_type(binding.local_default, binding)
}

# The characters local_generate yields for <bytes> of entropy.
generated_length(kind) := 2 * to_number(bytes) if {
	[encoding, bytes] := split(kind, ":")
	encoding == "hex"
}

generated_length(kind) := 4 * ceil(to_number(bytes) / 3) if {
	[encoding, bytes] := split(kind, ":")
	encoding in {"base64", "base64url"}
}

matches_type(value, binding) if {
	binding.type in {"string", "list"}
	is_string(value)
}

matches_type(value, binding) if {
	binding.type == "boolean"
	is_boolean(value)
}

matches_type(value, binding) if {
	binding.type == "integer"
	is_number(value)
	value == round(value)
}

matches_type(value, binding) if {
	binding.type == "number"
	is_number(value)
}

matches_type(value, binding) if {
	binding.type == "enum"
	value in object.get(binding, "values", [])
}

# The invariants between a schema's blocks.
schema_problems(contents) := {problem |
	some problem in array.flatten([
		generated_problems(contents),
		shared_problems(contents),
		dynamic_problems(contents),
		coolify_problems(contents),
	])
}

generated_problems(contents) := [sprintf(
	"generated.%s is only for runtime %s, and runtime is %v",
	[block, runtime, contents.runtime],
) |
	some block, runtime in {"pydantic": "python", "ts": "sveltekit"}
	is_object(contents.generated[block])
	contents.runtime != runtime
]

shared_problems(contents) := array.concat(
	[sprintf("shared_with names %s, which is not a binding; declare it in bindings", [entry.name]) |
		some entry in object.get(contents, "shared_with", [])
		is_string(entry.name)
		not entry.name in object.keys(object.get(contents, "bindings", {}))
	],
	[sprintf("shared_with entry %s does not list this service, %v, in apps", [entry.name, contents.service]) |
		some entry in object.get(contents, "shared_with", [])
		is_string(entry.name)
		not lists_service(entry, contents.service)
	],
)

lists_service(entry, service) if {
	some app in entry.apps
	app.service == service
}

# A browser binding read from the server at start is empty at build time,
# so it needs a default and cannot be required.
dynamic_problems(contents) := [sprintf(
	concat(" ", [
		"binding %s is read by the browser at server start (t3-core-dynamic),",
		"so it needs a default and cannot be required",
	]),
	[name],
) |
	contents.generated.ts.framework == "t3-core-dynamic"
	prefix := object.get(contents.generated.ts, "client_prefix", "VITE_")
	some name, binding in object.get(contents, "bindings", {})
	startswith(name, prefix)
	is_object(binding)
	dynamic_unready(binding)
]

dynamic_unready(binding) if binding.required == true

dynamic_unready(binding) if not has(binding, "default")

coolify_problems(contents) := [sprintf("coolify_env lists %s as both required and optional; keep one", [name]) |
	some name in object.get(object.get(contents, "coolify_env", {}), "required", [])
	name in object.get(object.get(contents, "coolify_env", {}), "optional", [])
]

declares_shared(contents, name) if {
	some entry in object.get(contents, "shared_with", [])
	entry.name == name
}

# Two schemas that both declare a variable shared, and both bind it.
sharing_pairs contains {"path": path, "other": other, "name": name} if {
	some path, contents in env.documents
	some entry in object.get(contents, "shared_with", [])
	name := entry.name
	some other, other_contents in env.documents
	other != path
	declares_shared(other_contents, name)
	is_object(env.bindings_of(path)[name])
	is_object(env.bindings_of(other)[name])
}

# The runtime instances a schema declares, by ID.
default instances(_) := {}

instances(path) := {id: instance |
	some id, instance in env.documents[path].requires
	is_object(instance)
} if {
	is_object(env.documents[path].requires)
}

reached(path, id) if {
	some binding in env.bindings_of(path)
	is_object(binding)
	binding.requires == id
}

target_pattern := `^[A-Za-z0-9][A-Za-z0-9._-]*#[a-z][a-z0-9]*(-[a-z0-9]+)*$`

capabilities := {token | some token in object.get(data.conventions.index.vocabulary, "runtime_capabilities", [])}

files_has(binding, key) if is_string(binding[key])
