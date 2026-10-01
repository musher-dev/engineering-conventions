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

dev_schema(bindings) := td.file(".devcontainer/env.schema.yaml", {"service": "devcontainer", "bindings": bindings})

host_binding := {"type": "string", "sensitivity": "secret", "source": "host", "description": "x"}

dev_container(secrets) := td.file(".devcontainer/devcontainer.json", {"name": "x", "secrets": secrets})

test_envs_15_missing_and_undeclared_secrets if {
	docs := [
		dev_schema({"MODEL_API_KEY": host_binding, "LOG_LEVEL": {"type": "string", "sensitivity": "internal"}}),
		dev_container({"OTHER_TOKEN": {}}),
	]
	found := env_contract.findings with input as docs
	td.pairs(found) == {["ENVS-15", ".devcontainer/devcontainer.json"]}
	{f.message | some f in found} == {
		concat(" ", [
			"MODEL_API_KEY comes from the host (source: host in .devcontainer/env.schema.yaml) but is not in secrets;",
			"add it so Codespaces asks for it",
		]),
		concat(" ", [
			"secrets names OTHER_TOKEN, which .devcontainer/env.schema.yaml does not declare with source: host;",
			"declare it there, or remove it",
		]),
	}
}

test_envs_15_no_secrets_block if {
	docs := [dev_schema({"MODEL_API_KEY": host_binding}), td.file(".devcontainer/devcontainer.json", {"name": "x"})]
	td.ids(env_contract.findings) == {"ENVS-15"} with input as docs
}

test_envs_15_matching_secrets if {
	docs := [dev_schema({"MODEL_API_KEY": host_binding}), dev_container({"MODEL_API_KEY": {"description": "x"}})]
	count(env_contract.findings) == 0 with input as docs
}

test_envs_15_needs_the_dev_schema if {
	docs := [dev_container({"MODEL_API_KEY": {}}), td.file(".devcontainer.json", {"secrets": {"A": {}}})]
	count(env_contract.findings) == 0 with input as docs
}

test_envs_02_skips_a_vendored_copy if {
	paths := [
		".repo/repository.toml", "platform-api/env.schema.yaml",
		"platform-api/contracts/vendor/host-agent/contracts/env.schema.yaml",
	]
	count(env_contract.findings) == 0 with input as repo("platform-api", paths)
}

test_envs_02_vendor_is_only_under_contracts if {
	paths := [".repo/repository.toml", "platform-api/env.schema.yaml", "platform-api/vendor/host-agent/env.schema.yaml"]
	found := env_contract.findings with input as repo("platform-api", paths)
	td.pairs(found) == {["ENVS-02", "platform-api/vendor/host-agent/env.schema.yaml"]}
}
