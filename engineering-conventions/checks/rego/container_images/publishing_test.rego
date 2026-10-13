package conventions.checks.container_images.publishing_test

import data.conventions.checks.container_images.publishing
import data.conventions.lib.testdata_test as td

workflow_path := ".github/workflows/publish.yml"

workflow(job) := td.file(workflow_path, {
	"name": "Publish",
	"on": {"push": {"tags": ["v*"]}},
	"permissions": {"contents": "read"},
	"jobs": {"image": object.union({"runs-on": "ubuntu-24.04"}, job)},
})

granted := {"permissions": {"id-token": "write", "attestations": "write", "artifact-metadata": "write"}}

push := {"id": "push", "uses": "docker/build-push-action@abc", "with": {"push": true, "tags": "ghcr.io/x/y:1"}}

load := {"uses": "docker/build-push-action@abc", "with": {"load": true, "tags": "ghcr.io/x/y:1"}}

attest := {"uses": "actions/attest@abc", "with": {"subject-name": "ghcr.io/x/y", "push-to-registry": true}}

scan := {"run": "trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed ghcr.io/x/y:1"}

messages(found, id) := {f.message | some f in found; f.id == id}

repo(docs) := array.concat([td.inventory([workflow_path])], docs)

test_conforming_job if {
	conforming := [workflow(object.union(granted, {"steps": [load, scan, push, attest]}))]
	found := publishing.findings with input as repo(conforming)
	count(found) == 0
}

test_image_11_scans if {
	passing := [
		scan,
		{"run": "trivy i --severity=critical,high --exit-code=1 img"},
		{"run": "trivy image img", "env": {"TRIVY_EXIT_CODE": "1"}},
		{"run": "trivy image --config .config/security/trivy.yaml img"},
		{"uses": "aquasecurity/trivy-action@abc", "with": {"image-ref": "img", "exit-code": "1"}},
		{"uses": "aquasecurity/trivy-action@abc", "with": {"exit-code": 1, "severity": "HIGH,CRITICAL"}},
		{"run": "docker build -t img . && trivy image --exit-code 1 img && docker push img"},
	]
	every step in passing {
		found := publishing.findings with input as repo([workflow(object.union(granted, {"steps": [step, push, attest]}))])
		count(messages(found, "IMAGE-11")) == 0
	}
	failing := [
		{"run": "trivy image img"},
		{"run": "trivy image --exit-code 1 --severity CRITICAL img"},
		{"uses": "aquasecurity/trivy-action@abc", "with": {"image-ref": "img"}},
		{"uses": "aquasecurity/trivy-action@abc", "with": {"scan-type": "fs", "exit-code": "1"}},
	]
	every step in failing {
		found := publishing.findings with input as repo([workflow(object.union(granted, {"steps": [step, push, attest]}))])
		count(messages(found, "IMAGE-11")) == 1
	}
	late := publishing.findings with input as repo([workflow(object.union(granted, {"steps": [push, scan, attest]}))])
	messages(late, "IMAGE-11") == {concat(" ", [
		`job "image" pushes an image without scanning it first; before the push, run trivy image`,
		"--exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed on the built image (or",
		"aquasecurity/trivy-action with exit-code: 1), so a known vulnerability stops the publish",
	])}
}

test_image_11_through_a_task if {
	taskfile := td.file("Taskfile.yml", {"version": "3", "tasks": {
		"scan": {"cmds": ["trivy image --exit-code 1 {{.IMAGE}}"]},
		"check:image": {"cmds": [{"task": "scan"}]},
	}})
	docs := [
		td.inventory([workflow_path, "Taskfile.yml"]),
		taskfile,
		workflow(object.union(granted, {"steps": [{"run": "task check:image"}, push, attest]})),
	]
	found := publishing.findings with input as docs
	count(messages(found, "IMAGE-11")) == 0
}

test_image_12_attestation if {
	unattested := publishing.findings with input as repo([workflow(object.union(granted, {"steps": [scan, push]}))])
	messages(unattested, "IMAGE-12") == {concat(" ", [
		`job "image" pushes an image without attesting its build provenance; attest the pushed digest`,
		"with actions/attest and push-to-registry: true (a private or internal repository, where",
		"GitHub offers no attestations, declares visibility in .repo/repository.toml)",
	])}
	packages_only := [workflow({"permissions": {"packages": "write"}, "steps": [scan, push, attest]})]
	unpermitted := publishing.findings with input as repo(packages_only)
	messages(unpermitted, "IMAGE-12") == {
		`job "image" attests the image without id-token: write; grant it so the attestation can be signed and stored`,
		`job "image" attests the image without attestations: write; grant it so the attestation can be signed and stored`,
	}
	private := td.file(".repo/repository.toml", {"name": "x", "visibility": "private"})
	exempt := publishing.findings with input as repo([private, workflow({"steps": [scan, push]})])
	count(messages(exempt, "IMAGE-12")) == 0
}

test_validation_builds_are_not_published if {
	validate := td.file(".github/workflows/validate.yml", {"on": "pull_request", "jobs": {"image": {"steps": [push]}}})
	found := publishing.findings with input as [td.inventory([".github/workflows/validate.yml"]), validate]
	count(found) == 0
}
