package conventions.lib.schema_test

import data.conventions.lib.schema
import data.conventions.lib.testdata_test as td

test_valid_declaration_has_no_problems if {
	schema.problems([object.union({"schema_version": 1}, td.identity)], td.repository_schema) == []
}

test_problems_are_sorted_and_rendered if {
	declaration := {"schema_version": 1, "name": "x", "owner": "@musher-dev/x", "tier": 4, "team": "x"}
	found := schema.problems([declaration], td.repository_schema)
	found == [
		"the declaration: Additional property team is not allowed.",
		"`tier`: Must be less than or equal to 3.",
	]
}

test_summary_counts_the_rest if {
	schema.summary(["a"]) == "a"
	schema.summary(["a", "b"]) == "a (1 more problem in the declaration)"
	schema.summary(["a", "b", "c"]) == "a (2 more problems in the declaration)"
}

test_problems_name_their_subject if {
	frontmatter := {"title": "x", "date": "x", "status": "x", "k": 1}
	found := schema.problems_of([frontmatter], td.decision_schema, "the frontmatter")
	found == [
		"the frontmatter: Additional property k is not allowed.",
		"`status`: status must be one of the following: \"proposed\", \"accepted\", \"superseded\".",
	]
	schema.summary_of(found, "the frontmatter") == concat("", [
		"the frontmatter: Additional property k is not allowed.",
		" (1 more problem in the frontmatter)",
	])
}

test_unique_keeps_first_occurrences if {
	schema.unique(["b", "a", "b"]) == ["b", "a"]
}

conditional := {
	"type": "object",
	"properties": {"kind": {"type": "string"}, "label": {"type": "string"}},
	"if": {"properties": {"kind": {"const": "input"}}},
	"then": {"required": ["label"]},
}

test_specific_problems_drop_combinators_that_name_no_field if {
	schema.specific_problems_of([{"kind": "input"}], conditional, "the form") == ["the form: label is required."]
}

test_specific_problems_keep_a_combinator_when_it_is_all_there_is if {
	either := {"properties": {"v": {"anyOf": [{"type": "string"}, {"type": "integer"}]}}}
	found := schema.specific_problems_of([{"v": true}], either, "the value")
	count(found) > 0
	every problem in found {
		startswith(problem, "`v`:")
	}
}
