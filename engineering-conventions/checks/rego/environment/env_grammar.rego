# METADATA
# title: Environment variable names
# description: >-
#   Every binding an env.schema.yaml declares is named by one grammar: the
#   case and a declared component (ENVS-04), boolean prefixes (ENVS-09),
#   abbreviated units (ENVS-10), no repeated word (ENVS-11), _URL for a URL
#   (ENVS-12), __ in a nested name (ENVS-13) and a client prefix for what the
#   browser reads (ENVS-14).
# scope: package
# custom:
#   convention: EC-0020
package conventions.checks.environment.env_grammar

import data.conventions.lib.env
import data.conventions.lib.findings as lib

# ENVS-04. The name's shape.
findings contains lib.finding("ENVS-04", entry.path, message) if {
	some entry in env.grammar_bindings
	not regex.match(name_pattern, entry.name)
	message := sprintf(
		"binding %s is not UPPER_SNAKE_CASE; rename it to upper-case words joined by underscores",
		[entry.name],
	)
}

# ENVS-04. The first word, when the schema declares its components.
findings contains lib.finding("ENVS-04", path, message) if {
	some entry in env.grammar_bindings
	path := entry.path
	name := entry.name
	regex.match(name_pattern, name)
	components := env.documents[path].naming.components
	is_array(components)
	count(components) > 0
	not starts_with_component(name, components)
	not env.starts_with_any(name, boolean_prefixes)
	not env.starts_with_any(name, env.client_prefixes(path))
	message := sprintf(
		concat(" ", [
			"binding %s does not start with a declared component (%s); rename it,",
			"or add its component to naming.components",
		]),
		[name, concat(", ", sort(components))],
	)
}

# ENVS-09
findings contains lib.finding("ENVS-09", entry.path, boolean_message(entry.path, entry.name)) if {
	some entry in env.grammar_bindings
	entry.binding.type == "boolean"
	not boolean_name(entry.path, entry.name)
}

# ENVS-10
findings contains lib.finding("ENVS-10", entry.path, message) if {
	some entry in env.grammar_bindings
	last := regex.replace(entry.name, `^.*_`, "")
	short := unit_abbreviations[last]
	message := sprintf("binding %s spells out its unit; end it in _%s instead of _%s", [entry.name, short, last])
}

# ENVS-11
findings contains lib.finding("ENVS-11", entry.path, message) if {
	some entry in env.grammar_bindings
	words := split(entry.name, "_")
	some i in numbers.range(0, count(words) - 2)
	words[i] != ""
	words[i] == words[i + 1]
	message := sprintf("binding %s repeats %s; say it once", [entry.name, words[i]])
}

# ENVS-12
findings contains lib.finding("ENVS-12", entry.path, message) if {
	some entry in env.grammar_bindings
	entry.binding.format == "url"
	not endswith(entry.name, "_URL")
	message := sprintf("binding %s holds a URL; end its name in _URL or _BASE_URL", [entry.name])
}

# ENVS-13
findings contains lib.finding("ENVS-13", entry.path, message) if {
	some entry in env.grammar_bindings
	nested := entry.binding.nested
	is_object(nested)
	not contains(entry.name, "__")
	message := sprintf(
		"binding %s is nested, so its name separates group, sub-model and field with __, e.g. %s__%s",
		[entry.name, upper(object.get(nested, "group", "GROUP")), upper(object.get(nested, "field", "FIELD"))],
	)
}

# ENVS-14
findings contains lib.finding("ENVS-14", entry.path, message) if {
	some entry in env.grammar_bindings
	entry.binding.consumer == "client"
	prefixes := env.client_prefixes(entry.path)
	not env.starts_with_any(entry.name, prefixes)
	message := sprintf(
		"binding %s is read by the browser, so it starts with a client prefix (%s)",
		[entry.name, concat(", ", sort(prefixes))],
	)
}

name_pattern := `^[A-Z][A-Z0-9]*(__?[A-Z0-9]+)*$`

boolean_prefixes := ["ENABLE_", "IS_", "HAS_", "SHOULD_"]

unit_abbreviations := {"SECONDS": "SEC", "MINUTES": "MIN", "MILLISECONDS": "MS", "PERCENT": "PCT"}

starts_with_component(name, components) if {
	some component in components
	is_string(component)
	startswith(name, concat("", [component, "_"]))
}

# A boolean's name starts with a boolean prefix, directly, after a client
# prefix, or in the field of a nested name (WORKERS__EXPORT__IS_ENABLED).
boolean_name(_, name) if env.starts_with_any(name, boolean_prefixes)

boolean_name(path, name) if {
	some prefix in env.client_prefixes(path)
	startswith(name, prefix)
	env.starts_with_any(trim_prefix(name, prefix), boolean_prefixes)
}

boolean_name(_, name) if {
	contains(name, "__")
	field := regex.replace(name, `^.*__`, "")
	env.starts_with_any(field, boolean_prefixes)
}

boolean_message(path, name) := sprintf(
	concat(" ", [
		"boolean %s does not start with ENABLE_, IS_, HAS_ or SHOULD_;",
		"a browser flag is <client prefix>ENABLE_, e.g. %sENABLE_...",
	]),
	[name, prefix],
) if {
	some prefix in env.client_prefixes(path)
	startswith(name, prefix)
}

else := sprintf("boolean %s does not start with ENABLE_, IS_, HAS_ or SHOULD_; rename it, e.g. ENABLE_...", [name])
