package conventions.checks.toolchain.tool_pins_test

import data.conventions.checks.toolchain.tool_pins
import data.conventions.lib.testdata_test as td

tools := {
	"node": "24.21.0",
	"python": "3.13.15",
	"aqua:astral-sh/uv": "0.12.18",
	"aqua:oven-sh/bun": "1.3.14",
	"aqua:go-task/task": "3.53.1",
}

config := td.file(".config/mise/config.toml", {"min_version": "2026.9.12", "tools": tools})

default_paths := [".config/mise/config.toml", ".config/mise/mise.lock"]

# A repository: the mise configuration, the inventory, and whatever the case
# adds, pre-parsed files and texts included.
repo(docs, paths, parsed, texts) := array.concat(
	[config, td.file("/tmp/inventory.json", {"conventions_inventory": {
		"files": array.concat(default_paths, paths),
		"parsed": parsed,
		"texts": texts,
	}})],
	docs,
)

# A mise configuration with the given tools and the lockfile beside it.
configured(contents) := [td.file(".config/mise/config.toml", contents), td.inventory(default_paths)]

messages(found, id) := {f.message | some f in found; f.id == id}

floating_message(key, version) := sprintf(
	"[tools] pins %q to %q, which resolves to a different release over time; pin one exact version, such as \"1.2.3\"",
	[key, version],
)

test_a_conforming_repository if {
	found := tool_pins.findings with input as repo([], [], [], {})
	count(found) == 0
}

test_no_mise_configuration_is_quiet if {
	found := tool_pins.findings with input as [td.inventory(["README.md"])]
	count(found) == 0
}

# TOOL-01
test_tool_01_other_locations if {
	paths := [
		"mise.toml", ".mise.toml", "mise.local.toml", "mise.ci.toml", ".config/mise.toml",
		"mise/config.toml", ".mise/conf.d/extra.toml", ".config/mise/conf.d/extra.toml",
		".devcontainer/mise.toml", "api/mise.toml",
	]
	found := tool_pins.findings with input as repo([], paths, [], {})
	td.pairs(found) == {["TOOL-01", path] | some path in paths}
}

test_tool_01_message if {
	found := tool_pins.findings with input as repo([], ["mise.toml"], [], {})
	messages(found, "TOOL-01") == {concat(" ", [
		"mise.toml is a mise configuration outside .config/mise/config.toml; move its settings and [tools]",
		"there and delete it, so one file pins every tool",
	])}
}

test_tool_01_ignores_lookalikes if {
	paths := ["docs/mise.md", ".config/mise/locks/x/pyproject.toml", "promise.toml"]
	found := tool_pins.findings with input as repo([], paths, [], {})
	count(found) == 0
}

# TOOL-02
test_tool_02_unqualified_backend if {
	docs := configured({"min_version": "2026.9.12", "tools": {"uv": "0.12.18", "node": "24.21.0"}})
	found := tool_pins.findings with input as docs
	messages(found, "TOOL-02") == {concat(" ", [
		`[tools] names "uv" without a backend, so mise's registry decides what it installs;`,
		`name the backend, such as "aqua:<owner>/<repo>"`,
	])}
}

# TOOL-03
test_tool_03_floating_versions if {
	docs := configured({"min_version": "2026.9.12", "tools": {
		"node": "lts",
		"python": ["3.13.15", "3.12"],
		"aqua:astral-sh/uv": {"version": "latest"},
	}})
	found := tool_pins.findings with input as docs
	messages(found, "TOOL-03") == {
		floating_message("node", "lts"),
		floating_message("python", "3.12"),
		floating_message("aqua:astral-sh/uv", "latest"),
	}
}

# TOOL-04
test_tool_04_no_min_version if {
	found := tool_pins.findings with input as configured({"tools": tools})
	td.pairs(found) == {["TOOL-04", ".config/mise/config.toml"]}
}

test_tool_04_soft_minimum_only if {
	found := tool_pins.findings with input as configured({"min_version": {"soft": "2026.9.12"}, "tools": tools})
	td.pairs(found) == {["TOOL-04", ".config/mise/config.toml"]}
}

mise_action(fields) := td.file(".github/workflows/validate.yml", {"on": "push", "jobs": {"lint": {"steps": [
	object.union({"name": "Install tools", "uses": "jdx/mise-action@0a1b2c"}, fields),
]}}})

test_tool_04_mise_action_version if {
	found := tool_pins.findings with input as repo([mise_action({"with": {"version": "v2026.9.1"}})], [], [], {})
	messages(found, "TOOL-04") == {concat(" ", [
		`step "Install tools" installs mise v2026.9.1 but the mise configuration's min_version is 2026.9.12;`,
		"set version: to 2026.9.12",
	])}
}

