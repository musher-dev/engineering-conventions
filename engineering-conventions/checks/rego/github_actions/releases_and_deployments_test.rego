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
		{"name": "Advice", "run": "cat >&2 <<- 'MSG'\n  To fix it: git push --force-with-lease\nMSG\nexit 1"},
		{"name": "Printed", "run": "echo 'then run git push -f'"},
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

test_gha_49_recognises_the_production_slug if {
	by_slug := wf("deploy-prod.yml", workflow("push", {"a": job({})}))
	by_environment := wf("deploy.yml", workflow("push", {"a": job({"environment": "prod"})}))
	results := checks.findings with input as [by_slug, by_environment] with data.conventions.index as td.index
	count(messages(results, "GHA-49")) == 2
}

test_gha_50_environment_names if {
	jobs := {
		"slug": job({"environment": "prod"}),
		"synonym": job({"environment": {"name": "STG"}}),
		"local": job({"environment": "local"}),
		"named": job({"environment": "production"}),
		"gate": job({"environment": "pypi"}),
		"computed": job({"environment": "${{ inputs.environment }}"}),
		"test": job({"environment": "test"}),
	}
	docs := [wf("deploy.yml", workflow("workflow_dispatch", jobs))]
	results := checks.findings with input as docs with data.conventions.index as td.index
	found := messages(results, "GHA-50")
	count(found) == 3
	some slug in found
	slug == concat(" ", [
		`job "slug" deploys to the GitHub environment "prod", another word for the production deployment`,
		`environment; name the environment "production", the name every deployment record, ruleset and`,
		"search uses",
	])
	some synonym in found
	contains(synonym, `"STG", another word for the staging deployment environment`)
	some local in found
	contains(local, `name the environment "development"`)
}

test_gha_51_environment_in_names if {
	steps := [{
		"name": "Use", "env": {
			"A": "${{ secrets.PROD_ORDERS_DATABASE_URL }}",
			"B": "${{ vars.API_BASE_URL_STAGING }}",
			"C": "${{ secrets.ORDERS_DATABASE_URL }}",
			"D": "${{ secrets.TEST_PYPI_TOKEN }}",
			"E": "${{ secrets.DEVCONTAINER_TOKEN }}",
			"F": "${{ secrets.PROD_ORDERS_DATABASE_URL }}",
		},
		"run": "cp config/secrets.production.yaml .",
	}]
	conditional := {"name": "Maybe", "if": "vars.PRODUCTION_ENABLED == 'true'", "run": "true"}
	dev_mode := {"name": "Dev", "env": {"ATLAS": "${{ vars.ATLAS_DEV_URL }}"}, "run": "true"}
	all_steps := array.concat(steps, [conditional, dev_mode])
	docs := [wf("deploy.yml", workflow("workflow_dispatch", {"a": job({"steps": all_steps})}))]
	results := checks.findings with input as docs with data.conventions.index as td.index
	found := messages(results, "GHA-51")
	count(found) == 3
	some prod in found
	prod == concat(" ", [
		"secrets.PROD_ORDERS_DATABASE_URL scopes a value to a deployment environment by its name (PROD); set it",
		"on that environment's GitHub environment as secrets.ORDERS_DATABASE_URL, the same name in each",
		"environment, and read it from a job with that environment:",
	])
	some staging in found
	contains(staging, "vars.API_BASE_URL_STAGING scopes")
	some production in found
	contains(production, "vars.PRODUCTION_ENABLED scopes")
}

app_token(given) := {"name": "Mint", "uses": "actions/create-github-app-token@x", "with": given}

test_gha_52_app_token_steps if {
	steps := [
		app_token({"client-id": "${{ vars.DEPLOY_APP_CLIENT_ID }}", "private-key": "${{ secrets.DEPLOY_APP_PRIVATE_KEY }}"}),
		app_token({"app-id": "${{ secrets.DEPLOY_APP_ID }}", "private-key": "${{ secrets.DEPLOY_KEY }}"}),
		app_token({"client-id": "${{ secrets.DEPLOY_APP_CLIENT_ID }}", "private-key": "${{ secrets.BOT_APP_PRIVATE_KEY }}"}),
		app_token({"client-id": "${{ vars.DEPLOY_APP_CLIENT_ID }}", "private-key": "${{ secrets.BOT_APP_PRIVATE_KEY }}"}),
	]
	docs := [wf("deploy.yml", workflow("workflow_dispatch", {"a": job({"steps": steps})}))]
	results := checks.findings with input as docs with data.conventions.index as td.index
	found := messages(results, "GHA-52")
	found == {
		concat(" ", [
			`step "Mint" in job "a" mints a GitHub App token with app-id, the older input; name the App with`,
			"client-id: ${{ vars.<PURPOSE>_APP_CLIENT_ID }} and sign with private-key:",
			"${{ secrets.<PURPOSE>_APP_PRIVATE_KEY }}, one purpose for both",
		]),
		concat(" ", [
			`step "Mint" in job "a" mints a GitHub App token with private-key ${{ secrets.DEPLOY_KEY }}; name the`,
			"App with client-id: ${{ vars.<PURPOSE>_APP_CLIENT_ID }} and sign with private-key:",
			"${{ secrets.<PURPOSE>_APP_PRIVATE_KEY }}, one purpose for both",
		]),
		concat(" ", [
			`step "Mint" in job "a" mints a GitHub App token with client-id ${{ secrets.DEPLOY_APP_CLIENT_ID }};`,
			"name the App with client-id: ${{ vars.<PURPOSE>_APP_CLIENT_ID }} and sign with private-key:",
			"${{ secrets.<PURPOSE>_APP_PRIVATE_KEY }}, one purpose for both",
		]),
		concat(" ", [
			`step "Mint" in job "a" mints a GitHub App token with a client ID for DEPLOY and a private key for BOT;`,
			"name the App with client-id: ${{ vars.<PURPOSE>_APP_CLIENT_ID }} and sign with private-key:",
			"${{ secrets.<PURPOSE>_APP_PRIVATE_KEY }}, one purpose for both",
		]),
	}
}

