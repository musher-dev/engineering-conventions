package conventions.checks.commits.messages_test

import data.conventions.checks.commits.messages
import data.conventions.lib.testdata_test as td

config_path := ".config/commits/committed.toml"

committed := {
	"style": "conventional",
	"subject_length": 72,
	"line_length": 0,
	"subject_capitalized": false,
	"subject_not_punctuated": true,
	"imperative_subject": true,
	"no_fixup": false,
	"no_wip": true,
	"allowed_types": ["feat", "fix", "chore"],
	"allowed_scopes": ["api", "release"],
}

mise_config := {"min_version": "2026.9.12", "tools": {"github:crate-ci/committed": "1.1.11"}}

hook := "committed --config .config/commits/committed.toml --commit-file {1}"

lefthook_config := {"commit-msg": {"skip": ["merge", "rebase"], "jobs": [{
	"name": "committed",
	"run": hook,
	"fail_text": "The message must pass committed.",
}]}}

title_steps := [
	{
		"name": "Check the title passes committed",
		"env": {"TITLE": "${{ github.event.pull_request.title }}"},
		"run": "printf '%s\\n' \"$TITLE\" | committed --config .config/commits/committed.toml --commit-file -",
	},
	{
		"name": "Check the title has a scope",
		"uses": "amannn/action-semantic-pull-request@48f256284bd46cdaab1048c3721360e808335d50",
		"with": {"requireScope": true, "subjectPattern": "^[a-z].+$"},
	},
]

workflow(steps) := {
	"name": "Validate Pull Request",
	"on": {"pull_request": {"types": ["opened", "edited"]}},
	"jobs": {"title": {"runs-on": "ubuntu-24.04", "steps": steps}},
}

files := [
	config_path,
	".config/mise/config.toml",
	".config/lefthook.yml",
	".github/workflows/validate-pull-request.yml",
]

docs(overrides) := [
	td.inventory(object.get(overrides, "inventory", files)),
	td.file(config_path, object.get(overrides, "committed", committed)),
	td.file(".config/mise/config.toml", object.get(overrides, "mise", mise_config)),
	td.file(".config/lefthook.yml", object.get(overrides, "lefthook", lefthook_config)),
	td.file(".github/workflows/validate-pull-request.yml", object.get(overrides, "workflow", workflow(title_steps))),
]

messages_for(found, id) := {f.message | some f in found; f.id == id}

ids(found) := {f.id | some f in found}

test_conforming_repository if {
	count(messages.findings) == 0 with input as docs({})
}

test_commit_01_missing_configuration if {
	found := messages.findings with input as [td.inventory(["README.md"])]
	ids(found) == {"COMMIT-01"}
	some f in found
	f.path == config_path
	contains(f.message, "there is no .config/commits/committed.toml")
}

fallback := " is not a list of names, so committed falls back to its default; list every one this repository accepts"

test_commit_01_wrong_settings if {
	wrong := {
		"style": "none",
		"subject_length": 0,
		"imperative_subject": false,
		"no_wip": false,
		"subject_not_punctuated": "yes",
		"allowed_types": [],
		"allowed_scopes": ["api", 3],
	}
	found := messages.findings with input as docs({"committed": wrong})
	messages_for(found, "COMMIT-01") == {
		`style is "none", so committed does not read the type and scope; set style = "conventional"`,
		concat("", ["allowed_types", fallback]),
		concat("", ["allowed_scopes", fallback]),
		"subject_length is 0; set it between 1 and 72 so the header fits a terminal and the commit list",
		"imperative_subject is false; set imperative_subject = true",
		"no_wip is false; set no_wip = true",
		"subject_not_punctuated is yes; set subject_not_punctuated = true",
	}
}

test_commit_01_defaults_satisfy_the_rules if {
	minimal := {"style": "conventional", "allowed_types": ["feat"], "allowed_scopes": ["api"]}
	count(messages_for(messages.findings, "COMMIT-01")) == 0 with input as docs({"committed": minimal})
}

test_commit_01_subject_length_boundary if {
	at_limit := object.union(committed, {"subject_length": 72})
	count(messages_for(messages.findings, "COMMIT-01")) == 0 with input as docs({"committed": at_limit})
	over := object.union(committed, {"subject_length": 73})
	count(messages_for(messages.findings, "COMMIT-01")) == 1 with input as docs({"committed": over})
}

test_commit_01_missing_lists if {
	no_lists := object.remove(committed, ["allowed_types", "allowed_scopes"])
	count(messages_for(messages.findings, "COMMIT-01")) == 2 with input as docs({"committed": no_lists})
}

test_commit_02_unpinned if {
	unpinned := {"min_version": "2026.9.12", "tools": {"aqua:go-task/task": "3.53.1"}}
	found := messages.findings with input as docs({"mise": unpinned})
	some f in found
	f.id == "COMMIT-02"
	f.path == ".config/mise/config.toml"
}

test_commit_02_any_backend if {
	aqua := {"tools": {"aqua:crate-ci/committed": "1.1.11"}}
	count(messages_for(messages.findings, "COMMIT-02")) == 0 with input as docs({"mise": aqua})
}

