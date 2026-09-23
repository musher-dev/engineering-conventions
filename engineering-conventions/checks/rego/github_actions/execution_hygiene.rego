# METADATA
# title: Execution hygiene
# description: >-
#   Workflows pin what they run, grant the least privilege they need, cannot
#   hang, and never let a path filter or a shared concurrency group hide a
#   required check.
# scope: package
# custom:
#   convention: EC-0005
package conventions.checks.github_actions.execution_hygiene

import data.conventions.lib.contexts
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.names

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
