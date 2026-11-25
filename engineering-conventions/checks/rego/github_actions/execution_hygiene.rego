# METADATA
# title: Execution hygiene
# description: >-
#   Workflows pin what they run, grant the least privilege they need, cannot
#   hang, never let a path filter or a shared concurrency group hide a
#   required check, and give mise a GitHub token after jdx/mise-action
#   (GHA-55).
# scope: package
# custom:
#   convention: EC-0005
package conventions.checks.github_actions.execution_hygiene

import data.conventions.lib.contexts
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.names
import data.conventions.lib.runs
import data.conventions.lib.steps
import data.conventions.lib.taskfiles

# GHA-24
findings contains lib.finding("GHA-24", reference.path, message) if {
	some reference in references
	not local(reference.uses)
	not pinned(reference.uses)
	message := pin_message(reference)
}

# GHA-26
findings contains lib.finding("GHA-26", path, missing_permissions) if {
	some path, workflow in files.workflows
	not "permissions" in object.keys(workflow)
}

# GHA-27. Only write access is refused at the workflow level, and read-all
# with it: it grants every read scope, which is more than any job states.
findings contains lib.finding("GHA-27", path, message) if {
	some path, workflow in files.workflows
	"permissions" in object.keys(workflow)
	problem := permissions_problem(workflow.permissions)
	message := sprintf(
		concat(" ", [
			"workflow-level permissions %s; keep the workflow level read-only ({contents: read} or {})",
			"and grant anything wider on the job that needs it",
		]),
		[problem],
	)
}

# GHA-28
findings contains lib.finding("GHA-28", entry.path, message) if {
	some entry in checkout_steps
	message := sprintf(
		concat(" ", [
			"%s in %s checks out without persist-credentials: false, leaving the token in .git/config",
			"for every later step; add with: {persist-credentials: false}",
		]),
		[entry.label, entry.where],
	)
}

# GHA-29. A job that only calls a reusable workflow has no steps and takes
# its timeouts from the callee.
findings contains lib.finding("GHA-29", path, message) if {
	some path, workflow in files.workflows
	some job_id, job in files.jobs(workflow)
	"steps" in object.keys(job)
	not "timeout-minutes" in object.keys(job)
	message := sprintf(
		concat(" ", [
			"job %q runs steps without timeout-minutes, so a hung step holds a runner for six hours;",
			"add timeout-minutes: set a little above its normal duration",
		]),
		[job_id],
	)
}

# GHA-30
findings contains lib.finding("GHA-30", path, message) if {
	some path, workflow in files.workflows
	files.is_entry_point(workflow)
	count(superseding_events(workflow)) > 0
	not standard_concurrency(workflow)
	message := sprintf(
		concat(" ", [
			"%s; set concurrency: {group: %q, cancel-in-progress: ${{ github.event_name ==",
			"'pull_request' }}} so a newer push supersedes an older run of the same ref",
		]),
		[concurrency_problem(workflow), concurrency_prefix],
	)
}

# GHA-31, ported from the platform's CI-06: it inspects the workflow-level key
# only. Inside a called workflow `github.workflow` is the caller's name, so a
# group there is shared by every caller and they cancel each other.
findings contains lib.finding("GHA-31", path, callable_concurrency) if {
	some path, workflow in files.workflows
	files.is_reusable(workflow)
	"concurrency" in object.keys(workflow)
}

# GHA-32
findings contains lib.finding("GHA-32", path, message) if {
	some path in contexts.required_workflows
	workflow := files.workflows[path]
	some event in filtered_events
	config := files.trigger_config(workflow, event)
	some key in {"paths", "paths-ignore"}
	key in object.keys(config)
	message := sprintf(
		concat(" ", [
			"on.%s has a %s filter, but this workflow emits a required check; when the filter skips the",
			"run the check never reports and the pull request cannot merge; remove the filter and skip",
			"work inside the jobs instead",
		]),
		[event, key],
	)
}

# GHA-55
findings contains lib.finding("GHA-55", path, message) if {
	some path, workflow in files.workflows
	not token_set(workflow)
	some job_id, job in files.jobs(workflow)
	not token_set(job)
	job_steps := files.steps(job)
	some setup, setup_step in job_steps
	sets_up_mise(setup_step)
	some index, step in job_steps
	index > setup
	not token_set(step)
	not exported_before(job_steps, index)
	installing := [line | some line in steps.command_lines(step); installs_through_mise(line)]
	count(installing) > 0
	message := sprintf(
		concat(" ", [
			"%s in job %q runs %q after jdx/mise-action, which keeps its GitHub token to its own step,",
			"so what mise installs here goes to the GitHub API unauthenticated and fails once the runner's",
			"shared 60-call hourly limit is spent; set env: {MISE_GITHUB_TOKEN: ${{ github.token }}} on the",
			"step or the job",
		]),
		[files.step_label(step, index), job_id, installing[0]],
	)
}

