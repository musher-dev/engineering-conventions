# METADATA
# title: Environment schemas
# description: >-
#   Every env.schema.yaml the repository holds, its bindings, the
#   prefixes its naming vocabulary declares, and the part of each name the
#   grammar applies to (EC-0020), for the schema and grammar checks.
package conventions.lib.env

import data.conventions.lib.contracts
import data.conventions.lib.files

schema_path_pattern := `^([^/]+/)*env\.schema\.ya?ml$`

# A vendored copy under the contracts directory is another repository's
# schema, kept unchanged (EC-0032): no ENVS check reads it.
schema_documents contains doc if {
	some doc in files.own_documents
	regex.match(schema_path_pattern, doc.path)
	not vendored(doc.path)
}

# Undefined, so false, until the layout says where the contracts directory is.
vendored(path) if startswith(path, contracts.vendor_prefix)

documents[doc.path] := doc.contents if {
	some doc in schema_documents
	is_object(doc.contents)
}

bindings_of(path) := documents[path].bindings if is_object(documents[path].bindings)

# Every binding, as its schema's path, its name and its declaration.
bindings contains {"path": path, "name": name, "binding": binding} if {
	some path, _ in documents
	some name, binding in bindings_of(path)
	is_object(binding)
}

# The bindings the naming grammar applies to: not exempt, not under a
# vendor prefix the schema declares, and not a reserved organization-wide
# name. Each carries the part of its name the grammar applies to: the name
# without the schema's consumer prefix, keeping any client prefix before it.
grammar_bindings contains object.union(entry, {"rest": rest(entry.path, entry.name)}) if {
	some entry in bindings
	not entry.binding.grammar_exempt == true
	not starts_with_any(entry.name, vendor_prefixes(entry.path))
	not entry.name in org_scoped
}

# The variable names reserved for every Musher program (env.org-scoped).
org_scoped := {name | some name in object.get(data.conventions.index.vocabulary, "org_scoped_variables", [])}

# The schema's consumer prefix, with the underscore that follows it.
consumer_prefix(path) := concat("", [prefix, "_"]) if {
	prefix := documents[path].naming.consumer_prefix
	is_string(prefix)
}

default legacy(_) := set()

legacy(path) := {name | some name in documents[path].naming.legacy; is_string(name)} if {
	is_array(documents[path].naming.legacy)
}

# The name with its consumer prefix taken out: directly after the start, or
# after a client prefix.
rest(path, name) := trim_prefix(name, consumer_prefix(path)) if {
	startswith(name, consumer_prefix(path))
} else := concat("", [client, trim_prefix(trim_prefix(name, client), consumer_prefix(path))]) if {
	some client in client_prefixes(path)
	startswith(trim_prefix(name, client), consumer_prefix(path))
} else := name

# Whether a name carries the schema's consumer prefix.
prefixed(path, name) if rest(path, name) != name

# A name a library the repository does not own reads: under a vendor
# prefix, a vendor_passthrough entry, or exempt from the grammar.
vendor_name(path, name) if starts_with_any(name, vendor_prefixes(path))

vendor_name(path, name) if {
	some entry in object.get(documents[path], "vendor_passthrough", [])
	is_string(entry)
	passes(entry, name)
}

vendor_name(path, name) if bindings_of(path)[name].grammar_exempt == true

passes(entry, name) if entry == name

passes(entry, name) if {
	endswith(entry, "*")
	startswith(name, trim_suffix(entry, "*"))
}

default_client_prefixes := ["VITE_", "PUBLIC_"]

# The prefixes that mark a variable the browser reads: the schema's own, or
# the defaults, and the generated module's.
client_prefixes(path) := prefixes if {
	declared := documents[path].naming.client_prefixes
	is_array(declared)
	prefixes := {p | some p in declared} | generated_prefix(path)
} else := {p | some p in default_client_prefixes} | generated_prefix(path)

generated_prefix(path) := {prefix} if {
	prefix := documents[path].generated.ts.client_prefix
	is_string(prefix)
} else := set()

vendor_prefixes(path) := prefixes if {
	prefixes := documents[path].naming.vendor_prefixes
	is_array(prefixes)
} else := []

starts_with_any(name, prefixes) if {
	some prefix in prefixes
	is_string(prefix)
	startswith(name, prefix)
}
