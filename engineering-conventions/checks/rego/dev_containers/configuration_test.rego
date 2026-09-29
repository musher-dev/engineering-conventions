package conventions.checks.dev_containers.configuration_test

import data.conventions.checks.dev_containers.configuration
import data.conventions.lib.testdata_test as td

config_path := ".devcontainer/devcontainer.json"

lock_path := ".devcontainer/devcontainer-lock.json"

git_feature := "ghcr.io/devcontainers/features/git:1"

devcontainer := {
	"name": "Platform API",
	"image": "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
	"features": {git_feature: {}},
	"remoteUser": "vscode",
	"mounts": ["source=musher-${devcontainerId}-gh-config,target=/home/vscode/.config/gh,type=volume"],
	"postCreateCommand": ["bash", ".devcontainer/scripts/post-create.sh"],
}

without_features := object.remove(devcontainer, ["features"])

lock(references) := {"features": {reference: {"version": "1.0.0"} | some reference in references}}

dependabot := td.file(".github/dependabot.yml", {"version": 2, "updates": [{
	"package-ecosystem": "devcontainers",
	"directory": "/",
}]})

build_workflow(run) := td.file(".github/workflows/validate-devcontainer.yml", {
	"name": "Validate Dev Container",
	"on": {"pull_request": null},
	"jobs": {"build": {"runs-on": "ubuntu-24.04", "steps": [{"name": "Build", "run": run}]}},
})

frozen_build := build_workflow("npx -y @devcontainers/cli@0.89.0 build --workspace-folder . --frozen-lockfile")

default_paths := [
	config_path, lock_path, ".devcontainer/scripts/post-create.sh",
	".github/dependabot.yml", ".github/workflows/validate-devcontainer.yml",
]

# The default paths without the lockfile.
unlocked_paths := [path | some path in default_paths; path != lock_path]

# A repository with the given configuration, lockfile features, other
# documents, and extra paths.
repo(config, locked, docs, paths) := array.concat(
	[
		td.file(config_path, config),
		td.file(lock_path, lock(locked)),
		td.inventory(array.concat(default_paths, paths)),
	],
	docs,
)

conforming(config) := repo(config, [git_feature], [dependabot, frozen_build], [])

# A repository with no lockfile, and the given configuration and documents.
unlocked(config, docs) := array.concat([td.file(config_path, config), td.inventory(unlocked_paths)], docs)

with_config(patch) := conforming(object.union(devcontainer, patch))

messages(found, id) := {f.message | some f in found; f.id == id}

test_a_conforming_dev_container if {
	count(configuration.findings) == 0 with input as conforming(devcontainer)
}

test_no_dev_container_no_findings if {
	count(configuration.findings) == 0 with input as [td.inventory(["README.md"])]
}

test_devc_01_root_and_nested if {
	extra := td.inventory([".devcontainer.json", ".devcontainer/a/b/devcontainer.json"])
	found := configuration.findings with input as array.concat(conforming(devcontainer), [extra])
	{p | some p in td.pairs(found); p[0] == "DEVC-01"} == {
		["DEVC-01", ".devcontainer.json"],
		["DEVC-01", ".devcontainer/a/b/devcontainer.json"],
	}
}

test_devc_01_named_configuration_passes if {
	extra := td.inventory([".devcontainer/python/devcontainer.json"])
	found := configuration.findings with input as array.concat(conforming(devcontainer), [extra])
	not "DEVC-01" in td.ids(found)
}

test_devc_02_missing_lockfile if {
	found := configuration.findings with input as unlocked(devcontainer, [dependabot, frozen_build])
	td.pairs(found) == {["DEVC-02", config_path]}
	messages(found, "DEVC-02") == {concat("", [
		"the Features are not locked; commit .devcontainer/devcontainer-lock.json, ",
		"written by `devcontainer build` or `devcontainer upgrade`",
	])}
}

test_devc_02_root_form_lockfile if {
	docs := [
		td.file(".devcontainer.json", devcontainer), dependabot, frozen_build,
		td.inventory([".devcontainer.json"]),
	]
	found := configuration.findings with input as docs
	contains(concat("", messages(found, "DEVC-02")), "commit .devcontainer-lock.json")
}

test_devc_02_no_features_needs_no_lockfile if {
	docs := unlocked(without_features, [dependabot, build_workflow("devcontainer build")])
	count(configuration.findings) == 0 with input as docs
}

