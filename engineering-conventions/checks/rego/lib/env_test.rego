package conventions.lib.env_test

import data.conventions.lib.env
import data.conventions.lib.testdata_test as td

schema(contents) := [td.file("api/env.schema.yaml", object.union({"service": "api", "bindings": {}}, contents))]

test_documents_are_env_schemas_only if {
	docs := array.concat(schema({}), [td.file("api/other.yaml", {"service": "x"})])
	object.keys(env.documents) == {"api/env.schema.yaml"} with input as docs
}

test_bindings if {
	docs := schema({"bindings": {"API_PORT": {"type": "integer"}, "BROKEN": "not a mapping"}})
	{entry.name | some entry in env.bindings} == {"API_PORT"} with input as docs
}

test_grammar_bindings_skip_exemptions if {
	docs := schema({
		"naming": {"vendor_prefixes": ["OTEL_"]},
		"bindings": {"API_PORT": {}, "OTEL_SERVICE_NAME": {}, "Legacy": {"grammar_exempt": true}},
	})
	{entry.name | some entry in env.grammar_bindings} == {"API_PORT"} with input as docs
}

test_client_prefixes if {
	env.client_prefixes("api/env.schema.yaml") == {"VITE_", "PUBLIC_"} with input as schema({})
	docs := schema({
		"naming": {"client_prefixes": ["APP_"]},
		"generated": {"ts": {"client_prefix": "WEB_"}},
	})
	env.client_prefixes("api/env.schema.yaml") == {"APP_", "WEB_"} with input as docs
}

test_vendored_copies_are_not_schemas if {
	docs := [
		td.repository(object.union(td.identity, {"layout": {"product": "api"}})),
		td.file("api/contracts/vendor/host-agent/contracts/env.schema.yaml", {"service": "host-agent", "bindings": {}}),
		td.file("api/env.schema.yaml", {"service": "api", "bindings": {}}),
	]
	object.keys(env.documents) == {"api/env.schema.yaml"} with input as docs
}
