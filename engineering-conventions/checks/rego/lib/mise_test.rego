package conventions.lib.mise_test

import data.conventions.lib.mise
import data.conventions.lib.testdata_test as td

config(contents) := td.file(".config/mise/config.toml", contents)

test_entries_read_every_value_shape if {
	docs := [config({"tools": {
		"node": "24.21.0",
		"aqua:astral-sh/uv": ["0.12.18", "0.11.0"],
		"core:python": {"version": "3.13.15", "os": ["linux"]},
		"aqua:jqlang/jq": {"os": ["linux"]},
	}})]
	pins := mise.pins with input as docs
	pins == {"node": {"24.21.0"}, "uv": {"0.12.18", "0.11.0"}, "python": {"3.13.15"}}
}

test_configs_ignore_other_toml if {
	docs := [td.file("pyproject.toml", {"tools": {"node": "1.0.0"}}), config({"tools": {}})]
	mise.configs == {".config/mise/config.toml": {"tools": {}}} with input as docs
	not mise.configured with input as [td.file("pyproject.toml", {})]
}

test_tool_name_normalises_backends if {
	mise.tool_name("node") == "node"
	mise.tool_name("core:node") == "node"
	mise.tool_name("aqua:nodejs/node") == "node"
	mise.tool_name("aqua:golang/go") == "go"
	mise.tool_name("aqua:go-task/task") == "task"
	mise.tool_name("ubi:go-task/task[exe=task]") == "task"
	mise.tool_name("npm:@scope/Name") == "name"
	mise.tool_name("pipx:yamllint") == "yamllint"
}

test_pin_text_and_matches if {
	docs := [config({"tools": {"node": ["22.0.0", "v20.0.0"]}})]
	mise.pin_text("node") == "20.0.0 or 22.0.0" with input as docs
	mise.matches_pin("node", "v22.0.0") with input as docs
	not mise.matches_pin("node", "22") with input as docs
}

test_min_version_forms if {
	mise.min_version({"min_version": "v2026.9.12"}) == "2026.9.12"
	mise.min_version({"min_version": {"hard": "2026.9.12", "soft": "2026.10.0"}}) == "2026.9.12"
	not mise.min_version({"min_version": {"soft": "2026.10.0"}})
	not mise.min_version({})
}

test_exact_versions if {
	every version in ["24.21.0", "v2026.9.12", "1.0.0-rc.1", "b3456", "0.12.18"] {
		mise.exact(version)
	}
}

test_floating_versions if {
	every version in [
		"latest", "LTS", "lts/iron", "stable", "", "24", "3.13", "v3",
		"^1.2.3", "~1.2", ">=1.0.0", "1.x", "1.2.*", "prefix:1.20", "ref:main", "path:/opt/x", "sub-1:latest",
	] {
		not mise.exact(version)
	}
	not mise.exact(3.13)
}

dockerfile(path, instructions) := td.file("/tmp/inventory.json", {"conventions_inventory": {
	"files": [path],
	"parsed": [{"path": path, "contents": instructions}],
}})

instruction(cmd, values, flags) := {"Cmd": cmd, "Flags": flags, "Value": values}

test_dockerfile_arguments_and_images if {
	instructions := [
		instruction("arg", ["NODE_VERSION=24.21.0", `UV_VERSION="0.12.18"`, "EMPTY"], []),
		instruction("arg", ["NODE_VERSION=22.0.0"], []),
		instruction("from", ["node:${NODE_VERSION}-slim", "AS", "build"], []),
		instruction("from", ["${UNSET}"], []),
		instruction("from", ["build"], []),
		instruction("copy", ["/uv", "/bin/"], ["--from=ghcr.io/astral-sh/uv:${UV_VERSION}"]),
		instruction("copy", ["/a", "/b"], ["--chown=1000"]),
		instruction("run", ["true"], []),
	]
	mise.arg_defaults(instructions) == [
		["NODE_VERSION", "24.21.0"],
		["UV_VERSION", "0.12.18"],
		["NODE_VERSION", "22.0.0"],
	]
	docs := [dockerfile("docker/build.Dockerfile", instructions)]
	mise.images == {
		{"path": "docker/build.Dockerfile", "reference": "node:24.21.0-slim"},
		{"path": "docker/build.Dockerfile", "reference": "build"},
		{"path": "docker/build.Dockerfile", "reference": "ghcr.io/astral-sh/uv:0.12.18"},
	} with input as docs
}

