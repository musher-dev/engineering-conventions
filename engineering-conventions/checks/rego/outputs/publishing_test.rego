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
	count(publishing.findings) == 0 with input as repo([workflow(steps)])
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
	count(publishing.findings) == 0 with input as repo([workflow(steps)])
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
	count(publishing.findings) == 0 with input as repo([workflow(steps)])
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
	td.pairs(found) == {["OUT-13", workflow_path], ["OUT-13", "Dockerfile"]}
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
	count(publishing.findings) == 0 with input as repo([action, dockerfile])
	messages(publishing.findings) == {missing("the action", "step 1")} with input as repo([action])
}

test_metadata_labels_read_by_a_run_step if {
	run := `docker buildx build --push --label "$DOCKER_METADATA_OUTPUT_LABELS" -t ghcr.io/musher-dev/platform-api .`
	steps := [meta, {"run": run}]
	count(publishing.findings) == 0 with input as repo([workflow(steps)])
}

test_without_an_identity if {
	steps := [build({"tags": "ghcr.io/musher-dev/platform-api:1"})]
	count(publishing.findings) == 0 with input as [td.inventory([workflow_path]), workflow(steps)]
}
