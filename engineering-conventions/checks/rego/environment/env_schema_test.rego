package conventions.checks.environment.env_schema_test

import data.conventions.checks.environment.env_schema
import data.conventions.lib.testdata_test as td

path := "api/env.schema.yaml"

# A cut-down format with the shapes ENVS-03's message depends on.
index := object.union(td.index, {"env_schema": {
	"type": "object",
	"required": ["service", "runtime", "bindings"],
	"properties": {"bindings": {"type": "object", "additionalProperties": {
		"type": "object",
		"properties": {"type": {"enum": ["string", "integer", "number", "boolean", "enum", "list"]}},
	}}},
}})

binding(fields) := object.union(
	{"type": "string", "sensitivity": "internal", "description": "What the variable is for, at length."},
	fields,
)

schema(contents) := object.union(
	{"service": "api", "runtime": "python", "naming": {"components": ["API", "DATABASE"]}, "bindings": {}},
	contents,
)

one(bindings) := [td.file(path, schema({"bindings": bindings}))]

messages(found, id) := {f.message | some f in found; f.id == id}

conforming := {
	"API_PORT": binding({"type": "integer", "default": 8080}),
	"API_REQUEST_TIMEOUT_SEC": binding({"type": "integer", "default": 30}),
	"DATABASE_URL": binding({
		"format": "url", "required": true, "sensitivity": "secret",
		"local_default": "postgres://postgres@localhost:5432/app",
	}),
	"ENABLE_AUDIT_LOG": binding({"type": "boolean", "default": false}),
	"VITE_ENABLE_BILLING": binding({"type": "boolean", "default": false, "consumer": "client"}),
	"WORKERS__EXPORT__IS_ENABLED": binding({
		"type": "boolean", "default": true,
		"nested": {"group": "workers", "field": "is_enabled"},
	}),
	"API_SIGNING_KEY": binding({"sensitivity": "secret", "local_generate": "base64:32"}),
	"OTEL_SERVICE_NAME": binding({}),
	"LegacyName": binding({"grammar_exempt": true, "grammar_exempt_reason": "A vendor fixes it."}),
}

test_conforming_schema if {
	docs := [td.file(path, schema({
		"bindings": conforming,
		"naming": {"components": ["API", "DATABASE", "WORKERS"], "vendor_prefixes": ["OTEL_"]},
	}))]
	count(env_schema.findings) == 0 with input as docs with data.conventions.index as index
}

test_envs_03_invalid if {
	found := env_schema.findings with input as one({"API_PORT": binding({"type": "int"})})
		with data.conventions.index as index
	td.pairs(found) == {["ENVS-03", path]}
}

test_envs_03_reads_only_env_schemas if {
	count(env_schema.findings) == 0 with input as [td.file("api/other.yaml", {})] with data.conventions.index as index
}

test_envs_05_retired if {
	docs := [td.file(path, schema({
		"bindings": {"API_TOKEN": binding({})},
		"vendor_passthrough": ["API_TOKEN"],
		"retired": [{"name": "API_TOKEN", "retired_on": "2026-05-01", "reason": "Signed tokens replaced it."}],
	}))]
	found := env_schema.findings with input as docs with data.conventions.index as index
	messages(found, "ENVS-05") == {
		concat(" ", [
			"API_TOKEN was retired on 2026-05-01 and is declared in bindings again:",
			"Signed tokens replaced it. Remove it, or delete its retired entry in the same change, deliberately",
		]),
		concat(" ", [
			"API_TOKEN was retired on 2026-05-01 and is listed in vendor_passthrough again:",
			"Signed tokens replaced it. Remove it, or delete its retired entry in the same change, deliberately",
		]),
	}
}

test_envs_05_coolify if {
	docs := [td.file(path, schema({
		"coolify_env": {"required": ["API_TOKEN"]},
		"retired": [{"name": "API_TOKEN", "retired_on": "2026-05-01", "reason": "Gone."}],
	}))]
	found := env_schema.findings with input as docs with data.conventions.index as index
	"ENVS-05" in td.ids(found)
}

test_envs_06_secret_values if {
	found := env_schema.findings with input as one({"DATABASE_URL": binding({
		"format": "url", "sensitivity": "secret",
		"default": "postgres://app@db.example.com/app",
		"local_default": "hunter2",
	})})
		with data.conventions.index as index
	count(messages(found, "ENVS-06")) == 2
}

test_envs_06_local_values if {
	count(env_schema.findings) == 0 with input as one({
		"DATABASE_URL": binding({
			"format": "url", "sensitivity": "secret",
			"default": "", "local_default": "redis://[::1]:6379",
		}),
		"API_HOST_URL": binding({
			"format": "url", "sensitivity": "secret",
			"local_default": "http://host.docker.internal:8080/x",
		}),
	})
		with data.conventions.index as index
}

