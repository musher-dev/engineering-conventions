# METADATA
# title: Dependencies declaration
# description: >-
#   Every vendored copy is declared, and not as fetched (DEPS-01) in a valid declaration
#   (DEPS-02), once and never on the repository itself (DEPS-03), at an
#   exact release, as is every package another Musher repository publishes
#   (DEPS-04); each copy carries the producer's release record for that
#   release (DEPS-05) and exactly the bytes it lists (DEPS-06), unless the
#   dependency is fetched at test or build time; and no pin lives in a file
#   of its own (DEPS-07).
# scope: package
# custom:
#   convention: EC-0032
package conventions.checks.dependencies.declaration

import data.conventions.lib.contracts
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.repository
import data.conventions.lib.schema

# DEPS-01. Reported on each undeclared copy's directory.
findings contains lib.finding("DEPS-01", path, message) if {
	some copy in copies
	not copy in declared
	path := contracts.copy_dir(copy.repository, copy.output)
	message := sprintf(
		concat(" ", [
			"%s/ is a vendored copy of %s's %q, but %s declares no such dependency; declare it with",
			"the release it is, or remove the copy",
		]),
		[path, copy.repository, copy.output, files.dependencies_path],
	)
}

# DEPS-01. A copy of a dependency declared as fetched, which nothing proves.
findings contains lib.finding("DEPS-01", path, message) if {
	some dep in dependencies
	fetched(dep)
	key(dep) in copies
	path := contracts.copy_dir(dep.repository, dep.output)
	message := sprintf(
		concat(" ", [
			"%s/ is a vendored copy of %s's %q, but %s declares it fetched, so no check proves the copy;",
			"remove the copy, or drop `fetched` so the release record proves it",
		]),
		[path, dep.repository, dep.output, files.dependencies_path],
	)
}

# DEPS-02. One finding per declaration: the first problem, and how many more.
findings contains lib.finding("DEPS-02", files.dependencies_path, schema.summary(problems)) if {
	problems := schema.problems(files.dependencies_documents, data.conventions.index.dependencies_schema)
	count(problems) > 0
}

# DEPS-03
findings contains lib.finding("DEPS-03", files.dependencies_path, message) if {
	some copy in declared
	count([dep | some dep in dependencies; key(dep) == copy]) > 1
	message := sprintf(
		"%s's %q is declared more than once; declare each vendored output once, with one version",
		[copy.repository, copy.output],
	)
}

findings contains lib.finding("DEPS-03", files.dependencies_path, message) if {
	some dep in dependencies
	dep.repository == repository.declared_name
	message := sprintf(
		concat(" ", [
			"the repository declares a dependency on itself (%q); a repository reads its own",
			"interfaces from its source, never from a release of itself",
		]),
		[dep.output],
	)
}

# DEPS-04
findings contains lib.finding("DEPS-04", files.dependencies_path, message) if {
	some dep in dependencies
	is_string(dep.version)
	not exact(dep.version)
	message := sprintf(
		concat(" ", [
			"%s's %q is pinned to %q, which is not an exact release; pin the version the producer",
			"released, such as 1.4.0, never a commit, branch or range",
		]),
		[dep.repository, dep.output, dep.version],
	)
}

findings contains lib.finding("DEPS-04", path, message) if {
	some doc in files.own_documents
	regex.match(`(^|/)package\.json$`, doc.path)
	path := doc.path
	some field in package_fields
	some name, version in object.get(doc.contents, field, {})
	startswith(name, "@musher-dev/")
	is_string(version)
	not exact(version)
	not local_protocol(version)
	message := sprintf(
		concat(" ", [
			"%s pins %s to %q in %s; pin the exact version it released, so the repository builds",
			"against one release until it chooses another",
		]),
		[path, name, version, field],
	)
}

# DEPS-05
findings contains lib.finding("DEPS-05", files.dependencies_path, message) if {
	some dep in vendored_dependencies
	record_path := contracts.record_path(dep.repository, dep.output)
	not contracts.records[record_path]
	message := sprintf(
		concat(" ", [
			"%s's %q at %s has no vendored copy with a release record at %s; vendor the release",
			"with `task deps:sync`",
		]),
		[dep.repository, dep.output, dep.version, record_path],
	)
}

findings contains lib.finding("DEPS-05", record_path, message) if {
	some dep in vendored_dependencies
	record_path := contracts.record_path(dep.repository, dep.output)
	record := contracts.records[record_path]
	problems := schema.problems_of([record], data.conventions.index.release_record_schema, "the release record")
	count(problems) > 0
	message := concat(" ", [
		schema.summary_of(problems, "the release record"),
		"Vendor the release again with `task deps:sync`.",
	])
}

findings contains lib.finding("DEPS-05", record_path, message) if {
	some dep in vendored_dependencies
	record_path := contracts.record_path(dep.repository, dep.output)
	record := contracts.records[record_path]
	some field in ["repository", "output", "version"]
	is_string(record[field])
	record[field] != dep[field]
	message := sprintf(
		concat(" ", [
			"the release record says %s %q, but %s declares %q; vendor the declared release with",
			"`task deps:sync`, or declare the one that is vendored",
		]),
		[field, record[field], files.dependencies_path, dep[field]],
	)
}

