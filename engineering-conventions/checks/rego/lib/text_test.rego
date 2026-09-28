package conventions.lib.text_test

import data.conventions.lib.text

doc := concat("\n", [
	"---",
	"title: One",
	"paths:",
	"  - \"src/**\"",
	"---",
	"# Title",
	"",
	"See @README.md and @docs/guide.md.",
	"",
	"## Context",
	"",
	"```sh",
	"# not a heading",
	"cat @nope.md",
	"```",
	"",
	"Inline `@skipped.md` code.",
	"### Decision ###",
	"",
])

test_frontmatter_parses if {
	text.frontmatter(doc) == {"title": "One", "paths": ["src/**"]}
	text.has_frontmatter(doc)
}

test_no_frontmatter if {
	not text.frontmatter("# Title\n")
	not text.has_frontmatter("# Title\n")
	text.body("# Title\n") == "# Title\n"
}

test_frontmatter_at_end_of_file if {
	text.frontmatter("---\na: 1\n---") == {"a": 1}
}

test_headings_skip_code_blocks if {
	text.headings(doc) == [
		{"level": 1, "title": "Title"},
		{"level": 2, "title": "Context"},
		{"level": 3, "title": "Decision"},
	]
	text.has_heading(doc, 2, "context")
	not text.has_heading(doc, 2, "Decision")
}

test_imports_skip_code if {
	text.imports(doc) == ["README.md", "docs/guide.md"]
}

test_import_in_parentheses_and_relative if {
	text.imports("(@../README.md)\n@./notes.md\nmail me at a@b.c\n") == ["../README.md", "./notes.md"]
}
