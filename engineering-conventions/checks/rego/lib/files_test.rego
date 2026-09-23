package conventions.lib.files_test

import data.conventions.lib.files
import data.conventions.lib.testdata_test as td

test_classifies_and_normalises_paths if {
	docs := [
		td.file("./.github/workflows/validate.yml", td.validate),
		td.file(".github/actions/setup-tools/action.yml", {"name": "Setup Tools"}),
		td.file(".github/rulesets/main.json", td.ruleset([])),
		td.declaration({"profile": "base-repo"}),
		td.inventory(["./.github/README.md"]),
		td.file("notes.txt", "plain"),
	]
	object.keys(files.workflows) == {".github/workflows/validate.yml"} with input as docs
	object.keys(files.actions) == {".github/actions/setup-tools/action.yml"} with input as docs
	object.keys(files.rulesets) == {".github/rulesets/main.json"} with input as docs
	files.declaration == {"profile": "base-repo"} with input as docs
	files.declared with input as docs
	".github/README.md" in files.repository_files with input as docs
	not "/tmp/inventory.json" in files.repository_files with input as docs
}

test_missing_declaration_reads_as_empty if {
	files.declaration == {} with input as [td.inventory([])]
	not files.declared with input as [td.inventory([])]
}

test_declaration_seen_only_in_inventory_counts_as_declared if {
	files.declared with input as [td.inventory([".repo/conventions.yaml"])]
}

test_non_array_input_has_no_documents if {
	files.documents == [] with input as {"path": "x"}
}

test_triggers_in_every_form if {
	files.triggers({"on": "push"}) == {"push"}
	files.triggers({"on": ["push", "pull_request"]}) == {"push", "pull_request"}
	files.triggers({"true": {"workflow_call": null}}) == {"workflow_call"}
	files.triggers({"on": {"push": null}, "true": {"schedule": null}}) == {"push"}
	files.triggers({"name": "x"}) == set()
}

test_workflow_units if {
	reusable := {"on": "workflow_call"}
	files.is_reusable(reusable)
	files.is_callable(reusable)
	not files.is_entry_point(reusable)

	dual := {"on": ["workflow_call", "workflow_dispatch"]}
	files.is_entry_point(dual)
	files.is_callable(dual)
	not files.is_reusable(dual)

	entry := {"on": "push"}
	files.is_entry_point(entry)
	not files.is_callable(entry)
	not files.is_reusable(entry)

	untriggered := {"name": "x"}
	not files.is_entry_point(untriggered)
	not files.is_callable(untriggered)
}

test_uppercase_extension_is_a_workflow if {
	docs := [td.file(".github/workflows/validate.YML", td.validate), td.inventory([".github/workflows/deploy.Yaml"])]
	object.keys(files.workflows) == {".github/workflows/validate.YML"} with input as docs
	files.workflow_files == {".github/workflows/validate.YML", ".github/workflows/deploy.Yaml"} with input as docs
	files.stem(".github/workflows/validate.YML") == "validate"
}

test_trigger_config_only_for_mapping_form if {
	files.trigger_config({"on": {"push": {"paths": ["a"]}}}, "push") == {"paths": ["a"]}
	not files.trigger_config({"on": ["push"]}, "push")
}

test_jobs_and_steps_skip_malformed_entries if {
	files.jobs({"jobs": {"a": {"x": 1}, "b": "junk"}}) == {"a": {"x": 1}}
	files.jobs({"jobs": []}) == {}
	files.steps({"steps": [{"run": "x"}, "junk"]}) == [{"run": "x"}]
	files.steps({}) == []
	files.action_steps({"runs": {"steps": [{"run": "x"}]}}) == [{"run": "x"}]
	files.action_steps({"runs": "node20"}) == []
}

test_step_collections if {
	docs := [
		td.file(".github/workflows/validate.yml", td.validate),
		td.file(".github/actions/setup-tools/action.yml", {"runs": {"steps": [{"run": "x"}]}}),
	]
	count(files.workflow_steps) == 3 with input as docs
	entry := {"path": ".github/actions/setup-tools/action.yml", "index": 0, "step": {"run": "x"}}
	files.action_step_entries == {entry} with input as docs
}

test_path_helpers if {
	files.basename(".github/workflows/validate.yml") == "validate.yml"
	files.stem(".github/workflows/validate.yaml") == "validate"
	files.extension(".github/workflows/validate.yaml") == "yaml"
}

test_as_list if {
	files.as_list("a") == ["a"]
	files.as_list(["a", "b"]) == ["a", "b"]
	files.as_list(null) == []
}

test_step_label if {
	files.step_label({"id": "build"}, 0) == `step "build"`
	files.step_label({"name": "Build it"}, 0) == `step "Build it"`
	files.step_label({"run": "x"}, 2) == "step 3"
}
