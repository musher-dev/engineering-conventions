# METADATA
# title: Shared test data
# description: >-
#   A minimal index in the shape of checks/data/index.json and builders for
#   the combined input, shared by every package's tests.
package conventions.lib.testdata_test

now := "2026-09-23T00:00:00Z"

requirement_ids := [
	"ADOPT-01", "ADOPT-02", "ADOPT-03", "ADOPT-04", "ADOPT-05", "ADOPT-06", "ADOPT-07", "ADOPT-08",
	"GHA-01", "GHA-02", "GHA-03", "GHA-04", "GHA-05", "GHA-06", "GHA-07", "GHA-08", "GHA-09",
	"GHA-10", "GHA-11", "GHA-12", "GHA-13", "GHA-14", "GHA-15", "GHA-16", "GHA-17",
	"GHA-20", "GHA-21", "GHA-22", "GHA-23",
	"GHA-24", "GHA-25", "GHA-26", "GHA-27", "GHA-28", "GHA-29", "GHA-30", "GHA-31", "GHA-32", "GHA-38",
]

index := {
	"schema_version": 1,
	"repository": "https://github.com/musher-dev/engineering-conventions",
	"product_dir": "engineering-conventions",
	"conventions": {"EC-0002": {"title": "Workflow files", "path": "conventions/github-actions/workflow-files.md"}},
	"requirements": object.union(
		{id: {
			"convention": "EC-0002",
			"status": "proposed",
			"severity": "warning",
			"path": "conventions/github-actions/workflow-files.md",
			"anchor": lower(id),
			"aliases": aliases(id),
			"waivable": waivable(id),
		} |
			some id in requirement_ids
		},
		{"GHA-99": {
			"convention": "EC-0002",
			"status": "retired",
			"severity": "warning",
			"path": "conventions/github-actions/workflow-files.md",
			"anchor": "gha-99",
			"waivable": true,
		}},
	),
	"profiles": {
		"base-repo": {"display_name": "Base", "requirements": requirement_ids, "severity": {}},
		"strict": {
			"display_name": "Strict",
			"requirements": requirement_ids,
			"severity": {id: "error" | some id in requirement_ids},
		},
		"narrow": {"display_name": "Narrow", "requirements": ["GHA-07"], "severity": {"GHA-07": "warning"}},
	},
	"vocabulary": {
		"responsibility_tokens": [
			"audit", "deploy", "maintain", "monitor", "publish",
			"release", "repository", "validate", "verify",
		],
		"capability_tokens": ["build", "check", "promote"],
		"action_tokens": ["authenticate", "check", "install", "setup"],
		"banned_identifier_tokens": {
			"ci": "validate", "cd": "deploy", "lint": "validate", "pr": "validate",
			"drift": "monitor", "scheduled": "audit, monitor or maintain",
			"nightly": "audit, monitor or maintain",
		},
		"schedule_tokens": ["nightly", "scheduled"],
		"display_forms": {"api": "API", "pr": "PR", "devcontainer": "Dev Container"},
	},
}

default waivable(_) := true

waivable(id) := false if startswith(id, "ADOPT-")

default aliases(_) := []

aliases("GHA-01") := ["platform:CI-14"]

aliases("GHA-02") := ["platform:CI-14"]

aliases("GHA-07") := ["platform:CI-15"]

file(path, contents) := {"path": path, "contents": contents}

inventory(paths) := file("/tmp/inventory.json", {"conventions_inventory": {"files": paths}})

declaration(contents) := file(".repo/conventions.yaml", contents)

pinned_checkout := {
	"name": "Check out the repository",
	"uses": "actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8",
	"with": {"persist-credentials": false},
}

standard_concurrency := {"group": "${{ github.workflow }}-${{ github.ref }}"}

# A conforming entry-point workflow with an aggregate.
validate := {
	"name": "Validate",
	"true": {"pull_request": null, "push": {"branches": ["main"]}},
	"permissions": {"contents": "read"},
	"concurrency": standard_concurrency,
	"jobs": {
		"lint": {
			"name": "Lint",
			"runs-on": "ubuntu-latest",
			"timeout-minutes": 10,
			"steps": [pinned_checkout, {"name": "Lint", "run": "task lint"}],
		},
		"required": {
			"name": "Validate / Required",
			"if": "${{ always() }}",
			"needs": ["lint"],
			"runs-on": "ubuntu-latest",
			"timeout-minutes": 5,
			"steps": [{"name": "Fail unless every job succeeded", "run": "true"}],
		},
	},
}

reusable_build := {
	"name": "Reusable Build",
	"on": {"workflow_call": null},
	"permissions": {},
	"jobs": {"build": {"name": "Build", "timeout-minutes": 5, "steps": [{"name": "Build", "run": "make"}]}},
}

ruleset(contexts) := {"rules": [
	{"type": "pull_request"},
	{
		"type": "required_status_checks",
		"parameters": {"required_status_checks": [{"context": context} | some context in contexts]},
	},
]}

pairs(findings) := {[f.id, f.path] | some f in findings}

ids(findings) := {f.id | some f in findings}
