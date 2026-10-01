package conventions.checks.community_files.community_files_test

import data.conventions.checks.community_files.community_files as community
import data.conventions.lib.testdata_test as td

# The shared test index, with the real vendored schemas: the point of these
# checks is what SchemaStore's schemas accept.
index := object.union(td.index, {
	"issue_forms_schema": data.conventions.index.issue_forms_schema,
	"issue_config_schema": data.conventions.index.issue_config_schema,
	"funding_schema": data.conventions.index.funding_schema,
	"discussion_forms_schema": data.conventions.index.discussion_forms_schema,
})

form := {
	"name": "Bug report",
	"description": "Something does not work as documented.",
	"labels": ["bug"],
	"body": [{
		"type": "textarea",
		"id": "what-happened",
		"attributes": {"label": "What happened?"},
		"validations": {"required": true},
	}],
}

chooser := {"blank_issues_enabled": false}

codeowners := "# Owners\n/docs/ @your-org/docs\n/src/ @alice bob@example.com # the API\n/src/generated/\n"

policy := "# Security policy\n\n## Reporting a vulnerability\n\nUse a private advisory.\n"

# A conforming repository: its parsed documents and texts, with `changes`
# applied. A null value removes a file.
# Issue forms are added only where a test needs them: validating against
# the issue-forms schema is the slowest thing these checks do.
standard_documents := {}

forms := {
	".github/ISSUE_TEMPLATE/bug-report.yml": form,
	".github/ISSUE_TEMPLATE/config.yml": chooser,
}

standard_texts := {
	".github/CODEOWNERS": codeowners,
	"SECURITY.md": policy,
}

repository(documents, texts, extra) := array.concat(
	[td.file(path, contents) | some path, contents in documents; contents != null],
	[td.file("/tmp/inventory.json", {"conventions_inventory": {
		"files": array.flatten([
			[path | some path, contents in documents; contents != null],
			[path | some path, body in texts; is_string(body)],
			extra,
		]),
		"texts": {path: body | some path, body in texts; is_string(body)},
	}})],
)

# A shallow merge: a changed file replaces the standard one whole.
merge(base, changes) := object.union(object.remove(base, object.keys(changes)), changes)

changed(documents, texts, extra) := repository(
	merge(standard_documents, documents),
	merge(standard_texts, texts),
	extra,
)

messages(findings, id) := {f.message | some f in findings; f.id == id}

test_a_conforming_repository if {
	count(community.findings) == 0 with input as changed(forms, {}, [])
		with data.conventions.index as index
}

test_comm_01_markdown_and_yaml_templates if {
	documents := object.union(forms, {".github/ISSUE_TEMPLATE/feature.yaml": form})
	result := community.findings with input as changed(documents, {}, [
		".github/ISSUE_TEMPLATE/question.md",
		"docs/issue_template.md",
		".github/ISSUE_TEMPLATE/drafts/old.md",
	])
		with data.conventions.index as index
	td.pairs(result) == {
		["COMM-01", ".github/ISSUE_TEMPLATE/feature.yaml"],
		["COMM-01", ".github/ISSUE_TEMPLATE/question.md"],
		["COMM-01", "docs/issue_template.md"],
	}
	messages(result, "COMM-01") == {
		concat(" ", [
			".github/ISSUE_TEMPLATE/question.md is a Markdown issue template, which GitHub opens as free text",
			"with nothing required; convert it to an issue form, .github/ISSUE_TEMPLATE/question.yml, with name,",
			"description and body",
		]),
		concat(" ", [
			".github/ISSUE_TEMPLATE/feature.yaml should be .github/ISSUE_TEMPLATE/feature.yml: GitHub reads the",
			"template chooser only as config.yml, so the directory uses .yml throughout",
		]),
		concat(" ", [
			"docs/issue_template.md is a single Markdown issue template, which GitHub opens as free text with",
			"nothing required; replace it with issue forms in .github/ISSUE_TEMPLATE/, such as",
			".github/ISSUE_TEMPLATE/bug-report.yml",
		]),
	}
}

test_comm_01_an_invalid_form if {
	broken := {"name": "Bug", "body": [{"type": "textarea", "attributes": {}}]}
	documents := merge(forms, {".github/ISSUE_TEMPLATE/bug-report.yml": broken})
	result := community.findings with input as changed(documents, {}, [])
		with data.conventions.index as index
	messages(result, "COMM-01") == {concat(" ", [
		"GitHub's issue-forms schema rejects this file, so GitHub will not offer the form:",
		"the form: description is required. (1 more problem in the form)",
	])}
}

test_comm_01_reads_only_the_template_directory if {
	elsewhere := ["docs/templates/bug.md", ".github/pull_request_template.md"]
	count(community.findings) == 0 with input as changed({}, {}, elsewhere)
		with data.conventions.index as index
}

