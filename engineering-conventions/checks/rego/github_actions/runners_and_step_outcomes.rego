# METADATA
# title: Runners and step outcomes
# description: >-
#   Jobs run on a pinned runner image they fit, every failure reaches the
#   run's result, and a job relies only on what exists: a cache no pull
#   request can write, the permissions its caller grants, a diff base it can
#   fetch, a directory in the repository.
# scope: package
# custom:
#   convention: EC-0022
package conventions.checks.github_actions.runners_and_step_outcomes

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.steps

# GHA-39
findings contains lib.finding("GHA-39", path, message) if {
	some path, workflow in files.workflows
	some job_id, job in runner_jobs(workflow)
	some label in runner_labels(job)
	moving(label)
	message := sprintf(
		concat(" ", [
			"job %q runs on %q, a label GitHub moves to a new image on its own schedule, so the job's",
			"toolchain changes on a day nobody chose; name the image it was proven on: %s",
		]),
		[job_id, label, pinned_advice(label)],
	)
}

# GHA-40: the 15-minute cap GitHub enforces on the 1-vCPU runner.
findings contains lib.finding("GHA-40", path, message) if {
	some path, workflow in files.workflows
	some job_id, job in runner_jobs(workflow)
	slim in runner_labels(job)
	problem := slim_timeout_problem(job)
	message := sprintf(
		concat(" ", [
			"job %q runs on ubuntu-slim but %s; GitHub stops an ubuntu-slim job at 15 minutes,",
			"so set timeout-minutes: 15 or less, or run it on ubuntu-24.04",
		]),
		[job_id, problem],
	)
}

# GHA-40: the 1-vCPU runner is a container with no Docker daemon.
findings contains lib.finding("GHA-40", path, message) if {
	some path, workflow in files.workflows
	some job_id, job in runner_jobs(workflow)
	slim in runner_labels(job)
	some use in docker_uses(job)
	message := sprintf(
		"job %q runs on ubuntu-slim but %s, and that runner has no Docker; run it on ubuntu-24.04",
		[job_id, use],
	)
}

# GHA-41: a swallowed exit code in a run: block.
findings contains lib.finding("GHA-41", entry.path, message) if {
	some entry in steps.entries
	some line in steps.lines(entry.step)
	regex.match(swallow_pattern, line)
	message := sprintf(
		concat(" ", [
			"%s in %s swallows a failure: %q; let the command fail, or capture its exit code and",
			"test it, so a broken check cannot report success",
		]),
		[entry.label, entry.where, line],
	)
}

# GHA-41: continue-on-error written as a literal true on a step.
findings contains lib.finding("GHA-41", entry.path, message) if {
	some entry in steps.entries
	continues_on_error(entry.step)
	message := sprintf(
		concat(" ", [
			"%s in %s sets continue-on-error: true, so its failure turns green; remove it,",
			"or make the step succeed only when what follows can rely on it",
		]),
		[entry.label, entry.where],
	)
}

# GHA-41: continue-on-error written as a literal true on a job.
findings contains lib.finding("GHA-41", path, message) if {
	some path, workflow in files.workflows
	some job_id, job in files.jobs(workflow)
	continues_on_error(job)
	message := sprintf(
		concat(" ", [
			"job %q sets continue-on-error: true, so the run succeeds when the job fails;",
			"remove it, or split what may fail into a job no aggregate depends on",
		]),
		[job_id],
	)
}

# GHA-42
findings contains lib.finding("GHA-42", entry.path, message) if {
	some entry in steps.entries
	some where in gha_cache(entry.step)
	message := sprintf(
		concat(" ", [
			"%s in %s uses the type=gha build cache in %s; Docker layers fill the repository's",
			"10 GB Actions cache and evict every other cache, so keep the build cache in a registry",
			"(type=registry) instead",
		]),
		[entry.label, entry.where, where],
	)
}

# GHA-43
findings contains lib.finding("GHA-43", path, message) if {
	some path, workflow in files.workflows
	some job_id, job in files.jobs(workflow)
	callee_path := local_callee(job)
	callee := files.workflows[callee_path]
	granted := caller_grants(workflow, job)
	some scope, needed in callee_needs(callee)
	level(granted, scope) < needed
	message := sprintf(
		concat(" ", [
			"job %q calls %s, which asks for %s, but grants it %s; GitHub refuses to start the run",
			"or the called job fails at its first API call, so grant %s on the job",
		]),
		[
			job_id, callee_path, grant_text(scope, needed),
			grant_text(scope, level(granted, scope)), grant_text(scope, needed),
		],
	)
}

