package conventions.checks.environment.env_grammar_test

import data.conventions.checks.environment.env_grammar
import data.conventions.checks.environment.env_schema_test as t
import data.conventions.lib.testdata_test as td

test_conforming_names if {
	docs := [td.file(t.path, t.schema({
		"bindings": t.conforming,
		"naming": {"components": ["API", "DATABASE", "WORKERS"], "vendor_prefixes": ["OTEL_"]},
	}))]
	count(env_grammar.findings) == 0 with input as docs
}

test_envs_04_case if {
	found := env_grammar.findings with input as t.one({"Api_port": t.binding({})})
	t.messages(found, "ENVS-04") == {
		"binding Api_port is not UPPER_SNAKE_CASE; rename it to upper-case words joined by underscores",
	}
}

test_envs_04_component if {
	found := env_grammar.findings with input as t.one({"SERVER_PORT": t.binding({})})
	t.messages(found, "ENVS-04") == {concat(" ", [
		"binding SERVER_PORT does not start with a declared component (API, DATABASE); rename it,",
		"or add its component to naming.components",
	])}
}

test_envs_04_without_components if {
	docs := [td.file(t.path, {"service": "api", "runtime": "go", "bindings": {"SERVER_PORT": t.binding({})}})]
	count(env_grammar.findings) == 0 with input as docs
}

test_envs_09_boolean if {
	found := env_grammar.findings with input as t.one({
		"API_AUDIT": t.binding({"type": "boolean"}),
		"VITE_BILLING": t.binding({"type": "boolean"}),
	})
	t.messages(found, "ENVS-09") == {
		"boolean API_AUDIT does not start with ENABLE_, IS_, HAS_ or SHOULD_; rename it, e.g. ENABLE_...",
		concat(" ", [
			"boolean VITE_BILLING does not start with ENABLE_, IS_, HAS_ or SHOULD_;",
			"a browser flag is <client prefix>ENABLE_, e.g. VITE_ENABLE_...",
		]),
	}
}

test_envs_10_unit if {
	found := env_grammar.findings with input as t.one({"API_TIMEOUT_MILLISECONDS": t.binding({})})
	t.messages(found, "ENVS-10") == {
		"binding API_TIMEOUT_MILLISECONDS spells out its unit; end it in _MS instead of _MILLISECONDS",
	}
}

test_envs_11_stutter if {
	found := env_grammar.findings with input as t.one({"API_API_PORT": t.binding({})})
	t.messages(found, "ENVS-11") == {"binding API_API_PORT repeats API; say it once"}
}

test_envs_12_url if {
	found := env_grammar.findings with input as t.one({"API_ENDPOINT": t.binding({"format": "url"})})
	td.ids(found) == {"ENVS-12"}
	t.messages(found, "ENVS-12") == {concat(" ", [
		"binding API_ENDPOINT holds a URL; end its name in _URL or _BASE_URL, or leave format unset",
		"if it names an identifier rather than an address",
	])}
}

test_envs_12_url_identifier_without_format if {
	identifier := t.binding({"constraints": {"pattern": "^https://"}})
	found := env_grammar.findings with input as t.one({"API_JWT_ISSUER": identifier})
	not "ENVS-12" in td.ids(found)
}

test_envs_13_nested if {
	docs := t.one({"API_EXPORT_SIZE": t.binding({"nested": {"group": "api", "field": "size"}})})
	found := env_grammar.findings with input as docs
	t.messages(found, "ENVS-13") == {concat(" ", [
		"binding API_EXPORT_SIZE is nested, so its name separates group, sub-model and field with __,",
		"e.g. API__SIZE",
	])}
}

test_envs_14_client if {
	docs := [td.file(t.path, t.schema({
		"bindings": {"API_BASE_URL": t.binding({"format": "url", "consumer": "client"})},
		"naming": {"components": ["API"], "client_prefixes": ["PUBLIC_"]},
		"generated": {"ts": {"framework": "t3-core-client", "client_prefix": "APP_", "output_path": "x"}},
		"runtime": "sveltekit",
	}))]
	found := env_grammar.findings with input as docs
	t.messages(found, "ENVS-14") == {
		"binding API_BASE_URL is read by the browser, so it starts with a client prefix (APP_, PUBLIC_)",
	}
}
