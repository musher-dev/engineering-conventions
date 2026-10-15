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

config_path := ".devcontainer/devcontainer.json"

forwarding(forward, attributes) := {
	"image": "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
	"forwardPorts": forward,
	"portsAttributes": attributes,
}

with_config(config_files, services) := array.concat(
	[td.file(p, c) | some p, c in config_files],
	[td.file(path, {"services": services}), td.inventory(array.concat([p | some p, _ in config_files], [path]))],
)

described := {"15432": {"label": "PostgreSQL"}}

test_a_conforming_forwarded_stack if {
	docs := with_config(
		{config_path: forwarding([15432, "15433", "postgres:5432"], {
			"15432": {"label": "PostgreSQL"},
			"15433-15434": {"label": "Spare"},
			".+/server\\.js": {"onAutoForward": "silent"},
		})},
		postgres(["127.0.0.1:15432:5432", "127.0.0.1:15433:5433", "${PORT}:5434"]),
	)
	count(stacks.findings) == 0 with input as docs
}

test_devc_19_each_side if {
	docs := with_config(
		{config_path: forwarding([15432, "15433"], {"15432": {}, "15434": {}})},
		postgres(["127.0.0.1:15432:5432", "127.0.0.1:15433:5433"]),
	)
	found := stacks.findings with input as docs
	td.pairs(found) == {["DEVC-19", config_path]}
	messages(found, "DEVC-19") == {
		"forwardPorts lists 15433, but portsAttributes has no entry for it; add one with the port's label",
		"portsAttributes describes 15434, which forwardPorts does not list; forward it, or remove the entry",
	}
}

test_devc_19_without_either_property if {
	docs := [td.file(config_path, {"image": "x:1"}), td.inventory([config_path])]
	count(stacks.findings) == 0 with input as docs
}

test_devc_20_not_forwarded if {
	docs := with_config(
		{config_path: forwarding([15432], described)},
		postgres(["127.0.0.1:15432:5432", "127.0.0.1:15433-15434:6379-6380", {"target": 9000, "published": 15435}]),
	)
	found := stacks.findings with input as docs
	messages(found, "DEVC-20") == {not_forwarded(port, config_path) | some port in [15433, 15434, 15435]}
}

not_forwarded(port, paths) := sprintf(
	"the service postgres publishes host port %d, which %s does not forward; add it to forwardPorts",
	[port, paths],
)

test_devc_20_without_a_configuration if {
	count(stacks.findings) == 0 with input as compose(postgres(["127.0.0.1:15432:5432"]))
}

test_devc_20_pairs_a_named_configuration if {
	named := ".devcontainer/stacks/devcontainer.json"
	docs := with_config(
		{config_path: forwarding([15432], described), named: forwarding([], {})},
		postgres(["127.0.0.1:15432:5432"]),
	)
	found := stacks.findings with input as docs
	messages(found, "DEVC-20") == {not_forwarded(15432, named)}
}

test_devc_20_any_named_configuration if {
	python := ".devcontainer/python/devcontainer.json"
	node := ".devcontainer/node/devcontainer.json"
	forwarded := with_config(
		{python: forwarding([15432], described), node: forwarding([], {})},
		postgres(["127.0.0.1:15432:5432"]),
	)
	count(stacks.findings) == 0 with input as forwarded
	neither := with_config({python: forwarding([], {}), node: forwarding([], {})}, postgres(["127.0.0.1:15432:5432"]))
	found := stacks.findings with input as neither
	messages(found, "DEVC-20") == {not_forwarded(15432, concat(" or ", [node, python]))}
}

outside(port) := sprintf(
	"forwardPorts lists %d, outside the reserved range 15432-15460; %s",
	[port, "forward the host port a stack publishes from the range"],
)

test_devc_21_outside_the_range if {
	docs := with_config(
		{config_path: forwarding([5432, "15461", 15460, "db:5432"], {"5432": {}, "15461": {}, "15460": {}})},
		postgres(["127.0.0.1:15460:5432"]),
	)
	found := stacks.findings with input as docs
	td.pairs(found) == {["DEVC-21", config_path]}
	messages(found, "DEVC-21") == {outside(5432), outside(15461)}
}

test_devc_21_leaves_an_application_port_alone if {
	docs := with_config(
		{config_path: forwarding([15432, 17200], {"15432": {}, "17200": {}})},
		postgres(["127.0.0.1:15432:5432"]),
	)
	found := stacks.findings with input as docs
	not "DEVC-21" in {f.id | some f in found}
}
