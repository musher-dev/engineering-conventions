package conventions.checks.github_actions.execution_hygiene_test

import data.conventions.checks.github_actions.execution_hygiene
import data.conventions.lib.testdata_test as td

wf(name, contents) := td.file(concat("", [".github/workflows/", name]), contents)

messages(found, id) := {f.message | some f in found; f.id == id}

sha := "08c6903cd8c0fde910a37f88322edcfb5dd907a8"

pinned(action) := concat("@", [action, sha])

test_conforming_repository_has_no_findings if {
	docs := [
		wf("validate.yml", td.validate),
		wf("reusable-build.yml", td.reusable_build),
		td.file(".github/rulesets/main.json", td.ruleset(["Validate / Required"])),
	]
	count(execution_hygiene.findings) == 0 with input as docs with data.conventions.index as td.index
}

test_gha_24_pins if {
	workflow := object.union(td.validate, {"jobs": {
		"a": {"name": "Validate / A", "timeout-minutes": 1, "steps": [
			{"name": "Tag", "uses": "actions/setup-node@v4"},
			{"name": "Sha", "uses": pinned("actions/setup-node")},
			{"name": "Local", "uses": "./.github/actions/setup-tools"},
			{"name": "Image", "uses": "docker://alpine:3"},
			{"name": "Digest", "uses": concat("", ["docker://alpine@sha256:", sha, "0123456789abcdef01234567"])},
		]},
		"remote": {"name": "Validate / Remote", "uses": "org/repo/.github/workflows/x.yml@main"},
	}})
	action := {"runs": {"steps": [{"name": "Bare", "uses": "org/action"}]}}
	docs := [wf("validate.yml", workflow), td.file(".github/actions/setup-x/action.yml", action)]
	found := execution_hygiene.findings with input as docs with data.conventions.index as td.index
	count(messages(found, "GHA-24")) == 4
	some tag in messages(found, "GHA-24")
	contains(tag, `job "a" uses "actions/setup-node@v4" by a movable reference;`)
	contains(tag, `the full 40-character commit SHA that v4 resolves to and keep "# v4" as a trailing comment`)
	some image in messages(found, "GHA-24")
	contains(image, `job "a" uses the image "docker://alpine:3" by tag; pin it by digest`)
	some remote in messages(found, "GHA-24")
	contains(remote, `job "remote" uses "org/repo/.github/workflows/x.yml@main"`)
	some bare in messages(found, "GHA-24")
	startswith(bare, `step 1 uses "org/action" with no version at all;`)
}

test_gha_26_permissions_declared if {
	docs := [wf("validate.yml", object.remove(td.validate, ["permissions"]))]
	td.ids(execution_hygiene.findings) == {"GHA-26"} with input as docs with data.conventions.index as td.index
}

with_permissions(permissions) := [wf("validate.yml", object.union(td.validate, {"permissions": permissions}))]

test_gha_27_least_privilege if {
	advice := concat(" ", [
		"keep the workflow level read-only ({contents: read} or {})",
		"and grant anything wider on the job that needs it",
	])
	allowed_cases := [{}, {"contents": "read"}, {"contents": "read", "pull-requests": "read", "id-token": "none"}]
	every allowed in allowed_cases {
		count(execution_hygiene.findings) == 0 with input as with_permissions(allowed)
			with data.conventions.index as td.index
	}
	cases := {
		"read-all": concat(" ", [
			"workflow-level permissions are read-all,",
			"which grants every read scope rather than the ones a job needs",
		]),
		"write-all": "workflow-level permissions are write-all, which grants every job write access to every scope",
	}
	every permissions, problem in cases {
		found := execution_hygiene.findings with input as with_permissions(permissions)
			with data.conventions.index as td.index
		messages(found, "GHA-27") == {sprintf("%s; %s", [problem, advice])}
	}
	wide := with_permissions({"contents": "write", "packages": "write", "issues": "read"})
	found := execution_hygiene.findings with input as wide with data.conventions.index as td.index
	expected := sprintf(`workflow-level permissions grant write access to "contents", "packages"; %s`, [advice])
	messages(found, "GHA-27") == {expected}
}

test_gha_28_checkout_persist_credentials if {
	workflow := object.union(td.validate, {"jobs": {"a": {"name": "Validate / A", "timeout-minutes": 1, "steps": [
		{"id": "co", "uses": pinned("actions/checkout")},
		{"name": "Keep", "uses": pinned("actions/checkout"), "with": {"persist-credentials": true}},
		{"uses": pinned("actions/checkout"), "with": {"persist-credentials": "false"}},
	]}}})
	action := {"runs": {"steps": [{"uses": pinned("actions/checkout")}]}}
	docs := [wf("validate.yml", workflow), td.file(".github/actions/setup-x/action.yml", action)]
	found := execution_hygiene.findings with input as docs with data.conventions.index as td.index
	rest := concat(" ", [
		"checks out without persist-credentials: false, leaving the token in .git/config for every later step;",
		"add with: {persist-credentials: false}",
	])
	messages(found, "GHA-28") == {
		sprintf(`step "co" in job "a" %s`, [rest]),
		sprintf(`step "Keep" in job "a" %s`, [rest]),
		sprintf(`step 1 in the action %s`, [rest]),
	}
}

