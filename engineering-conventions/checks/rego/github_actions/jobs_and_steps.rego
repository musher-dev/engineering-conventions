# METADATA
# title: Jobs and steps
# description: >-
#   Jobs are named for the result they report, only required-check jobs
#   lead with their workflow's name, identifiers are snake_case, and
#   required checks are stable aggregates.
# scope: package
# custom:
#   convention: EC-0003
package conventions.checks.github_actions.jobs_and_steps

import data.conventions.lib.contexts
import data.conventions.lib.filenames
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.names

# GHA-10
findings contains lib.finding("GHA-10", path, message) if {
	some path, workflow in files.workflows
	some job_id, _ in files.jobs(workflow)
	not names.is_snake_case(job_id)
	message := sprintf(
		"job id %q is not snake_case; rename it to %q and update every needs: that names it",
		[job_id, names.snake_case(job_id)],
	)
}

findings contains lib.finding("GHA-10", entry.path, message) if {
	some entry in files.workflow_steps
	is_string(entry.step.id)
	not names.is_snake_case(entry.step.id)
	message := sprintf(
		"step id %q in job %q is not snake_case; rename it to %q and update every steps.%s reference",
		[entry.step.id, entry.job, names.snake_case(entry.step.id), entry.step.id],
	)
}

findings contains lib.finding("GHA-10", entry.path, message) if {
	some entry in files.action_step_entries
	is_string(entry.step.id)
	not names.is_snake_case(entry.step.id)
	message := sprintf(
		"step id %q is not snake_case; rename it to %q and update every steps.%s reference",
		[entry.step.id, names.snake_case(entry.step.id), entry.step.id],
	)
}

# GHA-11
findings contains lib.finding("GHA-11", path, message) if {
	some path, workflow in files.workflows
	some job_id, job in files.jobs(workflow)
	not has_name(job)
	message := sprintf(
		"job %q has no name, so its check reports as the bare id; add name: %q",
		[job_id, suggested_job_name(path, workflow, job_id)],
	)
}

findings contains lib.finding("GHA-11", path, message) if {
	some path, workflow in files.workflows
	some rendered in {name | some [_, name] in reported_names(workflow)}
	owners := {job_id | some [job_id, name] in reported_names(workflow); name == rendered}
	count(owners) > 1
	message := sprintf(
		"jobs %s all report as %q, so a failure cannot say which one it was; give each job its own name",
		[names.quoted_list(owners), rendered],
	)
}

# GHA-12. GitHub shows a job as `<workflow name> / <job name>`, so a job that
# leads with its workflow's name reads twice. Only a required-check job does:
# a ruleset matches the job name alone, which must then be unique across the
# repository. The name GitHub prefixes today is the declared one, so it
# counts even while the filename (and so the name) is about to change.
findings contains lib.finding("GHA-12", path, message) if {
	some path, workflow in files.workflows
	qualified_unit(workflow)
	some job_id, job in files.jobs(workflow)
	has_name(job)
	not empty_segment(job.name)
	not job.name in contexts.required_names
	not unrequired_aggregate_allowed(path, workflow, job.name)
	prefix := repeated_prefix(path, workflow, job.name)
	message := sprintf(
		concat(" ", [
			"job %q is named %q, but GitHub already shows the workflow name before the job's, so it",
			"reads twice; rename it to %q (only a required-check job leads with its workflow's name)",
		]),
		[job_id, job.name, trim_space(trim_prefix(job.name, prefix))],
	)
}

# GHA-12. Not judged while the filename must change, because the name to
# lead with derives from it; nor for a job GHA-16 says to stop requiring.
findings contains lib.finding("GHA-12", path, message) if {
	some path, workflow in files.workflows
	qualified_unit(workflow)
	not path in filenames.renaming
	some job_id, job in files.jobs(workflow)
	has_name(job)
	job.name in contexts.required_names
	not contexts.calls(job)
	not contexts.dynamic(job_id, job)
	not qualified(job.name, names.accepted_workflow_names(path, workflow))
	not replaced_by_aggregate(path, job.name)
	expected := names.expected_workflow_name(path)
	message := sprintf(
		concat(" ", [
			"job %q emits the required context %q, and a ruleset matches the job name alone, so a",
			"required-check job leads with its workflow's name to stay unique across the repository;",
			"rename it to %q and update the ruleset",
		]),
		[job_id, job.name, sprintf("%s / %s", [expected, without_workflow(job.name, expected)])],
	)
}

