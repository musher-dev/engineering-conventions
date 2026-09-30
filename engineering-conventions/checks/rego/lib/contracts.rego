# METADATA
# title: Contracts directory
# description: >-
#   Where a repository keeps the interfaces it offers and the copies it
#   vendors (EC-0030, EC-0032): the contracts directory of its product, the
#   interfaces its outputs declaration lists and the files each one covers,
#   and each vendored copy with the release record it carries.
package conventions.lib.contracts

import data.conventions.lib.doublestar
import data.conventions.lib.files
import data.conventions.lib.layout

# <product>/contracts, or contracts at the root when the repository declares
# no product directory (product = ""). Undefined until the layout is
# declared: REPO-14 reports that first.
dir := concat("/", [layout.product_dir, "contracts"]) if layout.product_dir

dir := "contracts" if {
	layout.declared
	not layout.product_dir
}

vendor_dir := concat("/", [dir, "vendor"])

# Every file under the contracts directory that the repository offers: not a
# vendored copy, not a document and not a dotfile.
offered_files contains path if {
	some path in files.repository_files
	startswith(path, concat("", [dir, "/"]))
	not startswith(path, concat("", [vendor_dir, "/"]))
	not endswith(lower(path), ".md")
	not startswith(files.basename(path), ".")
}

default interfaces := []

interfaces := [entry | some entry in files.outputs_declaration.interfaces; is_object(entry)] if {
	is_array(files.outputs_declaration.interfaces)
}

default definitions(_) := []

definitions(entry) := [pattern | some pattern in entry.definitions; is_string(pattern)] if {
	is_array(entry.definitions)
}

# The files one definitions entry names: a file, a directory (with or
# without its trailing /), or a doublestar glob.
covered(pattern) := {path | some path in files.repository_files; startswith(path, pattern)} if {
	endswith(pattern, "/")
}

covered(pattern) := {path |
	some path in files.repository_files
	doublestar.match(pattern, path)
} if {
	not endswith(pattern, "/")
	glob_pattern(pattern)
}

covered(pattern) := {pattern} if {
	not endswith(pattern, "/")
	not glob_pattern(pattern)
	pattern in files.repository_files
}

covered(pattern) := {path | some path in files.repository_files; startswith(path, concat("", [pattern, "/"]))} if {
	not endswith(pattern, "/")
	not glob_pattern(pattern)
	not pattern in files.repository_files
}

glob_pattern(pattern) if regex.match(`[*?\[{]`, pattern)

# The files an interface covers, across all its definitions.
interface_files(entry) := {path | some pattern in definitions(entry); some path in covered(pattern)}

# Every file of a vendored copy, as the repository and output it came from
# and its path inside the copy, which is its path in the producer's bundle.
vendored contains {"repository": parts[0], "output": parts[1], "file": path, "path": inner} if {
	some path in files.repository_files
	startswith(path, vendor_prefix)
	parts := split(trim_prefix(path, vendor_prefix), "/")
	count(parts) > 2
	inner := concat("/", array.slice(parts, 2, count(parts)))
}

vendor_prefix := concat("", [vendor_dir, "/"])

copy_dir(repository, output) := concat("/", [vendor_dir, repository, output])

record_path(repository, output) := concat("/", [copy_dir(repository, output), "release.json"])

# The release record a vendored copy carries, as parsed.
records[path] := doc.contents if {
	some doc in files.own_documents
	path := doc.path
	regex.match(`(^|/)contracts/vendor/[^/]+/[^/]+/release\.json$`, path)
}