test_envs_07_binding_invariants if {
	found := env_schema.findings with input as one({
		"API_MODE": binding({"type": "enum"}),
		"API_KEY": binding({"required": true, "default": "x", "local_default": "a", "local_generate": "hex:4"}),
		"API_POOL_URL": binding({"format": "url", "allow_empty": true}),
		"API_Name": binding({"grammar_exempt": true}),
		"API_SHORT_KEY": binding({
			"sensitivity": "secret", "local_generate": "base64:8",
			"constraints": {"min_length": 32},
		}),
		"API_COUNT": binding({"type": "integer", "local_default": "ten"}),
	})
		with data.conventions.index as index
	messages(found, "ENVS-07") == {
		"binding API_MODE: type enum needs a values list",
		"binding API_KEY: required: true and a default contradict each other; drop one",
		"binding API_KEY: local_default and local_generate are both set; a binding has one local source",
		"binding API_KEY: local_generate mints secret material, so the binding is sensitivity: secret",
		`binding API_POOL_URL: allow_empty: true needs default: ""`,
		"binding API_Name: grammar_exempt: true needs a grammar_exempt_reason saying why",
		"binding API_SHORT_KEY: local_generate yields fewer characters than constraints.min_length",
		"binding API_COUNT: local_default does not satisfy the binding's type",
	}
}

test_envs_07_local_default_types if {
	count(env_schema.findings) == 0 with input as one({
		"API_RATIO": binding({"type": "number", "local_default": 0.5}),
		"API_MODE": binding({"type": "enum", "values": ["a", "b"], "local_default": "a"}),
		"API_TAGS": binding({"type": "list", "local_default": "a,b"}),
		"ENABLE_X": binding({"type": "boolean", "local_default": true}),
		"API_KEY": binding({"sensitivity": "secret", "local_generate": "hex:16", "constraints": {"min_length": 32}}),
	})
		with data.conventions.index as index
}

test_envs_07_schema_invariants if {
	docs := [td.file(path, schema({
		"runtime": "go",
		"bindings": {
			"VITE_API_URL": binding({"format": "url", "required": true}),
			"API_SIGNING_KEY": binding({"sensitivity": "secret"}),
		},
		"generated": {"pydantic": {}, "ts": {"framework": "t3-core-dynamic", "output_path": "src/env.ts"}},
		"shared_with": [
			{"name": "API_MISSING", "apps": [{"service": "api", "path": "/a"}, {"service": "web", "path": "/w"}]},
			{"name": "API_SIGNING_KEY", "apps": [{"service": "web", "path": "/w"}, {"service": "admin", "path": "/x"}]},
		],
		"coolify_env": {"required": ["API_SIGNING_KEY"], "optional": ["API_SIGNING_KEY"]},
	}))]
	found := env_schema.findings with input as docs with data.conventions.index as index
	messages(found, "ENVS-07") == {
		"generated.pydantic is only for runtime python, and runtime is go",
		"generated.ts is only for runtime sveltekit, and runtime is go",
		concat(" ", [
			"binding VITE_API_URL is read by the browser at server start (t3-core-dynamic),",
			"so it needs a default and cannot be required",
		]),
		"shared_with names API_MISSING, which is not a binding; declare it in bindings",
		"shared_with entry API_SIGNING_KEY does not list this service, api, in apps",
		"coolify_env lists API_SIGNING_KEY as both required and optional; keep one",
	}
}

shared(service, sensitivity, others) := {
	"service": service,
	"runtime": "python",
	"bindings": {"API_SIGNING_KEY": binding({"sensitivity": sensitivity})},
	"shared_with": [{
		"name": "API_SIGNING_KEY",
		"apps": [{"service": s, "path": "/p"} | some s in array.concat([service], others)],
	}],
}

test_envs_08_mismatch if {
	docs := [
		td.file("api/env.schema.yaml", shared("api", "secret", ["worker"])),
		td.file("worker/env.schema.yaml", shared("worker", "internal", ["api"])),
	]
	found := env_schema.findings with input as docs with data.conventions.index as index
	td.pairs(found) == {["ENVS-08", "api/env.schema.yaml"], ["ENVS-08", "worker/env.schema.yaml"]}
	concat(" ", [
		"shared variable API_SIGNING_KEY has sensitivity secret here but internal in worker/env.schema.yaml;",
		"make every copy agree",
	]) in messages(found, "ENVS-08")
}

test_envs_08_symmetry if {
	worker := {
		"service": "worker", "runtime": "python",
		"bindings": {"API_SIGNING_KEY": binding({"sensitivity": "secret"})},
	}
	docs := [
		td.file("api/env.schema.yaml", shared("api", "secret", ["worker"])),
		td.file("worker/env.schema.yaml", worker),
	]
	found := env_schema.findings with input as docs with data.conventions.index as index
	messages(found, "ENVS-08") == {concat(" ", [
		"shared variable API_SIGNING_KEY names service worker, but worker/env.schema.yaml declares",
		"no shared_with entry for it; add one there",
	])}
}

test_generated_length if {
	env_schema.generated_length("hex:16") == 32
	env_schema.generated_length("base64:32") == 44
	env_schema.generated_length("base64url:1") == 4
}
