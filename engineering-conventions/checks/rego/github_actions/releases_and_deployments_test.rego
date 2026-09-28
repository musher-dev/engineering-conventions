package conventions.checks.github_actions.releases_and_deployments_test

import data.conventions.checks.github_actions.releases_and_deployments as checks
import data.conventions.lib.testdata_test as td

wf(name, contents) := td.file(concat("", [".github/workflows/", name]), contents)

messages(found, id) := {f.message | some f in found; f.id == id}

job(extra) := object.union({"name": "Job", "runs-on": "ubuntu-24.04", "timeout-minutes": 5, "steps": []}, extra)

workflow(on, jobs) := {"name": "W", "on": on, "permissions": {}, "jobs": jobs}

test_conforming_repository_has_no_findings if {
	docs := [wf("validate.yml", td.validate), wf("reusable-build.yml", td.reusable_build)]
	results_1 := checks.findings with input as docs with data.conventions.index as td.index
	count(results_1) == 0
}

test_gha_46_force_push if {
	lines := [
		"git push --force origin main",
		"git push -f origin HEAD:main",
		"git push -fu origin main",
		"git push --force-with-lease origin main",
		"git push --force-with-lease=main origin main",
		"git push origin +main",
		"git push \\\n  --force \\\n  origin main",
	]
	jobs := {"a": job({"steps": [{"name": sprintf("Push %d", [i]), "run": line} | some i, line in lines]})}
	safe := {"b": job({"steps": [
		{"name": "Lease", "run": `git push --force-with-lease="main:${EXPECTED}" origin main`},
		{"name": "Plain", "run": "git push origin main && echo -f"},
		{"name": "Comment", "run": "# never git push --force\ngit push --follow-tags"},
	]})}
	action := {"runs": {"steps": [{"name": "Force", "run": "git push -f", "shell": "bash"}]}}
	docs := [
		wf("release.yml", workflow("push", object.union(jobs, safe))),
		td.file(".github/actions/setup-x/action.yml", action),
	]
	results_2 := checks.findings with input as docs with data.conventions.index as td.index
	found := messages(results_2, "GHA-46")
	count(found) == 8
	some first in found
	first == concat(" ", [
		`step "Push 0" in job "a" force-pushes with "--force", which overwrites whatever the remote holds;`,
		"use --force-with-lease=<branch>:<expected-sha> so the push fails if the branch moved",
	])
	some refspec in found
	contains(refspec, `force-pushes with "+main"`)
	some in_action in found
	startswith(in_action, `step "Force" in the action force-pushes with "-f"`)
}

release_step(given) := {"name": "Release", "uses": "googleapis/release-please-action@x", "with": given}

test_gha_47_release_please_token if {
	steps := [
		release_step({"config-file": "c.json"}),
		release_step({"token": "${{ secrets.GITHUB_TOKEN }}"}),
		release_step({"token": "${{ github.token }}"}),
		release_step({"token": "${{ steps.app_token.outputs.token }}"}),
		{"name": "Other", "uses": "actions/checkout@x"},
	]
	docs := [wf("release.yml", workflow("push", {"a": job({"steps": steps})}))]
	results_3 := checks.findings with input as docs with data.conventions.index as td.index
	found := messages(results_3, "GHA-47")
	found == {
		concat(" ", [
			`step "Release" in job "a" runs release-please without a token input, so it uses the default`,
			"GITHUB_TOKEN; GitHub starts no workflow for what the default token creates, so the release pull",
			"request never reports its required checks and the tag never starts the publish workflow; pass a",
			"GitHub App installation token as token:",
		]),
		concat(" ", [
			`step "Release" in job "a" runs release-please with token: ${{ secrets.GITHUB_TOKEN }}, the default`,
			"GITHUB_TOKEN; GitHub starts no workflow for what the default token creates, so the release pull",
			"request never reports its required checks and the tag never starts the publish workflow; pass a",
			"GitHub App installation token as token:",
		]),
		concat(" ", [
			`step "Release" in job "a" runs release-please with token: ${{ github.token }}, the default`,
			"GITHUB_TOKEN; GitHub starts no workflow for what the default token creates, so the release pull",
			"request never reports its required checks and the tag never starts the publish workflow; pass a",
			"GitHub App installation token as token:",
		]),
	}
}