# Every `uses:` a repository's automation resolves, with where it sits.
references contains {"path": entry.path, "where": sprintf("job %q", [entry.job]), "uses": entry.step.uses} if {
	some entry in files.workflow_steps
	is_string(entry.step.uses)
}

references contains {"path": entry.path, "where": sprintf("step %d", [entry.index + 1]), "uses": entry.step.uses} if {
	some entry in files.action_step_entries
	is_string(entry.step.uses)
}

references contains {"path": path, "where": sprintf("job %q", [job_id]), "uses": job.uses} if {
	some path, workflow in files.workflows
	some job_id, job in files.jobs(workflow)
	is_string(job.uses)
}

missing_permissions := concat(" ", [
	"the workflow declares no top-level permissions, so every job gets the repository's default token scope;",
	"add permissions: {contents: read} (or {}) and widen per job",
])

callable_concurrency := concat(" ", [
	"the workflow is triggered only by workflow_call yet declares concurrency;",
	"inside a called workflow github.workflow is the caller's name, so callers share one group and cancel each other;",
	"remove concurrency: and let the caller set it",
])

local(uses) if startswith(uses, "./")

pinned(uses) if regex.match(`@[0-9a-f]{40}$`, uses)

# A container image pinned by digest is as immutable as a commit SHA.
pinned(uses) if regex.match(`^docker://.+@sha256:[0-9a-f]{64}$`, uses)

pin_message(reference) := sprintf(
	concat(" ", [
		"%s uses %q by a movable reference; pin it to the full 40-character commit SHA that %s",
		"resolves to and keep %q as a trailing comment",
	]),
	[reference.where, reference.uses, ref, concat("", ["# ", ref])],
) if {
	not startswith(reference.uses, "docker://")
	contains(reference.uses, "@")
	ref := regex.replace(reference.uses, `^.*@`, "")
}

pin_message(reference) := sprintf(
	concat(" ", [
		"%s uses %q with no version at all; pin it to a full 40-character commit SHA with the",
		"release tag as a trailing comment",
	]),
	[reference.where, reference.uses],
) if {
	not startswith(reference.uses, "docker://")
	not contains(reference.uses, "@")
}

pin_message(reference) := sprintf(
	"%s uses the image %q by tag; pin it by digest (docker://<image>@sha256:<digest>)",
	[reference.where, reference.uses],
) if {
	startswith(reference.uses, "docker://")
}

permissions_problem("write-all") := "are write-all, which grants every job write access to every scope"

permissions_problem("read-all") := "are read-all, which grants every read scope rather than the ones a job needs"

permissions_problem(permissions) := sprintf("grant write access to %s", [names.quoted_list(written)]) if {
	is_object(permissions)
	written := {scope | some scope, access in permissions; access == "write"}
	count(written) > 0
}

checkout(step) if regex.match(`^actions/checkout(@|$)`, step.uses)

persist_disabled(step) if step["with"]["persist-credentials"] == false

persist_disabled(step) if step["with"]["persist-credentials"] == "false"

checkout_steps contains {"path": entry.path, "where": where, "label": label} if {
	some entry in files.workflow_steps
	where := sprintf("job %q", [entry.job])
	label := files.step_label(entry.step, entry.index)
	checkout(entry.step)
	not persist_disabled(entry.step)
}

checkout_steps contains {"path": entry.path, "where": "the action", "label": label} if {
	some entry in files.action_step_entries
	label := files.step_label(entry.step, entry.index)
	checkout(entry.step)
	not persist_disabled(entry.step)
}

# Only events where a newer run supersedes an older one on the same ref. A
# push-only workflow (a deploy, a release) may group by SHA on purpose so that
# no run is ever cancelled; GHA-30 leaves that choice to it. pull_request_target
# runs trusted code from the base branch and is left to its author.
change_events := {"pull_request", "merge_group"}

# The pull_request activity types a newer push can supersede. A workflow on
# pull_request types: [closed] (say) runs once per pull request, so no later
# run replaces it.
superseded_types := {"opened", "synchronize", "reopened"}

superseding_events(workflow) := {event |
	some event in (files.triggers(workflow) & change_events)
	not inert(workflow, event)
}

inert(workflow, event) if {
	types := files.as_list(files.trigger_config(workflow, event).types)
	count(types) > 0
	count({type | some type in types} & superseded_types) == 0
}

concurrency_prefix := "${{ github.workflow }}-${{ github.ref }}"

concurrency_group(workflow) := workflow.concurrency if is_string(workflow.concurrency)

concurrency_group(workflow) := workflow.concurrency.group if is_string(workflow.concurrency.group)

