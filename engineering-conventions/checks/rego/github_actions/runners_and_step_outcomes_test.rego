package conventions.checks.github_actions.runners_and_step_outcomes_test

import data.conventions.checks.github_actions.runners_and_step_outcomes as checks
import data.conventions.lib.testdata_test as td

wf(name, contents) := td.file(concat("", [".github/workflows/", name]), contents)

messages(found, id) := {f.message | some f in found; f.id == id}

with_jobs(jobs) := object.union(td.validate, {"jobs": jobs})

job(extra) := object.union({"name": "Job", "runs-on": "ubuntu-24.04", "timeout-minutes": 5, "steps": []}, extra)

test_conforming_repository_has_no_findings if {
	docs := [
		wf("validate.yml", td.validate),
		wf("reusable-build.yml", td.reusable_build),
		td.inventory([".github/workflows/validate.yml"]),
	]
	results_1 := checks.findings with input as docs with data.conventions.index as td.index
	count(results_1) == 0
}

test_gha_39_moving_labels if {
	workflow := with_jobs({
		"plain": job({"runs-on": "ubuntu-latest"}),
		"mac": job({"runs-on": ["macos-latest"]}),
		"win": job({"runs-on": {"group": "big", "labels": "windows-latest"}}),
		"arm": job({"runs-on": "ubuntu-latest-arm"}),
		"matrix": job({
			"runs-on": "${{ matrix.os }}",
			"strategy": {"matrix": {
				"os": ["ubuntu-24.04", "ubuntu-latest", "${{ inputs.os }}"],
				"include": [{"os": "self-hosted-latest"}, "x"],
			}},
		}),
		"input": job({"runs-on": "${{ inputs.runner }}"}),
		"pinned": job({"runs-on": ["self-hosted", "linux"]}),
		"slim": job({"runs-on": "ubuntu-slim"}),
		"call": {"name": "Call", "uses": "org/repo/.github/workflows/x.yml@main"},
	})
	results_2 := checks.findings with input as [wf("validate.yml", workflow)] with data.conventions.index as td.index
	found := messages(results_2, "GHA-39")
	count(found) == 6
	some plain in found
	startswith(plain, `job "plain" runs on "ubuntu-latest", a label GitHub moves`)
	endswith(plain, "name the image it was proven on: ubuntu-24.04, or ubuntu-slim for a short job that runs no Docker")
	some mac in found
	endswith(mac, "a versioned macOS label such as macos-15")
	some win in found
	endswith(win, "a versioned Windows label such as windows-2025")
	some other in found
	startswith(other, `job "matrix" runs on "self-hosted-latest"`)
	endswith(other, "a versioned label")
}

test_gha_40_slim_timeout if {
	workflow := with_jobs({
		"none": object.remove(job({"runs-on": "ubuntu-slim"}), ["timeout-minutes"]),
		"long": job({"runs-on": "ubuntu-slim", "timeout-minutes": 30}),
		"short": job({"runs-on": "ubuntu-slim", "timeout-minutes": 15}),
		"expr": job({"runs-on": "ubuntu-slim", "timeout-minutes": "${{ inputs.t }}"}),
		"big": job({"runs-on": "ubuntu-24.04", "timeout-minutes": 60}),
	})
	results_3 := checks.findings with input as [wf("validate.yml", workflow)] with data.conventions.index as td.index
	found := messages(results_3, "GHA-40")
	found == {
		concat(" ", [
			`job "none" runs on ubuntu-slim but declares no timeout-minutes; GitHub stops an ubuntu-slim job`,
			"at 15 minutes, so set timeout-minutes: 15 or less, or run it on ubuntu-24.04",
		]),
		concat(" ", [
			`job "long" runs on ubuntu-slim but sets timeout-minutes: 30; GitHub stops an ubuntu-slim job`,
			"at 15 minutes, so set timeout-minutes: 15 or less, or run it on ubuntu-24.04",
		]),
	}
}

slim(extra) := job(object.union({"runs-on": "ubuntu-slim"}, extra))

test_gha_40_slim_docker if {
	workflow := with_jobs({
		"container": slim({"container": "node:22"}),
		"services": slim({"services": {"db": {"image": "postgres"}}}),
		"empty": slim({"services": {}, "container": null}),
		"action": slim({"steps": [{"name": "Buildx", "uses": "docker/setup-buildx-action@x"}]}),
		"image": slim({"steps": [{"name": "Image", "uses": "docker://alpine@sha256:x"}]}),
		"command": slim({"steps": [{"name": "Build", "run": "set -e\nmake && sudo docker build ."}]}),
		"path": slim({"steps": [{"name": "Read", "run": "cat build/docker/Dockerfile\n# docker build ."}]}),
	})
	results_4 := checks.findings with input as [wf("validate.yml", workflow)] with data.conventions.index as td.index
	found := messages(results_4, "GHA-40")
	found == {
		`job "container" runs on ubuntu-slim but declares container:, and that runner has no Docker; run it on ubuntu-24.04`,
		`job "services" runs on ubuntu-slim but declares services:, and that runner has no Docker; run it on ubuntu-24.04`,
		concat(" ", [
			`job "action" runs on ubuntu-slim but step "Buildx" runs Docker,`,
			"and that runner has no Docker; run it on ubuntu-24.04",
		]),
		concat(" ", [
			`job "image" runs on ubuntu-slim but step "Image" runs Docker,`,
			"and that runner has no Docker; run it on ubuntu-24.04",
		]),
		concat(" ", [
			`job "command" runs on ubuntu-slim but step "Build" runs Docker,`,
			"and that runner has no Docker; run it on ubuntu-24.04",
		]),
	}
}

