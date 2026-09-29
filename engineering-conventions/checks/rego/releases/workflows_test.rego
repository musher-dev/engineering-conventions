package conventions.checks.releases.workflows_test

import data.conventions.checks.releases.workflows as checks
import data.conventions.lib.testdata_test as td

wf(name, contents) := td.file(concat("", [".github/workflows/", name]), contents)

drafted := td.file(".github/release-please/config.json", {"draft": true, "packages": {".": {}}})

app_token := {
	"name": "Mint the release App token",
	"id": "app_token",
	"uses": "actions/create-github-app-token@x",
	"with": {
		"client-id": "${{ vars.RELEASE_APP_CLIENT_ID }}",
		"private-key": "${{secrets.RELEASE_APP_PRIVATE_KEY}}",
		"permission-contents": "write",
	},
}

release_please := {"name": "Release", "id": "release", "uses": "googleapis/release-please-action@x"}

attest := {"name": "Attest", "uses": "actions/attest@x", "with": {"subject-checksums": "dist/SHA256SUMS"}}

upload := {"name": "Upload", "run": "gh release upload \"$TAG\" dist/*", "env": {"GH_TOKEN": "${{ github.token }}"}}

publish := {
	"name": "Publish",
	"run": "gh release edit \"$TAG\" --draft=false",
	"env": {"GH_TOKEN": "${{ steps.app_token.outputs.token }}"},
}

attest_permissions := {"contents": "write", "id-token": "write", "attestations": "write"}

# A conforming release.yml: release-please, assets attached to the draft,
# then the draft published with the App token.
release := {
	"name": "Release",
	"on": {"push": {"branches": ["main"]}, "workflow_dispatch": {"inputs": {"tag": {"required": true}}}},
	"concurrency": {"group": "${{ github.workflow }}-${{ github.ref }}", "cancel-in-progress": false},
	"jobs": {
		"release_please": {"name": "Release", "steps": [app_token, release_please]},
		"bundle": {"name": "Bundle", "permissions": attest_permissions, "steps": [attest, upload]},
		"finalize": {"name": "Publish", "steps": [app_token, publish]},
	},
}

messages(results, id) := {f.message | some f in results; f.id == id}

has(found, fragment) if {
	some message in found
	contains(message, fragment)
}

# The base with each changed key replaced whole: object.union alone merges
# nested objects, which would keep the base's other jobs and triggers.
replaced(base, changes) := object.union(object.remove(base, object.keys(changes)), changes)

# release.yml with its jobs replaced, beside a drafting config.
release_with(jobs) := [drafted, wf("release.yml", replaced(release, {"jobs": jobs}))]

test_conforming_release_workflow_has_no_findings if {
	results := checks.findings with input as [drafted, wf("release.yml", release)] with data.conventions.index as td.index
	count(results) == 0
	queued := replaced(release, {"concurrency": "release"})
	results_queued := checks.findings with input as [drafted, wf("release.yml", queued)]
		with data.conventions.index as td.index
	count(results_queued) == 0
}

test_rel_15_one_release_workflow if {
	elsewhere := {"name": "Release PR", "on": "push", "jobs": {"a": {"name": "A", "steps": [release_please]}}}
	results := checks.findings with input as [wf("release-pr.yml", elsewhere)] with data.conventions.index as td.index
	{f.path | some f in results; f.id == "REL-15"} == {".github/workflows/release-pr.yml"}
	manual := replaced(release, {"on": {"workflow_dispatch": {"inputs": {"tag": {}}}}})
	results_manual := checks.findings with input as [drafted, wf("release.yml", manual)]
		with data.conventions.index as td.index
	has(messages(results_manual, "REL-15"), "release.yml runs release-please but not on push")
	cancelling := replaced(release, {"concurrency": {"group": "g", "cancel-in-progress": true}})
	results_cancelling := checks.findings with input as [drafted, wf("release.yml", cancelling)]
		with data.conventions.index as td.index
	count(messages(results_cancelling, "REL-15")) == 1
	unqueued := object.remove(release, ["concurrency"])
	results_unqueued := checks.findings with input as [drafted, wf("release.yml", unqueued)]
		with data.conventions.index as td.index
	count(messages(results_unqueued, "REL-15")) == 1
}

test_rel_16_release_app_token if {
	legacy := {"name": "Token", "uses": "actions/create-github-app-token@x", "with": {
		"app-id": "${{ secrets.AUTOMATION_APP_ID }}",
		"private-key": "${{ secrets.AUTOMATION_APP_PRIVATE_KEY }}",
	}}
	other := {"name": "Other", "uses": "actions/create-github-app-token@x", "with": {
		"client-id": "${{ vars.OTHER_CLIENT_ID }}",
		"private-key": "${{ secrets.RELEASE_APP_PRIVATE_KEY }}",
		"permission-contents": "write",
	}}
	bare := {"name": "Bare", "uses": "actions/create-github-app-token@x"}
	jobs := {"release_please": {"name": "Release", "steps": [legacy, other, bare, release_please]}}
	results := checks.findings with input as release_with(jobs) with data.conventions.index as td.index
	found := messages(results, "REL-16")
	count(found) == 7
	has(found, `step "Token" in job "release_please" mints the release token with app-id rather than client-id`)
	has(found, `with client-id "${{ vars.OTHER_CLIENT_ID }}"`)
	has(found, `step "Bare" in job "release_please" mints the release token without a client-id`)
	outside := wf("validate.yml", {"name": "Validate", "on": "push", "jobs": {"a": {"name": "A", "steps": [legacy]}}})
	results_outside := checks.findings with input as [outside] with data.conventions.index as td.index
	count(messages(results_outside, "REL-16")) == 0
}

