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

mise_setup := {"name": "Install the pinned tools", "uses": "jdx/mise-action@2d8d4cafcbd33be2ea37d2b6f5ad595363d1f1ca"}

with_jobs(jobs) := object.union(td.validate, {"jobs": jobs})

job(extra) := object.union({"name": "Job", "runs-on": "ubuntu-24.04", "timeout-minutes": 5, "steps": []}, extra)

gha_55_docs(workflow, extra) := array.concat([wf("validate.yml", workflow)], extra)

gha_55_message(step, job_id, line) := sprintf(
	concat(" ", [
		"step %q in job %q runs %q after jdx/mise-action, which keeps its GitHub token to its own step,",
		"so what mise installs here goes to the GitHub API unauthenticated and fails once the runner's",
		"shared 60-call hourly limit is spent; set env: {MISE_GITHUB_TOKEN: ${{ github.token }}} on the",
		"step or the job",
	]),
	[step, job_id, line],
)

test_gha_55_installs_after_mise_action if {
	workflow := with_jobs({"check": job({"steps": [
		mise_setup,
		{"name": "Install", "run": "mise install"},
		{"name": "Exec", "run": "mise exec jq@1.8.2 -- jq --version"},
		{"name": "Short", "run": "cd site && mise x -- node build.js"},
		{"name": "Use", "run": "mise use -g aqua:jqlang/jq@1.8.2"},
		{"name": "Conventions", "run": "conventions check --fail-on warning"},
		{"name": "Bundled", "run": "./engineering-conventions/bin/conventions hadolint"},
	]})})
	found_1 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(workflow, [])
		with data.conventions.index as td.index
	found_1 == {
		gha_55_message("Install", "check", "mise install"),
		gha_55_message("Exec", "check", "mise exec jq@1.8.2 -- jq --version"),
		gha_55_message("Short", "check", "cd site && mise x -- node build.js"),
		gha_55_message("Use", "check", "mise use -g aqua:jqlang/jq@1.8.2"),
		gha_55_message("Conventions", "check", "conventions check --fail-on warning"),
		gha_55_message("Bundled", "check", "./engineering-conventions/bin/conventions hadolint"),
	}
}

test_gha_55_token_at_step_job_or_workflow_level if {
	token := {"MISE_GITHUB_TOKEN": "${{ github.token }}"}
	step_level := with_jobs({"check": job({"steps": [
		mise_setup,
		{"name": "Install", "env": token, "run": "mise install"},
	]})})
	found_2 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(step_level, [])
		with data.conventions.index as td.index
	count(found_2) == 0
	job_level := with_jobs({"check": job({"env": token, "steps": [
		mise_setup,
		{"name": "Install", "run": "mise install"},
	]})})
	found_3 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(job_level, [])
		with data.conventions.index as td.index
	count(found_3) == 0
	workflow_level := object.union(
		with_jobs({"check": job({"steps": [mise_setup, {"name": "Install", "run": "mise install"}]})}),
		{"env": token},
	)
	found_4 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(workflow_level, [])
		with data.conventions.index as td.index
	count(found_4) == 0
}

test_gha_55_other_token_variables_and_exports if {
	github_token := with_jobs({"check": job({"steps": [
		mise_setup,
		{"name": "Install", "env": {"GITHUB_TOKEN": "${{ github.token }}"}, "run": "mise install"},
	]})})
	found_5 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(github_token, [])
		with data.conventions.index as td.index
	count(found_5) == 0
	expression := with_jobs({"check": job({"env": "${{ fromJSON(inputs.env) }}", "steps": [
		mise_setup,
		{"name": "Install", "run": "mise install"},
	]})})
	found_6 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(expression, [])
		with data.conventions.index as td.index
	count(found_6) == 0
	exported := with_jobs({"check": job({"steps": [
		{"name": "Export", "env": {"T": "${{ github.token }}"}, "run": `echo "MISE_GITHUB_TOKEN=$T" >> "$GITHUB_ENV"`},
		mise_setup,
		{"name": "Install", "run": "mise install"},
	]})})
	found_7 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(exported, [])
		with data.conventions.index as td.index
	count(found_7) == 0
}

test_gha_55_no_mise_action_or_step_before_it if {
	no_action := with_jobs({"check": job({"steps": [
		{"name": "Install", "run": "mise install"},
		{"name": "Conventions", "run": "conventions check"},
	]})})
	found_8 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(no_action, [])
		with data.conventions.index as td.index
	count(found_8) == 0
	before := with_jobs({"check": job({"steps": [
		{"name": "Install", "run": "mise install"},
		mise_setup,
		{"name": "Lint", "run": "task lint"},
	]})})
	found_9 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(before, [])
		with data.conventions.index as td.index
	count(found_9) == 0
	other_job := with_jobs({
		"setup": job({"steps": [mise_setup]}),
		"check": job({"steps": [{"name": "Install", "run": "mise install"}]}),
	})
	found_10 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(other_job, [])
		with data.conventions.index as td.index
	count(found_10) == 0
}

