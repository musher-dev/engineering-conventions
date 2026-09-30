# METADATA
# title: Release workflows
# description: >-
#   release.yml alone runs release-please, on a push, never cancelled; it mints
#   its token from the release App, attests what it uploads through a
#   SHA256SUMS file (a private repository uploads the file unattested),
#   publishes the draft last with the App's token, and can be dispatched for
#   a draft's tag. Nothing writes to a release once published.
# scope: package
# custom:
#   convention: EC-0026
package conventions.checks.releases.workflows

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.release_please as rp
import data.conventions.lib.repository
import data.conventions.lib.steps

release_workflow := ".github/workflows/release.yml"

client_id := "${{ vars.RELEASE_APP_CLIENT_ID }}"

private_key := "${{ secrets.RELEASE_APP_PRIVATE_KEY }}"

# REL-15
findings contains lib.finding("REL-15", entry.path, message) if {
	some entry in rp.entries
	files.stem(entry.path) != "release"
	message := sprintf(
		concat(" ", [
			"%s in %s runs release-please outside release.yml; run it only in %s, so one workflow owns",
			"release pull requests, tags and releases",
		]),
		[entry.label, entry.where, release_workflow],
	)
}

findings contains lib.finding("REL-15", path, message) if {
	message := concat(" ", [
		"release.yml runs release-please but not on push; trigger it on a push to the default branch,",
		"where release-please opens the release pull request and cuts the release it merges",
	])
	some path in release_please_workflows
	not "push" in files.triggers(files.workflows[path])
}

findings contains lib.finding("REL-15", path, message) if {
	message := concat(" ", [
		"release.yml runs release-please without a workflow concurrency group that never cancels;",
		"set concurrency: with a group and cancel-in-progress: false, since a run cancelled between",
		"the tag and the published release leaves a half-made release",
	])
	some path in release_please_workflows
	not queued(files.workflows[path])
}

# REL-16
findings contains lib.finding("REL-16", entry.path, message) if {
	some [entry, problem] in token_problems
	message := sprintf(
		concat(" ", [
			"%s in %s mints the release token %s; mint it from the release App with client-id: %s,",
			"private-key: %s and a permission-* input for each permission the job needs",
		]),
		[entry.label, entry.where, problem, client_id, private_key],
	)
}

# REL-17
findings contains lib.finding("REL-17", path, message) if {
	some path, workflow in files.workflows
	"release" in files.triggers(workflow)
	some job_id, job in files.jobs(workflow)
	some index, step in files.steps(job)
	rp.writes(step)
	message := sprintf(
		concat(" ", [
			"%s in job %q writes to a release from a workflow started by a release event, when the",
			"release is already published and its assets can no longer change; attach assets to the",
			"draft in release.yml, and push only to other registries here",
		]),
		[files.step_label(step, index), job_id],
	)
}

findings contains lib.finding("REL-17", entry.path, message) if {
	some entry in steps.entries
	rp.deletes(entry.step)
	message := sprintf(
		concat(" ", [
			"%s in %s deletes a release; a published release is what consumers pinned and verified,",
			"and its tag can never be reused, so fix forward with the next version instead",
		]),
		[entry.label, entry.where],
	)
}

# REL-18
findings contains lib.finding("REL-18", path, message) if {
	some path, workflow in files.workflows
	some job_id, job in files.jobs(workflow)
	some step in files.steps(job)
	rp.uploads(step)
	not repository.attestations_unavailable
	not attests_checksums(job)
	message := sprintf(
		concat(" ", [
			"job %q uploads release assets without attesting them through a SHA256SUMS file; write",
			"SHA256SUMS over the assets, upload it with them, and attest it with actions/attest",
			"subject-checksums: <dir>/SHA256SUMS (a private or internal repository, where GitHub offers",
			"no attestations, declares visibility in .repo/repository.toml and needs only SHA256SUMS)",
		]),
		[job_id],
	)
}

findings contains lib.finding("REL-18", path, message) if {
	repository.attestations_unavailable
	some path, workflow in files.workflows
	some job_id, job in files.jobs(workflow)
	some step in files.steps(job)
	rp.uploads(step)
	not writes_checksums(job)
	message := sprintf(
		concat(" ", [
			"job %q uploads release assets without a SHA256SUMS file; write SHA256SUMS over the",
			"assets and upload it with them, so a consumer can verify each download",
		]),
		[job_id],
	)
}

findings contains lib.finding("REL-18", path, message) if {
	some path, workflow in files.workflows
	some job_id, job in files.jobs(workflow)
	attests_checksums(job)
	some permission in ["id-token", "attestations"]
	not granted(workflow, job, permission)
	message := sprintf(
		"job %q attests release assets without %s: write; grant it so the attestation can be signed and stored",
		[job_id, permission],
	)
}

