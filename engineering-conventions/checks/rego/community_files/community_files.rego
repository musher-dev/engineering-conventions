# METADATA
# title: Community files
# description: >-
#   The files GitHub reads to route people to a repository: its issue forms
#   (COMM-01) and template chooser (COMM-02), its one CODEOWNERS where it has
#   one (COMM-03) written in syntax GitHub honours (COMM-04), its own security
#   policy, which says how to report a vulnerability (COMM-05), and its
#   discussion category forms (COMM-07). The forms are validated against
#   SchemaStore's schemas, vendored under checks/schemas/vendor/.
# scope: package
# custom:
#   convention: EC-0036
package conventions.checks.community_files.community_files

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.schema
import data.conventions.lib.text

index := data.conventions.index

# The documents conftest parsed, keyed by path.
parsed[doc.path] := doc.contents if some doc in files.own_documents

# GitHub reads the files directly in a template directory, not below it.
directly_in(directory, path) if {
	startswith(path, concat("", [directory, "/"]))
	not contains(substring(path, count(directory) + 1, -1), "/")
}

suggest_yml(path) := regex.replace(path, `\.[^./]+$`, ".yml")

issue_dir := ".github/ISSUE_TEMPLATE"

config_path := ".github/ISSUE_TEMPLATE/config.yml"

issue_files contains path if {
	some path in files.repository_files
	directly_in(issue_dir, path)
}

issue_forms contains path if {
	some path in issue_files
	endswith(path, ".yml")
	path != config_path
}

discussion_dir := ".github/DISCUSSION_TEMPLATE"

discussion_files contains path if {
	some path in files.repository_files
	directly_in(discussion_dir, path)
}

codeowners_path := ".github/CODEOWNERS"

# Where GitHub looks, in the order it looks; it reads the first it finds.
codeowners_locations := [codeowners_path, "CODEOWNERS", "docs/CODEOWNERS"]

codeowners_files := [path | some path in codeowners_locations; path in files.repository_files]

# Each rule: its 1-based line number, its pattern and its owners. A token is
# a run of non-space characters in which a backslash escapes the next one,
# so `docs/a\ b` is one pattern; a token starting with # ends the line.
rules[path] := [rule |
	some i, raw in split(files.texts[path], "\n")
	line := trim_space(raw)
	line != ""
	not startswith(line, "#")
	words := regex.find_n(`(?:\\.|[^\s\\])+`, line, -1)
	rule := {"line": i + 1, "pattern": words[0], "owners": owners_of(words)}
] if {
	some path in codeowners_files
	files.texts[path]
}

comment_starts(words) := [i | some i, word in words; i > 0; startswith(word, "#")]

owners_of(words) := array.slice(words, 1, min(array.concat(comment_starts(words), [count(words)])))

user_pattern := `^@[A-Za-z0-9][A-Za-z0-9_-]*$`

team_pattern := `^@[A-Za-z0-9][A-Za-z0-9_-]*/[A-Za-z0-9][A-Za-z0-9._-]*$`

email_pattern := `^[^@\s]+@[^@\s/]+\.[^@\s/]+$`

well_formed(owner) if regex.match(user_pattern, owner)

well_formed(owner) if regex.match(team_pattern, owner)

well_formed(owner) if regex.match(email_pattern, owner)

unsupported(pattern) := "starts with !, a negation CODEOWNERS does not support" if startswith(pattern, "!")

unsupported(pattern) := "uses a [ ] character range, which CODEOWNERS does not support" if {
	not startswith(pattern, "!")
	regex.match(`(^|[^\\])\[`, pattern)
}

unsupported(pattern) := `escapes a leading # with \, which CODEOWNERS does not support` if {
	startswith(pattern, `\#`)
}

security_pattern := `^(\.github/|docs/)?(?i:security)\.(?i:md|markdown|adoc|rst)$`

security_files contains path if {
	some path in files.repository_files
	regex.match(security_pattern, path)
}

reporting_pattern := `(?i)\breport(ing|s)?\b.*\bvulnerabilit(y|ies)\b`

# The titles of a policy's headings, in Markdown, AsciiDoc or
# reStructuredText (a title underlined with punctuation).
titles(path, body) := [heading.title | some heading in text.headings(body)] if {
	regex.match(`(?i)\.(md|markdown)$`, path)
}

titles(path, body) := [match[1] |
	some match in regex.find_all_string_submatch_n(`(?m)^=+[ \t]+(.+?)[ \t]*$`, body, -1)
] if {
	regex.match(`(?i)\.adoc$`, path)
}

titles(path, body) := [trim_space(match[1]) |
	some match in regex.find_all_string_submatch_n(`(?m)^([^\s].*)\r?\n[=~^"'#*+:.\x60-]{3,}[ \t]*\r?$`, body, -1)
] if {
	regex.match(`(?i)\.rst$`, path)
}