test_dockerfiles_by_name if {
	docs := [
		dockerfile("Containerfile", []),
		dockerfile("README.md", []),
	]
	object.keys(mise.dockerfiles) == {"Containerfile"} with input as docs
}

test_image_references if {
	mise.image("node:24.21.0-slim") == {"name": "node", "tag": "24.21.0-slim", "digest": ""}
	mise.image("docker.io/library/python:3.13.15@sha256:ab") == {"name": "python", "tag": "3.13.15", "digest": "sha256:ab"}
	mise.image("localhost:5000/node") == {"name": "localhost:5000/node", "tag": "", "digest": ""}
	mise.image("oven/bun@sha256:ab") == {"name": "oven/bun", "tag": "", "digest": "sha256:ab"}
}

test_tag_versions if {
	mise.tag_version("24.21.0-slim") == "24.21.0"
	mise.tag_version("alpine-2.5.0") == "2.5.0"
	mise.tag_version("v1.3.14") == "1.3.14"
	mise.tag_version("24") == "24"
	not mise.tag_version("latest")
	not mise.tag_version("python3.13-bookworm")
}

test_features if {
	docs := [td.file("/tmp/inventory.json", {"conventions_inventory": {
		"files": [".devcontainer/devcontainer.json"],
		"parsed": [{"path": ".devcontainer/devcontainer.json", "contents": {"features": {
			"ghcr.io/devcontainers/features/node:1": {"version": "24.21.0"},
			"ghcr.io/devcontainers/features/python@sha256:0a": "3.13.15",
			"ghcr.io/devcontainers-extra/features/uv:1": {},
			"ghcr.io/devcontainers/features/git:1": {},
		}}}],
	}})]
	found := mise.features with input as docs
	found == {
		{
			"path": ".devcontainer/devcontainer.json", "reference": "ghcr.io/devcontainers/features/node:1",
			"tool": "node", "version": "24.21.0",
		},
		{
			"path": ".devcontainer/devcontainer.json", "reference": "ghcr.io/devcontainers/features/python@sha256:0a",
			"tool": "python", "version": "3.13.15",
		},
		{
			"path": ".devcontainer/devcontainer.json", "reference": "ghcr.io/devcontainers-extra/features/uv:1",
			"tool": "uv", "version": null,
		},
	}
}

test_package_manager if {
	mise.package_manager({"packageManager": "bun@1.3.14+sha512.abc"}) == {"tool": "bun", "version": "1.3.14"}
	mise.package_manager({"packageManager": "pnpm@9.0.0"}) == {"tool": "pnpm", "version": "9.0.0"}
	not mise.package_manager({"name": "x"})
}

test_input_text if {
	mise.input_text("1.2.3") == "1.2.3"
	mise.input_text(24) == "24"
	mise.input_text(1.25) == "1.25"
	mise.expression("${{ inputs.version }}")
}

test_setup_steps if {
	workflow := {"on": "push", "jobs": {"build": {"steps": [
		{"uses": "actions/setup-node@0a1b", "with": {"node-version": "24.21.0"}},
		{"uses": "actions/checkout@0a1b"},
		{"run": "true"},
	]}}}
	steps := mise.setup_steps with input as [td.file(".github/workflows/build.yml", workflow)]
	{[s.action, s.label] | some s in steps} == {["actions/setup-node", "step 1"]}
}

test_file_version if {
	mise.file_version("# pinned\n\nv24.21.0\n") == "v24.21.0"
	not mise.file_version("\n")
}
