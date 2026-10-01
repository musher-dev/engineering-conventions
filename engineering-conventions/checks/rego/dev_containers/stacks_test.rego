package conventions.checks.dev_containers.stacks_test

import data.conventions.checks.dev_containers.stacks
import data.conventions.lib.testdata_test as td

path := ".devcontainer/stacks/postgres/compose.yaml"

compose(services) := [td.file(path, {"services": services}), td.inventory([path])]

postgres(ports) := {"postgres": {"image": "pgvector/pgvector:0.8.5-pg17", "ports": ports}}

messages(found, id) := {f.message | some f in found; f.id == id}

test_a_conforming_stack if {
	count(stacks.findings) == 0 with input as compose(postgres(["127.0.0.1:15432:5432"]))
}

test_compose_outside_the_dev_container_is_ignored if {
	docs := [td.file("platform-api/compose.yaml", {"services": postgres(["5432:5432"])})]
	count(stacks.findings) == 0 with input as docs
}

test_devc_11_floating_images if {
	services := {
		"a": {"image": "redis"},
		"b": {"image": "pgvector/pgvector:latest"},
		"c": {"image": "ghcr.io/azimuttapp/azimutt:main@sha256:f5a8"},
		"d": {"image": "${IMAGE:-redis:7}"},
		"e": {"build": "./e"},
	}
	found := stacks.findings with input as compose(services)
	td.pairs(found) == {["DEVC-11", path]}
	count(messages(found, "DEVC-11")) == 2
}

test_devc_12_every_interface if {
	found := stacks.findings with input as compose(postgres([
		"15432:5432", 5433, "5434", "0.0.0.0:15435:5435",
		{"target": 5436, "published": 15436},
	]))
	messages(found, "DEVC-12") == {
		every_interface("15432:5432", "127.0.0.1:15432:5432"),
		every_interface("5433", "127.0.0.1:<host port>:5433"),
		every_interface("5434", "127.0.0.1:<host port>:5434"),
		every_interface("0.0.0.0:15435:5435", "127.0.0.1:15435:5435"),
		every_interface("15436:5436", "127.0.0.1:15436:5436"),
	}
}

every_interface(spec, example) := sprintf(
	"the service postgres publishes %s on every network interface; bind it to 127.0.0.1, as in %q",
	[spec, example],
)

test_devc_12_loopback_forms_pass if {
	docs := compose(postgres([
		"127.0.0.1:15432:5432/tcp",
		"[::1]:15433:6379",
		{"target": 5434, "published": "15434", "host_ip": "127.0.0.1"},
		"${PORT:-15435}:5435",
	]))
	count(stacks.findings) == 0 with input as docs
}

test_devc_13_outside_the_range if {
	found := stacks.findings with input as compose(postgres([
		"127.0.0.1:5432:5432", "127.0.0.1:15460-15461:9000-9001", "[::1]:8080:80",
	]))
	messages(found, "DEVC-13") == {
		"the service postgres publishes host port 5432, outside the reserved range 15432-15460; move it into the range",
		"the service postgres publishes host port 15461, outside the reserved range 15432-15460; move it into the range",
		"the service postgres publishes host port 8080, outside the reserved range 15432-15460; move it into the range",
	}
}

test_numbers_in if {
	stacks.numbers_in("15432") == {15432}
	stacks.numbers_in("15432-15434") == {15432, 15433, 15434}
	stacks.numbers_in("") == set()
}

schema_path := "platform-api/env.schema.yaml"

requiring(capability, range) := td.file(schema_path, {
	"service": "platform-api",
	"bindings": {},
	"requires": {"cache": {"capability": capability, "version": range, "description": "Counters."}},
})

stack(labels) := [
	requiring("valkey", ">=9, <10"),
	td.file(path, {"services": {"valkey": {"image": "valkey/valkey:9.0.1", "labels": labels}}}),
	td.inventory([path, schema_path]),
]

test_devc_16_a_version_in_range if {
	labels := {"dev.musher.capability": "valkey", "dev.musher.capability-version": "9.0.1"}
	count(stacks.findings) == 0 with input as stack(labels)
	listed := ["dev.musher.capability=valkey", "dev.musher.capability-version=9", "other"]
	count(stacks.findings) == 0 with input as stack(listed)
}

test_devc_16_unlabelled_and_unrequired_stacks_are_silent if {
	count(stacks.findings) == 0 with input as stack({"maintainer": "x"})
	labels := {"dev.musher.capability": "postgresql", "dev.musher.capability-version": "17"}
	count(stacks.findings) == 0 with input as stack(labels)
}

test_devc_16_a_version_outside_the_range if {
	found := stacks.findings with input as stack(["dev.musher.capability=valkey", "dev.musher.capability-version=8.1.3"])
	messages(found, "DEVC-16") == {concat(" ", [
		"the service valkey runs valkey 8.1.3, but platform-api/env.schema.yaml requires >=9, <10 for cache;",
		"run a version in the range, and set dev.musher.capability-version to match",
	])}
	td.pairs(found) == {["DEVC-16", path]}
	above := {"dev.musher.capability": "valkey", "dev.musher.capability-version": "10.0"}
	count(stacks.findings) == 1 with input as stack(above)
}

test_devc_16_a_number_label if {
	labels := {"dev.musher.capability": "valkey", "dev.musher.capability-version": 9}
	count(stacks.findings) == 0 with input as stack(labels)
}

test_devc_16_no_version if {
	found := stacks.findings with input as stack({"dev.musher.capability": "valkey"})
	messages(found, "DEVC-16") == {concat(" ", [
		"the service valkey labels dev.musher.capability valkey but no dev.musher.capability-version;",
		"label the version of the engine it runs",
	])}
}

test_devc_16_not_a_version if {
	labels := {"dev.musher.capability": "valkey", "dev.musher.capability-version": "9-alpine"}
	found := stacks.findings with input as stack(labels)
	messages(found, "DEVC-16") == {concat(" ", [
		`the service valkey labels dev.musher.capability-version "9-alpine", which is not a version;`,
		"write the engine's version as integers separated by dots",
	])}
}
