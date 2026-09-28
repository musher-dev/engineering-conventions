# METADATA
# title: Dates and terms
# description: >-
#   The evaluation time, date parsing and the longest term a time-boxed
#   deviation may run: a waiver in the conventions declaration, or a
#   suppression in a scanner's ignore file.
package conventions.lib.dates

day_ns := ((24 * 60) * 60) * 1000000000

max_term_days := 180

# The runner passes the evaluation time so a fixture's expectations never
# depend on the day it runs; outside the runner the clock is the fallback.
given_now := data.conventions.runtime.now if is_string(data.conventions.runtime.now)

now_ns := time.parse_rfc3339_ns(given_now) if given_now

now_ns := time.now_ns() if not given_now

date_pattern := `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`

# A date written "YYYY-MM-DD" is midnight UTC. A full RFC 3339 timestamp is
# accepted too, which is also how conftest renders an unquoted TOML date.
# Undefined for anything else, including an impossible date.
date_ns(value) := time.parse_rfc3339_ns(concat("", [value, "T00:00:00Z"])) if {
	is_string(value)
	regex.match(date_pattern, value)
}

date_ns(value) := time.parse_rfc3339_ns(value) if {
	is_string(value)
	not regex.match(date_pattern, value)
}

is_date(value) if date_ns(value)

past(value) if date_ns(value) < now_ns

beyond_term(value) if date_ns(value) > now_ns + (max_term_days * day_ns)

latest_allowed_date := substring(time.format([now_ns + (max_term_days * day_ns), "UTC", "2006-01-02"]), 0, 10)
