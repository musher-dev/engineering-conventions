package conventions.checks.opentofu.state_test

import data.conventions.checks.opentofu.state
import data.conventions.lib.testdata_test as td

identity := td.repository({"name": "platform-network"})

# A Taskfile kept in the root's own directory, as the includes of a shared
# layer Taskfile pass it.
layer(path, vars) := td.file(path, {"version": "3", "includes": {"tofu": {
	"taskfile": "../../taskfiles/layer.yml",
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

network := "tfstate/platform-network/network/terraform.tfstate"

test_a_conforming_key_in_the_root_directory if {
	docs := [layer("terraform/network/Taskfile.yml", {"TOFU_STATE_KEY": network})]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_a_conforming_key_named_by_directory if {
	docs := [named("taskfiles/tofu.Taskfile.yml", {
		"TOFU_DIR": "terraform/network",
		"TOFU_STATE_KEY": network,
	})]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_a_templated_environment_segment_passes if {
	docs := [layer("terraform/app/Taskfile.yml", {
		"TOFU_STATE_KEY": "tfstate/platform-network/app/{{.ENV}}/terraform.tfstate",
		"TOFU_NEEDS_ENV": "true",
	})]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_a_directory_per_environment_passes if {
	docs := [named("Taskfile.yml", {
		"TOFU_DIR": "./terraform/network/prod",
		"TOFU_STATE_KEY": "tfstate/platform-network/network/prod/terraform.tfstate",
	})]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_a_key_built_at_run_time_is_not_judged if {
	docs := [named("taskfiles/layer.yml", {
		"TOFU_STATE_KEY": "{{.TOFU_STATE_KEY | default \"\"}}",
		"OTHER_STATE_KEY": "{{if eq .ENV \"prod\"}}tfstate/x/terraform.tfstate{{end}}",
		"EMPTY_STATE_KEY": "",
		"SHELL_STATE_KEY": "${KEY}",
	})]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_other_variables_are_not_keys if {
	docs := [named("Taskfile.yml", {"TOFU_BACKEND_CONFIG": "../backend.hcl", "STATE_KEYS": "x"})]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_a_non_taskfile_is_ignored if {
	vars := {"TOFU_STATE_KEY": "tfstate/shared-network/terraform.tfstate"}
	docs := [td.file("config/vars.yml", {"vars": vars})]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_no_repository_segment if {
	path := "taskfiles/tofu.Taskfile.yml"
	docs := [named(path, {
		"TOFU_DIR": "terraform/network",
		"TOFU_STATE_KEY": "tfstate/shared-network/terraform.tfstate",
	})]
	found := state.findings with input as with_identity(docs)
	td.pairs(found) == {["TOFU-01", path]}
	messages(found) == {concat("", [
		"TOFU_STATE_KEY \"tfstate/shared-network/terraform.tfstate\" names no repository after tfstate/, ",
		"so it is unique only by luck and says nothing of its owner; name the state key ",
		"tfstate/platform-network/network/terraform.tfstate, or ",
		"tfstate/platform-network/network/<env>/terraform.tfstate for a root split by environment, ",
		"and migrate a used key rather than edit it",
	])}
}

test_outside_tfstate if {
	found := state.findings with input as root_key("platform-network/network/terraform.tfstate")
	reason(found) == ["is outside tfstate/, so retention rules and tools that scan tfstate/ miss it"]
}

test_no_root_segment if {
	found := state.findings with input as root_key("tfstate/platform-network/terraform.tfstate")
	reason(found) == ["names no root, so a second root in the repository has nowhere to go"]
	some f in found
	contains(f.message, "tfstate/platform-network/<root>/terraform.tfstate")
}

test_wrong_file_name if {
	found := state.findings with input as root_key("tfstate/platform-network/network/state.json")
	reason(found) == ["does not end in /terraform.tfstate"]
}

test_too_many_segments if {
	found := state.findings with input as root_key("tfstate/platform-network/a/b/c/terraform.tfstate")
	reason(found) == ["has more segments than a root and an environment"]
}

test_root_segment_differs_from_the_directory if {
	path := "terraform/network/Taskfile.yml"
	docs := [layer(path, {"TOFU_STATE_KEY": "tfstate/platform-network/shared-network/terraform.tfstate"})]
	found := state.findings with input as with_identity(docs)
	td.pairs(found) == {["TOFU-01", path]}
	reason(found) == ["names the root shared-network, but the root's directory is network"]
}

test_a_prefixed_key_pairs_with_its_directory if {
	docs := [named("Taskfile.yml", {
		"TOFU_DIR": "./terraform/network",
		"TOFU_STATE_KEY": "tfstate/platform-network/network/terraform.tfstate",
		"DNS_DIR": "./terraform/dns",
		"DNS_STATE_KEY": "tfstate/platform-network/network/terraform.tfstate",
	})]
	found := state.findings with input as with_identity(docs)
	reason(found) == ["names the root network, but the root's directory is dns"]
	some f in found
	startswith(f.message, "DNS_STATE_KEY ")
}

test_the_root_is_not_compared_when_ambiguous if {
	docs := [
		named("Taskfile.yml", {"TOFU_DIR": ".", "TOFU_STATE_KEY": "tfstate/platform-network/a/terraform.tfstate"}),
		named("taskfiles/b.yml", {"TOFU_DIR": "./", "TOFU_STATE_KEY": "tfstate/platform-network/b/terraform.tfstate"}),
		named("c/Taskfile.yml", {"TOFU_STATE_KEY": "tfstate/platform-network/c2/terraform.tfstate"}),
		named("d/Taskfile.yml", {"TOFU_DIR": "{{.ROOT}}", "TOFU_STATE_KEY": "tfstate/platform-network/d2/terraform.tfstate"}),
	]
	count(state.findings) == 0 with input as with_identity(docs)
}

test_the_actual_name_is_judged if {
	docs := [
		td.named_inventory(["Taskfile.yml"], "platform-network-renamed"),
		named("Taskfile.yml", {"TOFU_STATE_KEY": network}),
	]
	found := state.findings with input as with_identity(docs)
	reason(found) == ["names no repository after tfstate/, so it is unique only by luck and says nothing of its owner"]
}

test_without_a_name_only_the_shape_is_judged if {
	passing := [named("Taskfile.yml", {"TOFU_STATE_KEY": "tfstate/anything/network/terraform.tfstate"})]
	count(state.findings) == 0 with input as passing
	failing := [named("Taskfile.yml", {"TOFU_STATE_KEY": "tfstate/x/terraform.tfstate"})]
	found := state.findings with input as failing
	some f in found
	contains(f.message, "tfstate/<repository>/<root>/terraform.tfstate")
}