# GHA-44
findings contains lib.finding("GHA-44", path, message) if {
	some path, workflow in files.workflows
	"push" in files.triggers(workflow)
	some job_id, job in files.jobs(workflow)
	some index, step in files.steps(job)
	steps.action(step) == "dorny/paths-filter"
	not has_base(step)
	message := sprintf(
		concat(" ", [
			"%s in job %q runs dorny/paths-filter in a workflow triggered by push without a base input;",
			"on push it diffs against the commit before the push, which a shallow checkout does not hold;",
			"set with: {base: ...} (for example the default branch)",
		]),
		[files.step_label(step, index), job_id],
	)
}

# GHA-45
findings contains lib.finding("GHA-45", setting.path, message) if {
	some setting in working_directories
	directory := normalised_directory(setting.value)
	checkable_directory(directory)
	not directory in files.directories
	message := sprintf(
		"%s sets working-directory %q, which is not a directory in the repository; name one that exists",
		[setting.where, setting.value],
	)
}

# Only a job that runs steps chooses a runner; a job that calls a reusable
# workflow takes the callee's.
runner_jobs(workflow) := {job_id: job |
	some job_id, job in files.jobs(workflow)
	not "uses" in object.keys(job)
}

slim := "ubuntu-slim"

# Every literal label a job may run on: `runs-on` as a string, a list or a
# {group, labels} mapping, and a `${{ matrix.<key> }}` resolved to the
# matrix's literal values. Any other expression is decided at run time and
# is left alone.
runner_labels(job) := {label |
	some value in runs_on_values(job)
	some label in resolved(job, value)
}

runs_on_values(job) := [job["runs-on"]] if is_string(job["runs-on"])

runs_on_values(job) := job["runs-on"] if is_array(job["runs-on"])

runs_on_values(job) := files.as_list(job["runs-on"].labels) if is_object(job["runs-on"])

matrix_reference := `^\$\{\{\s*matrix\.([A-Za-z0-9_-]+)\s*\}\}$`

resolved(_, value) := {value} if {
	is_string(value)
	steps.literal(value)
}

resolved(job, value) := matrix_values(job, key) if {
	is_string(value)
	some match in regex.find_all_string_submatch_n(matrix_reference, value, 1)
	key := match[1]
}

default matrix_values(_, _) := set()

matrix_values(job, key) := {value |
	matrix := job.strategy.matrix
	is_object(matrix)
	some value in array.concat(files.as_list(matrix[key]), included(matrix, key))
	steps.literal(value)
	is_string(value)
}

included(matrix, key) := [entry[key] | some entry in files.as_list(matrix.include); is_object(entry)]

moving(label) if regex.match(`(?i)-latest($|-)`, label)

pinned_advice(label) := "ubuntu-24.04, or ubuntu-slim for a short job that runs no Docker" if {
	startswith(lower(label), "ubuntu")
}

pinned_advice(label) := "a versioned macOS label such as macos-15" if startswith(lower(label), "macos")

pinned_advice(label) := "a versioned Windows label such as windows-2025" if startswith(lower(label), "windows")

pinned_advice(label) := "a versioned label" if {
	not startswith(lower(label), "ubuntu")
	not startswith(lower(label), "macos")
	not startswith(lower(label), "windows")
}

slim_timeout_problem(job) := "declares no timeout-minutes" if not "timeout-minutes" in object.keys(job)

slim_timeout_problem(job) := sprintf("sets timeout-minutes: %v", [job["timeout-minutes"]]) if {
	is_number(job["timeout-minutes"])
	job["timeout-minutes"] > 15
}

docker_uses(job) := {use |
	some key in ["container", "services"]
	declared(job[key])
	use := sprintf("declares %s:", [key])
} | {use |
	some index, step in files.steps(job)
	docker_step(step)
	use := sprintf("%s runs Docker", [files.step_label(step, index)])
}

declared(value) if {
	value != null
	value != ""
	value != {}
	value != []
}

docker_step(step) if startswith(step.uses, "docker/")

docker_step(step) if startswith(step.uses, "docker://")

# `docker` in command position (a line's start, or after a shell operator),
# not a path such as `build/docker/Dockerfile`.
docker_step(step) if {
	some line in steps.lines(step)
	regex.match(`(^|[;&|(])\s*(sudo\s+)?docker(\s|$)`, line)
}

# `|| true`, `|| :` and `set +e` as commands; the pattern reads one line of
# comment-free code.
swallow_pattern := `\|\|\s*(true|:)(\s|;|\)|$)|(^|[;&|]\s*|\bthen\s+)set\s+\+e\b`

continues_on_error(node) if node["continue-on-error"] == true

continues_on_error(node) if node["continue-on-error"] == "true"