test_devc_03_missing_and_stale_entries if {
	cli := "ghcr.io/devcontainers/features/github-cli:1"
	config := object.union(devcontainer, {"features": {cli: {}}})
	locked := [git_feature, "ghcr.io/devcontainers/features/node:1"]
	found := configuration.findings with input as repo(config, locked, [dependabot, frozen_build], [])
	td.pairs(found) == {["DEVC-03", lock_path]}
	count(messages(found, "DEVC-03")) == 2
}

utils := "ghcr.io/devcontainers/features/common-utils:2"

# A lockfile with the given entries, replacing the default one.
lockfile(entries) := td.file(lock_path, {"features": entries})

test_devc_03_depends_on_is_not_stale if {
	entries := {git_feature: {"version": "1.3.8", "dependsOn": [utils]}, utils: {"version": "2.7.0"}}
	docs := array.concat(unlocked(devcontainer, [dependabot, frozen_build]), [lockfile(entries)])
	count(configuration.findings) == 0 with input as docs
}

test_devc_03_depends_on_as_object if {
	entries := {git_feature: {"dependsOn": {utils: {}}}, utils: {}}
	docs := array.concat(unlocked(devcontainer, [dependabot, frozen_build]), [lockfile(entries)])
	count(configuration.findings) == 0 with input as docs
}

test_devc_04_floating_image if {
	some image in [
		"mcr.microsoft.com/devcontainers/base",
		"mcr.microsoft.com/devcontainers/base:latest",
		"localhost:5000/dev:main",
	]
	found := configuration.findings with input as with_config({"image": image})
	td.pairs(found) == {["DEVC-04", config_path]}
}

test_devc_04_fixed_images_pass if {
	some image in [
		"mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
		"mcr.microsoft.com/devcontainers/base:latest@sha256:0f4e",
		"ghcr.io/musher-dev/dev:${VERSION}",
	]
	count(configuration.findings) == 0 with input as with_config({"image": image})
}

from(values) := {"Cmd": "from", "Value": values, "Flags": []}

without_image := object.remove(devcontainer, ["image"])

built(config, instructions) := array.concat(
	conforming(config),
	[td.file(".devcontainer/Dockerfile", instructions)],
)

test_devc_04_floating_from if {
	config := object.union(without_image, {"build": {"dockerfile": "Dockerfile"}})
	found := configuration.findings with input as built(config, [from(["mcr.microsoft.com/devcontainers/base"])])
	td.pairs(found) == {["DEVC-04", ".devcontainer/Dockerfile"]}
}

test_devc_04_legacy_key_and_stages if {
	config := object.union(without_image, {"build": {"dockerFile": "Dockerfile"}})
	instructions := [
		from(["mcr.microsoft.com/devcontainers/base:ubuntu-24.04", "AS", "base"]),
		from(["base"]),
		from(["scratch"]),
	]
	count(configuration.findings) == 0 with input as built(config, instructions)
}

test_devc_04_top_level_docker_file if {
	config := object.union(without_image, {"dockerFile": "./Dockerfile"})
	found := configuration.findings with input as built(config, [from(["ubuntu:latest"])])
	td.pairs(found) == {["DEVC-04", ".devcontainer/Dockerfile"]}
}

test_build_dockerfile_paths if {
	parent := {"build": {"dockerfile": "../Dockerfile"}}
	nested := ".devcontainer/python/devcontainer.json"
	configuration.build_dockerfile(nested, parent) == ".devcontainer/Dockerfile"
	configuration.build_dockerfile(config_path, parent) == "Dockerfile"
	configuration.build_dockerfile(config_path, {"build": {"dockerfile": "Dockerfile"}}) == ".devcontainer/Dockerfile"
}

test_devc_05_unset_and_root if {
	unset := configuration.findings with input as conforming(object.remove(devcontainer, ["remoteUser"]))
	td.pairs(unset) == {["DEVC-05", config_path]}
	root := configuration.findings with input as with_config({"containerUser": "root", "remoteUser": "root"})
	count(messages(root, "DEVC-05")) == 2
}

missing_script(hook, script) := sprintf(
	"%s runs %s, which the repository does not hold; correct the path, or add the script",
	[hook, script],
)

test_devc_06_missing_scripts if {
	found := configuration.findings with input as with_config({
		"initializeCommand": "bash .devcontainer/scripts/initialize.sh",
		"postCreateCommand": {"a": ["bash", "./.devcontainer/post-create.sh"], "b": "git --version"},
	})
	messages(found, "DEVC-06") == {
		missing_script("initializeCommand", ".devcontainer/scripts/initialize.sh"),
		missing_script("postCreateCommand", ".devcontainer/post-create.sh"),
	}
}

