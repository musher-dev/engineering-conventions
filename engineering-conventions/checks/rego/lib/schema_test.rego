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

test_unique_keeps_first_occurrences if {
	schema.unique(["b", "a", "b"]) == ["b", "a"]
}