test_gha_52_release_token_steps_are_rel_16s if {
	steps := [app_token({"app-id": "${{ secrets.AUTOMATION_APP_ID }}"})]
	docs := [wf("release.yml", workflow("push", {"a": job({"steps": steps})}))]
	results := checks.findings with input as docs with data.conventions.index as td.index
	count(messages(results, "GHA-52")) == 0
}

test_gha_52_credential_references if {
	steps := [{
		"name": "Use", "env": {
			"A": "${{ secrets.BOT_APP_ID }}",
			"B": "${{ vars.BOT_APP_ID }}",
			"C": "${{ secrets.BOT_APP_CLIENT_ID }}",
			"D": "${{ vars.BOT_APP_PRIVATE_KEY }}",
			"E": "${{ vars.BOT_APP_CLIENT_ID }}",
			"F": "${{ secrets.BOT_APP_PRIVATE_KEY }}",
		},
		"run": "true",
	}]
	bot := {"client-id": "${{ vars.BOT_APP_CLIENT_ID }}", "private-key": "${{ secrets.BOT_APP_PRIVATE_KEY }}"}
	action := {"runs": {"steps": [app_token(bot)]}}
	docs := [
		wf("maintain.yml", workflow("workflow_dispatch", {"a": job({"steps": steps})})),
		td.file(".github/actions/authenticate-bot/action.yml", action),
	]
	results := checks.findings with input as docs with data.conventions.index as td.index
	found := messages(results, "GHA-52")
	count(found) == 4
	some secret_id in found
	startswith(secret_id, "secrets.BOT_APP_ID keeps an App ID as a secret")
	some key in found
	startswith(key, "vars.BOT_APP_PRIVATE_KEY keeps a private key in a variable")
}

record_step := {
	"name": "Record",
	"run": "gh api -X POST \"orgs/$OWNER/artifacts/metadata/deployment-record\" --input record.json",
}

deploy_job(extra) := job(object.union({"environment": "production"}, extra))

test_gha_53_deployment_records if {
	jobs := {
		"bare": deploy_job({"steps": [{"name": "Deploy", "run": "task deploy"}]}),
		"recorded": deploy_job({"permissions": {"artifact-metadata": "write"}, "steps": [record_step]}),
		"unpermitted": deploy_job({"permissions": {"contents": "read"}, "steps": [record_step]}),
		"inherited": deploy_job({"steps": [record_step]}),
		"through_action": deploy_job({"steps": [{"name": "Record", "uses": "./.github/actions/sync-deployment"}]}),
		"no_environment": job({"steps": [{"name": "Plan", "run": "task plan"}]}),
		"caller": {"name": "Call", "uses": "./.github/workflows/reusable-deploy-api.yml", "environment": "production"},
	}
	deploy := {"name": "W", "on": "workflow_dispatch", "permissions": {"artifact-metadata": "write"}, "jobs": jobs}
	action := {"runs": {"steps": [object.union(record_step, {"shell": "bash"})]}}
	docs := [
		wf("deploy-production-api.yml", deploy),
		td.file(".github/actions/sync-deployment/action.yml", action),
	]
	results := checks.findings with input as docs with data.conventions.index as td.index
	found := messages(results, "GHA-53")
	found == {concat(" ", [
		`job "unpermitted" posts a deployment record without artifact-metadata: write; grant it in the job's`,
		"permissions so the record is written",
	])}
	unrecorded := {
		"name": "W", "on": "workflow_dispatch",
		"jobs": {"bare": jobs.bare, "no_environment": jobs.no_environment},
	}
	results_bare := checks.findings with input as [wf("deploy-staging-api.yml", unrecorded)]
		with data.conventions.index as td.index
	messages(results_bare, "GHA-53") == {concat(" ", [
		`job "bare" deploys to the "production" environment but records no deployment; post the deployment`,
		"record (gh api -X POST orgs/<org>/artifacts/metadata/deployment-record with name, digest, version,",
		"status: deployed and logical_environment: production) so the organization's linked artifacts show",
		"what runs there",
	])}
	other := [wf("verify-production.yml", deploy)]
	results_other := checks.findings with input as other with data.conventions.index as td.index
	count(messages(results_other, "GHA-53")) == 0
}
