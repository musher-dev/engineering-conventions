package conventions.checks.dependencies.updates_test

import data.conventions.checks.dependencies.updates
import data.conventions.lib.testdata_test as td

identity := td.repository(object.union(td.identity, {"layout": {"product": "platform-api"}}))

dependabot(entries) := td.file(".github/dependabot.yml", {"version": 2, "updates": entries})

update(ecosystem, directories) := {"package-ecosystem": ecosystem, "directories": directories}

listed := [
	".github/workflows/validate.yml",
	".github/actions/setup-tools/action.yml",
	".devcontainer/Dockerfile",
	"platform-api/go.mod",
	"platform-api/docker/Dockerfile",
	".github/dependabot.yml",
]

full := [
	update("github-actions", ["/", "/.github/actions/setup-tools"]),
	update("docker", ["/.devcontainer", "/platform-api/docker"]),
	{"package-ecosystem": "gomod", "directory": "/platform-api"},
]

repo(entries, paths) := [identity, dependabot(entries), td.inventory(paths)]

test_conforming if {
	count(updates.findings) == 0 with input as repo(full, listed)
}

test_renovate_covers_everything if {
	docs := [identity, td.inventory(array.concat(listed, [".github/renovate.json"]))]
	count(updates.findings) == 0 with input as docs
}

test_no_configuration_at_all if {
	docs := [identity, td.inventory([".github/workflows/validate.yml", "platform-api/go.mod"])]
	found := updates.findings with input as docs
	{f.id | some f in found} == {"DEPS-11", "DEPS-13"}
	{f.path | some f in found} == {".github/dependabot.yml"}
}

test_deps_11_action_directory_missing if {
	entries := array.concat([update("github-actions", ["/"])], array.slice(full, 1, 3))
	found := updates.findings with input as repo(entries, listed)
	td.pairs(found) == {["DEPS-11", ".github/dependabot.yml"]}
	concat(" ", [
		"nothing updates the actions used by the composite action in .github/actions/setup-tools; add",
		"\"/.github/actions/setup-tools\" to the directories of a github-actions update in the Dependabot",
		"configuration, or configure Renovate",
	]) in {f.message | some f in found}
}

test_deps_11_glob_covers_actions if {
	entries := array.concat([update("github-actions", ["/", "/.github/actions/*"])], array.slice(full, 1, 3))
	count(updates.findings) == 0 with input as repo(entries, listed)
}

test_deps_11_no_workflows if {
	paths := ["platform-api/go.mod", ".github/dependabot.yml"]
	count(updates.findings) == 0 with input as repo([full[2]], paths)
}

test_deps_12_docker_directory_missing if {
	entries := [full[0], update("docker", ["/.devcontainer"]), full[2]]
	found := updates.findings with input as repo(entries, listed)
	td.pairs(found) == {["DEPS-12", ".github/dependabot.yml"]}
}

test_deps_12_test_input_is_not_updated if {
	paths := array.concat(listed, ["platform-api/tests/molecule/Dockerfile"])
	count(updates.findings) == 0 with input as repo(full, paths)
}

test_deps_13_product_missing if {
	entries := [full[0], full[1], {"package-ecosystem": "gomod", "directory": "/"}]
	found := updates.findings with input as repo(entries, listed)
	td.pairs(found) == {["DEPS-13", ".github/dependabot.yml"]}
}

test_deps_13_deno_has_no_updater if {
	paths := [".github/dependabot.yml", "platform-api/deno.json"]
	count(updates.findings) == 0 with input as repo([], paths)
}