test_gha_29_timeouts if {
	workflow := object.union(td.validate, {"jobs": {
		"a": {"name": "Validate / A", "steps": []},
		"b": {"name": "Validate / B", "uses": "./.github/workflows/reusable-build.yml"},
	}})
	docs := [wf("validate.yml", workflow)]
	found := execution_hygiene.findings with input as docs with data.conventions.index as td.index
	td.pairs(found) == {["GHA-29", ".github/workflows/validate.yml"]}
}

test_gha_30_missing_concurrency if {
	docs := [wf("validate.yml", object.remove(td.validate, ["concurrency"]))]
	found := execution_hygiene.findings with input as docs with data.conventions.index as td.index
	some message in messages(found, "GHA-30")
	startswith(message, `the workflow declares no concurrency group; set concurrency: {group: "${{ github.workflow }}`)
}

test_gha_30_other_group if {
	docs := [wf("validate.yml", object.union(td.validate, {"concurrency": "ci-${{ github.sha }}"}))]
	found := execution_hygiene.findings with input as docs with data.conventions.index as td.index
	some message in messages(found, "GHA-30")
	startswith(message, `the concurrency group "ci-${{ github.sha }}" does not start with the standard prefix`)
}

test_gha_30_string_form_and_scheduled_workflows if {
	string_form := object.union(td.validate, {"concurrency": "${{ github.workflow }}-${{ github.ref }}-x"})
	scheduled := {"name": "Audit", "on": {"schedule": [{"cron": "0 0 * * *"}]}, "permissions": {}, "jobs": {}}
	docs := [wf("validate.yml", string_form), wf("audit.yml", scheduled)]
	count(execution_hygiene.findings) == 0 with input as docs with data.conventions.index as td.index
}

test_gha_30_push_only_workflow_chooses_its_own_group if {
	deploy := {
		"name": "Deploy Staging",
		"on": {"push": {"branches": ["main"]}},
		"permissions": {"contents": "read"},
		"concurrency": {"group": "deploy-staging-${{ github.sha }}"},
		"jobs": {},
	}
	docs := [wf("deploy-staging.yml", deploy)]
	count({m | some m in messages(execution_hygiene.findings, "GHA-30")}) == 0 with input as docs
		with data.conventions.index as td.index
}

test_gha_31_callable_only_declares_no_concurrency if {
	called := object.union(td.reusable_build, {"concurrency": {"group": "x"}})
	docs := [wf("reusable-build.yml", called)]
	found := execution_hygiene.findings with input as docs with data.conventions.index as td.index
	td.pairs(found) == {["GHA-31", ".github/workflows/reusable-build.yml"]}
}

test_gha_31_job_level_concurrency_is_not_judged if {
	job := {"name": "Build", "timeout-minutes": 5, "concurrency": "x", "steps": []}
	docs := [wf("reusable-build.yml", object.union(td.reusable_build, {"jobs": {"build": job}}))]
	count(execution_hygiene.findings) == 0 with input as docs with data.conventions.index as td.index
}

test_gha_32_required_workflow_has_no_paths_filter if {
	triggers := {"pull_request": {"paths": ["src/**"]}, "push": {"paths-ignore": ["docs/**"]}}
	filtered := wf("validate.yml", object.union(td.validate, {"true": triggers}))
	count(execution_hygiene.findings) == 0 with input as [filtered] with data.conventions.index as td.index
	docs := [filtered, td.file(".github/rulesets/main.json", td.ruleset(["Validate / Required"]))]
	found := execution_hygiene.findings with input as docs with data.conventions.index as td.index
	count(messages(found, "GHA-32")) == 2
	some paths in messages(found, "GHA-32")
	startswith(paths, "on.pull_request has a paths filter, but this workflow emits a required check;")
	some ignore in messages(found, "GHA-32")
	startswith(ignore, "on.push has a paths-ignore filter")
}

no_group(triggers) := {"name": "Validate", "on": triggers, "permissions": {}, "jobs": {}}

test_gha_30_events_nothing_supersedes if {
	docs := [
		wf("validate.yml", no_group({"pull_request": {"types": ["closed"]}})),
		wf("release.yml", no_group({"pull_request_target": {"types": ["opened"]}})),
		wf("deploy.yml", no_group({"pull_request": {"types": "labeled"}, "push": null})),
	]
	found := execution_hygiene.findings with input as docs with data.conventions.index as td.index
	not "GHA-30" in td.ids(found)
}

test_gha_30_supersedable_types_and_dual_trigger if {
	docs := [
		wf("validate.yml", no_group({"pull_request": {"types": ["closed", "synchronize"]}})),
		wf("deploy.yml", no_group(["workflow_call", "merge_group"])),
	]
	found := execution_hygiene.findings with input as docs with data.conventions.index as td.index
	{[f.id, f.path] | some f in found} == {
		["GHA-30", ".github/workflows/validate.yml"],
		["GHA-30", ".github/workflows/deploy.yml"],
	}
}

test_gha_32_dual_trigger_and_matrix_contexts if {
	dual := {
		"name": "Validate",
		"on": {"workflow_call": null, "pull_request": {"paths": ["src/**"]}},
		"permissions": {},
		"concurrency": td.standard_concurrency,
		"jobs": {"test": {"name": "Test", "strategy": {"matrix": {"os": ["a"]}}}},
	}
	docs := [wf("validate.yml", dual), td.file(".github/rulesets/main.json", td.ruleset(["Test (a)"]))]
	found := execution_hygiene.findings with input as docs with data.conventions.index as td.index
	td.pairs(found) == {["GHA-32", ".github/workflows/validate.yml"]}
}
