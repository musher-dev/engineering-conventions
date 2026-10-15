package conventions.checks.dev_containers.workspace_test

import data.conventions.checks.dev_containers.configuration_test as ct
import data.conventions.checks.dev_containers.workspace
import data.conventions.lib.testdata_test as td

single := {"product": "platform-api"}

apps := {"product": "", "products": ["apps/*"]}

workspace_folder := "/workspaces/${localWorkspaceFolderBasename}"

# A conforming repository with the given mounts and settings, identity
# layout, and extra paths.
repo(patch, table, paths) := array.concat(ct.conforming(object.union(ct.devcontainer, patch)), [
	td.inventory(array.concat([".repo/repository.toml"], paths)),
	td.repository(object.union(td.identity, {"layout": table})),
])

volume(name, target) := sprintf("source=musher-${devcontainerId}-%s,target=%s,type=volume", [name, target])

mounts(targets) := {"mounts": [volume("cache", target) | some target in targets]}

linked(entries) := {"customizations": {"vscode": {"settings": {"rust-analyzer.linkedProjects": entries}}}}

stray(target, advice) := sprintf("the mount at %s %s", [target, advice])

test_devc_22_mounts_outside_the_product if {
	patch := {"mounts": [
		volume("target", concat("/", [workspace_folder, "target"])),
		{"source": "musher-${devcontainerId}-x", "target": "${containerWorkspaceFolder}/platform-api-web/x"},
		concat("", ["src=musher-${devcontainerId}-cache,dst=", workspace_folder, "/platform-apix,type=volume"]),
	]}
	found := workspace.findings with input as repo(patch, single, [])
	td.pairs(found) == {["DEVC-22", ct.config_path]}
	count(found) == 3
}

test_devc_22_mounts_in_the_product_pass if {
	patch := {"mounts": [
		volume("target", concat("/", [workspace_folder, "platform-api/target"])),
		{"source": "musher-${devcontainerId}-root", "target": "${containerWorkspaceFolder}/platform-api"},
		concat("", ["source=x,destination=", workspace_folder, "/platform-api/.cache,type=volume"]),
		volume("gh-config", "/home/vscode/.config/gh"),
	]}
	count(workspace.findings) == 0 with input as repo(patch, single, [])
}

test_devc_22_message_names_the_product if {
	target := concat("/", [workspace_folder, "target"])
	found := workspace.findings with input as repo(mounts([target]), single, [])
	{f.message | some f in found} == {stray(
		target,
		"lands outside the product directory platform-api; mount it under platform-api/, or remove it",
	)}
}

test_devc_22_no_product_declared if {
	target := concat("/", [workspace_folder, "demo/target"])
	found := workspace.findings with input as repo(mounts([target]), {}, [])
	{f.message | some f in found} == {stray(target, concat(" ", [
		"lands in the workspace, but .repo/repository.toml declares no product directory;",
		"declare one in [layout] and mount under it, or remove the mount",
	]))}
}

test_devc_22_multi_product if {
	targets := [concat("/", [workspace_folder, inside]) | some inside in ["apps/web/node_modules", "node_modules", "apps"]]
	found := workspace.findings with input as repo(mounts(targets), apps, [])
	advice := "lands outside every product directory (apps/*); mount it under one, or remove it"
	{f.message | some f in found} == {stray(targets[1], advice), stray(targets[2], advice)}
}

test_devc_22_silent_without_an_identity if {
	patch := mounts([concat("/", [workspace_folder, "target"])])
	count(workspace.findings) == 0 with input as ct.conforming(object.union(ct.devcontainer, patch))
}

test_devc_22_silent_beside_a_malformed_product if {
	patch := mounts([concat("/", [workspace_folder, "target"])])
	count(workspace.findings) == 0 with input as repo(patch, {"product": "a/b"}, [])
}

test_devc_23_unlinked_cargo_product if {
	found := workspace.findings with input as repo({}, single, ["platform-api/Cargo.toml"])
	{f.message | some f in found} == {concat("", [
		`customizations.vscode.settings["rust-analyzer.linkedProjects"] does not list platform-api/Cargo.toml; `,
		"add it so rust-analyzer loads the product; it searches only near the root, ",
		"and without it the editor has no Rust analysis",
	])}
}

test_devc_23_linked_cargo_product_passes if {
	patch := linked(["./platform-api/Cargo.toml"])
	count(workspace.findings) == 0 with input as repo(patch, single, ["platform-api/Cargo.toml"])
}

test_devc_23_multi_product if {
	patch := linked(["${workspaceFolder}/apps/a/Cargo.toml", {"crates": []}])
	paths := ["apps/a/Cargo.toml", "apps/b/Cargo.toml", "apps/c/package.json"]
	found := workspace.findings with input as repo(patch, apps, paths)
	td.pairs(found) == {["DEVC-23", ct.config_path]}
	count(found) == 1
}

test_devc_23_not_required_without_cargo if {
	count(workspace.findings) == 0 with input as repo({}, single, ["platform-api/package.json"])
}
