package conventions.checks.outputs.publishing_test

import data.conventions.checks.outputs.publishing
import data.conventions.lib.testdata_test as td

identity := td.file(".repo/repository.toml", {"name": "platform-api", "owner": "@musher-dev/platform"})

workflow_path := ".github/workflows/publish.yml"

workflow(steps) := td.file(workflow_path, {
	"name": "Publish",
	"on": {"push": {"tags": ["v*"]}},
	"env": {"REGISTRY": "ghcr.io"},
	"jobs": {"image": {"runs-on": "ubuntu-24.04", "steps": steps}},
})

repo(docs) := array.concat([identity, td.inventory([workflow_path])], docs)

messages(found) := {f.message | some f in found; f.id == "OUT-13"}

meta := {
	"id": "meta",
	"uses": "docker/metadata-action@abc",
	"with": {"images": "${{ env.REGISTRY }}/musher-dev/platform-api"},
}

build(fields) := {"name": "Build", "uses": "docker/build-push-action@abc", "with": object.union({"push": true}, fields)}

missing(where, label) := sprintf(
	concat("", [
		"%s %s publishes an image to ghcr.io without the label org.opencontainers.image.source=",
		"https://github.com/musher-dev/platform-api, so GHCR connects the package to no repository; add the ",
		"label to the build, take the labels from docker/metadata-action, or set it with LABEL in the Dockerfile",
	]),
	[where, label],
)

test_metadata_labels_pass if {
	steps := [meta, build({"tags": "${{ steps.meta.outputs.tags }}", "labels": "${{ steps.meta.outputs.labels }}"})]
	count(messages(publishing.findings)) == 0 with input as repo([workflow(steps)])
}

test_unlabelled_pushes if {
	steps := [
		meta,
		build({"tags": "${{ steps.meta.outputs.tags }}"}),
		{"id": "push", "run": concat("\n", [
			"docker build -t ghcr.io/musher-dev/platform-api:1 .",
			"docker push ghcr.io/musher-dev/platform-api:1",
		])},
	]
	messages(publishing.findings) == {
		missing(`job "image"`, `step "Build"`),
		missing(`job "image"`, `step "push"`),
	} with input as repo([workflow(steps)])
}

test_not_published_to_ghcr if {
	steps := [
		build({"tags": "docker.io/musher/platform-api:1"}),
		build({"tags": "ghcr.io/musher-dev/platform-api:1", "push": false}),
		{"run": "docker push docker.io/musher/platform-api:1\necho 'docker push ghcr.io/x/y'"},
	]
	count(messages(publishing.findings)) == 0 with input as repo([workflow(steps)])
}

test_literal_and_run_labels if {
	steps := [
		build({
			"tags": "ghcr.io/musher-dev/platform-api:1",
			"push": "${{ github.event_name != 'pull_request' }}",
			"labels": "org.opencontainers.image.source=https://github.com/musher-dev/platform-api",
		}),
		{"run": concat(" ", [
			"docker buildx build --push -t ${{ env.REGISTRY }}/musher-dev/platform-api:1",
			"--label org.opencontainers.image.source=${{ github.server_url }}/${{ github.repository }} .",
		])},
	]
	count(messages(publishing.findings)) == 0 with input as repo([workflow(steps)])
}

test_mismatched_labels if {
	steps := [build({
		"tags": ["ghcr.io/musher-dev/platform-api:1"],
		"labels": ["org.opencontainers.image.source=https://github.com/musher-dev/platform"],
	})]
	dockerfile := td.file("Dockerfile", [{"Cmd": "label", "Value": [
		"org.opencontainers.image.source", "\"https://github.com/other/repo\"", "=",
	]}])
	found := publishing.findings with input as repo([workflow(steps), dockerfile])
	td.pairs({f | some f in found; f.id == "OUT-13"}) == {["OUT-13", workflow_path], ["OUT-13", "Dockerfile"]}
	messages(found) == {
		concat("", [
			`job "image" step "Build" labels the image org.opencontainers.image.source=https://github.com/musher-dev/platform, `,
			"but this repository is https://github.com/musher-dev/platform-api; GHCR connects the package to the ",
			"repository the label names, so set it to https://github.com/musher-dev/platform-api",
		]),
		concat("", [
			"the Dockerfile labels the image org.opencontainers.image.source=https://github.com/other/repo, but this ",
			"repository is https://github.com/musher-dev/platform-api and publishes to GHCR, which connects the package ",
			"to the repository the label names; set it to https://github.com/musher-dev/platform-api",
		]),
	}
}

