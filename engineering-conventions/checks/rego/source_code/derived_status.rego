# METADATA
# title: Derived status
# description: >-
#   The one machine check behind EC-0045: pyright's and basedpyright's
#   reportMatchNotExhaustive, which makes a match over a state enum fail
#   when it misses a member, is not turned off (STATUS-06). The rest of the
#   convention is judged in review.
# scope: package
# custom:
#   convention: EC-0045
package conventions.checks.source_code.derived_status

import data.conventions.lib.files
import data.conventions.lib.findings as lib

# STATUS-06. A pyproject.toml section of either checker.
findings contains lib.finding("STATUS-06", path, message(section, value)) if {
	some path, contents in configurations(pyproject_pattern)
	some section in ["pyright", "basedpyright"]
	settings := contents.tool[section]
	is_object(settings)
	value := settings.reportMatchNotExhaustive
	off(value)
}

findings contains lib.finding("STATUS-06", path, message("pyright", value)) if {
	some path, contents in configurations(pyrightconfig_pattern)
	value := contents.reportMatchNotExhaustive
	off(value)
}

# The same files CONF-18 reads; bin/conventions passes or parses exactly
# these.
pyproject_pattern := `(^|/)pyproject\.toml$`

pyrightconfig_pattern := `(^|/)pyrightconfig\.json$`

configurations(pattern) := {doc.path: doc.contents |
	some doc in files.own_documents
	regex.match(pattern, doc.path)
	is_object(doc.contents)
}

# A level that never fails the type check. "warning" fails it, because a
# tool's warnings fail its gate (CONF-22); true is "error".
off_levels := {"none", "information", "hint"}

off(false)

off(value) if {
	is_string(value)
	lower(value) in off_levels
}

message(section, value) := sprintf(
	concat(" ", [
		"%s sets reportMatchNotExhaustive to %s, so a match over a state enum that misses a member",
		"passes the type check; remove the setting, or set it to error",
	]),
	[section, json.marshal(value)],
)
