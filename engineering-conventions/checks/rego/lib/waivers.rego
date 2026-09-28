# METADATA
# title: Waivers
# description: >-
#   Reads the waivers in the conventions declaration, decides which are still
#   in force at the evaluation time, and which findings each one covers.
package conventions.lib.waivers

import data.conventions.lib.dates
import data.conventions.lib.files

default declared := []

declared := [waiver | some waiver in files.declaration.waivers; is_object(waiver)] if {
	is_array(files.declaration.waivers)
}

# `expires` is a quoted date, "YYYY-MM-DD" (lib/dates.rego).
expires_ns(waiver) := dates.date_ns(waiver.expires)

expired(waiver) if dates.past(waiver.expires)

active(waiver) if expires_ns(waiver) >= dates.now_ns

too_long(waiver) if dates.beyond_term(waiver.expires)

requirement_entry(id) := data.conventions.index.requirements[id]

# The ADOPT family polices waivers themselves, so it can never be waived; the
# prefix test backs up the index flag.
waivable(id) if {
	requirement_entry(id).waivable == true
	not startswith(id, "ADOPT-")
}

# A waiver without `paths` covers the requirement everywhere.
matches(waiver, finding) if {
	waiver.requirement == finding.id
	not "paths" in object.keys(waiver)
}

matches(waiver, finding) if {
	waiver.requirement == finding.id
	some pattern in waiver.paths
	glob.match(pattern, ["/"], finding.path)
}

suppressed(finding) if {
	waivable(finding.id)
	some waiver in declared
	active(waiver)
	matches(waiver, finding)
}

# How a message names one waiver: its position and requirement, because two
# waivers may share a requirement.
label(index, waiver) := sprintf("waiver %d (%s)", [index + 1, waiver.requirement]) if is_string(waiver.requirement)

label(index, waiver) := sprintf("waiver %d", [index + 1]) if not files.has_string(waiver, "requirement")
