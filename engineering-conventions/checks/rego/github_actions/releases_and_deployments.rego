# METADATA
# title: Releases and deployments
# description: >-
#   A force push names the commit it replaces, a release is cut with a token
#   whose events start workflows, the last job of a release, publish or
#   deploy workflow cannot be skipped into a green run, nothing that acts
#   on production runs on a push to a branch, a job's environment, a secret's
#   name and a GitHub App's credentials follow one form, and a deploy job
#   records its deployment in linked artifacts.
# scope: package
# custom:
#   convention: EC-0023
package conventions.checks.github_actions.releases_and_deployments

import data.conventions.lib.environments
import data.conventions.lib.filenames
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.names
import data.conventions.lib.permissions
import data.conventions.lib.release_please
import data.conventions.lib.runs
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
	steps.action(entry.step) in release_please.actions
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

# GHA-50
findings contains lib.finding("GHA-50", path, message) if {
	some path, workflow in files.workflows
	some job_id, job in files.jobs(workflow)
	written := environment_name(job)
	name := environments.other_words[lower(written)]
	message := sprintf(
		concat(" ", [
			"job %q deploys to the GitHub environment %q, another word for the %s deployment",
			"environment; name the environment %q, the name every deployment record, ruleset and",
			"search uses",
		]),
		[job_id, written, name, name],
	)
}

# GHA-51
findings contains lib.finding("GHA-51", path, message) if {
	some path, document in workflows_and_actions
	some reference in referenced_names(document)
	words := [word | some word in split(lower(reference.name), "_")]
	scoping := {upper(word) | some word in words; word in environments.name_words}
	count(scoping) > 0
	message := sprintf(
		concat(" ", [
			"%s.%s scopes a value to a deployment environment by its name (%s); set it on that",
			"environment's GitHub environment as %s.%s, the same name in each environment, and read",
			"it from a job with that environment:",
		]),
		[reference.context, reference.name, concat(", ", sort(scoping)), reference.context, unscoped(reference.name)],
	)
}

# GHA-52. An App token step outside release.yml, whose steps REL-16 judges.
findings contains lib.finding("GHA-52", entry.path, message) if {
	some entry in app_token_entries
	some problem in app_token_problems(steps.inputs(entry.step))
	message := sprintf(
		concat(" ", [
			"%s in %s mints a GitHub App token %s; name the App with client-id:",
			"${{ vars.<PURPOSE>_APP_CLIENT_ID }} and sign with private-key:",
			"${{ secrets.<PURPOSE>_APP_PRIVATE_KEY }}, one purpose for both",
		]),
		[entry.label, entry.where, problem],
	)
}

# GHA-52. An App credential read anywhere else in the wrong form.
findings contains lib.finding("GHA-52", path, message) if {
	some path, document in workflows_and_actions
	some reference in credential_references(document)
	problem := credential_problem(reference.context, reference.name)
	message := sprintf(
		concat(" ", [
			"%s.%s %s; keep a GitHub App's client ID as the variable vars.<PURPOSE>_APP_CLIENT_ID and",
			"its private key as the secret secrets.<PURPOSE>_APP_PRIVATE_KEY",
		]),
		[reference.context, reference.name, problem],
	)
}

# GHA-53. A deploy job that posts no deployment record.
findings contains lib.finding("GHA-53", path, message) if {
	some path, workflow in files.workflows
	some job_id, job in deploy_jobs(path, workflow)
	not records_deployment(job)
	message := sprintf(
		concat(" ", [
			"job %q deploys to the %q environment but records no deployment; post the deployment",
			"record (gh api -X POST orgs/<org>/artifacts/metadata/deployment-record with name, digest,",
			"version, status: deployed and logical_environment: %s) so the organization's linked",
			"artifacts show what runs there",
		]),
		[job_id, environment_name(job), environment_name(job)],
	)
}

# GHA-53. A deployment record posted without the permission to write it.
findings contains lib.finding("GHA-53", path, message) if {
	some path, workflow in files.workflows
	some job_id, job in deploy_jobs(path, workflow)
	records_deployment(job)
	not permissions.granted(workflow, job, "artifact-metadata")
	message := sprintf(
		concat(" ", [
			"job %q posts a deployment record without artifact-metadata: write; grant it in the",
			"job's permissions so the record is written",
		]),
		[job_id],
	)
}

