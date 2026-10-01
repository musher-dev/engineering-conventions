# METADATA
# title: Schema problems
# description: >-
#   Validates a declaration, or any document such as a decision record's
#   frontmatter, against the self-contained schema the index carries and
#   renders each problem as one sentence, sorted, each once. A field that
#   fails several keywords with the same message is one problem.
package conventions.lib.schema

problems(documents, schema) := problems_of(documents, schema, "the declaration")

# The problems of `documents`, naming the whole document `subject` when a
# problem is at its top level.
problems_of(documents, schema, subject) := unique(messages(documents, schema, subject))

messages(documents, schema, subject) := [message(error, subject) |
	some contents in documents
	[_, errors] := json.match_schema(contents, schema)
	some error in sorted(errors)
]

# The problems of `documents` against a third-party schema, less the errors
# that only say a combinator failed ("Must validate all the schemas (allOf)")
# when a more specific error says why. SchemaStore's schemas nest if/then and
# allOf deeply, and those errors name no field a reader can fix.
specific_problems_of(documents, schema, subject) := unique([message(error, subject) |
	some contents in documents
	[_, errors] := json.match_schema(contents, schema)
	some error in sorted(specific(errors))
])

combinator_errors := {"condition_then", "condition_else", "number_all_of", "number_any_of", "number_one_of"}

specific(errors) := narrowed if {
	narrowed := [error | some error in errors; not error.type in combinator_errors]
	count(narrowed) > 0
} else := errors

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

message(error, subject) := sprintf("%s: %s.", [subject, trim_suffix(error.desc, ".")]) if error.field == "(Root)"

else := sprintf("`%s`: %s.", [error.field, trim_suffix(error.desc, ".")])

# One finding per declaration: the first problem, and how many more.
summary(found) := summary_of(found, "the declaration")

summary_of(found, _) := found[0] if count(found) == 1

summary_of(found, subject) := sprintf(
	"%s (%d more problem%s in %s)",
	[found[0], count(found) - 1, plural(count(found) - 1), subject],
) if {
	count(found) > 1
}

plural(1) := ""

plural(n) := "s" if n != 1
