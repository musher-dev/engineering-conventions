package conventions.checks.dependencies.updates_test

import data.conventions.checks.dependencies.updates
import data.conventions.lib.testdata_test as td

identity := td.repository(object.union(td.identity, {"layout": {"product": "platform-api"}}))

dependabot(entries) := td.file(".github/dependabot.yml", {"version": 2, "updates": entries})

quiet := {
	"schedule": {"interval": "monthly"},
	"groups": {"all": {"patterns": ["*"]}},
}

update(ecosystem, directories) := object.union(quiet, {"package-ecosystem": ecosystem, "directories": directories})

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
	object.union(quiet, {"package-ecosystem": "gomod", "directory": "/platform-api"}),
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
	entries := [full[0], full[1], object.union(quiet, {"package-ecosystem": "gomod", "directory": "/"})]
	found := updates.findings with input as repo(entries, listed)

	# DEPS-18 too: the root holds no go.mod for that update to read.
	td.pairs(found) == {["DEPS-13", ".github/dependabot.yml"], ["DEPS-18", ".github/dependabot.yml"]}
}

test_deps_13_deno_has_no_updater if {
	paths := [".github/dependabot.yml", "platform-api/deno.json"]
	count(updates.findings) == 0 with input as repo([], paths)
}

test_deps_17_weekly_and_ungrouped if {
	entries := [{
		"package-ecosystem": "github-actions",
		"directories": ["/", "/.github/actions/setup-tools"],
		"schedule": {"interval": "weekly"},
	}]
	paths := [".github/workflows/validate.yml", ".github/actions/setup-tools/action.yml", ".github/dependabot.yml"]
	found := updates.findings with input as repo(entries, paths)
	td.pairs(found) == {["DEPS-17", ".github/dependabot.yml"]}
	{f.message | some f in found} == {concat(" ", [
		"the github-actions update for /, /.github/actions/setup-tools runs weekly and groups nothing; set",
		"schedule.interval to monthly and add a group whose patterns are [\"*\"], so it opens at most one pull",
		"request a month",
	])}
}

test_deps_17_security_group_is_not_enough if {
	entry := {
		"package-ecosystem": "gomod",
		"schedule": {"interval": "monthly"},
		"directory": "/platform-api",
		"groups": {"security": {"applies-to": "security-updates", "patterns": ["*"]}},
	}
	found := updates.findings with input as repo([full[0], full[1], entry], listed)
	{f.message | some f in found} == {concat(" ", [
		"the gomod update for /platform-api groups nothing; set schedule.interval to monthly and add a group",
		"whose patterns are [\"*\"], so it opens at most one pull request a month",
	])}
}

test_deps_17_missing_interval if {
	entry := {"package-ecosystem": "gomod", "directory": "/platform-api", "groups": quiet.groups}
	found := updates.findings with input as repo([full[0], full[1], entry], listed)
	some f in found
	contains(f.message, "has no schedule.interval")
}

test_deps_17_quarterly_and_security_only_pass if {
	security_only := {
		"package-ecosystem": "npm",
		"directory": "/",
		"open-pull-requests-limit": 0,
		"schedule": {"interval": "daily"},
	}
	gomod := object.union(full[2], {"schedule": {"interval": "quarterly"}})
	paths := array.concat(listed, ["package.json"])
	count(updates.findings) == 0 with input as repo([full[0], full[1], gomod, security_only], paths)
}

# DEPS-18

test_deps_18_compose_only_directory_for_docker if {
	paths := array.concat(listed, [".devcontainer/stacks/redis/compose.yaml"])
	entries := array.concat(full, [update("docker", ["/.devcontainer/stacks/**"])])
	found := updates.findings with input as repo(entries, paths)
	td.pairs(found) == {["DEPS-18", ".github/dependabot.yml"]}
	concat(" ", [
		"the docker update scans \"/.devcontainer/stacks/**\", which holds nothing the docker ecosystem",
		"reads, so Dependabot aborts the update; point it at the directories that do, or use the ecosystem",
		"that reads what is there",
	]) in {f.message | some f in found}
}

test_deps_18_passes_compose_with_docker_compose if {
	paths := array.concat(listed, [".devcontainer/stacks/redis/compose.yaml"])
	entries := array.concat(full, [update("docker-compose", ["/.devcontainer/stacks/*"])])
	count(updates.findings) == 0 with input as repo(entries, paths)
}

test_deps_18_glob_matching_one_manifest_is_enough if {
	entries := array.concat(array.slice(full, 0, 1), [
		update("docker", ["/**"]),
		object.union(quiet, {"package-ecosystem": "gomod", "directory": "/platform-api"}),
	])
	count(updates.findings) == 0 with input as repo(entries, listed)
}

test_deps_18_devcontainers_reads_the_nested_file if {
	paths := array.concat(listed, [".devcontainer/devcontainer.json"])
	entries := array.concat(full, [update("devcontainers", ["/"])])
	count(updates.findings) == 0 with input as repo(entries, paths)
}

test_deps_18_devcontainers_without_one if {
	entries := array.concat(full, [update("devcontainers", ["/"])])
	found := updates.findings with input as repo(entries, listed)
	td.pairs(found) == {["DEPS-18", ".github/dependabot.yml"]}
}

test_deps_18_leaves_a_missing_directory_to_repo_22 if {
	entries := array.concat(full, [update("docker", ["/nowhere"])])
	count(updates.findings) == 0 with input as repo(entries, listed)
}

test_deps_18_ignores_an_ecosystem_it_does_not_know if {
	entries := array.concat(full, [update("swift", ["/platform-api"])])
	count(updates.findings) == 0 with input as repo(entries, listed)
}

# DEPS-19

test_deps_19_npm_over_a_bun_lock if {
	paths := array.concat(listed, ["web/package.json", "web/bun.lock"])
	entries := array.concat(full, [update("npm", ["/web"])])
	found := updates.findings with input as repo(entries, paths)
	td.pairs(found) == {["DEPS-19", ".github/dependabot.yml"]}
	concat(" ", [
		"the npm update scans /web, whose dependencies bun.lock records, and Dependabot refuses it as a",
		"misconfigured Bun project, security updates included; set its package-ecosystem to bun",
	]) in {f.message | some f in found}
}

test_deps_19_passes_bun_over_a_bun_lock if {
	paths := array.concat(listed, ["web/package.json", "web/bun.lock"])
	entries := array.concat(full, [update("bun", ["/web"])])
	count(updates.findings) == 0 with input as repo(entries, paths)
}

test_deps_19_passes_npm_over_a_package_lock if {
	paths := array.concat(listed, ["web/package.json", "web/package-lock.json"])
	entries := array.concat(full, [update("npm", ["/web"])])
	count(updates.findings) == 0 with input as repo(entries, paths)
}
