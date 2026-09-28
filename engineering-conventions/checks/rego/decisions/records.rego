# METADATA
# title: Decision records
# description: >-
#   A repository's decision records are named NNNN-kebab-slug in their
#   directory (DEC-01), carry valid frontmatter (DEC-02), are numbered
#   uniquely and without gaps (DEC-03), link to each other in both
#   directions (DEC-04), have the MADR sections (DEC-05) and an Enforcement
#   section (DEC-06), and are all linked from the directory's index (DEC-07).
#   Nothing fires in a repository without a decisions directory.
# scope: package
# custom:
#   convention: EC-0021
package conventions.checks.decisions.records

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.schema
import data.conventions.lib.text

# Where the records are: `[decisions]` in the conventions declaration, or
# docs/decisions/ with one NNNN-slug.md file per record.
default config := {}

config := files.declaration.decisions if is_object(files.declaration.decisions)

default directory := "docs/decisions"

directory := config.path if is_string(config.path)

default form := "file"

form := "directory" if config.form == "directory"

default page := "README.md"

page := config.page if is_string(config.page)

# The index is README.md beside file records, and the page itself at the
# top of a directory of records (a site's landing page for the section).
default index_name := "README.md"

index_name := page if form == "directory"

index_path := concat("/", [directory, index_name])

name_pattern := `^[0-9]{4}-[a-z0-9]+(-[a-z0-9]+)*$`

# Every Markdown file under the directory, keyed by its path relative to it.
entries[relative] := path if {
	some path in files.repository_files
	startswith(path, concat("", [directory, "/"]))
	endswith(path, ".md")
	relative := substring(path, count(directory) + 1, -1)
}

# The records, keyed by path, with their name (NNNN-slug), in either form.
# README.md and template.md (or template/) are not records.
candidates[path] := trim_suffix(relative, ".md") if {
	form == "file"
	some relative, path in entries
	not contains(relative, "/")
	not relative in {"README.md", "template.md"}
}

candidates[path] := parts[0] if {
	form == "directory"
	some relative, path in entries
	parts := split(relative, "/")
	count(parts) == 2
	parts[1] == page
	parts[0] != "template"
}

record_names[path] := name if {
	some path, name in candidates
	regex.match(name_pattern, name)
}

number(path) := substring(record_names[path], 0, 4)

used_numbers contains to_number(number(path)) if some path, _ in record_names

first := min(used_numbers)

pad(digits) := concat("", [substring("0000", 0, 4 - count(digits)), digits])

# Each record's frontmatter, when it parses to a mapping.
frontmatters[path] := parsed if {
	some path, _ in record_names
	parsed := text.frontmatter(files.texts[path])
	is_object(parsed)
}

inverse := {
	"supersedes": "superseded_by",
	"superseded_by": "supersedes",
	"amends": "amended_by",
	"amended_by": "amends",
}

linked(parsed, field) := [item | some item in files.as_list(parsed[field]); is_string(item)]

no_frontmatter := concat(" ", [
	"the decision record has no frontmatter; start it with a --- block holding at least",
	"title, date and status",
])

unparsed_frontmatter := "the decision record's frontmatter is not valid YAML; fix the block between the --- lines"

no_enforcement := concat(" ", [
	"the decision record has no `## Enforcement` section; add one naming the check that holds",
	"the decision, or saying review-only and what a reviewer looks for",
])

empty_enforcement := concat(" ", [
	"the `## Enforcement` section is empty; name the check that holds the decision, or write",
	"review-only and what a reviewer looks for",
])

required_sections := ["Context", "Decision", "Consequences"]

# A level-2 heading whose title starts with the word, such as "Context" or
# MADR's "Context and Problem Statement".
has_section(body, word) if {
	some heading in text.headings(body)
	heading.level == 2
	regex.match(sprintf(`(?i)^%s\b`, [word]), heading.title)
}

# The Enforcement section's text, up to the next level-1 or level-2 heading.
enforcement_pattern := `(?msi)^##[ \t]+Enforcement\b[^\n]*\n(.*?)(?:^#{1,2}[ \t]|\z)`

enforcement_stated(body) if {
	some match in regex.find_all_string_submatch_n(enforcement_pattern, text.prose(body), 1)
	trim_space(match[1]) != ""
}

# A Markdown link, inline or reference-style, whose target holds the
# record's name followed by its extension, a slash, an anchor or its end.
links_to(index, name) if regex.match(
	sprintf(`(?m)(\]\(|^\[[^\]]+\]:[ \t]*)[^)\s]*\b%s([./#?)]|\s|$)`, [name]),
	index,
)

# DEC-01: a record's name.
findings contains lib.finding("DEC-01", path, message) if {
	some path, name in candidates
	not regex.match(name_pattern, name)
	message := sprintf(
		concat(" ", [
			"decision record %q is not named NNNN-kebab-slug; rename it to a four-digit number and a",
			"lowercase, hyphenated slug, such as 0007-store-sessions-in-the-database",
		]),
		[name],
	)
}

# DEC-01: a Markdown file nested below file records is not a record.
findings contains lib.finding("DEC-01", path, message) if {
	form == "file"
	some relative, path in entries
	contains(relative, "/")
	message := sprintf(
		concat(" ", [
			"%s is in a subdirectory of %s, where only NNNN-slug.md records, README.md and template.md",
			"belong; move it into %s as a record, or out of the decisions directory",
		]),
		[path, directory, directory],
	)
}