test_tool_04_mise_action_without_version if {
	found := tool_pins.findings with input as repo([mise_action({})], [], [], {})
	messages(found, "TOOL-04") == {concat(" ", [
		`step "Install tools" runs jdx/mise-action without a version, so it installs the latest mise;`,
		"set version: 2026.9.12, the min_version",
	])}
}

test_tool_04_mise_action_agrees if {
	pinned := tool_pins.findings with input as repo([mise_action({"with": {"version": "v2026.9.12"}})], [], [], {})
	count(pinned) == 0
	expression := tool_pins.findings with input as repo(
		[mise_action({"with": {"version": "${{ inputs.mise }}"}})],
		[], [], {},
	)
	count(expression) == 0
}

dockerfile(instructions) := {"path": ".devcontainer/Dockerfile", "contents": instructions}

arg(value) := {"Cmd": "arg", "Flags": [], "Value": [value]}

from(image) := {"Cmd": "from", "Flags": [], "Value": [image]}

test_tool_04_dockerfile_mise_version if {
	older := tool_pins.findings with input as repo([], [], [dockerfile([arg("MISE_VERSION=v2026.1.0")])], {})
	td.pairs(older) == {["TOOL-04", ".devcontainer/Dockerfile"]}
	same := tool_pins.findings with input as repo([], [], [dockerfile([arg("MISE_VERSION=v2026.9.12")])], {})
	count(same) == 0
}

# TOOL-05
test_tool_05_no_lockfile if {
	found := tool_pins.findings with input as [config, td.inventory([".config/mise/config.toml"])]
	messages(found, "TOOL-05") == {concat(" ", [
		"no .config/mise/mise.lock beside the mise configuration, so each install resolves download URLs",
		"and checksums afresh; run `mise lock` and commit it",
	])}
}

test_tool_05_lockfile_beside_a_root_config if {
	docs := [td.file("mise.toml", {"min_version": "2026.9.12", "tools": {}}), td.inventory(["mise.toml", "mise.lock"])]
	found := tool_pins.findings with input as docs
	td.pairs(found) == {["TOOL-01", "mise.toml"]}
}

# TOOL-06
test_tool_06_floating_arguments if {
	instructions := [
		arg("NODE_VERSION=24"), arg("UV_VERSION=latest"), arg("TASK_VERSION"),
		arg("BUN_VERSION=${NODE_VERSION}"), arg("GO_VERSION=1.25.1"), arg("DEBIAN_FRONTEND=noninteractive"),
	]
	found := tool_pins.findings with input as repo([], [], [dockerfile(instructions)], {})
	messages(found, "TOOL-06") == {
		`ARG NODE_VERSION defaults to "24", which is not one release; set an exact version, such as NODE_VERSION=1.2.3`,
		`ARG UV_VERSION defaults to "latest", which is not one release; set an exact version, such as UV_VERSION=1.2.3`,
	}
}

test_tool_06_without_mise if {
	docs := [td.file("/tmp/inventory.json", {"conventions_inventory": {
		"files": ["Dockerfile"],
		"parsed": [{"path": "Dockerfile", "contents": [arg("TOOL_VERSION=stable")]}],
	}})]
	found := tool_pins.findings with input as docs
	td.pairs(found) == {["TOOL-06", "Dockerfile"]}
}

# TOOL-07
test_tool_07_runtime_images if {
	instructions := [
		arg("NODE_VERSION=24.20.0"),
		from("node:${NODE_VERSION}-slim"),
		from("docker.io/library/python:3.12.1-slim@sha256:ab"),
		from("golang"),
		from("oven/bun:latest"),
		from("ghcr.io/astral-sh/uv:0.12.18"),
		from("denoland/deno:alpine-2.5.0"),
		from("node@sha256:ab"),
		from("rust:1.90.0"),
		from("ubuntu:24.04"),
	]
	found := tool_pins.findings with input as repo([], [], [dockerfile(instructions)], {})
	messages(found, "TOOL-07") == {
		"node:24.20.0-slim runs node 24.20.0 but mise pins 24.21.0; use the 24.21.0 tag of node",
		concat(" ", [
			"docker.io/library/python:3.12.1-slim@sha256:ab runs python 3.12.1 but mise pins 3.13.15;",
			"use the 3.13.15 tag of python",
		]),
		"oven/bun:latest names no bun version, so it moves with the registry while mise pins 1.3.14; tag it with 1.3.14",
	}
}