# DEPS-06. An interface the dependency names that the release does not have.
findings contains lib.finding("DEPS-06", files.dependencies_path, message) if {
	some dep in vendored_dependencies
	record := contracts.records[contracts.record_path(dep.repository, dep.output)]
	some id in object.get(dep, "interfaces", [])
	not id in {entry.id | some entry in record_interfaces(record)}
	message := sprintf(
		"%s's %q %s delivers no interface %q; name one of %s",
		[dep.repository, dep.output, dep.version, id, sorted_ids(record)],
	)
}

# DEPS-06. A file the release lists that is missing or changed.
findings contains lib.finding("DEPS-06", path, message) if {
	some dep in vendored_dependencies
	some path, digest in expected(dep)
	not path in files.repository_files
	message := sprintf(
		concat(" ", [
			"%s is missing from the vendored copy of %s's %q %s (sha256 %s); vendor the release",
			"again with `task deps:sync`",
		]),
		[path, dep.repository, dep.output, dep.version, digest],
	)
}

findings contains lib.finding("DEPS-06", path, message) if {
	some dep in vendored_dependencies
	some path, digest in expected(dep)
	actual := files.digests[path]
	actual != digest
	message := sprintf(
		concat(" ", [
			"%s is not the file %s's %q %s released: its sha256 is %s, not %s; a vendored copy is never",
			"edited, so vendor the release again with `task deps:sync`",
		]),
		[path, dep.repository, dep.output, dep.version, actual, digest],
	)
}

# DEPS-06. A file in the copy that no interface it depends on lists.
findings contains lib.finding("DEPS-06", entry.file, message) if {
	some dep in vendored_dependencies
	contracts.records[contracts.record_path(dep.repository, dep.output)]
	some entry in contracts.vendored
	entry.repository == dep.repository
	entry.output == dep.output
	entry.path != "release.json"
	not entry.file in object.keys(expected(dep))
	message := sprintf(
		concat(" ", [
			"%s is in the vendored copy of %s's %q but no interface it depends on lists it; remove",
			"it, or depend on the interface that delivers it",
		]),
		[entry.file, dep.repository, dep.output],
	)
}

# DEPS-07
findings contains lib.finding("DEPS-07", path, message) if {
	some path in files.repository_files
	regex.match(`(^|/)config/[^/]+\.(ref|lock\.json)$`, path)
	message := sprintf(
		concat(" ", [
			"%s keeps a pin in a file of its own; declare the release in %s and vendor it with",
			"`task deps:sync`, so every pin has one place and one form",
		]),
		[path, files.dependencies_path],
	)
}

default dependencies := []

dependencies := [dep |
	some dep in files.dependencies_declaration.dependencies
	is_object(dep)
	is_string(dep.repository)
	is_string(dep.output)
] if {
	is_array(files.dependencies_declaration.dependencies)
}

# The dependencies the repository vendors: every one not fetched at test or
# build time, which has no copy for DEPS-05 and DEPS-06 to prove.
vendored_dependencies := [dep | some dep in dependencies; not fetched(dep)]

fetched(dep) if dep.fetched == true

key(dep) := {"repository": dep.repository, "output": dep.output}

declared contains key(dep) if some dep in dependencies

copies contains {"repository": entry.repository, "output": entry.output} if some entry in contracts.vendored

package_fields := ["dependencies", "devDependencies", "optionalDependencies"]

exact(version) if regex.match(`^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$`, version)

# A package from the same workspace or disk, not a release.
local_protocol(version) if regex.match(`^(workspace|file|link|portal):`, version)

default record_interfaces(_) := []

record_interfaces(record) := [entry | some entry in record.interfaces; is_object(entry); is_string(entry.id)] if {
	is_array(record.interfaces)
}

sorted_ids(record) := concat(", ", sort([sprintf("%q", [entry.id]) | some entry in record_interfaces(record)]))

# The interfaces a dependency takes: the ones it names, or every one.
consumed(dep, record) := [entry | some entry in record_interfaces(record); entry.id in dep.interfaces] if {
	is_array(dep.interfaces)
}

consumed(dep, record) := record_interfaces(record) if not names_interfaces(dep)

# `not is_array(dep.interfaces)` is undefined, not true, for a missing key:
# OPA evaluates a call's arguments outside the negation.
names_interfaces(dep) if is_array(dep.interfaces)

# Each file the copy must hold, by its path in the repository, with its digest.
expected(dep) := {path: file.sha256 |
	record := contracts.records[contracts.record_path(dep.repository, dep.output)]
	some entry in consumed(dep, record)
	some file in entry.files
	is_string(file.path)
	is_string(file.sha256)
	path := concat("/", [contracts.copy_dir(dep.repository, dep.output), file.path])
}
