package conventions.checks.environment.env_stacks_test

import data.conventions.checks.environment.env_stacks
import data.conventions.lib.testdata_test as td

binding(extra) := object.union({"type": "string", "sensitivity": "internal", "description": "x"}, extra)

dev_schema(bindings) := td.file(".devcontainer/env.schema.yaml", {"service": "devcontainer", "bindings": bindings})

postgres_compose(environment) := td.file(".devcontainer/stacks/postgres/compose.yaml", {"services": {"postgres": {
	"image": "postgres:17.6",
	"environment": environment,
}}})

inventory(paths, texts) := td.file("/tmp/inventory.json", {"conventions_inventory": {
	"files": array.concat(paths, [path | some path, _ in texts]),
	"texts": texts,
}})

test_conforming_stack if {
	docs := [
		dev_schema({"POSTGRES_USER": binding({"local_default": "postgres", "consumers": ["postgres"]})}),
		postgres_compose({"POSTGRES_USER": "${POSTGRES_USER:-postgres}"}),
	]
	count(env_stacks.findings) == 0 with input as docs
}

test_envs_32_every_form if {
	docs := [
		dev_schema({"A": binding({})}),
		td.file(".devcontainer/stacks/app/compose.yaml", {
			"name": "${PROJECT}",
			"x-common": {"user": "${RUN_AS:?set RUN_AS}"},
			"services": {"app": {
				"image": "app:1.0.0",
				"command": ["sh", "-c", "echo ${A} ${B-b} ${C:+c} ${D?d} ${E:-${F}}"],
			}},
		}),
	]
	found := env_stacks.findings with input as docs
	td.pairs(found) == {["ENVS-32", ".devcontainer/stacks/app/compose.yaml"]}
	names := {name |
		some f in found
		some name in {"PROJECT", "RUN_AS", "B", "C", "D", "E", "F"}
		contains(f.message, sprintf("${%s}", [name]))
	}
	count(names) == 7
	count(found) == 7
	concat(" ", [
		"this file reads ${PROJECT}, which .devcontainer/env.schema.yaml does not declare;",
		"add it as a binding there, or stop reading it",
	]) in {f.message | some f in found}
}

test_envs_32_escapes_passthrough_and_compose if {
	docs := [
		td.file(".devcontainer/env.schema.yaml", {
			"service": "devcontainer",
			"vendor_passthrough": ["HOME", "AWS_*"],
			"bindings": {},
		}),
		postgres_compose({
			"LITERAL": "$${NOT_A_REFERENCE} $$$${ALSO_NOT}",
			"HOME_DIR": "${HOME}",
			"REGION": "${AWS_REGION}",
			"PROJECT": "${COMPOSE_PROJECT_NAME}",
			"PLAIN": "$UNBRACED",
		}),
	]
	count(env_stacks.findings) == 0 with input as docs
}

test_envs_32_escape_then_reference if {
	docs := [dev_schema({}), postgres_compose({"X": "$$${REAL}"})]
	found := env_stacks.findings with input as docs
	td.pairs(found) == {["ENVS-32", ".devcontainer/stacks/postgres/compose.yaml"]}
}

test_envs_32_needs_the_dev_schema if {
	docs := [
		td.file("platform-api/env.schema.yaml", {"service": "platform-api", "bindings": {}}),
		postgres_compose({"X": "${UNDECLARED}"}),
		td.file("docker/compose.yaml", {"services": {"a": {"image": "a:1", "environment": {"X": "${Y}"}}}}),
	]
	count(env_stacks.findings) == 0 with input as docs
}

test_envs_32_only_dev_container_compose_files if {
	docs := [dev_schema({}), td.file("docker/compose.yaml", {"services": {"a": {"environment": {"X": "${Y}"}}}})]
	count(env_stacks.findings) == 0 with input as docs
}

test_envs_33_unknown_stack if {
	docs := [
		dev_schema({"POSTGRES_USER": binding({"consumers": ["postgres", "nope"]})}),
		postgres_compose({"POSTGRES_USER": "${POSTGRES_USER}"}),
	]
	found := env_stacks.findings with input as docs
	td.pairs(found) == {["ENVS-33", ".devcontainer/env.schema.yaml"]}
	{f.message | some f in found} == {concat(" ", [
		"POSTGRES_USER lists the consumer nope, but no compose file under .devcontainer/ is in a directory named nope;",
		"name the stack that reads it, or remove the entry",
	])}
}

