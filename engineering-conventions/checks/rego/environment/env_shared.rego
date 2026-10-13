# METADATA
# title: Names and values every Musher program shares
# description: >-
#   The deployment environment reaches a process only as MUSHER_ENVIRONMENT,
#   holding a registered name (ENVS-28); a name under a vendor's reserved
#   prefix is one that vendor defines (ENVS-29); no deployment environment
#   appears in a variable's name (ENVS-30); and a variable ending in a
#   shared stem keeps the stem's registered values (ENVS-31). Decision 0034.
# scope: package
# custom:
#   convention: EC-0020
package conventions.checks.environment.env_shared

import data.conventions.lib.env
import data.conventions.lib.files
import data.conventions.lib.findings as lib

tier := env.grammar.deployment_environment

variable := tier.variable

# ENVS-28. A binding other than MUSHER_ENVIRONMENT that carries the tier.
findings contains lib.finding("ENVS-28", entry.path, message) if {
	some entry in env.bindings
	carrier(entry)
	client := client_of(entry.path, entry.name)
	message := sprintf(
		concat(" ", [
			"binding %s carries the deployment environment, which reaches a process only as %s%s;",
			"read that instead, and retire %s with it as the replacement",
		]),
		[entry.name, client, variable, entry.name],
	)
}

# ENVS-28. MUSHER_ENVIRONMENT admits a value that is not a registered name.
findings contains lib.finding("ENVS-28", entry.path, message) if {
	some entry in env.bindings
	trim_prefix(entry.name, client_of(entry.path, entry.name)) == variable
	some [field, value] in declared_values(entry.binding)
	not value in env.tier_names
	message := value_message(entry.name, field, value)
}

# ENVS-28. A pattern that admits a slug.
findings contains lib.finding("ENVS-28", entry.path, message) if {
	some entry in env.bindings
	trim_prefix(entry.name, client_of(entry.path, entry.name)) == variable
	pattern := entry.binding.constraints.pattern
	is_string(pattern)
	some slug in env.tier_slugs
	regex.match(pattern, slug)
	message := sprintf(
		"binding %s has a pattern that admits the slug %s; its value is the name, so admit %s instead",
		[entry.name, slug, env.tier_name_of(slug)],
	)
}

# ENVS-29. A made-up name under a vendor's reserved prefix.
findings contains lib.finding("ENVS-29", entry.path, message) if {
	some entry in env.bindings
	some reserved in env.grammar.reserved_prefixes
	some prefix in reserved.prefixes
	startswith(entry.name, prefix)
	not entry.name in {name | some name in reserved.names}
	not carrier(entry)
	message := undefined_message(entry.name, prefix, reserved)
}

# ENVS-29. A name the CI vendor sets only inside a run, declared by a service.
findings contains lib.finding("ENVS-29", entry.path, message) if {
	files.repository_declaration.kind == "service"
	some entry in env.bindings
	some reserved in env.grammar.reserved_prefixes
	reserved.runner_only
	entry.name in {name | some name in reserved.names}
	not entry.binding.lifecycle == "build-time"
	message := sprintf(
		concat(" ", [
			"binding %s is set by %s only inside a workflow run, and a deployed service never runs there;",
			"pass the value in under the service's own name, or mark the binding lifecycle: build-time",
			"if only the build reads it",
		]),
		[entry.name, reserved.vendor],
	)
}

# ENVS-30
findings contains lib.finding("ENVS-30", entry.path, message) if {
	some entry in env.grammar_bindings
	not reserved_name(entry.name)
	found := {word | some word in words(entry.name); word in tier_words}
	count(found) > 0
	message := sprintf(
		concat(" ", [
			"binding %s names the deployment environment (%s); the environment selects the value,",
			"not the name, so call it %s and set a different value in each environment",
		]),
		[entry.name, concat(", ", sort(found)), without_words(entry.name, found)],
	)
}

# ENVS-31
findings contains lib.finding("ENVS-31", entry.path, message) if {
	some entry in env.bindings
	not env.vendor_name(entry.path, entry.name)
	not reserved_name(entry.name)
	some stem, values in data.conventions.index.vocabulary.env_shared_stems
	has_stem(entry.name, stem)
	some [field, value] in declared_values(entry.binding)
	not value in {v | some v in values}
	message := sprintf(
		"binding %s %s %s, but every _%s holds one of %s%s",
		[entry.name, field_verb(field), value, stem, concat(", ", values), stem_hint(value, values)],
	)
}

