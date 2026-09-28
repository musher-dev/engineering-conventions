# METADATA
# title: Markdown text
# description: >-
#   Reads the parts of a Markdown file the checks need from its raw text
#   (decision 0015): the YAML frontmatter, the headings and the @imports,
#   ignoring anything inside a fenced code block.
package conventions.lib.text

frontmatter_pattern := `^---\r?\n((?s:.*?))\r?\n---(\r?\n|$)`

has_frontmatter(text) if regex.match(frontmatter_pattern, text)

# The frontmatter's YAML, parsed; undefined when there is none or it does
# not parse.
frontmatter(text) := yaml.unmarshal(block) if {
	some match in regex.find_all_string_submatch_n(frontmatter_pattern, text, 1)
	block := match[1]
}

# The text after the frontmatter.
body(text) := regex.replace(text, frontmatter_pattern, "")

# The body with fenced code blocks removed, so a `#` comment in an example
# is not a heading and an address in one is not an import.
prose(text) := regex.replace(body(text), fence_pattern, "")

# A fenced code block, opened and closed by ``` or ~~~ (\x60 is a backtick).
fence_pattern := `(?ms)^ {0,3}(\x60{3}|~{3}).*?^ {0,3}(\x60{3}|~{3})[^\n]*$`

# Each heading as {"level": n, "title": "..."}, in the order they appear.
headings(text) := [{"level": count(match[1]), "title": trim_space(match[2])} |
	some match in regex.find_all_string_submatch_n(`(?m)^(#{1,6})[ \t]+(.+?)[ \t#]*$`, prose(text), -1)
]

has_heading(text, level, title) if {
	some heading in headings(text)
	heading.level == level
	lower(heading.title) == lower(title)
}

# The files a CLAUDE.md imports: every @path outside code, as written, less
# the punctuation that ends a sentence.
imports(text) := [trim_right(match[1], ".,;:") |
	some match in regex.find_all_string_submatch_n(import_pattern, without_code_spans(prose(text)), -1)
]

import_pattern := `(?m)(?:^|[\s(])@([A-Za-z0-9._~][A-Za-z0-9._~/-]*)`

without_code_spans(text) := regex.replace(text, `\x60[^\x60\n]*\x60`, "")