test_comm_02_forms_without_a_chooser if {
	result := community.findings with input as changed({".github/ISSUE_TEMPLATE/bug-report.yml": form}, {}, [])
		with data.conventions.index as index
	td.pairs(result) == {["COMM-02", ".github/ISSUE_TEMPLATE/config.yml"]}
}

test_comm_02_no_chooser_needed_without_forms if {
	count(community.findings) == 0 with input as changed({}, {}, [".github/ISSUE_TEMPLATE/notes.txt"])
		with data.conventions.index as index
}

test_comm_02_an_invalid_chooser if {
	config := {"blank_issues_enabled": false, "contact_links": [{"name": "Docs", "url": "https://example.com"}]}
	result := community.findings with input as changed({".github/ISSUE_TEMPLATE/config.yml": config}, {}, [])
		with data.conventions.index as index
	messages(result, "COMM-02") == {concat(" ", [
		"GitHub's issue-config schema rejects this file, so GitHub ignores the template chooser:",
		"`contact_links.0`: about is required.",
	])}
}

test_comm_02_blank_issues_left_to_the_default if {
	result := community.findings with input as changed({".github/ISSUE_TEMPLATE/config.yml": {}}, {}, [])
		with data.conventions.index as index
	messages(result, "COMM-02") == {concat(" ", [
		"the template chooser does not set blank_issues_enabled, and GitHub then allows blank issues that",
		"skip every form; set it to false, or to true if a blank issue is wanted",
	])}
}

test_comm_03_funding if {
	count(community.findings) == 0 with input as changed({".github/FUNDING.yml": {"github": ["your-org"]}}, {}, [])
		with data.conventions.index as index
	misplaced := ["FUNDING.yml", ".github/FUNDING.yaml"]
	result := community.findings with input as changed({".github/FUNDING.yml": {"paypal": "your-org"}}, {}, misplaced)
		with data.conventions.index as index
	td.pairs(result) == {
		["COMM-03", ".github/FUNDING.yml"],
		["COMM-03", "FUNDING.yml"],
		["COMM-03", ".github/FUNDING.yaml"],
	}
	"GitHub reads funding links only from .github/FUNDING.yml; move FUNDING.yml there" in messages(result, "COMM-03")
}

test_comm_04_no_codeowners if {
	result := community.findings with input as changed({}, {".github/CODEOWNERS": null}, [])
		with data.conventions.index as index
	td.pairs(result) == {["COMM-04", ".github/CODEOWNERS"]}
}

test_comm_04_misplaced_and_ignored if {
	texts := {".github/CODEOWNERS": null, "CODEOWNERS": codeowners, "docs/CODEOWNERS": codeowners}
	result := community.findings with input as changed({}, texts, [])
		with data.conventions.index as index
	td.pairs(result) == {["COMM-04", "CODEOWNERS"], ["COMM-04", "docs/CODEOWNERS"]}
	messages(result, "COMM-04") == {
		"keep the repository's one CODEOWNERS at .github/CODEOWNERS; move CODEOWNERS there",
		concat(" ", [
			"GitHub reads only the first CODEOWNERS it finds, CODEOWNERS, and ignores this one;",
			"merge its rules there and delete it",
		]),
	}
}

test_comm_04_a_second_copy_beside_github if {
	result := community.findings with input as changed({}, {"docs/CODEOWNERS": codeowners}, [])
		with data.conventions.index as index
	td.pairs(result) == {["COMM-04", "docs/CODEOWNERS"]}
}

test_comm_05_unsupported_syntax if {
	text := concat("\n", [
		"!/docs/ @alice",
		"/src/[ab]/ @alice",
		`\#notes @alice`,
		`/docs/a\ b/ @alice`,
		`/docs/\[x\]/ @alice`,
	])
	result := community.findings with input as changed({}, {".github/CODEOWNERS": text}, [])
		with data.conventions.index as index
	messages(result, "COMM-05") == {
		concat(" ", [
			"line 1: the pattern `!/docs/` starts with !, a negation CODEOWNERS does not support, so GitHub",
			"skips the whole line; list the paths it should match instead",
		]),
		concat(" ", [
			"line 2: the pattern `/src/[ab]/` uses a [ ] character range, which CODEOWNERS does not support,",
			"so GitHub skips the whole line; list the paths it should match instead",
		]),
		concat(" ", [
			"line 3: the pattern `\\#notes` escapes a leading # with \\, which CODEOWNERS does not support,",
			"so GitHub skips the whole line; list the paths it should match instead",
		]),
	}
}

