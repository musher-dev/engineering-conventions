# METADATA
# title: Dev container stacks
# description: >-
#   The compose stacks under .devcontainer/ run fixed images (DEVC-11), publish
#   their ports on the loopback address only (DEVC-12), publish them from
#   the reserved range (DEVC-13), and run a version of the capability they
#   label that every environment schema's range accepts (DEVC-16). The dev
#   container names the same ports in forwardPorts and portsAttributes
#   (DEVC-19), forwards every port its stacks publish (DEVC-20), and forwards
#   none outside the reserved range (DEVC-21).
# scope: package
# custom:
#   convention: EC-0028
package conventions.checks.dev_containers.stacks

import data.conventions.lib.env
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.mise
import data.conventions.lib.versions

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

# DEVC-16. A version outside a range a schema requires.
findings contains lib.finding("DEVC-16", entry.path, message) if {
	some entry in labelled
	versions.parse(entry.version)
	some required in requirements
	required.capability == entry.capability
	not versions.satisfies(entry.version, required.version)
	message := sprintf(
		concat(" ", [
			"the service %s runs %s %s, but %s requires %s for %s; run a version in the range,",
			"and set %s to match",
		]),
		[entry.name, entry.capability, entry.version, required.path, required.version, required.id, version_label],
	)
}

# DEVC-16. A capability without its version.
findings contains lib.finding("DEVC-16", entry.path, message) if {
	some entry in labelled
	entry.version == ""
	some required in requirements
	required.capability == entry.capability
	message := sprintf(
		"the service %s labels %s %s but no %s; label the version of the engine it runs",
		[entry.name, capability_label, entry.capability, version_label],
	)
}

# DEVC-16. A version that cannot be compared.
findings contains lib.finding("DEVC-16", entry.path, message) if {
	some entry in labelled
	entry.version != ""
	not versions.parse(entry.version)
	some required in requirements
	required.capability == entry.capability
	message := sprintf(
		"the service %s labels %s %q, which is not a version; write the engine's version as integers separated by dots",
		[entry.name, version_label, entry.version],
	)
}

# DEVC-19. A forwarded port without attributes.
findings contains lib.finding("DEVC-19", path, message) if {
	some path, config in configurations
	some port in forwarded(config)
	not described(config, port)
	message := sprintf(
		"forwardPorts lists %d, but portsAttributes has no entry for it; add one with the port's label",
		[port],
	)
}

# DEVC-19. Attributes for a port that is not forwarded.
findings contains lib.finding("DEVC-19", path, message) if {
	some path, config in configurations
	some port in attribute_ports(config)
	not port in forwarded(config)
	message := sprintf(
		"portsAttributes describes %d, which forwardPorts does not list; forward it, or remove the entry",
		[port],
	)
}

# DEVC-20
findings contains lib.finding("DEVC-20", port.path, message) if {
	some port in published
	paired := pairs(port.path)
	count(paired) > 0
	some host_port in port.host_ports
	not forwarded_by_any(paired, host_port)
	message := sprintf(
		"the service %s publishes host port %d, which %s does not forward; add it to forwardPorts",
		[port.service, host_port, concat(" or ", sort(paired))],
	)
}

# DEVC-21
findings contains lib.finding("DEVC-21", path, message) if {
	some path, config in configurations
	some port in forwarded(config)
	not in_range(port)
	message := sprintf(
		"forwardPorts lists %d, outside the reserved range %d-%d; forward the host port a stack publishes from the range",
		[port, port_range.low, port_range.high],
	)
}

configurations := mise.devcontainers

# The configurations at the root of .devcontainer/, in either form the
# specification allows.
root_configurations contains path if {
	some path, _ in configurations
	path in {".devcontainer/devcontainer.json", ".devcontainer.json"}
}

# The configurations a compose file's stack is compared with: the one in the
# same .devcontainer/<name>/ directory; else the one at the root of
# .devcontainer/; else, when the repository holds only named configurations,
# any of them.
pairs(compose_path) := {named} if {
	named := named_configuration(compose_path)
	configurations[named]
}

pairs(compose_path) := root_configurations if {
	not configurations[named_configuration(compose_path)]
	count(root_configurations) > 0
}

pairs(compose_path) := object.keys(configurations) if {
	not configurations[named_configuration(compose_path)]
	count(root_configurations) == 0
}

named_configuration(compose_path) := sprintf(".devcontainer/%s/devcontainer.json", [split(compose_path, "/")[1]])

forwarded_by_any(paths, port) if {
	some path in paths
	port in forwarded(configurations[path])
}

# The numeric entries of forwardPorts. A "service:port" entry forwards a
# compose service's port and is not compared.
forwarded(config) := {to_number(value) | some value in forward_ports(config); numeric(value)}

forward_ports(config) := config.forwardPorts if is_array(config.forwardPorts)

forward_ports(config) := [] if not is_array(config.forwardPorts)

# The ports portsAttributes names one by one.
attribute_ports(config) := {to_number(key) | some key, _ in attributes(config); numeric(key)}

# The ranges portsAttributes names, such as "40000-55000".
attribute_ranges(config) := {[to_number(bounds[0]), to_number(bounds[1])] |
	some key, _ in attributes(config)
	regex.match(`^[0-9]+-[0-9]+$`, key)
	bounds := split(key, "-")
}

attributes(config) := config.portsAttributes if is_object(config.portsAttributes)

attributes(config) := {} if not is_object(config.portsAttributes)

# A forwarded port has attributes under its own key, or under a range that
# holds it. A key written as a regular expression is not matched.
described(config, port) if port in attribute_ports(config)

described(config, port) if {
	some bounds in attribute_ranges(config)
	port >= bounds[0]
	port <= bounds[1]
}

numeric(value) if is_number(value)

numeric(value) if {
	is_string(value)
	regex.match(`^[0-9]+$`, value)
}

capability_label := "dev.musher.capability"

version_label := "dev.musher.capability-version"

# A service's labels as a map, from either form compose accepts: a mapping,
# or a list of KEY=VALUE strings.
labels(service) := {key: sprintf("%v", [value]) | some key, value in service.labels} if is_object(service.labels)

labels(service) := {parts[0]: concat("=", array.slice(parts, 1, count(parts))) |
	some item in service.labels
	is_string(item)
	parts := split(item, "=")
	count(parts) > 1
} if {
	is_array(service.labels)
}

# Every service that labels the capability it provides, with the version it
# labels, or "" when it labels none.
labelled contains {"path": entry.path, "name": entry.name, "capability": capability, "version": version} if {
	some entry in services
	service_labels := labels(entry.service)
	capability := service_labels[capability_label]
	version := object.get(service_labels, version_label, "")
}

# Every runtime instance an environment schema requires, with its range.
requirements contains {"path": path, "id": id, "capability": instance.capability, "version": instance.version} if {
	some path, contents in env.documents
	is_object(contents.requires)
	some id, instance in contents.requires
	is_string(instance.capability)
	versions.valid_range(instance.version)
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