findings contains lib.finding("GHA-12", path, message) if {
	some path, workflow in files.workflows
	qualified_unit(workflow)
	some job_id, job in files.jobs(workflow)
	has_name(job)
	empty_segment(job.name)
	message := sprintf(
		"job %q is named %q, which has an empty subject; name the result it reports, e.g. %q",
		[job_id, job.name, subject_from_id(job_id)],
	)
}

# GHA-13
findings contains lib.finding("GHA-13", path, message) if {
	some path, workflow in files.workflows
	files.is_callable(workflow)
	some job_id, job in files.jobs(workflow)
	has_name(job)
	contains(job.name, " / ")
	parts := split(job.name, " / ")
	message := sprintf(
		concat(" ", [
			"job %q is named %q in a workflow callable through workflow_call; GitHub prefixes a called",
			"job with its caller's job name, so use a bare name such as %q",
		]),
		[job_id, job.name, parts[count(parts) - 1]],
	)
}

findings contains lib.finding("GHA-14", path, message) if {
	some path, workflow in files.workflows
	some [job_id, job] in contexts.aggregates(path, workflow)
	not runs_after_failure(job)
	message := sprintf(
		concat(" ", [
			"aggregate job %q has no if: always() (or !cancelled()), so it is skipped when a job it needs",
			"fails and the required check never reports; add if: always() and fail on any result but success",
		]),
		[job_id],
	)
}

findings contains lib.finding("GHA-14", path, message) if {
	some path, workflow in files.workflows
	some [job_id, job] in contexts.aggregates(path, workflow)
	needed := {need | some need in files.as_list(job.needs)}
	missing := {other | some other, _ in files.jobs(workflow); other != job_id} - needed
	count(missing) > 0
	message := sprintf(
		concat(" ", [
			"aggregate job %q does not need %s; list every other job under needs: so none can fail",
			"without failing the required check",
		]),
		[job_id, names.quoted_list(missing)],
	)
}

# GHA-15. A context that a matrix or an expression may produce is GHA-16's,
# and one reported under a call to another repository cannot be verified.
findings contains lib.finding("GHA-15", required.path, message) if {
	some required in contexts.required
	not required.context in contexts.emitted_names
	not contexts.matches_pattern(required.context)
	not contexts.unverified(required.context)
	message := sprintf(
		"requires context %q, which no job emits, so every pull request waits on it forever; %s",
		[required.context, context_hint(required.context)],
	)
}

findings contains lib.finding("GHA-15", required.path, message) if {
	some required in contexts.required
	emitters := {sprintf("job %q in %s", [entry.leaf[1], entry.leaf[0]]) |
		some entry in contexts.emitted
		entry.context == required.context
	}
	count(emitters) > 1
	message := sprintf(
		"requires context %q, which %d jobs emit (%s), so the ruleset cannot tell them apart; give each job its own name",
		[required.context, count(emitters), concat(", ", sort(emitters))],
	)
}

# GHA-16. One finding per workflow and ruleset, naming every context.
findings contains lib.finding("GHA-16", ruleset, message) if {
	some [ruleset, path] in {[offender.ruleset, offender.workflow] | some offender in unaggregated}
	offenders := {offender |
		some offender in unaggregated
		offender.ruleset == ruleset
		offender.workflow == path
	}
	message := sprintf(
		"requires %s from individual jobs of %q%s; a workflow is required only through its aggregate, so %s",
		[
			names.quoted_list({offender.context | some offender in offenders}),
			path,
			matrix_note({offender.context | some offender in offenders; offender.matrix}),
			aggregate_hint(path, files.workflows[path]),
		],
	)
}