# DEC-01: a loose file beside directory records is not a record.
findings contains lib.finding("DEC-01", path, message) if {
	form == "directory"
	some relative, path in entries
	not contains(relative, "/")
	not relative in {page, "template.md"}
	message := sprintf(
		concat(" ", [
			"%s is a file in %s, whose records are directories; move it to %s/NNNN-slug/%s,",
			"or out of the decisions directory",
		]),
		[path, directory, directory, page],
	)
}

# DEC-02: frontmatter that is missing, is not YAML, or fails the schema.
findings contains lib.finding("DEC-02", path, no_frontmatter) if {
	some path, _ in record_names
	not text.has_frontmatter(files.texts[path])
}

findings contains lib.finding("DEC-02", path, unparsed_frontmatter) if {
	some path, _ in record_names
	body := files.texts[path]
	text.has_frontmatter(body)
	not text.frontmatter(body)
}

findings contains lib.finding("DEC-02", path, schema.summary_of(problems, "the frontmatter")) if {
	some path, _ in record_names
	problems := schema.problems_of(
		[text.frontmatter(files.texts[path])],
		data.conventions.index.decision_schema,
		"the frontmatter",
	)
	count(problems) > 0
}

# DEC-03: each number is used once.
findings contains lib.finding("DEC-03", path, message) if {
	some path, _ in record_names
	others := sort([other |
		some other_path, other in record_names
		other_path != path
		number(other_path) == number(path)
	])
	count(others) > 0
	message := sprintf(
		"number %s is also used by %s; give this decision the next unused number, since a number is never shared",
		[number(path), concat(", ", others)],
	)
}

# DEC-03: numbering starts at 0000 or 0001.
findings contains lib.finding("DEC-03", path, message) if {
	first > 1
	some path, _ in record_names
	to_number(number(path)) == first
	message := sprintf(
		"the first decision record is numbered %s; number records from 0000 or 0001, without gaps",
		[number(path)],
	)
}

# DEC-03: no gaps.
findings contains lib.finding("DEC-03", path, message) if {
	some path, _ in record_names
	n := to_number(number(path))
	n > first
	not (n - 1) in used_numbers
	message := sprintf(
		concat(" ", [
			"no decision record is numbered %s, the number before %s; a record is never deleted, so",
			"restore it (a withdrawn decision stays, with status rejected or deprecated), or renumber",
			"this record if it is new",
		]),
		[pad(format_int(n - 1, 10)), number(path)],
	)
}

# DEC-04: a link names a record that exists.
findings contains lib.finding("DEC-04", path, message) if {
	some path, parsed in frontmatters
	some field, _ in inverse
	some target in linked(parsed, field)
	not target in {number(other) | some other, _ in record_names}
	message := sprintf(
		"%s lists %s, but no decision record is numbered %s; correct the number or remove it",
		[field, target, target],
	)
}

# DEC-04: the record a link names links back. The finding is on the record
# that lacks the link, since that is the file to change.
findings contains lib.finding("DEC-04", target_path, message) if {
	some path, parsed in frontmatters
	some field, back in inverse
	some target in linked(parsed, field)
	some target_path, target_parsed in frontmatters
	number(target_path) == target
	target_path != path
	not number(path) in linked(target_parsed, back)
	message := sprintf(
		"%s lists %s in %s, but this record's %s does not list %s; add %q to %s",
		[number(path), target, field, back, number(path), number(path), back],
	)
}

# DEC-04: only a superseded record names its successors. The schema
# (DEC-02) requires superseded_by once the status is superseded.
findings contains lib.finding("DEC-04", path, message) if {
	some path, parsed in frontmatters
	count(linked(parsed, "superseded_by")) > 0
	is_string(parsed.status)
	parsed.status != "superseded"
	message := sprintf(
		"superseded_by is set but the status is %q; a decision another replaces has status superseded",
		[parsed.status],
	)
}

# DEC-05
findings contains lib.finding("DEC-05", path, message) if {
	some path, _ in record_names
	body := files.texts[path]
	some section in required_sections
	not has_section(body, section)
	message := sprintf(
		"the decision record has no `## %s` section; add it (Context, Decision and Consequences are required)",
		[section],
	)
}

# DEC-06: the Enforcement section exists and says something.
findings contains lib.finding("DEC-06", path, no_enforcement) if {
	some path, _ in record_names
	not has_section(files.texts[path], "Enforcement")
}

findings contains lib.finding("DEC-06", path, empty_enforcement) if {
	some path, _ in record_names
	body := files.texts[path]
	has_section(body, "Enforcement")
	not enforcement_stated(body)
}

# DEC-07: the index exists.
findings contains lib.finding("DEC-07", index_path, message) if {
	count(record_names) > 0
	not index_path in files.repository_files
	message := sprintf(
		"the decisions directory has no index; add %s with a link to every record",
		[index_path],
	)
}

# DEC-07: the index links every record.
findings contains lib.finding("DEC-07", index_path, message) if {
	index := files.texts[index_path]
	some name in record_names
	not links_to(index, name)
	message := sprintf("the index does not link decision record %s; add a link to it", [name])
}
