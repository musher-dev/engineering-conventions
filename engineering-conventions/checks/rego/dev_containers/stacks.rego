# METADATA
# title: Dev container stacks
# description: >-
#   The compose stacks under .devcontainer/ run fixed images (DEVC-11), publish
#   their ports on the loopback address only (DEVC-12), and publish them from
#   the reserved range (DEVC-13).
# scope: package
# custom:
#   convention: EC-0028
package conventions.checks.dev_containers.stacks

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.mise

compose_pattern := `^\.devcontainer/(.+/)?(docker-)?compose(\.[^/]+)?\.ya?ml$`

# The reserved block of host ports for dev container stacks.
port_range := {"low": 15432, "high": 15460}

services contains {"path": doc.path, "name": name, "service": service} if {
	some doc in files.own_documents
	regex.match(compose_pattern, doc.path)
	is_object(doc.contents.services)
	some name, service in doc.contents.services
	is_object(service)
}

# DEVC-11
findings contains lib.finding("DEVC-11", entry.path, message) if {
	some entry in services
	image := entry.service.image
	is_string(image)
	mise.floating_image(image)
	message := sprintf(
		"the service %s runs %s, which moves without a commit; name a fixed tag such as a version, or add a digest",
		[entry.name, image],
	)
}

# DEVC-12
findings contains lib.finding("DEVC-12", port.path, message) if {
	some port in published
	not loopback(port.host_ip)
	message := sprintf(
		"the service %s publishes %s on every network interface; bind it to 127.0.0.1, as in \"127.0.0.1:%s\"",
		[port.service, port.spec, loopback_example(port)],
	)
}

# DEVC-13
findings contains lib.finding("DEVC-13", port.path, message) if {
	some port in published
	some host_port in port.host_ports
	not in_range(host_port)
	message := sprintf(
		"the service %s publishes host port %d, outside the reserved range %d-%d; move it into the range",
		[port.service, host_port, port_range.low, port_range.high],
	)
}

in_range(number) if {
	number >= port_range.low
	number <= port_range.high
}

loopback(ip) if ip in {"127.0.0.1", "::1", "[::1]", "localhost"}

# The same port bound to the loopback address; a port with no host side
# gets a placeholder for the one to choose.
loopback_example(port) := trim_prefix(port.spec, concat("", [port.host_ip, ":"])) if port.host_ip != ""

loopback_example(port) := port.spec if {
	port.host_ip == ""
	contains(port.spec, ":")
}

loopback_example(port) := sprintf("<host port>:%s", [port.spec]) if {
	port.host_ip == ""
	not contains(port.spec, ":")
}

# Every port a service publishes, as {path, service, spec, host_ip,
# host_ports}. A port written with a variable is left alone: the
# environment decides it.
published contains port if {
	some entry in services
	some value in object.get(entry.service, "ports", [])
	port := object.union(
		{"path": entry.path, "service": entry.name},
		parse(value),
	)
}

# The short syntax: [HOST_IP:][HOST:]CONTAINER[/PROTOCOL], as a string or a
# bare number.
parse(value) := {"spec": sprintf("%d", [value]), "host_ip": "", "host_ports": set()} if is_number(value)

parse(value) := short(spec) if {
	is_string(value)
	not contains(value, "$")
	spec := regex.replace(value, `/[a-z]+$`, "")
}

# The long syntax.
parse(value) := {"spec": spec, "host_ip": host_ip, "host_ports": host_ports} if {
	is_object(value)
	not contains(sprintf("%v", [value]), "$")
	host_ip := object.get(value, "host_ip", "")
	published_value := object.get(value, "published", "")
	host_ports := numbers_in(sprintf("%v", [published_value]))
	spec := sprintf("%v:%v", [published_value, object.get(value, "target", "")])
}

# An IPv6 address is bracketed; its colons are not separators.
short(spec) := {"spec": spec, "host_ip": ip, "host_ports": numbers_in(rest[0])} if {
	startswith(spec, "[")
	ip := concat("", [split(spec, "]")[0], "]"])
	rest := split(trim_prefix(spec, concat("", [ip, ":"])), ":")
	count(rest) == 2
}

short(spec) := {"spec": spec, "host_ip": parts[0], "host_ports": numbers_in(parts[1])} if {
	not startswith(spec, "[")
	parts := split(spec, ":")
	count(parts) == 3
}

short(spec) := {"spec": spec, "host_ip": "", "host_ports": numbers_in(parts[0])} if {
	not startswith(spec, "[")
	parts := split(spec, ":")
	count(parts) == 2
}

short(spec) := {"spec": spec, "host_ip": "", "host_ports": set()} if {
	not startswith(spec, "[")
	not contains(spec, ":")
}

# The ports in "15432" or the range "15432-15434".
numbers_in(text) := {to_number(text)} if regex.match(`^[0-9]+$`, text)

numbers_in(text) := {number |
	bounds := split(text, "-")
	some number in numbers.range(to_number(bounds[0]), to_number(bounds[1]))
} if {
	regex.match(`^[0-9]+-[0-9]+$`, text)
}

numbers_in(text) := set() if not regex.match(`^[0-9]+(-[0-9]+)?$`, text)
