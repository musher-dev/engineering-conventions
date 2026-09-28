# METADATA
# title: Values in a document
# description: >-
#   Every string value a parsed document holds, at any depth, for checks that
#   look for a path or a name wherever a caller writes it: a Taskfile
#   variable, a hook command, a workflow step, an editor setting.
package conventions.lib.values

# Every string value in a document; object keys are not included.
string_values(document) := {value |
	walk(document, [_, value])
	is_string(value)
}
