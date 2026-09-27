# METADATA
# title: Shared test data
# description: >-
#   A minimal index in the shape of checks/data/index.json and builders for
#   the combined input, shared by every package's tests.
package conventions.lib.testdata_test

now := "2026-09-23T00:00:00Z"

requirement_ids := [
	"ADOPT-02", "ADOPT-03", "ADOPT-04", "ADOPT-05", "ADOPT-06", "ADOPT-07", "ADOPT-08", "ADOPT-09",
	"GHA-01", "GHA-02", "GHA-03", "GHA-04", "GHA-05", "GHA-06", "GHA-07", "GHA-08", "GHA-09",
	"GHA-10", "GHA-11", "GHA-12", "GHA-13", "GHA-14", "GHA-15", "GHA-16", "GHA-17",
	"GHA-20", "GHA-21", "GHA-22", "GHA-23",
	"GHA-24", "GHA-26", "GHA-27", "GHA-28", "GHA-29", "GHA-30", "GHA-31", "GHA-32", "GHA-38",
	"OUT-01", "OUT-02", "OUT-03", "OUT-04", "OUT-05", "OUT-06", "OUT-07",
]

# In the index but outside base-repo here, so the tests of the other
# families need not declare an identity; the service profile selects them.
repo_requirement_ids := [
	"REPO-01", "REPO-02", "REPO-03", "REPO-04",
	"REPO-07", "REPO-08", "REPO-09", "REPO-10", "REPO-11",
]

index := {
	"schema_version": 1,
	"repository": "https://github.com/musher-dev/engineering-conventions",
	"product_dir": "engineering-conventions",
	"conventions": {"EC-0002": {
		"title": "Workflow files",
		"path": "definitions/conventions/github-actions/workflow-files.md",
	}},
	"requirements": object.union(
		{id: {
			"convention": "EC-0002",
			"status": "proposed",
			"severity": "warning",
			"path": "definitions/conventions/github-actions/workflow-files.md",
			"anchor": lower(id),
			"aliases": aliases(id),
			"waivable": waivable(id),
		} |
			some id in array.concat(requirement_ids, repo_requirement_ids)
		},
		{"GHA-99": {
			"convention": "EC-0002",
			"status": "retired",
			"severity": "warning",
			"path": "definitions/conventions/github-actions/workflow-files.md",
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
		"service": {
			"display_name": "Service",
			"requirements": array.concat(requirement_ids, repo_requirement_ids),
			"severity": {},
		},
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
		"output_kinds": ["bundle", "cli", "contract", "image", "library"],
		"repository_systems": ["engineering", "platform", "sdk"],
		"repository_kinds": ["library", "service", "specification"],
		"repository_lifecycles": ["deprecated", "experimental", "production"],
		"repository_audiences": ["internal", "public"],
		"banned_repository_tokens": {
			"musher": "The organization already says it; drop the token.",
			"utils": "Says nothing about what it holds; name what it holds.",
		},
	},
	"declaration_schema": declaration_schema,
	"outputs_schema": outputs_schema,
	"repository_schema": repository_schema,
}

# A cut-down declaration schema with the shapes ADOPT-02's messages depend on:
# an unknown key, a wrong type, a waiver of an ADOPT requirement, and an
# expires date that is not YYYY-MM-DD (which fails two keywords).
declaration_schema := {
	"type": "object",
	"additionalProperties": false,
	"required": ["schema_version"],
	"properties": {
		"schema_version": {"const": 1},
		"conventions": {"type": "object", "properties": {"version": {"type": "string"}}},
		"profile": {"type": "string"},
		"vocabulary": {"type": "object"},
		"waivers": {"type": "array", "items": {
			"type": "object",
			"properties": {
				"requirement": {"type": "string", "not": {"pattern": "^ADOPT-"}},
				"expires": {"type": "string", "format": "date", "pattern": `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`},
			},
		}},
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

# The inventory of a repository whose actual name the runner knows (EC-0010).
named_inventory(paths, name) := file(
	"/tmp/inventory.json",
	{"conventions_inventory": {"files": paths, "repository": {"name": name}}},
)

# schema_version is filled in so a test states only what it is about.
declaration(contents) := file(".repo/conventions.toml", object.union({"schema_version": 1}, contents))

# schema_version is filled in so a test states only what it is about.
repository(contents) := file(".repo/repository.toml", object.union({"schema_version": 1}, contents))

# A conforming identity declaration (EC-0009).
identity := {
	"name": "platform-api",
	"system": "platform",
	"component": "api",
	"kind": "service",
	"owner": "@musher-dev/platform",
	"lifecycle": "production",
	"audience": "internal",
	"tier": 1,
}

# The mise entry that pins the release (ADOPT-09).
pin := file("mise.toml", {"tools": {"github:musher-dev/engineering-conventions": "0.2.0"}})

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

# A cut-down outputs schema with the shapes OUT-02's messages depend on: a
# missing required key and an unknown key.
outputs_schema := {
	"type": "object",
	"additionalProperties": false,
	"required": ["schema_version", "outputs"],
	"properties": {
		"schema_version": {"const": 1},
		"outputs": {"type": "array", "items": {
			"type": "object",
			"additionalProperties": false,
			"required": ["id", "kind"],
			"properties": {
				"id": {"type": "string"},
				"kind": {"type": "string"},
				"source": {"type": "string"},
				"publish_workflow": {"type": "string"},
				"location": {"type": "string"},
				"docs": {"type": "string"},
				"format": {"type": "string"},
				"definition": {"type": "string"},
			},
		}},
	},
}

# schema_version is filled in so a test states only what it is about.
outputs(entries) := file(".repo/outputs.toml", {"schema_version": 1, "outputs": entries})

# A conforming image output published by publish.yml.
image_output := {
	"id": "api-image",
	"kind": "image",
	"source": "api",
	"publish_workflow": "publish.yml",
	"location": "ghcr.io/example/api",
	"docs": "api/README.md#run",
}

# A cut-down identity schema with the shapes REPO-02's messages depend on: a
# missing required key, an unknown key and a value out of range.
repository_schema := {
	"type": "object",
	"additionalProperties": false,
	"required": ["schema_version", "name", "owner", "tier"],
	"properties": {
		"schema_version": {"const": 1},
		"name": {"type": "string"},
		"system": {"type": "string"},
		"component": {"type": "string"},
		"kind": {"type": "string"},
		"owner": {"type": "string", "pattern": "^@musher-dev/[a-z0-9-]+$"},
		"lifecycle": {"type": "string"},
		"audience": {"type": "string"},
		"tier": {"type": "integer", "minimum": 1, "maximum": 3},
	},
}
