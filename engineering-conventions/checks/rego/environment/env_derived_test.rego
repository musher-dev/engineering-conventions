package conventions.checks.environment.env_derived_test

import data.conventions.checks.environment.env_derived
import data.conventions.lib.testdata_test as td

schema_path := "platform-api/env.schema.yaml"

contract_path := "platform-api/contracts/env/platform-api.env.schema.json"

example_path := "platform-api/.env.example"

contract := {"title": "platform-api", "type": "object", "properties": {}}

example := "# The environment platform-api reads.\n"

identity := td.repository(object.union(td.identity, {"layout": {"product": "platform-api"}}))

schema := td.file(schema_path, {"service": "platform-api", "runtime": "go", "bindings": {}})

outputs(definitions) := td.file(".repo/outputs.toml", {
	"schema_version": 2,
	"interfaces": [{"id": "runtime-config", "format": "env-schema", "definitions": definitions}],
})

# The inventory, with what the runner derived from the schema and the text
# of the files it embeds.
inventory(paths, texts) := td.file("/tmp/inventory.json", {"conventions_inventory": {
	"files": paths,
	"texts": texts,
	"derived": {"platform-api/env.schema.yaml": {
		"contract": {"title": "platform-api", "type": "object", "properties": {}},
		"example": "# The environment platform-api reads.\n",
	}},
}})

repo(extra, paths, texts) := array.concat([identity, schema, inventory(paths, texts)], extra)

test_conforming if {
	docs := repo(
		[outputs([contract_path]), td.file(contract_path, contract)],
		[".repo/outputs.toml", schema_path, contract_path, example_path],
		{example_path: example},
	)
	count(env_derived.findings) == 0 with input as docs
}

test_no_interface_asks_for_no_contract if {
	count(env_derived.findings) == 0 with input as repo([], [schema_path], {})
}

test_envs_20_missing_contract if {
	found := env_derived.findings with input as repo([outputs([schema_path])], [".repo/outputs.toml", schema_path], {})
	td.pairs(found) == {["ENVS-20", schema_path]}
	concat(" ", [
		"interface runtime-config offers this environment as env-schema, so commit the contract derived from it:",
		"conventions env-contract platform-api/env.schema.yaml > platform-api/contracts/env/platform-api.env.schema.json",
	]) in {f.message | some f in found}
}

test_envs_20_contract_not_named if {
	docs := repo(
		[outputs([schema_path]), td.file(contract_path, contract)],
		[".repo/outputs.toml", schema_path, contract_path],
		{},
	)
	found := env_derived.findings with input as docs
	td.pairs(found) == {["ENVS-20", ".repo/outputs.toml"]}
}

test_envs_20_contract_named_by_directory if {
	docs := repo(
		[outputs(["platform-api/contracts/env/"]), td.file(contract_path, contract)],
		[".repo/outputs.toml", schema_path, contract_path],
		{},
	)
	count(env_derived.findings) == 0 with input as docs
}

test_envs_20_stale_contract if {
	stale := object.union(contract, {"title": "api"})
	docs := repo(
		[outputs([contract_path]), td.file(contract_path, stale)],
		[".repo/outputs.toml", schema_path, contract_path],
		{},
	)
	found := env_derived.findings with input as docs
	td.pairs(found) == {["ENVS-20", contract_path]}
}

test_envs_20_stale_contract_without_an_interface if {
	docs := repo([td.file(contract_path, {})], [schema_path, contract_path], {})
	td.pairs(env_derived.findings) == {["ENVS-20", contract_path]} with input as docs
}

test_envs_20_needs_a_service_name_that_is_a_file_name if {
	odd := td.file(schema_path, {"service": "platform api/x", "runtime": "go", "bindings": {}})
	docs := [identity, odd, outputs([schema_path]), inventory([".repo/outputs.toml", schema_path], {})]
	count(env_derived.findings) == 0 with input as docs
}

test_envs_21_stale_example if {
	docs := repo([], [schema_path, example_path], {example_path: "API_PORT=8080\n"})
	found := env_derived.findings with input as docs
	td.pairs(found) == {["ENVS-21", example_path]}
	concat(" ", [
		"this is not the .env.example platform-api/env.schema.yaml derives; generate it again with",
		"conventions env-contract --example platform-api/env.schema.yaml > platform-api/.env.example",
	]) in {f.message | some f in found}
}

test_envs_21_nothing_derived if {
	docs := [identity, schema, td.file("/tmp/inventory.json", {"conventions_inventory": {
		"files": [schema_path, example_path],
		"texts": {example_path: "API_PORT=8080\n"},
	}})]
	count(env_derived.findings) == 0 with input as docs
}