# GHA-17
findings contains lib.finding("GHA-17", entry.path, message) if {
	some entry in files.workflow_steps
	unnamed_run(entry.step)
	message := sprintf(
		"step %d of job %q runs a command but has no name; add name: with an imperative phrase saying what it does",
		[entry.index + 1, entry.job],
	)
}

findings contains lib.finding("GHA-17", entry.path, message) if {
	some entry in files.action_step_entries
	unnamed_run(entry.step)
	message := sprintf(
		"step %d runs a command but has no name; add name: with an imperative phrase saying what it does",
		[entry.index + 1],
	)
}

has_name(job) if {
	is_string(job.name)
	trim_space(job.name) != ""
}

subject_from_id(job_id) := names.title_case(replace(job_id, "_", "-"))

# GHA-12 applies to entry points that nothing can call; every other job,
# callable or not triggered at all, reports under its bare name.
qualified_unit(workflow) if {
	files.is_entry_point(workflow)
	not files.is_callable(workflow)
}

# An unnamed aggregate is the one job whose suggested name leads with its
# workflow's; every other job is suggested its bare subject.
suggested_job_name(path, workflow, "required") := sprintf("%s / Required", [names.expected_workflow_name(path)]) if {
	aggregate_suggestion(path, workflow, "required")
}

suggested_job_name(path, workflow, job_id) := subject_from_id(job_id) if {
	not aggregate_suggestion(path, workflow, job_id)
}

aggregate_suggestion(path, workflow, "required") if {
	qualified_unit(workflow)
	not path in filenames.renaming
}

# The names each job of a workflow reports under: one per matrix leg when the
# name renders a matrix value, else the name as written.
reported_names(workflow) := {[job_id, name] |
	some job_id, job in files.jobs(workflow)
	has_name(job)
	some name in rendered_names(job)
}

matrix_reference := `\$\{\{\s*matrix\.([A-Za-z0-9_-]+)(?:\.([A-Za-z0-9_-]+))?\s*\}\}`

rendered_names(job) := {job.name} if not renderable(job)

rendered_names(job) := {replace(job.name, reference[0], leg_value(leg, reference[2])) |
	reference := matrix_references(job.name)[0]
	some leg in job.strategy.matrix[reference[1]]
} if {
	renderable(job)
}

matrix_references(name) := regex.find_all_string_submatch_n(matrix_reference, name, -1)

# Only a name with one matrix reference into a list the file spells out can
# be rendered; a name built any other way stands for itself.
renderable(job) if {
	references := matrix_references(job.name)
	count(references) == 1
	is_array(job.strategy.matrix[references[0][1]])
}

leg_value(leg, "") := sprintf("%v", [leg])

leg_value(leg, field) := sprintf("%v", [object.get(leg, field, "")]) if field != ""

# The workflow names GitHub may show before a job's: the declared one, and
# the one the filename derives once the filename is final.
current_workflow_names(path, workflow) := names.accepted_workflow_names(path, workflow) if {
	not path in filenames.renaming
}

current_workflow_names(path, workflow) := {workflow.name} if {
	path in filenames.renaming
	is_string(workflow.name)
}

# The longest workflow-name prefix a job name repeats.
repeated_prefix(path, workflow, name) := prefixes[count(prefixes) - 1][1] if {
	prefixes := sort([[count(prefix), prefix] |
		some workflow_name in current_workflow_names(path, workflow)
		prefix := sprintf("%s / ", [workflow_name])
		startswith(name, prefix)
	])
	count(prefixes) > 0
}

empty_segment(name) if regex.match(`(^|/)\s*(/|$)`, trim_space(name))

# Without a committed ruleset nothing is required yet, and the aggregate is
# the job that will be; nor is it renamed while GHA-16 says to require it.
unrequired_aggregate_allowed(path, workflow, name) if {
	not contexts.has_rulesets
	name in contexts.aggregate_names(path, workflow)
}

