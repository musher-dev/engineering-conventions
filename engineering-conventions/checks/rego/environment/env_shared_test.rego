package conventions.checks.environment.env_shared_test

import data.conventions.checks.environment.env_schema_test as t
import data.conventions.checks.environment.env_shared
import data.conventions.lib.testdata_test as td

tiers := ["development", "production", "staging", "test"]

conforming := {
	"MUSHER_ENVIRONMENT": t.binding({"type": "enum", "values": tiers, "required": true}),
	"VITE_MUSHER_ENVIRONMENT": t.binding({"type": "enum", "values": tiers, "consumer": "client"}),
	"MUSHER_DEVELOPER_SLUG": t.binding({}),
	"NODE_ENV": t.binding({"type": "enum", "values": ["development", "production"]}),
	"RUNNER_ENVIRONMENT_NAME": t.binding({"grammar_exempt": true, "grammar_exempt_reason": "x"}),
	"OTEL_SDK_DISABLED": t.binding({"type": "boolean"}),
	"OTEL_EXPORTER_OTLP_TRACES_ENDPOINT": t.binding({"format": "url"}),
	"API_GITHUB_APP_PRIVATE_KEY": t.binding({"sensitivity": "secret"}),
	"E2E_TEST_TIMEOUT_SEC": t.binding({"type": "integer"}),
	"API_DEVICE_ID": t.binding({}),
	"API_LOG_LEVEL": t.binding({"type": "enum", "values": ["trace", "debug", "info", "warn", "error"], "default": "info"}),
	"LOG_FORMAT": t.binding({"type": "enum", "values": ["json", "text"]}),
	"OTEL_LOG_LEVEL": t.binding({"default": "INFO"}),
	"API_ENVIRONMENT_FILE": t.binding({}),
}

# Exempt from the grammar is not exempt from the vendor's prefix: the one
# finding is ENVS-29's.
test_conforming if {
	found := env_shared.findings with input as t.one(conforming)
	{f.message | some f in found} == {concat(" ", [
		"binding RUNNER_ENVIRONMENT_NAME is under RUNNER_, which GitHub Actions reserves, and GitHub Actions",
		"defines no such variable; use the name GitHub Actions defines, or name it after the program that",
		"reads it, outside RUNNER_",
	])}
}

test_envs_28_carriers if {
	found := env_shared.findings with input as t.one({
		"DEPLOYMENT_ENVIRONMENT": t.binding({}),
		"COLLECTOR_DEPLOYMENT_ENVIRONMENT": t.binding({}),
		"OTEL_ENVIRONMENT": t.binding({}),
		"API_ENV": t.binding({}),
		"VITE_APP_ENV": t.binding({"consumer": "client"}),
		"MUSHER_ENV": t.binding({}),
		"API_STAGE": t.binding({"type": "enum", "values": ["dev", "prod"]}),
	})
	{f.id | some f in found} == {"ENVS-28"}
	count(found) == 7
	concat(" ", [
		"binding VITE_APP_ENV carries the deployment environment, which reaches a process only as",
		"VITE_MUSHER_ENVIRONMENT; read that instead, and retire VITE_APP_ENV with it as the replacement",
	]) in t.messages(found, "ENVS-28")
}

test_envs_28_values if {
	found := env_shared.findings with input as t.one({"MUSHER_ENVIRONMENT": t.binding({
		"type": "enum",
		"values": ["prod", "staging", "qa"],
		"default": "dev",
		"local_default": "development",
		"constraints": {"pattern": "^(prod|staging)$"},
	})})
	t.messages(found, "ENVS-28") == {
		"binding MUSHER_ENVIRONMENT allows the slug prod; its value is the name, so write production",
		"binding MUSHER_ENVIRONMENT defaults to the slug dev; its value is the name, so write development",
		concat("", [
			"binding MUSHER_ENVIRONMENT allows qa, which is not a deployment environment; ",
			"its values are development, production, staging, test",
		]),
		concat("", [
			"binding MUSHER_ENVIRONMENT has a pattern that admits the slug prod; ",
			"its value is the name, so admit production instead",
		]),
	}
}

test_envs_29_undefined_names if {
	found := env_shared.findings with input as t.one({
		"OTEL_ENABLED": t.binding({"type": "boolean"}),
		"OTEL_SERVICE": t.binding({}),
		"OTEL_DEPLOYMENT_ENVIRONMENT": t.binding({}),
	})
	t.messages(found, "ENVS-29") == {
		concat(" ", [
			"binding OTEL_ENABLED is under OTEL_, which OpenTelemetry reserves, and OpenTelemetry defines no",
			"such variable; use OTEL_SDK_DISABLED, which is true where this was false",
		]),
		concat(" ", [
			"binding OTEL_SERVICE is under OTEL_, which OpenTelemetry reserves, and OpenTelemetry defines no",
			"such variable; use OTEL_SERVICE_NAME",
		]),
	}
}

test_envs_29_runner_names_in_a_service if {
	docs := array.concat([td.repository(td.identity)], t.one({
		"GITHUB_SHA": t.binding({}),
		"GITHUB_REF_NAME": t.binding({"lifecycle": "build-time"}),
	}))
	found := env_shared.findings with input as docs
	t.messages(found, "ENVS-29") == {concat(" ", [
		"binding GITHUB_SHA is set by GitHub Actions only inside a workflow run, and a deployed service never",
		"runs there; pass the value in under the service's own name, or mark the binding lifecycle: build-time",
		"if only the build reads it",
	])}
	library := [td.repository(object.union(td.identity, {"kind": "library"})), t.one({"GITHUB_SHA": t.binding({})})[0]]
	count(env_shared.findings) == 0 with input as library
}

test_envs_30_tier_words if {
	found := env_shared.findings with input as t.one({
		"PROD_READONLY_URL": t.binding({}),
		"ENABLE_DEV_TOOLS": t.binding({"type": "boolean"}),
		"WORKERS__STAGING__BATCH_SIZE": t.binding({}),
	})
	t.messages(found, "ENVS-30") == {
		concat(" ", [
			"binding PROD_READONLY_URL names the deployment environment (PROD); the environment selects the",
			"value, not the name, so call it READONLY_URL and set a different value in each environment",
		]),
		concat(" ", [
			"binding ENABLE_DEV_TOOLS names the deployment environment (DEV); the environment selects the",
			"value, not the name, so call it ENABLE_TOOLS and set a different value in each environment",
		]),
		concat(" ", [
			"binding WORKERS__STAGING__BATCH_SIZE names the deployment environment (STAGING); the environment",
			"selects the value, not the name, so call it WORKERS__BATCH_SIZE and set a different value in each",
			"environment",
		]),
	}
}

test_envs_31_stems if {
	found := env_shared.findings with input as t.one({
		"API_LOG_LEVEL": t.binding({"type": "enum", "values": ["INFO", "warning"]}),
		"WORKERS_LOG_FORMAT": t.binding({"local_default": "pretty"}),
	})
	t.messages(found, "ENVS-31") == {
		concat("", [
			"binding API_LOG_LEVEL allows INFO, but every _LOG_LEVEL holds one of ",
			"trace, debug, info, warn, error; write info",
		]),
		"binding API_LOG_LEVEL allows warning, but every _LOG_LEVEL holds one of trace, debug, info, warn, error",
		"binding WORKERS_LOG_FORMAT defaults locally to pretty, but every _LOG_FORMAT holds one of json, text",
	}
}
