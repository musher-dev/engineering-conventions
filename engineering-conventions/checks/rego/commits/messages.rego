# METADATA
# title: Commit messages
# description: >-
#   .config/commits/committed.toml states the commit rules (COMMIT-01),
#   committed is pinned in mise (COMMIT-02), lefthook's commit-msg hook runs
#   it on the message file (COMMIT-03), a pull request workflow runs it on
#   the title and requires a scope (COMMIT-04), and no
#   .github/conventional-commits.yaml remains (COMMIT-06).
# scope: package
# custom:
#   convention: EC-0035
package conventions.checks.commits.messages

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.mise

config_path := ".config/commits/committed.toml"

configs[doc.path] := doc.contents if {
	some doc in files.own_documents
	doc.path == config_path
	is_object(doc.contents)
}

# committed's own defaults, for a key the file leaves out
# (https://github.com/crate-ci/committed/blob/main/docs/reference.md).
defaults := {
	"style": "none",
	"subject_length": 50,
	"subject_not_punctuated": true,
	"imperative_subject": true,
	"no_wip": true,
}

setting(config, key) := object.get(config, key, defaults[key])

names(value) if {
	is_array(value)
	count(value) > 0
	every name in value {
		is_string(name)
		trim_space(name) != ""
	}
}

header_limit(value) if {
	is_number(value)
	value >= 1
	value <= 72
}

# A shell command that runs committed, rather than naming it in a path or a
# word such as "uncommitted".
runs_committed(command) if regex.match(`(^|[\s;&|(])committed(\s|$)`, command)

names_config(command) if regex.match(`--config[=\s]+["']?\.config/commits/committed\.toml(["'\s]|$)`, command)

# The message file lefthook passes as {1}, and standard input as -.
reads_message_file(command) if regex.match(`--commit-file[=\s]+["']?\{1\}(["'\s;|&)]|$)`, command)

reads_stdin(command) if regex.match(`--commit-file[=\s]+-(["'\s;|&)]|$)`, command)

# --- COMMIT-03: lefthook's commit-msg hook ----------------------------------

lefthook_pattern := `^(\.?lefthook|\.config/lefthook)\.ya?ml$`

lefthooks[doc.path] := doc.contents if {
	some doc in files.own_documents
	regex.match(lefthook_pattern, doc.path)
	is_object(doc.contents)
}

# Every run: in the commit-msg hook, at any depth of group nesting.
commit_msg_runs(config) := {node.run |
	is_object(config["commit-msg"])
	walk(config["commit-msg"], [_, node])
	is_object(node)
	is_string(node.run)
}

hook_checks(config) if {
	some command in commit_msg_runs(config)
	runs_committed(command)
	names_config(command)
	reads_message_file(command)
}

hook_runs_committed(config) if {
	some command in commit_msg_runs(config)
	runs_committed(command)
}

hook_problem(config) := "does not run committed" if not hook_runs_committed(config)

hook_problem(config) := "runs committed without --config .config/commits/committed.toml and --commit-file {1}" if {
	hook_runs_committed(config)
}

# --- COMMIT-04: the pull request title ---------------------------------------

pull_request_workflows[path] := workflow if {
	some path, workflow in files.workflows
	some event in files.triggers(workflow)
	event in {"pull_request", "pull_request_target"}
}

title_steps contains entry.step if {
	some entry in files.workflow_steps
	pull_request_workflows[entry.path]
}

title_checked_by_committed if {
	some step in title_steps
	is_string(step.run)
	runs_committed(step.run)
	names_config(step.run)
	reads_stdin(step.run)
}

scope_required if {
	some step in title_steps
	is_string(step.uses)
	startswith(lower(step.uses), "amannn/action-semantic-pull-request@")
	step.with.requireScope in {true, "true"}
}