test_devc_06_ignores_absolute_variable_and_parent_paths if {
	docs := with_config({
		"postStartCommand": "bash /usr/local/share/docker-init.sh && bash ${containerWorkspaceFolder}/x.sh",
		"postAttachCommand": "bash ../outside.sh; cat docs/setup.md",
		"onCreateCommand": 42,
	})
	count(configuration.findings) == 0 with input as docs
}

schema := td.file(".devcontainer/env.schema.yaml", {"service": "devcontainer", "bindings": {
	"MODEL_API_KEY": {"type": "string", "sensitivity": "secret", "source": "host", "description": "x"},
	"LOG_LEVEL": {"type": "string", "sensitivity": "internal", "description": "x"},
}})

test_devc_07_committed_secret if {
	docs := with_config({
		"containerEnv": {"MODEL_API_KEY": "abc", "LOG_LEVEL": "debug"},
		"remoteEnv": {"MODEL_API_KEY": "${localEnv:MODEL_API_KEY}"},
	})
	found := configuration.findings with input as array.concat(docs, [schema])
	td.pairs(found) == {["DEVC-07", config_path]}
	messages(found, "DEVC-07") == {concat("", [
		"containerEnv.MODEL_API_KEY commits a value for a secret; ",
		`pass it from the host as "${localEnv:MODEL_API_KEY}", or leave it empty`,
	])}
}

test_devc_07_empty_and_references_pass if {
	docs := with_config({
		"containerEnv": {"MODEL_API_KEY": ""},
		"remoteEnv": {"MODEL_API_KEY": "${containerEnv:MODEL_API_KEY}"},
	})
	count(configuration.findings) == 0 with input as array.concat(docs, [schema])
}

test_devc_08_volume_names if {
	config := object.union(devcontainer, {"mounts": [
		"source=gh-config,target=/home/vscode/.config/gh,type=volume",
		{"source": "musher-claude", "target": "/home/vscode/.claude", "type": "volume"},
		"src=musher-${devcontainerId}-codex-config,dst=/home/vscode/.codex,type=volume",
		"source=${localWorkspaceFolder}/.cache,target=/home/vscode/.cache,type=bind",
		"target=/tmp/scratch,type=volume",
	]})
	found := configuration.findings with input as conforming(config)
	count(messages(found, "DEVC-08")) == 2
}

test_devc_09_no_updates if {
	found := configuration.findings with input as repo(devcontainer, [git_feature], [frozen_build], [])
	td.pairs(found) == {["DEVC-09", ".github/dependabot.yml"]}
}

test_devc_09_other_ecosystems_only if {
	actions := td.file(".github/dependabot.yaml", {"updates": [{"package-ecosystem": "github-actions"}]})
	found := configuration.findings with input as repo(devcontainer, [git_feature], [actions, frozen_build], [])
	td.pairs(found) == {["DEVC-09", ".github/dependabot.yaml"]}
}

test_devc_09_renovate if {
	docs := repo(devcontainer, [git_feature], [frozen_build], [".github/renovate.json5"])
	count(configuration.findings) == 0 with input as docs
}

test_devc_10_no_build if {
	found := configuration.findings with input as repo(devcontainer, [git_feature], [dependabot], [])
	td.pairs(found) == {["DEVC-10", config_path]}
	contains(concat("", messages(found, "DEVC-10")), "no workflow builds the dev container")
}

test_devc_10_unfrozen if {
	unfrozen := build_workflow("devcontainer build --workspace-folder .")
	found := configuration.findings with input as repo(devcontainer, [git_feature], [dependabot, unfrozen], [])
	contains(concat("", messages(found, "DEVC-10")), "pass --frozen-lockfile")
}

test_devc_10_continued_line if {
	run := "# --frozen-lockfile keeps the lock honest\ndevcontainer up \\\n  --workspace-folder . \\\n  --frozen-lockfile"
	docs := repo(devcontainer, [git_feature], [dependabot, build_workflow(run)], [])
	count(configuration.findings) == 0 with input as docs
}

test_devc_10_ci_action_without_lockfile if {
	step := {"uses": "devcontainers/ci@8bf61b26e9c3a98f69cb6ce2f88d24ff59b785c6"}
	action := td.file(".github/workflows/validate-devcontainer.yml", {
		"on": {"pull_request": null},
		"jobs": {"build": {"runs-on": "ubuntu-24.04", "steps": [step]}},
	})
	count(configuration.findings) == 0 with input as unlocked(without_features, [dependabot, action])
}
