package conventions.checks.dev_containers.specification_test

import data.conventions.checks.dev_containers.specification
import data.conventions.lib.testdata_test as td

config_path := ".devcontainer/devcontainer.json"

devcontainer := {
	"name": "Platform API",
	"image": "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
	"remoteUser": "vscode",
	"mounts": ["source=musher-${devcontainerId}-gh-config,target=/home/vscode/.config/gh,type=volume"],
	"postCreateCommand": ["bash", ".devcontainer/scripts/post-create.sh"],
}

conforming(config) := [td.file(config_path, config), td.inventory([config_path])]

messages(found, id) := {f.message | some f in found; f.id == id}

test_conforming if {
	count(specification.findings) == 0 with input as conforming(devcontainer)
}

test_devc_17_schema_problems if {
	config := object.union(devcontainer, {
		"postCreateCommands": "echo",
		"waitFor": "postCreate",
		"hostRequirements": {"cpu": 2},
	})
	found := specification.findings with input as conforming(config)
	td.pairs(found) == {["DEVC-17", config_path]}
	messages(found, "DEVC-17") == {concat("", [
		"the Dev Container specification's schema rejects this file, so a tool ignores the setting or ",
		"refuses the file: the file has the property postCreateCommands, which the specification does not ",
		"define. (2 more problems in the file)",
	])}
}

test_devc_17_one_problem if {
	config := object.union(devcontainer, {"shutdownAction": "stopCompose"})
	found := specification.findings with input as conforming(config)
	messages(found, "DEVC-17") == {concat("", [
		"the Dev Container specification's schema rejects this file, so a tool ignores the setting or ",
		"refuses the file: `shutdownAction`: shutdownAction must be one of the following: \"none\", ",
		"\"stopContainer\".",
	])}

	nested := object.union(devcontainer, {"hostRequirements": {"cpu": 2}})
	nested_found := messages(specification.findings, "DEVC-17") with input as conforming(nested)
	contains(concat("", nested_found), "`hostRequirements` has the property cpu")
}

test_devc_17_valid_forms_pass if {
	build := object.union(object.remove(devcontainer, ["image"]), {
		"build": {"dockerfile": "Dockerfile", "args": {"A": "1"}},
		"customizations": {"vscode": {"extensions": ["a.b"], "settings": {"x": 1}}},
		"hostRequirements": {"cpus": 2},
		"waitFor": "postCreateCommand",
	})
	not "DEVC-17" in td.ids(specification.findings) with input as conforming(build)
}

unknown_variable(property, name, remedy) := sprintf(
	concat("", [
		"%s uses ${%s}, which is not a variable the Dev Container specification defines, so it ",
		"is left as literal text; %s",
	]),
	[property, name, remedy],
)

test_devc_18_unknown_variables if {
	config := object.union(devcontainer, {
		"mounts": ["source=musher-${devContainerId}-gh-config,target=/home/vscode/.config/gh,type=volume"],
		"containerEnv": {"P": "${PATH}", "H": "${env:HOME}"},
		"postStartCommand": "echo ${LocalWorkspaceFolder} ${HOME} ${X:-y}",
	})
	found := specification.findings with input as conforming(config)
	messages(found, "DEVC-18") == {
		unknown_variable("mounts", "devContainerId", "write ${devcontainerId}"),
		unknown_variable("containerEnv", "env:HOME", "write ${localEnv:HOME}"),
		unknown_variable("containerEnv", "PATH", concat(" ", [
			"use ${localEnv:NAME}, ${containerEnv:NAME}, ${localWorkspaceFolder}, ${containerWorkspaceFolder},",
			"their Basename forms or ${devcontainerId}",
		])),
		unknown_variable("postStartCommand", "LocalWorkspaceFolder", "write ${localWorkspaceFolder}"),
	}
}

test_devc_18_placement if {
	config := object.union(devcontainer, {
		"containerEnv": {"P": "${containerEnv:PATH}:/x"},
		"remoteEnv": {"P": "${containerEnv:PATH}:/x", "W": "${localWorkspaceFolderBasename}"},
		"build": {"dockerfile": "Dockerfile", "args": {"ID": "${devcontainerId}"}},
	})
	found := specification.findings with input as conforming(object.remove(config, ["image"]))
	messages(found, "DEVC-18") == {
		concat("", [
			"containerEnv uses ${containerEnv:PATH}, which the specification resolves only in remoteEnv; ",
			"set the value in remoteEnv, or read a host variable with ${localEnv:...}",
		]),
		concat("", [
			"build uses ${devcontainerId}, which the specification resolves only in containerEnv, ",
			"containerUser, customizations, initializeCommand, mounts, name, onCreateCommand, ",
			"postAttachCommand, postCreateCommand, postStartCommand, remoteEnv, remoteUser, runArgs, ",
			"updateContentCommand, workspaceFolder, workspaceMount; move the value to one of them",
		]),
	}
}

test_devc_18_defined_variables_pass if {
	config := object.union(devcontainer, {
		"name": "api-${devcontainerId}",
		"workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}",
		"workspaceMount": "source=${localWorkspaceFolder},target=${containerWorkspaceFolder},type=bind",
		"containerEnv": {"T": "${localEnv:TOKEN:}", "U": "${localEnv:USER:vscode}"},
		"remoteEnv": {"P": "${containerEnv:PATH}:${containerWorkspaceFolderBasename}"},
		"postCreateCommand": "echo ${HOME} ${localEnv:HOME}",
		"customizations": {"vscode": {"settings": {"tool.config": "${workspaceFolder}/.config/tool.ini"}}},
	})
	not "DEVC-18" in td.ids(specification.findings) with input as conforming(config)
}
