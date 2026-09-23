package conventions.lib.filenames_test

import data.conventions.lib.filenames
import data.conventions.lib.testdata_test as td

push := {"on": "push"}

reusable := {"on": "workflow_call"}

test_offending_tokens_by_slot if {
	filenames.offending_tokens("lint-pr") == ["lint"] with data.conventions.index as td.index
	filenames.offending_tokens("release-pr") == [] with data.conventions.index as td.index
	filenames.offending_tokens("reusable-ci-nightly") == ["ci", "nightly"] with data.conventions.index as td.index
	filenames.offending_tokens("audit-scheduled") == ["scheduled"] with data.conventions.index as td.index
}

test_valid_needs_every_filename_requirement if {
	filenames.valid("validate-pr.yml", push) with data.conventions.index as td.index
	filenames.valid("reusable-build.yml", reusable) with data.conventions.index as td.index
	not filenames.valid("build.yml", push) with data.conventions.index as td.index
	not filenames.valid("reusable-validate.yml", push) with data.conventions.index as td.index
	not filenames.valid("validate.yml", reusable) with data.conventions.index as td.index
	not filenames.valid("audit-nightly.yml", push) with data.conventions.index as td.index
	not filenames.valid("Validate.yml", push) with data.conventions.index as td.index
}

suggested(stem, workflow) := filenames.suggestion(sprintf(".github/workflows/%s.yml", [stem]), workflow)

test_suggestion if {
	suggested("lint-pr", push) == "validate-pr.yml" with data.conventions.index as td.index
	suggested("lint", reusable) == "reusable-validate.yml" with data.conventions.index as td.index
	not suggested("nightly-build", push) with data.conventions.index as td.index
	existing := [td.inventory([".github/workflows/validate.yml"])]
	not suggested("ci", push) with input as existing with data.conventions.index as td.index
}