test_gha_55_commands_that_install_nothing if {
	workflow := with_jobs({"check": job({"steps": [
		mise_setup,
		{"name": "Version", "run": "conventions version"},
		{"name": "List", "run": "mise ls --current"},
		{"name": "Lock", "run": "mise lock"},
		{"name": "Print", "run": "echo 'run mise install to fix this'"},
		{"name": "Comment", "run": "# mise install happened above\ntask lint"},
		{"name": "Word", "run": "./scripts/promise exec"},
		{"name": "Action", "uses": "actions/upload-artifact@v4"},
	]})})
	found_11 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(workflow, [])
		with data.conventions.index as td.index
	count(found_11) == 0
}

test_gha_55_through_a_task if {
	taskfile := td.file("Taskfile.yml", {"version": "3", "tasks": {
		"conventions": {"cmds": [{"task": "conventions:check"}]},
		"conventions:check": {"cmds": ["conventions check --fail-on warning"]},
		"lint": {"cmds": ["markdownlint-cli2 '**/*.md'"]},
	}})
	workflow := with_jobs({"check": job({"steps": [
		mise_setup,
		{"name": "Conventions", "run": "task conventions"},
		{"name": "Lint", "run": "task lint"},
	]})})
	found_12 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(workflow, [taskfile])
		with data.conventions.index as td.index
	found_12 == {gha_55_message("Conventions", "check", "task conventions")}
}

test_gha_55_through_a_local_action if {
	setup := {"name": "Setup Tools", "description": "x", "runs": {"using": "composite", "steps": [mise_setup]}}
	workflow := with_jobs({"check": job({"steps": [
		{"uses": "./.github/actions/setup-tools"},
		{"name": "Install", "run": "mise install"},
	]})})
	plain := td.file(".github/actions/setup-tools/action.yml", setup)
	found_13 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(workflow, [plain])
		with data.conventions.index as td.index
	found_13 == {gha_55_message("Install", "check", "mise install")}

	# The action exports the token to every later step.
	exporting := {"name": "Setup Tools", "description": "x", "runs": {"using": "composite", "steps": [
		mise_setup,
		{"name": "Export", "shell": "bash", "run": `echo "MISE_GITHUB_TOKEN=${{ github.token }}" >> "$GITHUB_ENV"`},
	]}}
	exports := td.file(".github/actions/setup-tools/action.yml", exporting)
	found_14 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(workflow, [exports])
		with data.conventions.index as td.index
	count(found_14) == 0

	# An action in another repository is not read.
	remote := with_jobs({"check": job({"steps": [
		{"uses": "org/setup-tools@v1"},
		{"name": "Install", "run": "mise install"},
	]})})
	found_15 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(remote, [])
		with data.conventions.index as td.index
	count(found_15) == 0
}

test_gha_55_one_finding_per_step if {
	workflow := with_jobs({"check": job({"steps": [
		mise_setup,
		{"name": "Both", "run": "mise install\nmise exec -- jq ."},
	]})})
	found_16 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(workflow, [])
		with data.conventions.index as td.index
	found_16 == {gha_55_message("Both", "check", "mise install")}
}

test_gha_55_task_names_match_whole if {
	root := td.file("Taskfile.yml", {
		"version": "3", "includes": {
			"cli": "taskfiles/cli.yml",
			"tools": {"taskfile": "taskfiles/tools.yml", "flatten": true},
		},
		"tasks": {"lint": {"cmds": ["mise exec -- markdownlint-cli2"]}},
	})
	cli := td.file("taskfiles/cli.yml", {"version": "3", "tasks": {
		"lint": {"cmds": ["ruff check"]},
		"sync": {"cmds": [{"task": "install"}]},
		"install": {"cmds": ["mise install"]},
	}})
	tools := td.file("taskfiles/tools.yml", {"version": "3", "tasks": {"tools:check": {"cmds": ["actionlint"]}}})
	workflow := with_jobs({"check": job({"steps": [
		mise_setup,
		{"name": "Lint", "run": "task cli:lint tools:check"},
		{"name": "Sync", "run": "task cli:sync"},
	]})})
	found_17 := messages(execution_hygiene.findings, "GHA-55") with input as gha_55_docs(workflow, [root, cli, tools])
		with data.conventions.index as td.index
	found_17 == {gha_55_message("Sync", "check", "task cli:sync")}
}