# REL-19
findings contains lib.finding("REL-19", rp.config_path, message) if {
	drafts
	count(publishing_steps) == 0
	message := concat(" ", [
		"release-please drafts every release, but no workflow publishes the draft; end release.yml",
		"with a job that runs gh release edit <tag> --draft=false once the assets are attached",
	])
}

findings contains lib.finding("REL-19", entry.path, message) if {
	drafts
	some entry in publishing_steps
	not app_token(entry.token)
	message := sprintf(
		concat(" ", [
			"%s in %s publishes the draft release with %s; publish it with the release App's",
			"token, since a release published by the default token starts no workflow on its",
			"published event",
		]),
		[entry.label, entry.where, token_label(entry.token)],
	)
}

# REL-20
findings contains lib.finding("REL-20", path, message) if {
	message := concat(" ", [
		"release.yml attaches assets to releases but cannot be dispatched for one; add",
		"workflow_dispatch with a required tag input, so a draft left by a failed run can be",
		"completed with the fixed workflow",
	])
	some path, workflow in files.workflows
	files.stem(path) == "release"
	not dispatchable(workflow)
	uploads_assets(workflow)
}

uploads_assets(workflow) if {
	some job in files.jobs(workflow)
	some step in files.steps(job)
	rp.uploads(step)
}

release_please_workflows contains entry.path if {
	some entry in rp.entries
	files.stem(entry.path) == "release"
}

queued(workflow) if {
	is_string(workflow.concurrency)
}

queued(workflow) if {
	is_string(workflow.concurrency.group)
	object.get(workflow.concurrency, "cancel-in-progress", false) == false
}

app_token_actions := {"actions/create-github-app-token", "tibdex/github-app-token"}

app_token_steps contains entry if {
	some entry in steps.entries
	files.stem(entry.path) == "release"
	steps.action(entry.step) in app_token_actions
}

# Each way an App token step departs from the release App: [entry, problem].
token_problems contains [entry, sprintf("with client-id %q", [inputs["client-id"]])] if {
	some entry in app_token_steps
	inputs := steps.inputs(entry.step)
	is_string(inputs["client-id"])
	normalised(inputs["client-id"]) != client_id
}

token_problems contains [entry, "with app-id rather than client-id"] if {
	some entry in app_token_steps
	"app-id" in object.keys(steps.inputs(entry.step))
}

token_problems contains [entry, "without a client-id"] if {
	some entry in app_token_steps
	inputs := steps.inputs(entry.step)
	not "client-id" in object.keys(inputs)
	not "app-id" in object.keys(inputs)
}

token_problems contains [entry, sprintf("with private-key %q", [key])] if {
	some entry in app_token_steps
	key := object.get(steps.inputs(entry.step), "private-key", "")
	normalised(key) != private_key
}

token_problems contains [entry, "with every permission the App has"] if {
	some entry in app_token_steps
	count([key | some key, _ in steps.inputs(entry.step); startswith(key, "permission-")]) == 0
}

normalised(expression) := regex.replace(trim_space(expression), `\$\{\{\s*(.*?)\s*\}\}`, "$${{ $1 }}")

attests_checksums(job) if {
	some step in files.steps(job)
	steps.action(step) in {"actions/attest", "actions/attest-build-provenance"}
	checksums := steps.inputs(step)["subject-checksums"]
	is_string(checksums)
	endswith(checksums, "SHA256SUMS")
}

# A job that names SHA256SUMS in a command or an input: it writes the file,
# or uploads or attests it.
writes_checksums(job) if {
	some step in files.steps(job)
	contains(steps.code(step), "SHA256SUMS")
}

writes_checksums(job) if {
	some step in files.steps(job)
	some value in steps.inputs(step)
	is_string(value)
	contains(value, "SHA256SUMS")
}

granted(_, job, permission) if {
	"permissions" in object.keys(job)
	grants(job.permissions, permission)
}

granted(workflow, job, permission) if {
	not "permissions" in object.keys(job)
	grants(workflow.permissions, permission)
}

grants("write-all", _)

grants(permissions, permission) if permissions[permission] == "write"

drafts if {
	some settings in rp.settings
	settings.draft == true
}

publishing_steps contains object.union(entry, {"token": rp.token(job, entry.step)}) if {
	some entry in steps.entries
	rp.publishes(entry.step)
	job := job_of(entry)
}

job_of(entry) := job if {
	some path, workflow in files.workflows
	path == entry.path
	some job_id, job in files.jobs(workflow)
	entry.where == sprintf("job %q", [job_id])
}

job_of(entry) := {} if entry.where == "the action"

# A token that is not the default one, such as a step output of the App's
# token step.
app_token(token) if {
	token != ""
	not rp.default_token(token)
}

token_label("") := "no GH_TOKEN, so the default token"

token_label(token) := token if token != ""

dispatchable(workflow) if {
	"workflow_dispatch" in files.triggers(workflow)
	inputs := files.trigger_config(workflow, "workflow_dispatch").inputs
	is_object(inputs.tag)
}
