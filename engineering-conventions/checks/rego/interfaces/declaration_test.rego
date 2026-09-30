package conventions.checks.interfaces.declaration_test

import data.conventions.checks.interfaces.declaration
import data.conventions.lib.testdata_test as td

messages(found, id) := {f.message | some f in found; f.id == id}

identity := td.repository(object.union(td.identity, {"layout": {"product": "platform-api"}}))

bundle := {
	"id": "contracts",
	"kind": "bundle",
	"source": "platform-api/contracts/",
	"publish_workflow": "release.yml",
	"location": "https://github.com/example/platform-api/releases",
	"docs": "platform-api/contracts/README.md",
}

public := {
	"id": "public-http",
	"format": "openapi",
	"definitions": ["platform-api/contracts/openapi/public.json"],
	"delivered_by": "contracts",
	"compatibility": "gated",
	"audience": "public",
}

events := {
	"id": "events",
	"format": "json-schema",
	"definitions": ["platform-api/contracts/events/*.schema.json"],
	"delivered_by": "contracts",
	"compatibility": "versioned",
}

paths := [
	"platform-api/contracts/README.md",
	"platform-api/contracts/.gitkeep",
	"platform-api/contracts/openapi/public.json",
	"platform-api/contracts/events/order.created.v1.schema.json",
	"platform-api/contracts/vendor/specifications/schemas/release.json",
	"platform-api/proto/api.proto",
]

declared(interfaces) := td.file(".repo/outputs.toml", {
	"schema_version": 2,
	"outputs": [bundle],
	"interfaces": interfaces,
})

repo(extra, interfaces) := [identity, td.inventory(array.concat(paths, extra)), declared(interfaces)]

test_conforming_interfaces if {
	found := declaration.findings with input as repo([], [public, events])
		with data.conventions.index as td.index
	count(found) == 0
}

test_iface_01_undeclared_file if {
	given := repo(["platform-api/contracts/state-machines/order.mmd"], [public, events])
	found := declaration.findings with input as given
		with data.conventions.index as td.index
	td.pairs(found) == {["IFACE-01", "platform-api/contracts/state-machines/order.mmd"]}
	messages(found, "IFACE-01") == {concat(" ", [
		"platform-api/contracts/state-machines/order.mmd is in platform-api/contracts/, which holds only what",
		"other repositories build against, but no interface in .repo/outputs.toml covers it; add it to an",
		"interface's definitions, or move it out of platform-api/contracts/",
	])}
}

test_iface_01_needs_a_layout if {
	found := declaration.findings with input as [
		td.repository(td.identity),
		td.inventory(["platform-api/contracts/x.json"]),
		declared([]),
	]
		with data.conventions.index as td.index
	count(messages(found, "IFACE-01")) == 0
}

test_iface_01_root_contracts_without_a_product if {
	found := declaration.findings with input as [
		td.repository(object.union(td.identity, {"layout": {"product": ""}})),
		td.inventory(["contracts/x.json"]),
		declared([]),
	]
		with data.conventions.index as td.index
	td.pairs(found) == {["IFACE-01", "contracts/x.json"]}
}

test_iface_02_unregistered_values if {
	wrong := object.union(public, {"format": "swagger", "compatibility": "stable"})
	found := declaration.findings with input as repo([], [wrong, events])
		with data.conventions.index as td.index
	messages(found, "IFACE-02") == {
		concat("", [
			`interface "public-http" has format "swagger", which is not registered; use one of "asyncapi", `,
			`"env-schema", "json-schema", "openapi", "protobuf", "weaver"`,
		]),
		concat("", [
			`interface "public-http" has compatibility "stable", which is not registered; use one of `,
			`"gated", "lockstep", "versioned"`,
		]),
	}
}

test_iface_03_duplicate_ids if {
	found := declaration.findings with input as repo([], [public, object.union(events, {"id": "public-http"})])
		with data.conventions.index as td.index
	messages(found, "IFACE-03") == {concat(" ", [
		`interface ID "public-http" is used more than once; give each interface its own ID, which consumers`,
		"address as <repository>#<id>",
	])}
}