standard_concurrency(workflow) if startswith(concurrency_group(workflow), concurrency_prefix)

default concurrency_problem(_) := "the workflow declares no concurrency group"

concurrency_problem(workflow) := sprintf(
	"the concurrency group %q does not start with the standard prefix",
	[concurrency_group(workflow)],
)

filtered_events := {"pull_request", "push", "merge_group"}

# GHA-55: the step that sets up mise, directly or through a local composite
# action that uses jdx/mise-action. An action in another repository is not
# read.
mise_action := "jdx/mise-action"

sets_up_mise(step) if steps.action(step) == mise_action

sets_up_mise(step) if {
	some action_step in local_action_steps(step)
	steps.action(action_step) == mise_action
}

# The steps of the local action a step uses: `./.github/actions/<name>`.
local_action_steps(step) := files.action_steps(files.actions[path]) if {
	is_string(step.uses)
	startswith(step.uses, "./.github/actions/")
	some extension in ["yml", "yaml"]
	path := sprintf("%s/action.%s", [trim_right(trim_prefix(step.uses, "./"), "/"), extension])
	files.actions[path]
}

# The variables mise reads a GitHub token from, in its order of preference
# (https://mise.jdx.dev/configuration.html#mise-github-token).
token_variables := {"MISE_GITHUB_TOKEN", "GITHUB_API_TOKEN", "GITHUB_TOKEN"}

# A workflow, job or step whose env gives mise a token. An env written as an
# expression is resolved at run time, so it is taken to set one.
token_set(node) if {
	is_object(node.env)
	some name in token_variables
	name in object.keys(node.env)
}

token_set(node) if is_string(node.env)

# An earlier step, or a local action an earlier step uses, that writes a
# token variable to $GITHUB_ENV for every later step.
exported_before(job_steps, index) if {
	some earlier, step in job_steps
	earlier < index
	exports_token(step)
}

exports_token(step) if exports_in_code(step)

exports_token(step) if {
	some action_step in local_action_steps(step)
	exports_in_code(action_step)
}

exports_in_code(step) if {
	code := steps.code(step)
	contains(code, "GITHUB_ENV")
	some name in token_variables
	contains(code, name)
}

# A command that makes mise install a tool: `mise install`, `mise use` and
# `mise exec` (with their short forms), and every conventions CLI subcommand
# but `version`, which runs its engines through `mise exec`. A task matches
# when it runs one of these or calls a task that does.
mise_install_patterns := {
	`(?m)(^|[\s;&|(])mise\s+(install|i|use|exec|x)(\s|$)`,
	sprintf(`(?m)(^|[\s;&|(/])conventions\s+(%s)(\s|$)`, [concat("|", conventions_subcommands)]),
}

conventions_subcommands := [
	"check", "prose", "openapi", "hadolint", "env-contract", "env-file",
	"waivers", "codeowners", "dependencies",
]

# A command line that installs through mise, itself or through `task`.
installs_through_mise(line) if runs.matches(mise_install_patterns, line)

installs_through_mise(line) if {
	some name in runs.task_arguments(line)
	trim_prefix(name, ":") in installing_tasks
}

# Every task with the Taskfile that defines it.
defined_tasks contains {"path": path, "name": name, "task": task} if {
	some path, _ in taskfiles.documents
	some name, task in taskfiles.tasks(path)
}

# The names `task` calls a task by: its own, and under the namespace of each
# include that loads its Taskfile without flattening it. A name is matched
# whole, so `cli:lint` never stands for a task called `lint`.
namespaces(path) := {include.namespace |
	some include in taskfiles.includes
	taskfiles.target(include) == path
	not include.entry.flatten == true
}

qualified(path, name) := {name} | {concat(":", [namespace, name]) | some namespace in namespaces(path)}

# A call inside a Taskfile: `:name` from the root, else a name in the
# calling Taskfile's own namespaces.
resolved_call(_, call) := {trim_prefix(call, ":")} if startswith(call, ":")

resolved_call(path, call) := qualified(path, call) if not startswith(call, ":")

installing_directly contains name if {
	some entry in defined_tasks
	some command in runs.commands(entry.task)
	runs.matches(mise_install_patterns, command)
	some name in qualified(entry.path, entry.name)
}

# Each task name, with the names of the tasks that call it. Every name is a
# key, because graph.reachable follows only the nodes it finds as keys.
task_callers[name] := {caller_name |
	some caller in defined_tasks
	some call in runs.task_calls(caller.task)
	name in resolved_call(caller.path, call)
	some caller_name in qualified(caller.path, caller.name)
} if {
	some entry in defined_tasks
	some name in qualified(entry.path, entry.name)
}

# The tasks that install through mise, or call a task that does.
installing_tasks := graph.reachable(task_callers, installing_directly)
