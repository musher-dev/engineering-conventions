package conventions.checks.environment.env_contract_test

import data.conventions.checks.environment.env_contract
import data.conventions.lib.testdata_test as td

identity(dir) := td.repository(object.union(td.identity, {"layout": {"product": dir}}))

repo(dir, paths) := [identity(dir), td.inventory(paths)]

test_conforming_contract if {
	paths := [
		".repo/repository.toml", "platform-api/go.mod",
		"platform-api/env.schema.yaml", ".devcontainer/env.schema.yaml",
	]
	count(env_contract.findings) == 0 with input as repo("platform-api", paths)
}

test_envs_01_missing_contract if {
	found := env_contract.findings with input as repo("platform-api", [".repo/repository.toml", "platform-api/go.mod"])
	td.pairs(found) == {["ENVS-01", "platform-api/env.schema.yaml"]}
}

test_envs_01_needs_a_product if {
	count(env_contract.findings) == 0 with input as repo("", [".repo/repository.toml"])
	count(env_contract.findings) == 0 with input as [td.repository(td.identity), td.inventory([".repo/repository.toml"])]
}

test_envs_02_misplaced_schema if {
	paths := [
		".repo/repository.toml", "platform-api/env.schema.yaml",
		"platform-api/config/env.schema.yaml", "env.schema.yml",
	]
	found := env_contract.findings with input as repo("platform-api", paths)
	td.pairs(found) == {["ENVS-02", "platform-api/config/env.schema.yaml"], ["ENVS-02", "env.schema.yml"]}
	concat(" ", [
		"an environment schema lives at platform-api/env.schema.yaml or .devcontainer/env.schema.yaml,",
		"nowhere else; move this one to platform-api/env.schema.yaml",
	]) in {f.message | some f in found}
}

test_envs_02_devcontainer_copy if {
	paths := [".repo/repository.toml", ".devcontainer/config/env.schema.yaml"]
	found := env_contract.findings with input as repo("", paths)
	td.pairs(found) == {["ENVS-02", ".devcontainer/config/env.schema.yaml"]}
	endswith(concat("", {f.message | some f in found}), "move this one to .devcontainer/env.schema.yaml")
}

test_envs_02_without_a_product if {
	found := env_contract.findings with input as repo("", [".repo/repository.toml", "api/env.schema.yaml"])
	contains(concat("", {f.message | some f in found}), "<product>/env.schema.yaml")
}

test_envs_02_needs_a_layout if {
	docs := [td.repository(td.identity), td.inventory([".repo/repository.toml", "api/env.schema.yaml"])]
	count(env_contract.findings) == 0 with input as docs
}