test_iface_04_definitions_match_nothing if {
	given := repo([], [public, object.union(events, {"definitions": ["platform-api/contracts/event/*.json"]})])
	found := declaration.findings with input as given
		with data.conventions.index as td.index
	messages(found, "IFACE-04") == {concat(" ", [
		`interface "events" names definitions "platform-api/contracts/event/*.json", which matches no file the`,
		"repository holds; point it at the files that define the interface",
	])}
}

test_iface_04_a_directory_matches_its_files if {
	given := repo([], [public, object.union(events, {"definitions": ["platform-api/contracts/events"]})])
	found := declaration.findings with input as given
		with data.conventions.index as td.index
	count(messages(found, "IFACE-04")) == 0
}

test_iface_05_file_in_two_interfaces if {
	everything := object.union(events, {
		"id": "all",
		"definitions": ["platform-api/contracts/**"],
		"compatibility": "gated",
	})
	found := declaration.findings with input as repo([], [public, everything])
		with data.conventions.index as td.index
	td.pairs(found) == {["IFACE-05", "platform-api/contracts/openapi/public.json"]}
	messages(found, "IFACE-05") == {concat(" ", [
		`platform-api/contracts/openapi/public.json belongs to interfaces "all", "public-http"; narrow their`,
		"definitions so each file belongs to one interface",
	])}
}

test_iface_06_unknown_output if {
	found := declaration.findings with input as repo([], [object.union(public, {"delivered_by": "api-bundle"}), events])
		with data.conventions.index as td.index
	messages(found, "IFACE-06") == {concat(" ", [
		`interface "public-http" is delivered by "api-bundle", which is not an output in .repo/outputs.toml;`,
		"name the bundle, site or library output that delivers it",
	])}
}

test_iface_06_an_image_delivers_nothing if {
	image := object.union(bundle, {"id": "image", "kind": "image"})
	found := declaration.findings with input as [
		identity,
		td.inventory(paths),
		td.file(".repo/outputs.toml", {
			"schema_version": 2,
			"outputs": [bundle, image],
			"interfaces": [object.union(public, {"delivered_by": "image"}), events],
		}),
	]
		with data.conventions.index as td.index
	messages(found, "IFACE-06") == {concat("", [
		`interface "public-http" is delivered by "image", whose kind is "image"; an interface's files are `,
		"delivered by a bundle, library or site output",
	])}
}

test_iface_07_unversioned_file if {
	given := repo(["platform-api/contracts/events/order.paid.schema.json"], [public, events])
	found := declaration.findings with input as given
		with data.conventions.index as td.index
	td.pairs(found) == {["IFACE-07", "platform-api/contracts/events/order.paid.schema.json"]}
	messages(found, "IFACE-07") == {concat(" ", [
		`platform-api/contracts/events/order.paid.schema.json belongs to versioned interface "events" but its`,
		"name carries no .vN.; name it for its major version, such as order.paid.v1.schema.json",
	])}
}

test_iface_07_suggestions if {
	declaration.suggestion("a.proto") == "a.v1.proto"
	declaration.suggestion("README") == "README.v1"
}

test_iface_08_outside_the_contracts_directory if {
	proto := {
		"id": "grpc",
		"format": "protobuf",
		"definitions": ["platform-api/proto/"],
		"delivered_by": "contracts",
		"compatibility": "gated",
	}
	found := declaration.findings with input as repo([], [public, events, proto])
		with data.conventions.index as td.index
	messages(found, "IFACE-08") == {concat(" ", [
		`interface "grpc" names definitions "platform-api/proto/" outside platform-api/contracts/; keep every`,
		"interface the repository offers there, so its consumers and checks find it in one place",
	])}
}

test_iface_08_a_vendored_copy_is_not_offered if {
	vendored := object.union(public, {
		"id": "borrowed",
		"definitions": ["platform-api/contracts/vendor/specifications/schemas/release.json"],
	})
	found := declaration.findings with input as repo([], [public, events, vendored])
		with data.conventions.index as td.index
	count(messages(found, "IFACE-08")) == 1
}

test_labels_without_an_id if {
	found := declaration.findings with input as repo([], [public, events, {"format": "swagger"}])
		with data.conventions.index as td.index
	expected := concat("", [
		`interface 3 has format "swagger", which is not registered; use one of "asyncapi", "env-schema", `,
		`"json-schema", "openapi", "protobuf", "weaver"`,
	])
	expected in messages(found, "IFACE-02")
}
