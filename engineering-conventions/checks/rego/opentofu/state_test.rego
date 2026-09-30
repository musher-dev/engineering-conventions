package conventions.checks.opentofu.state_test

import data.conventions.checks.opentofu.state
import data.conventions.lib.testdata_test as td

identity := td.repository({"name": "infra-github"})

# A Taskfile kept in the root's own directory, as the includes of a shared
# layer Taskfile pass it.
layer(path, vars) := td.file(path, {"version": "3", "includes": {"tofu": {
	"taskfile": "../../taskfiles/tofu-layer.yml",
	"flatten": true,
	"vars": object.union({"TOFU_DIR": "."}, vars),
}}})

# A Taskfile that sets its variables itself.
named(path, vars) := td.file(path, {"version": "3", "vars": vars, "tasks": {}})

# The root Taskfile, stating one key and no directory.
root_key(value) := [identity, named("Taskfile.yml", {"TOFU_STATE_KEY": value})]

with_identity(docs) := array.concat([identity], docs)

messages(found) := {f.message | some f in found}

# The reason a finding gives, between the quoted key and the advice.
reason(found) := [trim_space(split(split(f.message, "; name the")[0], "\"")[2]) | some f in found]

organization := "tfstate/infra-github/organization/terraform.tfstate"

test_a_conforming_key_in_the_root_directory if {
	docs := [layer("terraform/organization/Taskfile.yml", {"TOFU_STATE_KEY": organization})]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_a_conforming_key_named_by_directory if {
	docs := [named("taskfiles/tofu.Taskfile.yml", {
		"TOFU_DIR": "terraform/organization",
		"TOFU_STATE_KEY": organization,
	})]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_a_templated_environment_segment_passes if {
	docs := [layer("terraform/runtime-substrate/Taskfile.yml", {
		"TOFU_STATE_KEY": "tfstate/infra-github/runtime-substrate/{{.ENV}}/terraform.tfstate",
		"TOFU_NEEDS_ENV": "true",
	})]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_a_directory_per_environment_passes if {
	docs := [named("Taskfile.yml", {
		"TOFU_DIR": "./terraform/organization/prod",
		"TOFU_STATE_KEY": "tfstate/infra-github/organization/prod/terraform.tfstate",
	})]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_a_key_built_at_run_time_is_not_judged if {
	docs := [named("taskfiles/tofu-layer.yml", {
		"TOFU_STATE_KEY": "{{.TOFU_STATE_KEY | default \"\"}}",
		"OTHER_STATE_KEY": "{{if eq .ENV \"prod\"}}tfstate/x/terraform.tfstate{{end}}",
		"EMPTY_STATE_KEY": "",
		"SHELL_STATE_KEY": "${KEY}",
	})]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_other_variables_are_not_keys if {
	docs := [named("Taskfile.yml", {"TOFU_BACKEND_CONFIG": "../backend.s3.hcl", "STATE_KEYS": "x"})]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_a_non_taskfile_is_ignored if {
	vars := {"TOFU_STATE_KEY": "tfstate/github-organization/terraform.tfstate"}
	docs := [td.file("config/vars.yml", {"vars": vars})]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_no_repository_segment if {
	path := "taskfiles/tofu.Taskfile.yml"
	docs := [named(path, {
		"TOFU_DIR": "terraform/organization",
		"TOFU_STATE_KEY": "tfstate/github-organization/terraform.tfstate",
	})]
	found := state.findings with input as with_identity(docs)
	td.pairs(found) == {["TOFU-01", path]}
	messages(found) == {concat("", [
		"TOFU_STATE_KEY \"tfstate/github-organization/terraform.tfstate\" names no repository after tfstate/, ",
		"so it is unique only by luck and says nothing of its owner; name the state key ",
		"tfstate/infra-github/organization/terraform.tfstate, or ",
		"tfstate/infra-github/organization/<env>/terraform.tfstate for a root split by environment, ",
		"and migrate a used key rather than edit it",
	])}
}

test_outside_tfstate if {
	found := state.findings with input as root_key("infra-github/organization/terraform.tfstate")
	reason(found) == ["is outside tfstate/, so the bucket's lifecycle rule and every tool that scans tfstate/ miss it"]
}

test_no_root_segment if {
	found := state.findings with input as root_key("tfstate/infra-github/terraform.tfstate")
	reason(found) == ["names no root, so a second root in the repository has nowhere to go"]
	some f in found
	contains(f.message, "tfstate/infra-github/<root>/terraform.tfstate")
}

test_wrong_file_name if {
	found := state.findings with input as root_key("tfstate/infra-github/organization/state.json")
	reason(found) == ["does not end in /terraform.tfstate"]
}

test_too_many_segments if {
	found := state.findings with input as root_key("tfstate/infra-github/a/b/c/terraform.tfstate")
	reason(found) == ["has more segments than a root and an environment"]
}

test_root_segment_differs_from_the_directory if {
	path := "terraform/organization/Taskfile.yml"
	docs := [layer(path, {"TOFU_STATE_KEY": "tfstate/infra-github/github-organization/terraform.tfstate"})]
	found := state.findings with input as with_identity(docs)
	td.pairs(found) == {["TOFU-01", path]}
	reason(found) == ["names the root github-organization, but the root's directory is organization"]
}

test_a_prefixed_key_pairs_with_its_directory if {
	docs := [named("Taskfile.yml", {
		"TOFU_DIR": "./terraform/bootstrap",
		"TOFU_STATE_KEY": "tfstate/infra-github/bootstrap/terraform.tfstate",
		"FOUNDATION_DIR": "./terraform/foundation",
		"FOUNDATION_STATE_KEY": "tfstate/infra-github/bootstrap/terraform.tfstate",
	})]
	found := state.findings with input as with_identity(docs)
	reason(found) == ["names the root bootstrap, but the root's directory is foundation"]
	some f in found
	startswith(f.message, "FOUNDATION_STATE_KEY ")
}

test_the_root_is_not_compared_when_ambiguous if {
	docs := [
		named("Taskfile.yml", {"TOFU_DIR": ".", "TOFU_STATE_KEY": "tfstate/infra-github/a/terraform.tfstate"}),
		named("taskfiles/b.yml", {"TOFU_DIR": "./", "TOFU_STATE_KEY": "tfstate/infra-github/b/terraform.tfstate"}),
		named("c/Taskfile.yml", {"TOFU_STATE_KEY": "tfstate/infra-github/c2/terraform.tfstate"}),
		named("d/Taskfile.yml", {"TOFU_DIR": "{{.ROOT}}", "TOFU_STATE_KEY": "tfstate/infra-github/d2/terraform.tfstate"}),
	]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_the_actual_name_is_judged if {
	docs := [
		td.named_inventory(["Taskfile.yml"], "infra-github-renamed"),
		named("Taskfile.yml", {"TOFU_STATE_KEY": organization}),
	]
	found := state.findings with input as with_identity(docs)
	reason(found) == ["names no repository after tfstate/, so it is unique only by luck and says nothing of its owner"]
}

test_without_a_name_only_the_shape_is_judged if {
	passing := [named("Taskfile.yml", {"TOFU_STATE_KEY": "tfstate/anything/organization/terraform.tfstate"})]
	count(state.findings) == 0 with input as passing
	failing := [named("Taskfile.yml", {"TOFU_STATE_KEY": "tfstate/x/terraform.tfstate"})]
	found := state.findings with input as failing
	some f in found
	contains(f.message, "tfstate/<repository>/<root>/terraform.tfstate")
}