# One `git push` command per match, to the end of its command line.
push_commands(step) := {match |
	some line in steps.command_lines(step)
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

production_reason(path, _) := "its filename names production" if production_filename(path)

production_reason(path, workflow) := sprintf("job %q deploys to the production environment", [job_id]) if {
	not production_filename(path)
	deploying := {id | some id, job in files.jobs(workflow); production_environment(job)}
	count(deploying) > 0
	job_id := min(deploying)
}

# Production by its registered name or its slug.
production_filename(path) if {
	some token in names.meaningful_tokens(files.stem(path))
	token in environments.production_words
}

production_environment(job) if lower(environment_name(job)) in environments.production_words

# A job's GitHub environment, written as a string or as its name.
environment_name(job) := job.environment if is_string(job.environment)

environment_name(job) := job.environment.name if is_string(job.environment.name)

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

# --- Secrets, variables and App credentials (GHA-51, GHA-52) ------------------

workflows_and_actions[path] := document if some path, document in files.workflows

workflows_and_actions[path] := document if some path, document in files.actions

reference_pattern := `\b(secrets|vars)\.([A-Za-z_][A-Za-z0-9_]*)`

# Every expression a document holds, as {"location", "text"}: the inside of
# each ${{ }}, and the whole of an if:, which GitHub reads as an expression
# without one. Text outside an expression, such as a file named
# secrets.production.yaml in a run: block, is not a reference.
expressions(document) := {{"location": location, "text": text} |
	walk(document, [location, value])
	is_string(value)
	some text in expression_texts(location, value)
}

expression_texts(location, value) := embedded(value) | whole_condition(location, value)

embedded(value) := {match[1] | some match in regex.find_all_string_submatch_n(`\$\{\{(.*?)\}\}`, value, -1)}

default whole_condition(_, _) := set()

whole_condition(location, value) := {value} if {
	count(location) > 0
	location[count(location) - 1] == "if"
}

# Each secrets.<NAME> and vars.<NAME> a document refers to, as
# {"location", "context", "name"}.
references(document) := {{"location": expression.location, "context": match[1], "name": match[2]} |
	some expression in expressions(document)
	some match in regex.find_all_string_submatch_n(reference_pattern, expression.text, -1)
}

# Each name once per file, wherever it is read.
referenced_names(document) := {{"context": reference.context, "name": reference.name} |
	some reference in references(document)
}

# A name without its deployment-environment words.
unscoped(name) := concat("_", [part |
	some part in split(name, "_")
	not lower(part) in environments.name_words
	part != ""
])

app_token_action := "actions/create-github-app-token"

# REL-16 judges the App token steps of release.yml.
release_token_step(path, step) if {
	files.stem(path) == "release"
	steps.action(step) == app_token_action
}

app_token_entries contains entry if {
	some entry in steps.entries
	steps.action(entry.step) == app_token_action
	not release_token_step(entry.path, entry.step)
}

client_id_pattern := `^\$\{\{\s*vars\.([A-Z0-9_]+)_APP_CLIENT_ID\s*\}\}$`

private_key_pattern := `^\$\{\{\s*secrets\.([A-Z0-9_]+)_APP_PRIVATE_KEY\s*\}\}$`

app_token_problems(inputs) := problems if {
	purposes := {
		"client": purpose(client_id_pattern, object.get(inputs, "client-id", "")),
		"key": purpose(private_key_pattern, object.get(inputs, "private-key", "")),
	}
	problems := {problem |
		some problem in [
			app_id_problem(inputs),
			client_problem(inputs, purposes.client),
			key_problem(inputs, purposes.key),
			mismatch_problem(purposes),
		]
		problem != ""
	}
}

default purpose(_, _) := ""

purpose(pattern, value) := match[1] if {
	is_string(value)
	some match in regex.find_all_string_submatch_n(pattern, trim_space(value), 1)
}

default app_id_problem(_) := ""

app_id_problem(inputs) := "with app-id, the older input" if "app-id" in object.keys(inputs)

default client_problem(_, _) := ""

client_problem(inputs, "") := sprintf("with client-id %v", [inputs["client-id"]]) if {
	"client-id" in object.keys(inputs)
}

client_problem(inputs, "") := "without a client-id" if {
	not "client-id" in object.keys(inputs)
	not "app-id" in object.keys(inputs)
}

default key_problem(_, _) := ""

key_problem(inputs, "") := sprintf("with private-key %v", [object.get(inputs, "private-key", "(none)")])

default mismatch_problem(_) := ""

mismatch_problem(purposes) := sprintf(
	"with a client ID for %s and a private key for %s",
	[purposes.client, purposes.key],
) if {
	purposes.client != ""
	purposes.key != ""
	purposes.client != purposes.key
}

# The references outside every App token step's inputs: those are judged
# as a whole above, or by REL-16 in release.yml.
credential_references(document) := {{"context": reference.context, "name": reference.name} |
	some reference in references(document)
	not token_input(document, reference.location)
}

token_input(document, location) if {
	count(location) > 4
	location[0] == "jobs"
	location[2] == "steps"
	location[4] == "with"
	steps.action(document.jobs[location[1]].steps[location[3]]) == app_token_action
}

token_input(document, location) if {
	count(location) > 3
	location[0] == "runs"
	location[1] == "steps"
	location[3] == "with"
	steps.action(document.runs.steps[location[2]]) == app_token_action
}

credential_problem("secrets", name) := concat(" ", [
	"keeps an App ID as a secret, where the older App ID stands in",
	"for the client ID",
]) if {
	endswith(name, "_APP_ID")
}

credential_problem("vars", name) := "is an App ID, the older way to name an App" if endswith(name, "_APP_ID")

credential_problem("secrets", name) := "keeps a client ID, which is not secret, as a secret" if {
	endswith(name, "_APP_CLIENT_ID")
}

credential_problem("vars", name) := concat(" ", [
	"keeps a private key in a variable, readable by anyone who can",
	"read the settings",
]) if {
	endswith(name, "_APP_PRIVATE_KEY")
}

# --- Deployment records (GHA-53) ---------------------------------------------

deployment_record_patterns := [`artifacts/metadata/deployment-record`]

# The jobs of a deploy workflow that name an environment and run steps.
deploy_jobs(path, workflow) := {job_id: job |
	filenames.slot(files.stem(path)) == "deploy"
	some job_id, job in files.jobs(workflow)
	environment_name(job)
	not "uses" in object.keys(job)
}

records_deployment(job) if {
	some step in files.steps(job)
	posts_record(step)
}

posts_record(step) if {
	some line in steps.command_lines(step)
	runs.line_runs(deployment_record_patterns, line)
}

# A local composite action whose steps post it.
posts_record(step) if {
	is_string(step.uses)
	startswith(step.uses, "./.github/actions/")
	some path, action in files.actions
	startswith(path, concat("", [trim_prefix(step.uses, "./"), "/action.y"]))
	some inner in files.action_steps(action)
	some line in steps.command_lines(inner)
	runs.line_runs(deployment_record_patterns, line)
}