delivery_jobs := {
	"build": job({}),
	"optional": job({"if": "vars.ENABLED == 'true'"}),
	"bare": job({"needs": ["build", "optional"]}),
	"always": job({"needs": "build", "if": "${{ always() }}"}),
	"success": job({"needs": "build", "if": "needs.build.result == 'success'"}),
	"kept": job({"needs": ["build"], "if": "${{ !cancelled() && needs.build.result == 'success' }}"}),
	"alone": job({}),
}

test_gha_48_terminal_jobs_survive_skips if {
	lane := [wf("deploy-production-api.yml", workflow("workflow_dispatch", delivery_jobs))]
	results_4 := checks.findings with input as lane with data.conventions.index as td.index
	found := messages(results_4, "GHA-48")
	found == {
		concat(" ", [
			`job "bare" is the last job of a deploy workflow and has no if: condition; a skipped job anywhere`,
			"before it skips it too and the run still reports success, so set if: ${{ !cancelled() &&",
			"needs.<job>.result == 'success' }} with each result it depends on",
		]),
		concat(" ", [
			`job "always" is the last job of a deploy workflow and runs with always(), even after the run is`,
			"cancelled; a skipped job anywhere before it skips it too and the run still reports success, so set",
			"if: ${{ !cancelled() && needs.<job>.result == 'success' }} with each result it depends on",
		]),
		concat(" ", [
			`job "success" is the last job of a deploy workflow and its if: condition does not include`,
			"!cancelled(); a skipped job anywhere before it skips it too and the run still reports success, so",
			"set if: ${{ !cancelled() && needs.<job>.result == 'success' }} with each result it depends on",
		]),
	}
	reusable := wf("reusable-publish-image.yml", workflow("workflow_call", delivery_jobs))
	results_5 := checks.findings with input as [reusable] with data.conventions.index as td.index
	count(messages(results_5, "GHA-48")) == 3
	validate := wf("validate.yml", workflow("pull_request", delivery_jobs))
	results_6 := checks.findings with input as [validate] with data.conventions.index as td.index
	count(messages(results_6, "GHA-48")) == 0
}

production_job := job({"environment": {"name": "Production", "url": "https://example.com"}})

test_gha_49_production_is_not_push_triggered if {
	by_name := wf("deploy-production.yml", workflow({"push": {"branches": ["main"]}}, {"a": job({})}))
	by_environment := wf("deploy.yml", workflow("push", {"a": job({"environment": "production"}), "b": production_job}))
	docs := [by_name, by_environment]
	results_7 := checks.findings with input as docs with data.conventions.index as td.index
	found := {[f.path, f.message] | some f in results_7; f.id == "GHA-49"}
	count(found) == 2
	some named in found
	named[0] == ".github/workflows/deploy-production.yml"
	startswith(named[1], "the workflow acts on production (its filename names production) but runs on a push")
	some environment in found
	startswith(environment[1], `the workflow acts on production (job "a" deploys to the production environment)`)
}

test_gha_49_allowed_triggers if {
	cases := [
		{"push": {"tags": ["v*"]}},
		{"push": {"paths": ["./.github/workflows/verify-production.yml"]}},
		{"release": {"types": ["published"]}},
		"workflow_dispatch",
	]
	every trigger in cases {
		docs := [wf("verify-production.yml", workflow(trigger, {"a": job({})}))]
		results_8 := checks.findings with input as docs with data.conventions.index as td.index
		count(messages(results_8, "GHA-49")) == 0
	}
	widened := {"push": {"tags": ["v*"], "branches": ["main"]}}
	wide := [wf("verify-production.yml", workflow(widened, {"a": job({})}))]
	results_9 := checks.findings with input as wide with data.conventions.index as td.index
	count(messages(results_9, "GHA-49")) == 1
	staging := wf("deploy-staging.yml", workflow("push", {"a": job({"environment": "staging"})}))
	results_10 := checks.findings with input as [staging] with data.conventions.index as td.index
	count(messages(results_10, "GHA-49")) == 0
}
