# METADATA
# title: Declaration schema problems
# description: >-
#   Validates a declaration against the self-contained schema the index
#   carries and renders each problem as one sentence, sorted, each once. A
#   field that fails several keywords with the same message is one problem.
package conventions.lib.schema

problems(documents, schema) := unique(messages(documents, schema))

messages(documents, schema) := [message(error) |
	some contents in documents
	[_, errors] := json.match_schema(contents, schema)
	some error in sorted(errors)
]

unique(items) := [item |
	some index, item in items
	not item in array.slice(items, 0, index)
]

sorted(errors) := [error |
	some key in sort({sort_key(e) | some e in errors})
	some error in errors
	sort_key(error) == key
]

sort_key(error) := sprintf("%s\u0000%s", [error.field, error.desc])

message(error) := sprintf("the declaration: %s.", [trim_suffix(error.desc, ".")]) if error.field == "(Root)"

else := sprintf("`%s`: %s.", [error.field, trim_suffix(error.desc, ".")])

# One finding per declaration: the first problem, and how many more.
summary(found) := found[0] if count(found) == 1

summary(found) := sprintf(
	"%s (%d more problem%s in the declaration)",
	[found[0], count(found) - 1, plural(count(found) - 1)],
) if {
	count(found) > 1
}

plural(1) := ""

plural(n) := "s" if n != 1