test_dockerfile_label_and_action if {
	action := td.file(".github/actions/publish/action.yml", {"runs": {"using": "composite", "steps": [
		{"run": "docker push ghcr.io/musher-dev/platform-api:1", "shell": "bash"},
	]}})
	dockerfile := td.file("Dockerfile", [{"Cmd": "label", "Value": [
		"org.opencontainers.image.source", "https://github.com/Musher-Dev/platform-api/", "=",
	]}])
	count(messages(publishing.findings)) == 0 with input as repo([action, dockerfile])
	messages(publishing.findings) == {missing("the action", "step 1")} with input as repo([action])
}

test_metadata_labels_read_by_a_run_step if {
	run := `docker buildx build --push --label "$DOCKER_METADATA_OUTPUT_LABELS" -t ghcr.io/musher-dev/platform-api .`
	steps := [meta, {"run": run}]
	count(messages(publishing.findings)) == 0 with input as repo([workflow(steps)])
}

test_without_an_identity if {
	steps := [build({"tags": "ghcr.io/musher-dev/platform-api:1"})]
	count(messages(publishing.findings)) == 0 with input as [td.inventory([workflow_path]), workflow(steps)]
}

storage_messages(found) := {f.message | some f in found; f.id == "OUT-14"}

publish_job(job_permissions, steps) := td.file(workflow_path, {
	"name": "Publish",
	"on": {"push": {"tags": ["v*"]}},
	"permissions": {"contents": "read"},
	"jobs": {"image": object.union({"runs-on": "ubuntu-24.04", "steps": steps}, job_permissions)},
})

attest(push) := {"uses": "actions/attest@abc", "with": {"subject-name": "ghcr.io/x/y", "push-to-registry": push}}

recorded := {"artifact-metadata": "write"}

test_out_14_storage_records if {
	pushed := build({"tags": "ghcr.io/x/y:1"})
	post := {"run": "gh api -X POST \"orgs/$OWNER/artifacts/metadata/storage-record\" --input r.json"}
	every steps in [[pushed, attest(true)], [pushed, attest("true")], [pushed, post]] {
		docs := repo([publish_job({"permissions": recorded}, steps)])
		count(storage_messages(publishing.findings)) == 0 with input as docs
	}
	unrecorded := repo([publish_job({"permissions": recorded}, [pushed, attest(false)])])
	storage_messages(publishing.findings) == {concat(" ", [
		`job "image" pushes an image without writing its storage record, so the organization's linked`,
		"artifacts do not list it; attest the pushed digest with actions/attest and push-to-registry: true,",
		"which writes it, and grant artifact-metadata: write",
	])} with input as unrecorded
	unpermitted := repo([publish_job({}, [pushed, attest(true)])])
	storage_messages(publishing.findings) == {concat(" ", [
		`job "image" writes the image's storage record without artifact-metadata: write, so no record`,
		"is written; grant it in the job's permissions",
	])} with input as unpermitted
}

test_out_14_private_repositories_post_the_record if {
	private := td.file(".repo/repository.toml", {"name": "platform-api", "visibility": "private"})
	docs := [td.inventory([workflow_path]), private, publish_job({}, [{"run": "docker push ghcr.io/x/y:1"}])]
	some message in storage_messages(publishing.findings) with input as docs
	contains(message, "post it to orgs/<org>/artifacts/metadata/storage-record")
}

test_out_14_ignores_validation_and_local_pushes if {
	local := publish_job({}, [{"run": "docker push localhost:5000/y:1"}])
	count(storage_messages(publishing.findings)) == 0 with input as repo([local])
	validate := td.file(".github/workflows/validate.yml", {
		"on": "pull_request",
		"jobs": {"image": {"steps": [build({"tags": "ghcr.io/x/y:pr"})]}},
	})
	docs := array.concat([identity, td.inventory([".github/workflows/validate.yml"])], [validate])
	count(storage_messages(publishing.findings)) == 0 with input as docs
}