test_envs_33_stack_does_not_read if {
	docs := [
		dev_schema({"POSTGRES_USER": binding({"consumers": ["postgres"]}), "POSTGRES_DB": binding({})}),
		postgres_compose({"POSTGRES_DB": "${POSTGRES_DB}"}),
	]
	found := env_stacks.findings with input as docs
	td.pairs(found) == {["ENVS-33", ".devcontainer/env.schema.yaml"]}
	{f.message | some f in found} == {concat(" ", [
		"POSTGRES_USER lists the stack postgres as a consumer, but its compose file does not read ${POSTGRES_USER};",
		"read it there, or remove postgres",
	])}
}

test_envs_33_any_compose_file_of_the_stack if {
	docs := [
		dev_schema({"POSTGRES_USER": binding({"consumers": ["postgres"]})}),
		postgres_compose({}),
		td.file(".devcontainer/stacks/postgres/compose.override.yaml", {"services": {"postgres": {
			"environment": {"POSTGRES_USER": "${POSTGRES_USER}"},
		}}}),
	]
	count(env_stacks.findings) == 0 with input as docs
}

test_stack_name if {
	env_stacks.stack_name(".devcontainer/stacks/postgres/compose.yaml") == "postgres"
	env_stacks.stack_name(".devcontainer/compose.yml") == ".devcontainer"
}

mirrored(local_default) := dev_schema({"MINIO_USER": binding({
	"local_default": local_default,
	"mirrored_in": ["stacks/minio/config.yaml"],
})})

test_envs_34_agrees if {
	docs := [mirrored("minioadmin"), inventory([], {".devcontainer/stacks/minio/config.yaml": "user: minioadmin\n"})]
	count(env_stacks.findings) == 0 with input as docs
}

test_envs_34_drift if {
	docs := [mirrored("hunter2"), inventory([], {".devcontainer/stacks/minio/config.yaml": "user: other\n"})]
	found := env_stacks.findings with input as docs
	td.pairs(found) == {["ENVS-34", ".devcontainer/stacks/minio/config.yaml"]}
	{f.message | some f in found} == {concat(" ", [
		"MINIO_USER has local_default \"hunter2\" in .devcontainer/env.schema.yaml, but this file does not contain it;",
		"make the two agree",
	])}
}

test_envs_34_non_string_default if {
	docs := [mirrored(15432), inventory([], {".devcontainer/stacks/minio/config.yaml": "port: 15432\n"})]
	count(env_stacks.findings) == 0 with input as docs
	drifted := [mirrored(true), inventory([], {".devcontainer/stacks/minio/config.yaml": "enabled: yes\n"})]
	contains(concat("", {f.message | some f in env_stacks.findings}), "local_default \"true\"") with input as drifted
}

test_envs_34_missing_file if {
	found := env_stacks.findings with input as [mirrored("x"), inventory([], {})]
	td.pairs(found) == {["ENVS-34", ".devcontainer/env.schema.yaml"]}
	{f.message | some f in found} == {concat(" ", [
		"MINIO_USER is mirrored_in .devcontainer/stacks/minio/config.yaml, which does not exist;",
		"correct the path, or remove it from mirrored_in",
	])}
}

test_envs_34_unembedded_file_is_not_compared if {
	docs := [mirrored("x"), inventory([".devcontainer/stacks/minio/config.yaml"], {})]
	count(env_stacks.findings) == 0 with input as docs
}

test_envs_34_no_local_default if {
	docs := [
		dev_schema({"MINIO_USER": binding({"mirrored_in": ["stacks/minio/config.yaml"]})}),
		inventory([], {".devcontainer/stacks/minio/config.yaml": "user: x\n"}),
	]
	found := env_stacks.findings with input as docs
	td.pairs(found) == {["ENVS-34", ".devcontainer/env.schema.yaml"]}
}

test_envs_34_escapes if {
	docs := [dev_schema({"A": binding({"local_default": "x", "mirrored_in": ["../README.md", "/etc/passwd"]})})]
	found := env_stacks.findings with input as docs
	td.pairs(found) == {["ENVS-34", ".devcontainer/env.schema.yaml"]}
	count(found) == 2
}

test_envs_34_product_schema_and_dot_segments if {
	docs := [
		td.file("platform-api/env.schema.yaml", {"service": "platform-api", "bindings": {
			"API_PORT": binding({"local_default": 8080, "mirrored_in": ["./config//local.toml"]}),
		}}),
		inventory([], {"platform-api/config/local.toml": "port = 8080\n"}),
	]
	count(env_stacks.findings) == 0 with input as docs
}

test_resolve if {
	env_stacks.resolve(".devcontainer", "./stacks/a/b.conf") == ".devcontainer/stacks/a/b.conf"
	env_stacks.resolve("", "a.conf") == "a.conf"
	env_stacks.resolve("x", "a/../b") == false
	env_stacks.resolve("x", "/a") == false
}