test_commit_02_needs_a_mise_configuration if {
	inventory := [config_path, ".github/workflows/validate-pull-request.yml"]
	found := messages.findings with input as [
		td.inventory(inventory),
		td.file(config_path, committed),
		td.file(".github/workflows/validate-pull-request.yml", workflow(title_steps)),
	]
	count(found) == 0
}

test_commit_03_no_commit_msg_hook if {
	found := messages.findings with input as docs({"lefthook": {"pre-commit": {"jobs": []}}})
	messages_for(found, "COMMIT-03") == {concat(" ", [
		"the commit-msg hook does not run committed, so a message is first checked on the pull request;",
		"add a commit-msg job that runs committed --config .config/commits/committed.toml --commit-file {1}",
	])}
}

test_commit_03_committed_checks_head if {
	head := {"commit-msg": {"jobs": [{"name": "committed", "run": "committed --config .config/commits/committed.toml"}]}}
	found := messages.findings with input as docs({"lefthook": head})
	some message in messages_for(found, "COMMIT-03")
	contains(message, "runs committed without --config")
}

test_commit_03_grouped_job_and_equals_form if {
	grouped := {"commit-msg": {"jobs": [{"group": {"jobs": [{
		"name": "committed",
		"run": "committed --config=.config/commits/committed.toml --commit-file={1}",
	}]}}]}}
	count(messages_for(messages.findings, "COMMIT-03")) == 0 with input as docs({"lefthook": grouped})
}

test_commit_03_word_is_not_a_command if {
	lookalike := {"commit-msg": {"jobs": [{"run": "echo uncommitted --commit-file {1}"}]}}
	found := messages.findings with input as docs({"lefthook": lookalike})
	some message in messages_for(found, "COMMIT-03")
	contains(message, "does not run committed")
}

test_commit_04_title_not_checked if {
	found := messages.findings with input as docs({"workflow": workflow([title_steps[1]])})
	some f in found
	f.id == "COMMIT-04"
	f.path == ".github/workflows/validate-pull-request.yml"
	contains(f.message, "no pull request workflow runs committed on the title")
}

test_commit_04_scope_not_required if {
	unscoped := object.union(title_steps[1], {"with": {"requireScope": false}})
	found := messages.findings with input as docs({"workflow": workflow([title_steps[0], unscoped])})
	messages_for(found, "COMMIT-04") == {concat(" ", [
		"no pull request workflow requires a scope on the title, which committed cannot; add",
		"amannn/action-semantic-pull-request with requireScope: true",
	])}
}

test_commit_04_committed_on_head_is_not_the_title if {
	head := object.union(title_steps[0], {"run": "committed --config .config/commits/committed.toml HEAD"})
	found := messages.findings with input as docs({"workflow": workflow([head, title_steps[1]])})
	count(messages_for(found, "COMMIT-04")) == 1
}

test_commit_04_string_true_and_other_workflow if {
	quoted := object.union(title_steps[1], {"with": {"requireScope": "true"}})
	pr_only := {"name": "Title", "on": ["pull_request"], "jobs": {"title": {"steps": [title_steps[0], quoted]}}}
	push_only := {"name": "Release", "on": {"push": {}}, "jobs": {}}
	found := messages.findings with input as [
		td.inventory(array.concat(files, [".github/workflows/title.yml", ".github/workflows/release.yml"])),
		td.file(config_path, committed),
		td.file(".config/mise/config.toml", mise_config),
		td.file(".config/lefthook.yml", lefthook_config),
		td.file(".github/workflows/title.yml", pr_only),
		td.file(".github/workflows/release.yml", push_only),
	]
	count(found) == 0
}

test_commit_04_not_on_a_push_workflow if {
	push := {"name": "Validate", "on": {"push": {}}, "jobs": {"title": {"steps": title_steps}}}
	found := messages.findings with input as [
		td.inventory([config_path, ".github/workflows/validate.yml"]),
		td.file(config_path, committed),
		td.file(".github/workflows/validate.yml", push),
	]
	count(messages_for(found, "COMMIT-04")) == 2
	some f in found
	f.path == ".github/workflows/validate-pull-request.yml"
}

test_commit_04_reported_on_the_first_pull_request_workflow if {
	validate := {"name": "Validate", "on": {"pull_request": {}}, "jobs": {}}
	found := messages.findings with input as [
		td.inventory([config_path, ".github/workflows/validate.yml"]),
		td.file(config_path, committed),
		td.file(".github/workflows/validate.yml", validate),
	]
	{f.path | some f in found; f.id == "COMMIT-04"} == {".github/workflows/validate.yml"}
}

test_commit_04_no_workflows_no_finding if {
	found := messages.findings with input as [td.inventory([config_path]), td.file(config_path, committed)]
	count(messages_for(found, "COMMIT-04")) == 0
}

test_commit_06_old_manifest if {
	old := array.concat(files, [".github/conventional-commits.yaml"])
	found := messages.findings with input as docs({"inventory": old})
	{f.path | some f in found; f.id == "COMMIT-06"} == {".github/conventional-commits.yaml"}
}

test_commit_06_elsewhere_is_fine if {
	moved := array.concat(files, ["docs/conventional-commits.yaml"])
	count(messages_for(messages.findings, "COMMIT-06")) == 0 with input as docs({"inventory": moved})
}
