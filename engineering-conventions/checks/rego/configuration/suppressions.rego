# METADATA
# title: Suppressions
# description: >-
#   Every entry in a scanner's ignore file says why it is acceptable and,
#   where the scanner can expire it, until when: Trivy's trivyignore.yaml
#   (CONF-10) and .trivyignore (CONF-11), and .gitleaksignore (CONF-12).
# scope: package
# custom:
#   convention: EC-0012
package conventions.checks.configuration.suppressions

import data.conventions.lib.dates
import data.conventions.lib.files
import data.conventions.lib.findings as lib

# CONF-10. One finding per entry, naming everything it lacks.
findings contains lib.finding("CONF-10", path, message) if {
	some [path, section, index, entry] in yaml_entries
	problems := entry_problems(entry)
	count(problems) > 0
	message := sprintf("%s %s: %s", [section, entry_label(entry, index), concat("; ", problems)])
}

# CONF-11
findings contains lib.finding("CONF-11", path, message) if {
	some path, text in files.texts
	regex.match(`(^|/)\.?trivyignore$`, path)
	lines := lines_of(text)
	some number, line in lines
	entry(line)
	problems := array.concat(expiry_problems(line), rationale_problems(lines, number))
	count(problems) > 0
	message := sprintf("line %d (%s): %s", [number + 1, first_word(line), concat("; ", problems)])
}

# CONF-12
findings contains lib.finding("CONF-12", path, message) if {
	some path, text in files.texts
	regex.match(`(^|/)\.?gitleaksignore$`, path)
	lines := lines_of(text)
	some number, line in lines
	entry(line)
	not rationale_above(lines, number)
	message := sprintf(
		"line %d (%s) has no rationale; add a # comment directly above it saying why the finding is not a secret",
		[number + 1, first_word(line)],
	)
}

# Trivy's ignore file lists entries under one key per kind of finding.
sections := ["vulnerabilities", "misconfigurations", "secrets", "licenses"]

yaml_entries contains [doc.path, section, index, entry] if {
	some doc in files.own_documents
	regex.match(`(^|/)\.?trivyignore\.ya?ml$`, doc.path)
	is_object(doc.contents)
	some section in sections
	is_array(doc.contents[section])
	some index, entry in doc.contents[section]
	is_object(entry)
}

entry_label(entry, _) := entry.id if files.has_string(entry, "id")

entry_label(entry, index) := sprintf("entry %d", [index + 1]) if not files.has_string(entry, "id")

entry_problems(entry) := [problem |
	some check in [statement_problems(entry), expired_at_problems(entry)]
	some problem in check
]

default statement_problems(_) := ["add a statement saying why the finding is acceptable"]

statement_problems(entry) := [] if trim_space(entry.statement) != ""

default expired_at_problems(_) := ["add an expired_at date, or Trivy ignores the finding forever"]

expired_at_problems(entry) := term_problems("expired_at", entry.expired_at) if "expired_at" in object.keys(entry)

# The problems with a date that ends a suppression: it must be a date, in
# the future, and no further ahead than a waiver may run.
default term_problems(_, _) := []

term_problems(field, value) := [sprintf(
	"%s %s is not a YYYY-MM-DD date",
	[field, json.marshal(value)],
)] if {
	not dates.is_date(value)
}

term_problems(field, value) := [sprintf(
	"%s %s has passed; fix the finding and delete the entry, or renew it with a new statement",
	[field, value],
)] if {
	dates.past(value)
}

term_problems(field, value) := [sprintf(
	"%s %s is more than %d days ahead; set it to %s or earlier",
	[field, value, dates.max_term_days, dates.latest_allowed_date],
)] if {
	dates.beyond_term(value)
}

lines_of(text) := [trim_right(line, "\r") | some line in split(text, "\n")]

entry(line) if {
	trimmed := trim_space(line)
	trimmed != ""
	not startswith(trimmed, "#")
}

first_word(line) := split(trim_space(line), " ")[0]

expiry_pattern := `(^|\s)exp:(\S+)`

default expiry_problems(_) := ["add exp:YYYY-MM-DD after the ID, or Trivy ignores the finding forever"]

expiry_problems(line) := term_problems("exp", match[2]) if {
	some match in regex.find_all_string_submatch_n(expiry_pattern, line, 1)
}

default rationale_problems(_, _) := ["add a # comment directly above it saying why the finding is acceptable"]

rationale_problems(lines, number) := [] if rationale_above(lines, number)

# An entry's rationale is the comment above it; consecutive entries under
# one comment share it, and a blank line ends the group.
rationale_above(lines, number) if {
	number > 0
	above := max({k | some k in numbers.range(0, number - 1); not entry(lines[k])})
	regex.match(`^\s*#\s*\S`, lines[above])
}
