# METADATA
# title: Releases and deployments
# description: >-
#   A force push names the commit it replaces, a release is cut with a token
#   whose events start workflows, the last job of a release, publish or
#   deploy workflow cannot be skipped into a green run, and nothing that acts
#   on production runs on a push to a branch.
# scope: package
# custom:
#   convention: EC-0023
package conventions.checks.github_actions.releases_and_deployments

import data.conventions.lib.filenames
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.names
import data.conventions.lib.steps

# GHA-46
findings contains lib.finding("GHA-46", entry.path, message) if {
	some entry in steps.entries
	some command in push_commands(entry.step)
	some flag in unleased_forces(command)
	message := sprintf(
		concat(" ", [
			"%s in %s force-pushes with %q, which overwrites whatever the remote holds; use",
			"--force-with-lease=<branch>:<expected-sha> so the push fails if the branch moved",
		]),
		[entry.label, entry.where, flag],
	)
}

# GHA-47
findings contains lib.finding("GHA-47", entry.path, message) if {
	some entry in steps.entries
	steps.action(entry.step) in release_please_actions
	problem := token_problem(entry.step)
	message := sprintf(
		concat(" ", [
			"%s in %s runs release-please %s; GitHub starts no workflow for what the default",
			"token creates, so the release pull request never reports its required checks and the",
			"tag never starts the publish workflow; pass a GitHub App installation token as token:",
		]),
		[entry.label, entry.where, problem],
	)
}

# GHA-48
findings contains lib.finding("GHA-48", path, message) if {
	some path, workflow in files.workflows
	delivery_workflow(path)
	some job_id, job in files.jobs(workflow)
	terminal(workflow, job_id)
	count(files.as_list(job.needs)) > 0
	not survives_skips(job)
	message := sprintf(
		concat(" ", [
			"job %q is the last job of a %s workflow and %s; a skipped job anywhere before it",
			"skips it too and the run still reports success, so set if: ${{ !cancelled() &&",
			"needs.<job>.result == 'success' }} with each result it depends on",
		]),
		[job_id, filenames.slot(files.stem(path)), condition_problem(job)],
	)
}

# GHA-49
findings contains lib.finding("GHA-49", path, message) if {
	some path, workflow in files.workflows
	"push" in files.triggers(workflow)
	not harmless_push(path, workflow)
	reason := production_reason(path, workflow)
	message := sprintf(
		concat(" ", [
			"the workflow acts on production (%s) but runs on a push to a branch; a merge does not",
			"release, so it acts on or reports about the previous release; trigger it from the release",
			"(a tag, release: published, or workflow_call from the deploy), a schedule, or",
			"workflow_dispatch",
		]),
		[reason],
	)
}

# One `git push` command per match, to the end of its command line.
push_commands(step) := {match |
	some line in steps.lines(step)
	some match in regex.find_n(`\bgit\s+push\b[^;&|]*`, line, -1)
}

# The arguments of a push that force it without a lease on a named value.
unleased_forces(command) := {argument |
	some argument in split(regex.replace(command, `["']`, ""), " ")
	unleased(argument)
}

unleased("--force")

unleased(argument) if regex.match(`^-[A-Za-z]*f[A-Za-z]*$`, argument)

unleased("--force-with-lease")

unleased(argument) if {
	startswith(argument, "--force-with-lease=")
	not contains(argument, ":")
}

# A `+` refspec forces that one ref.
unleased(argument) if regex.match(`^\+[^\s+]`, argument)

release_please_actions := {"googleapis/release-please-action", "google-github-actions/release-please-action"}

token_problem(step) := "without a token input, so it uses the default GITHUB_TOKEN" if {
	not files.has_string(steps.inputs(step), "token")
}

token_problem(step) := sprintf("with token: %s, the default GITHUB_TOKEN", [token]) if {
	token := steps.inputs(step).token
	is_string(token)
	regex.match(`(?i)(secrets\.github_token|github\.token)\b`, token)
}

delivery_tokens := {"release", "publish", "deploy"}

delivery_workflow(path) if filenames.slot(files.stem(path)) in delivery_tokens

# A job no other job needs: where the run's result is decided.
terminal(workflow, job_id) if not job_id in needed(workflow)

needed(workflow) := {need |
	some job in files.jobs(workflow)
	some need in files.as_list(job.needs)
}

survives_skips(job) if {
	is_string(job["if"])
	regex.match(`!\s*cancelled\(\)`, job["if"])
}

condition_problem(job) := "runs with always(), even after the run is cancelled" if {
	is_string(job["if"])
	contains(job["if"], "always()")
}

condition_problem(job) := "has no if: condition" if not "if" in object.keys(job)

condition_problem(job) := "its if: condition does not include !cancelled()" if {
	"if" in object.keys(job)
	not contains(sprintf("%v", [job["if"]]), "always()")
}

production_reason(path, _) := "its filename names production" if {
	"production" in names.meaningful_tokens(files.stem(path))
}

production_reason(path, workflow) := sprintf("job %q deploys to the production environment", [job_id]) if {
	not "production" in names.meaningful_tokens(files.stem(path))
	deploying := {id | some id, job in files.jobs(workflow); production_environment(job)}
	count(deploying) > 0
	job_id := min(deploying)
}

production_environment(job) if {
	is_string(job.environment)
	lower(job.environment) == "production"
}

production_environment(job) if {
	is_string(job.environment.name)
	lower(job.environment.name) == "production"
}

# A push limited to tags is the release itself, and a push limited to the
# workflow's own file re-runs it when it changes; neither claims anything
# about a merge.
harmless_push(_, workflow) if {
	config := files.trigger_config(workflow, "push")
	is_object(config)
	count(files.as_list(config.tags)) > 0
	not "branches" in object.keys(config)
	not "branches-ignore" in object.keys(config)
}

harmless_push(path, workflow) if {
	config := files.trigger_config(workflow, "push")
	paths := files.as_list(config.paths)
	count(paths) > 0
	every entry in paths {
		trim_prefix(entry, "./") == path
	}
}