test_gha_41_swallowed_exit_codes if {
	workflow := with_jobs({
		"a": job({"steps": [
			{"name": "True", "run": "task test || true"},
			{"name": "Colon", "run": "rm x || :"},
			{"name": "Subshell", "run": "v=$(grep a b || true)"},
			{"name": "Set", "run": "set +e\nmake"},
			{"name": "Then", "run": "if a; then set +e; fi"},
			{"name": "Fine", "run": "# a || true in a comment\nset -e\ntest -f x || exit 1\necho '||truthy'"},
			{"name": "Continue", "run": "x", "continue-on-error": true},
			{"name": "Quoted", "run": "x", "continue-on-error": "true"},
			{"name": "Expr", "run": "x", "continue-on-error": "${{ matrix.experimental }}"},
		]}),
		"b": job({"continue-on-error": true}),
	})
	action := {"runs": {"steps": [{"name": "Clean", "run": "rm -f x || true", "shell": "bash"}]}}
	docs := [wf("validate.yml", workflow), td.file(".github/actions/setup-x/action.yml", action)]
	results_5 := checks.findings with input as docs with data.conventions.index as td.index
	found := messages(results_5, "GHA-41")
	count(found) == 9
	some line in found
	startswith(line, `step "True" in job "a" swallows a failure: "task test || true"; let the command fail`)
	some step in found
	startswith(step, `step "Continue" in job "a" sets continue-on-error: true, so its failure turns green;`)
	some whole in found
	startswith(whole, `job "b" sets continue-on-error: true, so the run succeeds when the job fails;`)
	some in_action in found
	startswith(in_action, `step "Clean" in the action swallows a failure: "rm -f x || true"`)
}

test_gha_42_actions_cache if {
	workflow := with_jobs({"a": job({"steps": [
		{"name": "From", "uses": "docker/build-push-action@x", "with": {"cache-from": "type=gha"}},
		{"name": "To", "uses": "docker/build-push-action@x", "with": {"cache-to": "type=gha,mode=max"}},
		{"name": "Registry", "uses": "docker/build-push-action@x", "with": {"cache-to": "type=registry,ref=x"}},
		{"name": "Bake", "uses": "docker/bake-action@x", "with": {"set": "*.cache-to=type=gha,mode=max"}},
		{"name": "Cli", "run": "docker buildx build --cache-from type=gha ."},
	]})})
	results_6 := checks.findings with input as [wf("validate.yml", workflow)] with data.conventions.index as td.index
	found := messages(results_6, "GHA-42")
	count(found) == 4
	some to in found
	startswith(to, `step "To" in job "a" uses the type=gha build cache in its cache-to input;`)
	some bake in found
	contains(bake, "in its set input;")
	some cli in found
	contains(cli, "in its run: block;")
}

callee := {
	"name": "Reusable Deploy",
	"on": {"workflow_call": null},
	"permissions": {"contents": "read", "id-token": "write"},
	"jobs": {"deploy": {
		"name": "Deploy",
		"permissions": {"deployments": "write", "contents": "read"},
		"timeout-minutes": 5,
		"steps": [],
	}},
}

caller(workflow_permissions, job_permissions) := object.union(
	object.remove(td.validate, ["permissions", "jobs"]),
	{"permissions": workflow_permissions, "jobs": {"deploy": object.union(
		{"name": "Deploy", "uses": "./.github/workflows/reusable-deploy.yml"},
		job_permissions,
	)}},
)

gha_43_docs(workflow) := [wf("deploy.yml", workflow), wf("reusable-deploy.yml", callee)]