test_rel_17_no_writes_after_publishing if {
	late := {
		"name": "Publish",
		"on": {"release": {"types": ["published"]}},
		"jobs": {"assets": {"name": "Assets", "steps": [
			{"name": "Upload", "run": "gh release upload \"$TAG\" dist/*"},
			{"name": "Attach", "uses": "softprops/action-gh-release@x"},
			{"name": "Edit", "run": "gh api -X PATCH repos/o/r/releases/1 -f body=x"},
			{"name": "Read", "run": "gh release view \"$TAG\""},
		]}},
	}
	results := checks.findings with input as [wf("publish.yml", late)] with data.conventions.index as td.index
	count(messages(results, "REL-17")) == 3
	deleting := {"name": "Clean", "on": "workflow_dispatch", "jobs": {"a": {"name": "A", "steps": [
		{"name": "Delete", "run": "gh release delete \"$TAG\" --yes"},
	]}}}
	results_deleting := checks.findings with input as [wf("maintain-releases.yml", deleting)]
		with data.conventions.index as td.index
	messages(results_deleting, "REL-17") == {concat(" ", [
		`step "Delete" in job "a" deletes a release; a published release is what consumers pinned and`,
		"verified, and its tag can never be reused, so fix forward with the next version instead",
	])}
}

test_rel_18_attested_checksums if {
	by_path := {"name": "Attest", "uses": "actions/attest-build-provenance@x", "with": {"subject-path": "dist/*"}}
	unattested := {"bundle": {"name": "Bundle", "permissions": attest_permissions, "steps": [by_path, upload]}}
	results := checks.findings with input as release_with(unattested) with data.conventions.index as td.index
	messages(results, "REL-18") == {concat(" ", [
		`job "bundle" uploads release assets without attesting them through a SHA256SUMS file; write`,
		"SHA256SUMS over the assets, upload it with them, and attest it with actions/attest",
		"subject-checksums: <dir>/SHA256SUMS",
	])}
	unpermitted := {"bundle": {"name": "Bundle", "permissions": {"contents": "write"}, "steps": [attest, upload]}}
	results_unpermitted := checks.findings with input as release_with(unpermitted)
		with data.conventions.index as td.index
	count(messages(results_unpermitted, "REL-18")) == 2
	inherited := replaced(release, {
		"permissions": "write-all",
		"jobs": {"bundle": {"name": "Bundle", "steps": [attest, upload]}},
	})
	results_inherited := checks.findings with input as [wf("release.yml", inherited)]
		with data.conventions.index as td.index
	count(messages(results_inherited, "REL-18")) == 0
	api_upload := {"name": "Upload", "run": "gh api -X POST \"${upload_url}?name=a\" --input a"}
	via_api := {"bundle": {"name": "Bundle", "permissions": attest_permissions, "steps": [api_upload]}}
	results_api := checks.findings with input as release_with(via_api) with data.conventions.index as td.index
	count(messages(results_api, "REL-18")) == 1
}

test_rel_19_publish_the_draft if {
	unpublished := {"bundle": release.jobs.bundle}
	results := checks.findings with input as release_with(unpublished) with data.conventions.index as td.index
	messages(results, "REL-19") == {concat(" ", [
		"release-please drafts every release, but no workflow publishes the draft; end release.yml with a",
		"job that runs gh release edit <tag> --draft=false once the assets are attached",
	])}
	undrafted := [
		td.file(".github/release-please/config.json", {"packages": {".": {}}}),
		wf("release.yml", replaced(release, {"jobs": unpublished})),
	]
	results_undrafted := checks.findings with input as undrafted with data.conventions.index as td.index
	count(messages(results_undrafted, "REL-19")) == 0
}

test_rel_19_publish_with_the_app_token if {
	default_token := object.union(publish, {"env": {"GH_TOKEN": "${{ secrets.GITHUB_TOKEN }}"}})
	results := checks.findings with input as release_with({"finalize": {"name": "Publish", "steps": [default_token]}})
		with data.conventions.index as td.index
	has(messages(results, "REL-19"), "publishes the draft release with ${{ secrets.GITHUB_TOKEN }}")
	api := {"name": "Publish", "run": "gh api -X PATCH \"$api\" -F draft=false"}
	results_none := checks.findings with input as release_with({"finalize": {"name": "Publish", "steps": [api]}})
		with data.conventions.index as td.index
	has(messages(results_none, "REL-19"), "with no GH_TOKEN, so the default token")
	job_token := {"finalize": {
		"name": "Publish",
		"env": {"GH_TOKEN": "${{ steps.app_token.outputs.token }}"},
		"steps": [api],
	}}
	results_job := checks.findings with input as release_with(job_token) with data.conventions.index as td.index
	count(messages(results_job, "REL-19")) == 0
}

test_rel_20_dispatch_for_a_draft if {
	undispatchable := replaced(release, {"on": {"push": {"branches": ["main"]}}})
	results := checks.findings with input as [drafted, wf("release.yml", undispatchable)]
		with data.conventions.index as td.index
	{f.path | some f in results; f.id == "REL-20"} == {".github/workflows/release.yml"}
	no_input := replaced(release, {"on": {"push": null, "workflow_dispatch": null}})
	results_no_input := checks.findings with input as [drafted, wf("release.yml", no_input)]
		with data.conventions.index as td.index
	count(messages(results_no_input, "REL-20")) == 1
}