unrequired_aggregate_allowed(path, workflow, name) if {
	name in contexts.aggregate_names(path, workflow)
	some offender in unaggregated
	offender.workflow == path
}

replaced_by_aggregate(path, context) if {
	some offender in unaggregated
	offender.workflow == path
	offender.context == context
}

qualified(name, workflow_names) if {
	some workflow_name in workflow_names
	prefix := sprintf("%s / ", [workflow_name])
	startswith(name, prefix)
	trim_space(trim_prefix(name, prefix)) != ""
}

# A subject that repeats the workflow name would read "Validate / Validate
# PR Title" once qualified, so the leading copy is dropped.
without_workflow(subject, workflow_name) := trim_space(substring(subject, count(workflow_name) + 1, -1)) if {
	repeats_workflow(subject, workflow_name)
}

without_workflow(subject, workflow_name) := subject if not repeats_workflow(subject, workflow_name)

repeats_workflow(subject, workflow_name) if {
	startswith(lower(subject), lower(sprintf("%s ", [workflow_name])))
	trim_space(substring(subject, count(workflow_name) + 1, -1)) != ""
}

runs_after_failure(job) if regex.match(`always\(\)|!\s*cancelled\(\)`, sprintf("%v", [object.get(job, "if", "")]))

context_hint(context) := sprintf("the job is named %q; match the case exactly", [name]) if {
	some name in contexts.emitted_names
	lower(name) == lower(context)
}

context_hint(context) := concat(" ", [
	"rename the job to this context or require the context an existing job emits",
	"(names built from ${{ }} or a matrix never match)",
]) if {
	not case_variant_exists(context)
}

case_variant_exists(context) if {
	some name in contexts.emitted_names
	lower(name) == lower(context)
}

# Required contexts reported by a job other than the workflow's aggregate:
# any job of a multi-job workflow, and any context a matrix or expression
# expands, since that changes whenever the matrix does.
unaggregated contains offender(required, entry, false) if {
	some required in contexts.required
	some entry in contexts.emitted
	entry.context == required.context
	workflow := files.workflows[entry.workflow]
	count(files.jobs(workflow)) > 1
	not contexts.is_aggregate(entry.workflow, workflow, entry.job, files.jobs(workflow)[entry.job])
}

unaggregated contains offender(required, entry, true) if {
	some required in contexts.required
	not required.context in contexts.emitted_names
	some entry in contexts.patterned
	regex.match(entry.pattern, required.context)
}

offender(required, entry, matrix) := {
	"ruleset": required.path,
	"workflow": entry.workflow,
	"context": required.context,
	"matrix": matrix,
}

default matrix_note(_) := ""

matrix_note(expanded) := sprintf(" (%s expanded from a matrix or expression, so it changes whenever they do)", [
	names.quoted_list(expanded),
]) if {
	count(expanded) > 0
}

# Point at the aggregate the workflow already has, else at the one to add.
# The aggregate's name derives from the workflow's, so while the filename
# must change no name is proposed.
aggregate_hint(path, workflow) := sprintf("require its aggregate %q instead", [name]) if {
	existing := [contexts.job_name(job_id, job) | some [job_id, job] in contexts.aggregates(path, workflow)]
	name := sort(existing)[0]
}

aggregate_hint(path, workflow) := sprintf(
	"add an aggregate job named %q that runs if: always() and needs every other job, and require that instead",
	[sprintf("%s / Required", [names.expected_workflow_name(path)])],
) if {
	count(contexts.aggregates(path, workflow)) == 0
	not path in filenames.renaming
}

aggregate_hint(path, workflow) := concat(" ", [
	"rename the workflow file first (its name, and so the aggregate's, derives from the filename), then add",
	"an aggregate job named <Workflow> / Required that runs if: always() and needs every other job, and",
	"require that instead",
]) if {
	count(contexts.aggregates(path, workflow)) == 0
	path in filenames.renaming
}

unnamed_run(step) if {
	"run" in object.keys(step)
	not files.has_string(step, "name")
}

unnamed_run(step) if {
	"run" in object.keys(step)
	trim_space(step.name) == ""
}