has_reporting_heading(path) if {
	some title in titles(path, files.texts[path])
	regex.match(reporting_pattern, title)
}

any_policy_reports if {
	some path in security_files
	has_reporting_heading(path)
}

findings contains lib.finding("COMM-01", path, message) if {
	some path in issue_files
	regex.match(`(?i)\.yaml$`, path)
	message := sprintf(
		"%s should be %s: GitHub reads the template chooser only as config.yml, so the directory uses .yml throughout",
		[path, suggest_yml(path)],
	)
}

findings contains lib.finding("COMM-01", path, message) if {
	some path in issue_forms
	problems := schema.specific_problems_of([parsed[path]], index.issue_forms_schema, "the form")
	count(problems) > 0
	message := sprintf(
		"GitHub's issue-forms schema rejects this file, so GitHub will not offer the form: %s",
		[schema.summary_of(problems, "the form")],
	)
}

findings contains lib.finding("COMM-02", config_path, message) if {
	count(issue_forms) > 0
	not config_path in files.repository_files
	message := concat(" ", [
		"the issue forms have no template chooser; add .github/ISSUE_TEMPLATE/config.yml that sets",
		"blank_issues_enabled, so whether a blank issue can bypass the forms is decided, not defaulted",
	])
}

findings contains lib.finding("COMM-02", config_path, message) if {
	problems := schema.specific_problems_of([parsed[config_path]], index.issue_config_schema, "the file")
	count(problems) > 0
	message := sprintf(
		"GitHub's issue-config schema rejects this file, so GitHub ignores the template chooser: %s",
		[schema.summary_of(problems, "the file")],
	)
}

findings contains lib.finding("COMM-02", config_path, message) if {
	config := parsed[config_path]
	is_object(config)
	not "blank_issues_enabled" in object.keys(config)
	message := concat(" ", [
		"the template chooser does not set blank_issues_enabled, and GitHub then allows blank issues",
		"that skip every form; set it to false, or to true if a blank issue is wanted",
	])
}

findings contains lib.finding("COMM-07", path, message) if {
	some path in discussion_files
	not endswith(path, ".yml")
	message := sprintf(
		"GitHub reads a discussion category form only as <category-slug>.yml; rename %s to %s",
		[path, suggest_yml(path)],
	)
}

findings contains lib.finding("COMM-07", path, message) if {
	some path in discussion_files
	endswith(path, ".yml")
	problems := schema.specific_problems_of([parsed[path]], index.discussion_forms_schema, "the form")
	count(problems) > 0
	message := sprintf(
		"GitHub's discussion-forms schema rejects this file, so GitHub will not offer the form: %s",
		[schema.summary_of(problems, "the form")],
	)
}

findings contains lib.finding("COMM-03", path, message) if {
	first := codeowners_files[0]
	message := sprintf(
		"GitHub reads only the first CODEOWNERS it finds, %s, and ignores this one; merge its rules there and delete it",
		[first],
	)
	some path in codeowners_files
	path != codeowners_path
	path != first
}

findings contains lib.finding("COMM-03", path, message) if {
	path := codeowners_files[0]
	path != codeowners_path
	message := sprintf("keep the repository's one CODEOWNERS at %s; move %s there", [codeowners_path, path])
}

findings contains lib.finding("COMM-04", path, message) if {
	some path, path_rules in rules
	some rule in path_rules
	reason := unsupported(rule.pattern)
	message := sprintf(
		"line %d: the pattern `%s` %s, so GitHub skips the whole line; list the paths it should match instead",
		[rule.line, rule.pattern, reason],
	)
}

findings contains lib.finding("COMM-04", path, message) if {
	some path, path_rules in rules
	some rule in path_rules
	some owner in rule.owners
	not well_formed(owner)
	message := sprintf(
		concat(" ", [
			"line %d: `%s` is not an owner GitHub recognises; write @user, @org/team or an email address,",
			"or leave the pattern with no owner to make it explicitly unowned",
		]),
		[rule.line, owner],
	)
}

findings contains lib.finding("COMM-04", path, message) if {
	some path, path_rules in rules
	some later in path_rules
	earlier_lines := [rule.line | some rule in path_rules; rule.pattern == later.pattern; rule.line < later.line]
	count(earlier_lines) > 0
	message := sprintf(
		concat(" ", [
			"line %d repeats the pattern `%s` from line %d, and the later line silently replaces the",
			"earlier one's owners; put every owner for a pattern on one line",
		]),
		[later.line, later.pattern, max(earlier_lines)],
	)
}

# A policy too large to embed has no text here, and is not judged.
findings contains lib.finding("COMM-05", path, message) if {
	not any_policy_reports
	message := concat(" ", [
		"the security policy has no heading on reporting a vulnerability; add one, such as",
		"`## Reporting a vulnerability`, that says where to report privately and what happens next",
	])
	some path in security_files
	files.texts[path]
}