test_comm_05_owners if {
	text := "/docs/ alice @bob, @org/ @org/team-a @b_c dev@example.com # and @not-an-owner\n"
	result := community.findings with input as changed({}, {".github/CODEOWNERS": text}, [])
		with data.conventions.index as index
	{m | some m in messages(result, "COMM-05"); contains(m, "is not an owner")} == {
		concat(" ", [
			"line 1: `alice` is not an owner GitHub recognises; write @user, @org/team or an email address,",
			"or leave the pattern with no owner to make it explicitly unowned",
		]),
		concat(" ", [
			"line 1: `@bob,` is not an owner GitHub recognises; write @user, @org/team or an email address,",
			"or leave the pattern with no owner to make it explicitly unowned",
		]),
		concat(" ", [
			"line 1: `@org/` is not an owner GitHub recognises; write @user, @org/team or an email address,",
			"or leave the pattern with no owner to make it explicitly unowned",
		]),
	}
}

test_comm_05_repeated_patterns if {
	text := "/src/ @alice\r\n/docs/ @bob\r\n/src/ @carol\r\nsrc/ @dave\r\n/src/ @erin\r\n"
	result := community.findings with input as changed({}, {".github/CODEOWNERS": text}, [])
		with data.conventions.index as index
	messages(result, "COMM-05") == {
		concat(" ", [
			"line 3 repeats the pattern `/src/` from line 1, and the later line silently replaces the earlier",
			"one's owners; put every owner for a pattern on one line",
		]),
		concat(" ", [
			"line 5 repeats the pattern `/src/` from line 3, and the later line silently replaces the earlier",
			"one's owners; put every owner for a pattern on one line",
		]),
	}
}

test_comm_06_no_policy if {
	result := community.findings with input as changed({}, {"SECURITY.md": null}, [])
		with data.conventions.index as index
	td.pairs(result) == {["COMM-06", "SECURITY.md"]}
}

test_comm_06_no_reporting_heading if {
	text := "# Security\n\n```markdown\n## Reporting a vulnerability\n```\n\nBe careful.\n"
	result := community.findings with input as changed({}, {"SECURITY.md": text}, [])
		with data.conventions.index as index
	td.pairs(result) == {["COMM-06", "SECURITY.md"]}
}

test_comm_06_accepted_locations_and_formats if {
	markdown := "# Policy\n\n### How to report vulnerabilities\n"
	count(community.findings) == 0 with input as changed({}, {"SECURITY.md": null, ".github/security.md": markdown}, [])
		with data.conventions.index as index
	adoc := "= Policy\n\n== Reporting a Vulnerability\n"
	count(community.findings) == 0 with input as changed({}, {"SECURITY.md": null, "docs/SECURITY.adoc": adoc}, [])
		with data.conventions.index as index
	rst := "Policy\n======\n\nReporting a vulnerability\n-------------------------\n\nWrite to us.\n"
	count(community.findings) == 0 with input as changed({}, {"SECURITY.md": null, "SECURITY.rst": rst}, [])
		with data.conventions.index as index
	prose := "Policy\n======\n\nReport a vulnerability here.\n"
	count(community.findings) == 1 with input as changed({}, {"SECURITY.md": null, "SECURITY.rst": prose}, [])
		with data.conventions.index as index
}

test_comm_06_a_policy_too_large_to_embed_is_not_judged if {
	count(community.findings) == 0 with input as changed({}, {"SECURITY.md": null}, ["SECURITY.md"])
		with data.conventions.index as index
}

test_comm_06_a_policy_elsewhere_does_not_count if {
	result := community.findings with input as changed({}, {"SECURITY.md": null, "docs/security/SECURITY.md": policy}, [])
		with data.conventions.index as index
	td.pairs(result) == {["COMM-06", "SECURITY.md"]}
}

test_comm_08_discussion_forms if {
	ideas := {"body": [{"type": "textarea", "id": "idea", "attributes": {"label": "What?"}}]}
	count(community.findings) == 0 with input as changed({".github/DISCUSSION_TEMPLATE/ideas.yml": ideas}, {}, [])
		with data.conventions.index as index
	untitled := {".github/DISCUSSION_TEMPLATE/ideas.yml": {"title": "[Idea] "}}
	result := community.findings with input as changed(untitled, {}, [".github/DISCUSSION_TEMPLATE/q.yaml"])
		with data.conventions.index as index
	td.pairs(result) == {
		["COMM-08", ".github/DISCUSSION_TEMPLATE/ideas.yml"],
		["COMM-08", ".github/DISCUSSION_TEMPLATE/q.yaml"],
	}
	messages(result, "COMM-08") == {
		concat(" ", [
			"GitHub's discussion-forms schema rejects this file, so GitHub will not offer the form:",
			"the form: body is required.",
		]),
		concat(" ", [
			"GitHub reads a discussion category form only as <category-slug>.yml; rename",
			".github/DISCUSSION_TEMPLATE/q.yaml to .github/DISCUSSION_TEMPLATE/q.yml",
		]),
	}
}