test_gha_43_caller_grants_what_the_callee_asks if {
	passing := [
		caller({}, {"permissions": {"contents": "read", "id-token": "write", "deployments": "write"}}),
		caller({}, {"permissions": "write-all"}),
		object.remove(caller({}, {}), ["permissions"]),
	]
	every workflow in passing {
		passed := checks.findings with input as gha_43_docs(workflow) with data.conventions.index as td.index
		count(messages(passed, "GHA-43")) == 0
	}
	narrow := checks.findings with input as gha_43_docs(caller({"contents": "read"}, {}))
		with data.conventions.index as td.index
	messages(narrow, "GHA-43") == {
		concat(" ", [
			`job "deploy" calls .github/workflows/reusable-deploy.yml, which asks for deployments: write,`,
			"but grants it deployments: none; GitHub refuses to start the run or the called job fails at",
			"its first API call, so grant deployments: write on the job",
		]),
		concat(" ", [
			`job "deploy" calls .github/workflows/reusable-deploy.yml, which asks for id-token: write,`,
			"but grants it id-token: none; GitHub refuses to start the run or the called job fails at",
			"its first API call, so grant id-token: write on the job",
		]),
	}
	read_all := checks.findings with input as gha_43_docs(caller({}, {"permissions": "read-all"}))
		with data.conventions.index as td.index
	count(messages(read_all, "GHA-43")) == 2
}

test_gha_43_shorthand_callee if {
	wide := object.union(callee, {"permissions": "read-all"})
	docs := [wf("deploy.yml", caller({}, {"permissions": {"contents": "read"}})), wf("reusable-deploy.yml", wide)]
	results_8 := checks.findings with input as docs with data.conventions.index as td.index
	found := messages(results_8, "GHA-43")
	some all_read in found
	contains(all_read, "which asks for read-all, but grants it no permissions;")
}

test_gha_43_remote_callee_is_not_judged if {
	remote := caller({}, {"uses": "org/repo/.github/workflows/reusable-deploy.yml@main"})
	results_9 := checks.findings with input as [wf("deploy.yml", remote)] with data.conventions.index as td.index
	count(messages(results_9, "GHA-43")) == 0
}

filter_step(given) := {"name": "Filter", "uses": "dorny/paths-filter@x", "with": given}

test_gha_44_paths_filter_base if {
	pushed := with_jobs({"detect": job({"steps": [
		filter_step({"filters": "api: [api/**]"}),
		filter_step({"filters": "x", "base": "main"}),
		filter_step({"base": " "}),
	]})})
	results_10 := checks.findings with input as [wf("validate.yml", pushed)] with data.conventions.index as td.index
	found := messages(results_10, "GHA-44")
	found == {concat(" ", [
		`step "Filter" in job "detect" runs dorny/paths-filter in a workflow triggered by push without a base`,
		"input; on push it diffs against the commit before the push, which a shallow checkout does not hold;",
		"set with: {base: ...} (for example the default branch)",
	])}
	pull := object.union(object.remove(pushed, ["true"]), {"on": "pull_request"})
	results_11 := checks.findings with input as [wf("validate.yml", pull)] with data.conventions.index as td.index
	count(messages(results_11, "GHA-44")) == 0
}

missing_directory := "which is not a directory in the repository; name one that exists"

test_gha_45_working_directory if {
	workflow := object.union(
		with_jobs({
			"a": job({
				"defaults": {"run": {"working-directory": "missing/job"}},
				"steps": [
					{"name": "Here", "run": "x", "working-directory": "./apps/api/"},
					{"name": "Gone", "run": "x", "working-directory": "apps/web"},
					{"name": "Root", "run": "x", "working-directory": "."},
					{"name": "Expr", "run": "x", "working-directory": "${{ inputs.dir }}"},
					{"name": "Var", "run": "x", "working-directory": "$RUNNER_TEMP"},
					{"name": "Abs", "run": "x", "working-directory": "/tmp"},
					{"name": "Up", "run": "x", "working-directory": "../x"},
				],
			}),
		}),
		{"defaults": {"run": {"working-directory": "apps"}}},
	)
	action := {"runs": {"steps": [{"name": "Nope", "run": "x", "working-directory": "tools"}]}}
	docs := [
		wf("validate.yml", workflow),
		td.file(".github/actions/setup-x/action.yml", action),
		td.inventory(["apps/api/package.json", ".github/workflows/validate.yml"]),
	]
	results_12 := checks.findings with input as docs with data.conventions.index as td.index
	found := messages(results_12, "GHA-45")
	found == {
		sprintf("%s %s", [`job "a" defaults.run sets working-directory "missing/job",`, missing_directory]),
		sprintf("%s %s", [`step "Gone" in job "a" sets working-directory "apps/web",`, missing_directory]),
		sprintf("%s %s", [`step "Nope" in the action sets working-directory "tools",`, missing_directory]),
	}
}

test_gha_45_checkout_into_a_subdirectory_is_not_judged if {
	checkout := object.union(td.pinned_checkout, {"with": {"path": "src", "persist-credentials": false}})
	workflow := with_jobs({"a": job({"steps": [checkout, {"name": "Gone", "run": "x", "working-directory": "src/app"}]})})
	results_13 := checks.findings with input as [wf("validate.yml", workflow)] with data.conventions.index as td.index
	count(messages(results_13, "GHA-45")) == 0
}
