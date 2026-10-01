# METADATA
# title: INI text
# description: >-
#   Reads an INI file, such as a Vale config, from its raw text (decision
#   0015). conftest's ini parser drops the keys before the first section,
#   which is where Vale keeps StylesPath, Packages and MinAlertLevel, so the
#   checks parse the text the runner embeds instead.
package conventions.lib.ini

# The global section: the keys before the first [section].
global := ""

lines(text) := split(replace(text, "\r", ""), "\n")

# Each [section] header, with the line it is on.
headers(text) := [{"index": index, "name": trim_space(match[1])} |
	some index, line in lines(text)
	some match in regex.find_all_string_submatch_n(`^\s*\[(.*)\]\s*$`, line, 1)
]

# Each key = value line, with the section it belongs to. A value loses a
# trailing comment, which go-ini, Vale's parser, starts with " #" or " ;".
entries(text) := [entry |
	heads := headers(text)
	some index, line in lines(text)
	not comment(line)
	some match in regex.find_all_string_submatch_n(`^\s*([^=\[\]#;]+?)\s*=\s*(.*)$`, line, 1)
	entry := {
		"section": section_at(heads, index),
		"key": trim_space(match[1]),
		"value": trim_space(regex.replace(match[2], `\s+[#;].*$`, "")),
		"line": index + 1,
	}
]

comment(line) if regex.match(`^\s*[#;]`, line)

# The section a line belongs to: the last header above it.
section_at(heads, index) := head.name if {
	some head in heads
	head.index < index
	not later_header(heads, head.index, index)
}

else := global

later_header(heads, after, before) if {
	some head in heads
	head.index > after
	head.index < before
}

# The names of the sections the file declares.
sections(text) := {head.name | some head in headers(text)}

# The value of `key` in `section`; the last one wins, as in go-ini.
value(text, section, key) := last.value if {
	matching := [entry | some entry in entries(text); entry.section == section; entry.key == key]
	count(matching) > 0
	last := matching[count(matching) - 1]
}

# A comma-separated value as a list, without empty items: Packages and
# BasedOnStyles are written this way.
list(value) := [trim_space(item) | some item in split(value, ","); trim_space(item) != ""]