gha_backend := `(^|[\s,"'])type=gha\b`

gha_cache(step) := ({where |
	some key in ["cache-from", "cache-to"]
	value := steps.inputs(step)[key]
	is_string(value)
	regex.match(gha_backend, value)
	where := sprintf("its %s input", [key])
} | {"its set input" |
	value := steps.inputs(step).set
	is_string(value)
	regex.match(`cache-(from|to)=["']?type=gha\b`, value)
}) | {"its run: block" |
	some line in steps.lines(step)
	regex.match(`--cache-(from|to)(=|\s+)["']?type=gha\b`, line)
}

# The callee of a job that calls a reusable workflow in this repository. A
# callee in another repository declares permissions this check cannot read.
local_callee(job) := trim_prefix(job.uses, "./") if {
	is_string(job.uses)
	regex.match(`^\./\.github/workflows/[^/@]+\.(?i:ya?ml)$`, job.uses)
}

levels := {"none": 0, "read": 1, "write": 2}

# What a caller job grants: its own permissions, else the workflow's. With
# neither, the token has the repository default, which GHA-26 reports.
caller_grants(_, job) := permission_levels(job.permissions) if "permissions" in object.keys(job)

caller_grants(workflow, job) := permission_levels(workflow.permissions) if {
	not "permissions" in object.keys(job)
	"permissions" in object.keys(workflow)
}

# A permissions block as {scope: level}; `*` stands for every scope.
default permission_levels(_) := {}

permission_levels("read-all") := {"*": 1}

permission_levels("write-all") := {"*": 2}

permission_levels(permissions) := granted if {
	is_object(permissions)
	granted := {scope: levels[access] |
		some scope, access in permissions
		is_string(access)
		levels[access]
	}
}

level(granted, scope) := max({object.get(granted, scope, 0), object.get(granted, "*", 0)})

# The highest level the callee asks for each scope, at the workflow level or
# on any job: GitHub refuses the run for a job-level excess and cuts a
# workflow-level one down, so the first API call fails instead.
callee_needs(callee) := {scope: needed |
	some scope in callee_scopes(callee)
	needed := max({level(asked, scope) | some asked in callee_blocks(callee)})
	needed > 0
}

callee_blocks(callee) := array.concat(
	[permission_levels(callee.permissions) | "permissions" in object.keys(callee)],
	[permission_levels(job.permissions) | some job in files.jobs(callee); "permissions" in object.keys(job)],
)

callee_scopes(callee) := {scope | some block in callee_blocks(callee); some scope, _ in block}

grant_text("*", 1) := "read-all"

grant_text("*", 2) := "write-all"

grant_text(scope, needed) := sprintf("%s: %s", [scope, name]) if {
	scope != "*"
	some name, value in levels
	value == needed
}

grant_text("*", 0) := "no permissions"

has_base(step) if {
	value := steps.inputs(step).base
	is_string(value)
	trim_space(value) != ""
}

# Every working-directory a workflow or action sets, with where it is set.
working_directories contains {"path": path, "where": "defaults.run", "value": value} if {
	some path, workflow in checked_workflows
	value := workflow.defaults.run["working-directory"]
}

working_directories contains {"path": path, "where": sprintf("job %q defaults.run", [job_id]), "value": value} if {
	some path, workflow in checked_workflows
	some job_id, job in files.jobs(workflow)
	value := job.defaults.run["working-directory"]
}

working_directories contains {"path": entry.path, "where": where, "value": value} if {
	some entry in steps.entries
	checked_path(entry.path)
	value := entry.step["working-directory"]
	where := sprintf("%s in %s", [entry.label, entry.where])
}

# A checkout into a subdirectory (`with: {path: ...}`) moves every relative
# directory under it, so a workflow that does one is not judged.
checked_workflows[path] := workflow if {
	some path, workflow in files.workflows
	not checks_out_elsewhere(workflow)
}

checks_out_elsewhere(workflow) if {
	some job in files.jobs(workflow)
	some step in files.steps(job)
	steps.action(step) == "actions/checkout"
	steps.inputs(step).path
}

checked_path(path) if checked_workflows[path]

checked_path(path) if files.actions[path]

normalised_directory(value) := trim_right(trim_prefix(trim_space(value), "./"), "/") if is_string(value)

# Only a literal, relative directory inside the workspace is checked: an
# expression or a variable is resolved at run time, and `.` is the root.
checkable_directory(directory) if {
	directory != ""
	directory != "."
	not startswith(directory, "/")
	not startswith(directory, "~")
	not contains(directory, "$")
	not regex.match(`(^|/)\.\.(/|$)`, directory)
}