test_tool_07_copy_from if {
	copy := {"Cmd": "copy", "Flags": ["--from=ghcr.io/astral-sh/uv:0.11.0"], "Value": ["/uv", "/bin/"]}
	found := tool_pins.findings with input as repo([], [], [dockerfile([copy])], {})
	td.pairs(found) == {["TOOL-07", ".devcontainer/Dockerfile"]}
}

# TOOL-08
devcontainer(features) := {"path": ".devcontainer/devcontainer.json", "contents": {"features": features}}

test_tool_08_features if {
	features := {
		"ghcr.io/devcontainers/features/node:1": {"version": "24"},
		"ghcr.io/devcontainers/features/python:1": "3.13.15",
		"ghcr.io/devcontainers-extra/features/uv:1": {},
		"ghcr.io/devcontainers-extra/features/go-task:1": {"version": "none"},
		"ghcr.io/devcontainers/features/go:1": {"version": "1.25"},
	}
	found := tool_pins.findings with input as repo([], [], [devcontainer(features)], {})
	messages(found, "TOOL-08") == {
		"Feature ghcr.io/devcontainers/features/node:1 installs node 24 but mise pins 24.21.0; set its version to 24.21.0",
		concat(" ", [
			"Feature ghcr.io/devcontainers-extra/features/uv:1 sets no version, so it installs its default uv",
			"while mise pins 0.12.18; set its version to 0.12.18",
		]),
	}
}

# TOOL-09
test_tool_09_package_manager if {
	docs := array.concat(repo([], [], [], {}), [
		td.file("package.json", {"packageManager": "bun@1.3.9"}),
		td.file("web/package.json", {"packageManager": "bun@1.3.14+sha512.00"}),
		td.file("docs/package.json", {"packageManager": "pnpm@9.0.0"}),
	])
	found := tool_pins.findings with input as docs
	td.pairs(found) == {["TOOL-09", "package.json"]}
	messages(found, "TOOL-09") == {
		"packageManager is bun@1.3.9 but mise pins bun 1.3.14; set packageManager to bun@1.3.14",
	}
}

# TOOL-10
step(uses, inputs) := {"id": "setup", "uses": uses, "with": inputs}

action(steps) := td.file(".github/actions/setup/action.yml", {"runs": {"using": "composite", "steps": steps}})

setup(uses, inputs) := action([step(uses, inputs)])

test_tool_10_version_input if {
	found := tool_pins.findings with input as repo([setup("actions/setup-node@0a1b", {"node-version": 24})], [], [], {})
	messages(found, "TOOL-10") == {concat(" ", [
		`step "setup" installs node 24 with actions/setup-node but mise pins 24.21.0; set node-version: 24.21.0,`,
		"or install it with jdx/mise-action",
	])}
}

test_tool_10_no_version_input if {
	found := tool_pins.findings with input as repo([setup("arduino/setup-task@0a1b", {"repo-token": "x"})], [], [], {})
	messages(found, "TOOL-10") == {concat(" ", [
		`step "setup" runs arduino/setup-task with no version, so it installs a task that mise does not pin;`,
		"set version: 3.53.1, or install it with jdx/mise-action",
	])}
}

test_tool_10_quiet_cases if {
	steps := [
		step("actions/setup-node@0a1b", {"node-version-file": ".nvmrc"}),
		step("astral-sh/setup-uv@0a1b", {"version": "0.12.18"}),
		step("actions/setup-go@0a1b", {"go-version": "1.25.1"}),
		step("actions/setup-python@0a1b", {"python-version": "${{ matrix.python }}"}),
		step("oven-sh/setup-bun@0a1b", {"bun-version": "v1.3.14"}),
	]
	found := tool_pins.findings with input as repo([action(steps)], [], [], {})
	count(found) == 0
}

# TOOL-11
test_tool_11_version_files if {
	texts := {".nvmrc": "lts/*\n", "api/.python-version": "3.13\n", ".node-version": "v24.21.0\n"}
	found := tool_pins.findings with input as repo([], [".nvmrc", "api/.python-version", ".node-version"], [], texts)
	messages(found, "TOOL-11") == {
		".nvmrc says node lts/* but mise pins 24.21.0; write 24.21.0, or delete the file if nothing but mise reads it",
		concat(" ", [
			"api/.python-version says python 3.13 but mise pins 3.13.15; write 3.13.15, or delete the file if",
			"nothing but mise reads it",
		]),
	}
}

test_tool_11_tool_versions if {
	found := tool_pins.findings with input as [td.inventory([".tool-versions"])]
	messages(found, "TOOL-11") == {
		".tool-versions is a second place to pin tool versions; move its pins to .config/mise/config.toml and delete it",
	}
}
