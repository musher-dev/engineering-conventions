# METADATA
# title: Waivers
# description: >-
#   Reads the waivers in the conventions declaration, decides which are still
#   in force at the evaluation time, and which findings each one covers.
package conventions.lib.waivers

import data.conventions.lib.files

day_ns := ((24 * 60) * 60) * 1000000000

max_term_days := 180

# The runner passes the evaluation time so a fixture's expectations never
# depend on the day it runs; outside the runner the clock is the fallback.
given_now := data.conventions.runtime.now if is_string(data.conventions.runtime.now)

now_ns := time.parse_rfc3339_ns(given_now) if given_now

now_ns := time.now_ns() if not given_now

default declared := []

declared := [waiver | some waiver in files.declaration.waivers; is_object(waiver)] if {
	is_array(files.declaration.waivers)
}

# `expires` is a date; YAML leaves an unquoted date as its string, and a full
# RFC 3339 timestamp is accepted too.
expires_ns(waiver) := time.parse_rfc3339_ns(concat("", [waiver.expires, "T00:00:00Z"])) if {
	regex.match(`^[0-9]{4}-[0-9]{2}-[0-9]{2}$`, waiver.expires)
}

expires_ns(waiver) := time.parse_rfc3339_ns(waiver.expires) if {
	is_string(waiver.expires)
	not regex.match(`^[0-9]{4}-[0-9]{2}-[0-9]{2}$`, waiver.expires)
}

expired(waiver) if expires_ns(waiver) < now_ns

active(waiver) if expires_ns(waiver) >= now_ns

too_long(waiver) if expires_ns(waiver) > now_ns + (max_term_days * day_ns)

latest_allowed_date := substring(time.format([now_ns + (max_term_days * day_ns), "UTC", "2006-01-02"]), 0, 10)

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