# A binding that carries the tier: a name that always does, a name ending in
# one, the schema's own <COMPONENT>_ENVIRONMENT or _ENV, or values that are
# deployment environments. A framework's own mode, such as NODE_ENV, is not
# the deployment environment.
carrier(entry) if {
	name := trim_prefix(entry.name, client_of(entry.path, entry.name))
	name != variable
	carrier_name(entry.path, name)
	not entry.name in {name | some name in tier.vendor_modes}
}

carrier(entry) if {
	not trim_prefix(entry.name, client_of(entry.path, entry.name)) == variable
	not entry.name in {name | some name in tier.vendor_modes}
	not env.vendor_name(entry.path, entry.name)
	not reserved_name(entry.name)
	values := {v | some v in entry.binding.values; v in (env.tier_names | env.tier_slugs)}
	count(values) >= 2
}

carrier_name(_, name) if name in {n | some n in tier.carriers}

carrier_name(_, name) if {
	some suffix in tier.carrier_suffixes
	endswith(name, suffix)
}

carrier_name(path, name) if {
	some owner in owners(path)
	some ending in ["_ENVIRONMENT", "_ENV"]
	name == concat("", [owner, ending])
}

# The words a schema's own names begin with: its components, its consumer
# prefix, and MUSHER (MUSHER_ENV is MUSHER_ENVIRONMENT misspelled).
owners(path) := ({c | some c in env.documents[path].naming.components; is_string(c)} | {"MUSHER"}) | consumer(path)

default consumer(_) := set()

consumer(path) := {trim_suffix(env.consumer_prefix(path), "_")} if env.consumer_prefix(path)

client_of(path, name) := client if {
	some client in env.client_prefixes(path)
	startswith(name, client)
} else := ""

# The values a binding declares: each of values, and default and
# local_default when they are strings.
declared_values(binding) := {["values", v] | some v in binding.values; is_string(v)} | {[field, binding[field]] |
	some field in ["default", "local_default"]
	is_string(binding[field])
}

value_message(name, field, value) := sprintf(
	"binding %s %s the slug %s; its value is the name, so write %s",
	[name, field_verb(field), value, env.tier_name_of(value)],
) if {
	value in env.tier_slugs
} else := sprintf(
	"binding %s %s %s, which is not a deployment environment; its values are %s",
	[name, field_verb(field), value, concat(", ", sort(env.tier_names))],
)

field_verb("values") := "allows"

field_verb("default") := "defaults to"

field_verb("local_default") := "defaults locally to"

undefined_message(name, prefix, reserved) := sprintf(
	"binding %s is under %s, which %s reserves, and %s defines no such variable; use %s%s",
	[name, prefix, reserved.vendor, reserved.vendor, reserved.suggest[name], inverted(name, reserved.suggest[name])],
) if {
	reserved.suggest[name]
} else := sprintf(
	concat(" ", [
		"binding %s is under %s, which %s reserves, and %s defines no such variable;",
		"use the name %s defines, or name it after the program that reads it, outside %s",
	]),
	[name, prefix, reserved.vendor, reserved.vendor, reserved.vendor, prefix],
)

inverted(name, suggestion) := ", which is true where this was false" if {
	endswith(name, "_ENABLED")
	endswith(suggestion, "_DISABLED")
} else := ""

# The deployment environments' names and slugs, upper-cased, less the words
# a name may still use (TEST).
tier_words := {upper(word) | some word in (env.tier_names | env.tier_slugs)} - {w | some w in tier.name_words_allowed}

words(name) := {word | some word in split(name, "_"); word != ""}

# A name under a prefix a vendor reserves: its values and words are the vendor's.
reserved_name(name) if {
	some reserved in env.grammar.reserved_prefixes
	env.starts_with_any(name, reserved.prefixes)
}

# The name with the given words taken out of each __-separated part, and a
# part left empty dropped.
without_words(name, drop) := concat("__", [kept |
	some part in split(name, "__")
	kept := concat("_", [w | some w in split(part, "_"); not w in drop])
	kept != ""
])

has_stem(name, stem) if name == stem

has_stem(name, stem) if endswith(name, concat("", ["_", stem]))

stem_hint(value, values) := sprintf("; write %s", [lower(value)]) if {
	lower(value) != value
	lower(value) in {v | some v in values}
} else := ""
