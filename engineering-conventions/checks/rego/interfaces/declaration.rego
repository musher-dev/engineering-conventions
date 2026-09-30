# METADATA
# title: Interfaces declaration
# description: >-
#   Every file in the contracts directory belongs to a declared interface
#   (IFACE-01); each interface names registered values (IFACE-02), a unique
#   ID (IFACE-03), definitions that match files (IFACE-04) no other
#   interface claims (IFACE-05), and the output that delivers it (IFACE-06);
#   a versioned interface's files carry their major version (IFACE-07); and
#   its definitions live in the contracts directory (IFACE-08).
# scope: package
# custom:
#   convention: EC-0030
package conventions.checks.interfaces.declaration

import data.conventions.lib.contracts
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.names

# IFACE-01. Reported on each file, so a waiver can name the files it covers.
findings contains lib.finding("IFACE-01", path, message) if {
	some path in contracts.offered_files
	not path in declared_files
	message := sprintf(
		concat(" ", [
			"%s is in %s/, which holds only what other repositories build against, but no interface",
			"in %s covers it; add it to an interface's definitions, or move it out of %s/",
		]),
		[path, contracts.dir, files.outputs_path, contracts.dir],
	)
}

# IFACE-02
findings contains lib.finding("IFACE-02", files.outputs_path, message) if {
	some index, entry in contracts.interfaces
	some field, allowed in registered
	files.has_string(entry, field)
	not entry[field] in allowed
	message := sprintf(
		"%s has %s %q, which is not registered; use one of %s",
		[label(entry, index), field, entry[field], names.quoted_list(allowed)],
	)
}

# IFACE-03
findings contains lib.finding("IFACE-03", files.outputs_path, message) if {
	some id in {entry.id | some entry in contracts.interfaces; is_string(entry.id)}
	count([entry | some entry in contracts.interfaces; entry.id == id]) > 1
	message := sprintf(
		concat(" ", [
			"interface ID %q is used more than once; give each interface its own ID, which consumers",
			"address as <repository>#<id>",
		]),
		[id],
	)
}

# IFACE-04
findings contains lib.finding("IFACE-04", files.outputs_path, message) if {
	some index, entry in contracts.interfaces
	some pattern in contracts.definitions(entry)
	count(contracts.covered(pattern)) == 0
	message := sprintf(
		concat(" ", [
			"%s names definitions %q, which matches no file the repository holds; point it at the",
			"files that define the interface",
		]),
		[label(entry, index), pattern],
	)
}

# IFACE-05. Reported on each file two interfaces claim.
findings contains lib.finding("IFACE-05", path, message) if {
	some path in declared_files
	owners := {entry.id |
		some entry in contracts.interfaces
		is_string(entry.id)
		path in contracts.interface_files(entry)
	}
	count(owners) > 1
	message := sprintf(
		"%s belongs to interfaces %s; narrow their definitions so each file belongs to one interface",
		[path, names.quoted_list(owners)],
	)
}

# IFACE-06
findings contains lib.finding("IFACE-06", files.outputs_path, message) if {
	some index, entry in contracts.interfaces
	files.has_string(entry, "delivered_by")
	not entry.delivered_by in object.keys(outputs)
	message := sprintf(
		concat(" ", [
			"%s is delivered by %q, which is not an output in %s; name the bundle, site or library",
			"output that delivers it",
		]),
		[label(entry, index), entry.delivered_by, files.outputs_path],
	)
}

findings contains lib.finding("IFACE-06", files.outputs_path, message) if {
	some index, entry in contracts.interfaces
	output := outputs[entry.delivered_by]
	is_string(output.kind)
	not output.kind in deliverers
	message := sprintf(
		"%s is delivered by %q, whose kind is %q; an interface's files are delivered by a bundle, library or site output",
		[label(entry, index), entry.delivered_by, output.kind],
	)
}

# IFACE-07. Reported on each file without its version.
findings contains lib.finding("IFACE-07", path, message) if {
	some entry in contracts.interfaces
	entry.compatibility == "versioned"
	some path in contracts.interface_files(entry)
	not regex.match(`\.v[0-9]+\.`, files.basename(path))
	message := sprintf(
		concat(" ", [
			"%s belongs to versioned interface %q but its name carries no .vN.; name it for its major",
			"version, such as %s",
		]),
		[path, entry.id, suggestion(files.basename(path))],
	)
}

# IFACE-08
findings contains lib.finding("IFACE-08", files.outputs_path, message) if {
	some index, entry in contracts.interfaces
	some pattern in contracts.definitions(entry)
	not offered_path(pattern)
	message := sprintf(
		concat(" ", [
			"%s names definitions %q outside %s/; keep every interface the repository offers there,",
			"so its consumers and checks find it in one place",
		]),
		[label(entry, index), pattern, contracts.dir],
	)
}

vocabulary := object.get(data.conventions.index, "vocabulary", {})

registered := {
	"format": {token | some token in object.get(vocabulary, "interface_formats", [])},
	"compatibility": {token | some token in object.get(vocabulary, "interface_compatibilities", [])},
	"audience": {token | some token in object.get(vocabulary, "repository_audiences", [])},
}

# The output kinds that deliver an interface's files to its consumers.
deliverers := {"bundle", "library", "site"}

outputs[output.id] := output if {
	some output in files.outputs_declaration.outputs
	is_object(output)
	is_string(output.id)
}

declared_files contains path if {
	some entry in contracts.interfaces
	some path in contracts.interface_files(entry)
}

offered_path(pattern) if {
	startswith(pattern, concat("", [contracts.dir, "/"]))
	not startswith(pattern, concat("", [contracts.vendor_dir, "/"]))
}

label(entry, _) := sprintf("interface %q", [entry.id]) if files.has_string(entry, "id")

label(entry, index) := sprintf("interface %d", [index + 1]) if not files.has_string(entry, "id")

# order.created.schema.json -> order.created.v1.schema.json; a.proto -> a.v1.proto
suggestion(name) := concat("", [trim_suffix(name, ".schema.json"), ".v1.schema.json"]) if endswith(name, ".schema.json")

suggestion(name) := regex.replace(name, `^(.+)\.([^.]+)$`, "$1.v1.$2") if {
	not endswith(name, ".schema.json")
	contains(name, ".")
}

suggestion(name) := concat("", [name, ".v1"]) if not contains(name, ".")
