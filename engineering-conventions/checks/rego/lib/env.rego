# METADATA
# title: Environment schemas
# description: >-
#   Every env.schema.yaml the repository holds, its bindings, and the
#   prefixes its naming vocabulary declares (EC-0020), for the schema and
#   grammar checks.
package conventions.lib.env

import data.conventions.lib.files

schema_path_pattern := `^([^/]+/)*env\.schema\.ya?ml$`

schema_documents contains doc if {
	some doc in files.own_documents
	regex.match(schema_path_pattern, doc.path)
}

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

# The bindings the naming grammar applies to: not exempt, and not under a
# vendor prefix the schema declares.
grammar_bindings contains entry if {
	some entry in bindings
	not entry.binding.grammar_exempt == true
	not starts_with_any(entry.name, vendor_prefixes(entry.path))
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