# Where a missing title check is reported: the pull request workflow named for
# the pull request, else the first, else the file to add.
named_workflows := sort([path |
	some path, _ in pull_request_workflows
	contains(files.basename(path), "pull-request")
])

title_workflow := named_workflows[0] if count(named_workflows) > 0

title_workflow := sort(object.keys(pull_request_workflows))[0] if {
	count(named_workflows) == 0
	count(pull_request_workflows) > 0
}

title_workflow := ".github/workflows/validate-pull-request.yml" if count(pull_request_workflows) == 0

# --- Findings ----------------------------------------------------------------

missing_message := concat(" ", [
	"there is no .config/commits/committed.toml, so nothing states which commit types and scopes",
	"this repository accepts; add it with style = \"conventional\", allowed_types and allowed_scopes",
])

# COMMIT-01
findings contains lib.finding("COMMIT-01", config_path, missing_message) if {
	not config_path in files.repository_files
}

findings contains lib.finding("COMMIT-01", path, message) if {
	some path, config in configs
	setting(config, "style") != "conventional"
	message := sprintf(
		"style is %q, so committed does not read the type and scope; set style = \"conventional\"",
		[setting(config, "style")],
	)
}

findings contains lib.finding("COMMIT-01", path, message) if {
	some path, config in configs
	some key in ["allowed_types", "allowed_scopes"]
	not names(object.get(config, key, null))
	message := sprintf(
		"%s is not a list of names, so committed falls back to its default; list every one this repository accepts",
		[key],
	)
}

findings contains lib.finding("COMMIT-01", path, message) if {
	some path, config in configs
	not header_limit(setting(config, "subject_length"))
	message := sprintf(
		"subject_length is %v; set it between 1 and 72 so the header fits a terminal and the commit list",
		[setting(config, "subject_length")],
	)
}

findings contains lib.finding("COMMIT-01", path, message) if {
	some path, config in configs
	some key in ["subject_not_punctuated", "imperative_subject", "no_wip"]
	setting(config, key) != true
	message := sprintf("%s is %v; set %s = true", [key, setting(config, key), key])
}

# COMMIT-02
findings contains lib.finding("COMMIT-02", path, message) if {
	mise.configured
	not mise.pinned("committed")
	path := sort(object.keys(mise.configs))[0]
	message := concat(" ", [
		"the mise configuration does not pin committed, so the hook and the pull request check can run",
		"different versions; add \"github:crate-ci/committed\" = \"<version>\" under [tools]",
	])
}

# COMMIT-03
findings contains lib.finding("COMMIT-03", path, message) if {
	some path, config in lefthooks
	not hook_checks(config)
	message := sprintf(
		concat(" ", [
			"the commit-msg hook %s, so a message is first checked on the pull request; add a commit-msg job",
			"that runs committed --config .config/commits/committed.toml --commit-file {1}",
		]),
		[hook_problem(config)],
	)
}

# COMMIT-04
findings contains lib.finding("COMMIT-04", title_workflow, message) if {
	count(files.workflows) > 0
	not title_checked_by_committed
	message := concat(" ", [
		"no pull request workflow runs committed on the title; add a step that pipes the title from an",
		"environment variable into committed --config .config/commits/committed.toml --commit-file -",
	])
}

findings contains lib.finding("COMMIT-04", title_workflow, message) if {
	count(files.workflows) > 0
	not scope_required
	message := concat(" ", [
		"no pull request workflow requires a scope on the title, which committed cannot; add",
		"amannn/action-semantic-pull-request with requireScope: true",
	])
}

# COMMIT-06
findings contains lib.finding("COMMIT-06", path, message) if {
	some path in files.repository_files
	regex.match(`^\.github/conventional-commits\.ya?ml$`, path)
	message := sprintf(
		concat(" ", [
			"%s keeps a second list of commit types and scopes that nothing enforces; move them into",
			"allowed_types and allowed_scopes in .config/commits/committed.toml and delete this file",
		]),
		[path],
	)
}
