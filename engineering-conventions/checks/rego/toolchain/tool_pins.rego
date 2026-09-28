# METADATA
# title: Tool pins
# description: >-
#   One mise configuration, at .config/mise/config.toml, pins every tool
#   exactly with a qualified backend, requires a mise version and is locked
#   (TOOL-01..06), and every pin outside it (images, Features,
#   packageManager, setup actions, version files) equals it (TOOL-07..11).
# scope: package
# custom:
#   convention: EC-0017
package conventions.checks.toolchain.tool_pins

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.mise

# TOOL-01. Any mise configuration file other than the project one; mise
# merges every one it finds, so a second file silently overrides the first.
findings contains lib.finding("TOOL-01", path, message) if {
	some path in files.repository_files
	path != mise.project_config
	regex.match(other_config_pattern, path)
	message := sprintf(
		concat(" ", [
			"%s is a mise configuration outside %s; move its settings and [tools] there and delete it,",
			"so one file pins every tool",
		]),
		[path, mise.project_config],
	)
}

# TOOL-02
findings contains lib.finding("TOOL-02", path, message) if {
	some path, config in mise.configs
	some key, _ in mise.tool_table(config)
	not contains(key, ":")
	not key in mise.core_tools
	message := sprintf(
		concat(" ", [
			"[tools] names %q without a backend, so mise's registry decides what it installs;",
			"name the backend, such as \"aqua:<owner>/<repo>\"",
		]),
		[key],
	)
}

# TOOL-03
findings contains lib.finding("TOOL-03", entry.path, message) if {
	some entry in mise.entries
	not mise.exact(entry.version)
	message := sprintf(
		"[tools] pins %q to %q, which resolves to a different release over time; pin one exact version, such as \"1.2.3\"",
		[entry.key, entry.version],
	)
}

# TOOL-04: the configuration requires a mise version.
findings contains lib.finding("TOOL-04", path, no_min_version_message) if {
	some path, config in mise.configs
	not mise.min_version(config)
}

# TOOL-04: jdx/mise-action installs that version.
findings contains lib.finding("TOOL-04", step.path, message) if {
	count(mise.min_versions) > 0
	some step in mise.setup_steps
	step.action == "jdx/mise-action"
	not mise.step_inputs(step.step).version
	message := sprintf(
		"%s runs jdx/mise-action without a version, so it installs the latest mise; set version: %s, the min_version",
		[step.label, min_version_text],
	)
}

findings contains lib.finding("TOOL-04", step.path, message) if {
	count(mise.min_versions) > 0
	some step in mise.setup_steps
	step.action == "jdx/mise-action"
	version := mise.input_text(mise.step_inputs(step.step).version)
	not mise.expression(version)
	not mise.normalise(version) in mise.min_versions
	message := sprintf(
		"%s installs mise %s but the mise configuration's min_version is %s; set version: to %s",
		[step.label, version, min_version_text, min_version_text],
	)
}

# TOOL-04: a Dockerfile that bakes mise bakes that version.
findings contains lib.finding("TOOL-04", path, message) if {
	count(mise.min_versions) > 0
	some path, instructions in mise.dockerfiles
	some [name, version] in mise.arg_defaults(instructions)
	name == "MISE_VERSION"
	not mise.normalise(version) in mise.min_versions
	message := sprintf(
		"ARG MISE_VERSION is %s but the mise configuration's min_version is %s; bake the same mise",
		[version, min_version_text],
	)
}

# TOOL-05
findings contains lib.finding("TOOL-05", path, message) if {
	some path, _ in mise.configs
	lockfile := lockfile_for(path)
	not lockfile in files.repository_files
	message := sprintf(
		concat(" ", [
			"no %s beside the mise configuration, so each install resolves download URLs and checksums afresh;",
			"run `mise lock` and commit it",
		]),
		[lockfile],
	)
}

# TOOL-06
findings contains lib.finding("TOOL-06", path, message) if {
	some path, instructions in mise.dockerfiles
	some [name, version] in mise.arg_defaults(instructions)
	endswith(name, "_VERSION")
	not contains(version, "$")
	not mise.exact(version)
	message := sprintf(
		"ARG %s defaults to %q, which is not one release; set an exact version, such as %s=1.2.3",
		[name, version, name],
	)
}

# TOOL-07. An image of a runtime mise pins, with a version in its tag. A
# digest pins the image even when its tag names no version, so it is left.
findings contains lib.finding("TOOL-07", image.path, message) if {
	some image in mise.images
	parts := mise.image(image.reference)
	tool := mise.image_tools[parts.name]
	mise.pinned(tool)
	found := mise.tag_version(parts.tag)
	not mise.matches_pin(tool, found)
	message := sprintf(
		"%s runs %s %s but mise pins %s; use the %s tag of %s",
		[image.reference, tool, found, mise.pin_text(tool), mise.pin_text(tool), parts.name],
	)
}

findings contains lib.finding("TOOL-07", image.path, message) if {
	some image in mise.images
	parts := mise.image(image.reference)
	tool := mise.image_tools[parts.name]
	mise.pinned(tool)
	not mise.tag_version(parts.tag)
	parts.digest == ""
	message := sprintf(
		"%s names no %s version, so it moves with the registry while mise pins %s; tag it with %s",
		[image.reference, tool, mise.pin_text(tool), mise.pin_text(tool)],
	)
}

# TOOL-08. "none" is the Features' way to install nothing.
findings contains lib.finding("TOOL-08", feature.path, message) if {
	some feature in mise.features
	mise.pinned(feature.tool)
	is_string(feature.version)
	feature.version != "none"
	not mise.matches_pin(feature.tool, feature.version)
	message := sprintf(
		"Feature %s installs %s %s but mise pins %s; set its version to %s",
		[feature.reference, feature.tool, feature.version, mise.pin_text(feature.tool), mise.pin_text(feature.tool)],
	)
}

findings contains lib.finding("TOOL-08", feature.path, message) if {
	some feature in mise.features
	mise.pinned(feature.tool)
	feature.version == null
	message := sprintf(
		"Feature %s sets no version, so it installs its default %s while mise pins %s; set its version to %s",
		[feature.reference, feature.tool, mise.pin_text(feature.tool), mise.pin_text(feature.tool)],
	)
}

# TOOL-09
findings contains lib.finding("TOOL-09", path, message) if {
	some path, manifest in mise.package_manifests
	manager := mise.package_manager(manifest)
	mise.pinned(manager.tool)
	not mise.matches_pin(manager.tool, manager.version)
	message := sprintf(
		"packageManager is %s@%s but mise pins %s %s; set packageManager to %s@%s",
		[
			manager.tool, manager.version, manager.tool, mise.pin_text(manager.tool),
			manager.tool, mise.pin_text(manager.tool),
		],
	)
}

# TOOL-10. jdx/mise-action installs mise itself; TOOL-04 holds its version.
findings contains lib.finding("TOOL-10", step.path, message) if {
	some step in mise.setup_steps
	step.action != "jdx/mise-action"
	setup := mise.setup_actions[step.action]
	mise.pinned(setup.tool)
	inputs := mise.step_inputs(step.step)
	version := mise.input_text(inputs[setup.input])
	not mise.expression(version)
	not mise.matches_pin(setup.tool, version)
	message := sprintf(
		"%s installs %s %s with %s but mise pins %s; set %s: %s, or install it with jdx/mise-action",
		[step.label, setup.tool, version, step.action, mise.pin_text(setup.tool), setup.input, mise.pin_text(setup.tool)],
	)
}

findings contains lib.finding("TOOL-10", step.path, message) if {
	some step in mise.setup_steps
	step.action != "jdx/mise-action"
	setup := mise.setup_actions[step.action]
	mise.pinned(setup.tool)
	inputs := mise.step_inputs(step.step)
	not inputs[setup.input]
	every file_input in setup.file_inputs {
		not inputs[file_input]
	}
	message := sprintf(
		"%s runs %s with no %s, so it installs a %s that mise does not pin; set %s: %s, or install it with jdx/mise-action",
		[step.label, step.action, setup.input, setup.tool, setup.input, mise.pin_text(setup.tool)],
	)
}

# TOOL-11
findings contains lib.finding("TOOL-11", path, message) if {
	some path, text in files.texts
	tool := mise.version_files[files.basename(path)]
	mise.pinned(tool)
	version := mise.file_version(text)
	not mise.matches_pin(tool, version)
	message := sprintf(
		"%s says %s %s but mise pins %s; write %s, or delete the file if nothing but mise reads it",
		[path, tool, version, mise.pin_text(tool), mise.pin_text(tool)],
	)
}

findings contains lib.finding("TOOL-11", path, message) if {
	some path in files.repository_files
	files.basename(path) == ".tool-versions"
	message := sprintf(
		"%s is a second place to pin tool versions; move its pins to %s and delete it",
		[path, mise.project_config],
	)
}

# Helpers.
other_config_pattern := concat("|", [
	`(^|/)\.?mise(\.[^/]+)?\.toml$`,
	`(^|/)\.?mise/(config(\.[^/]+)?\.toml|conf\.d/[^/]+\.toml)$`,
	`(^|/)\.config/mise(\.[^/]+)?\.toml$`,
	`(^|/)\.config/mise/(config(\.[^/]+)?\.toml|conf\.d/[^/]+\.toml)$`,
])

min_version_text := concat(" or ", sort(mise.min_versions))

lockfile_for(path) := concat("", [regex.replace(path, `[^/]*$`, ""), "mise.lock"])

no_min_version_message := concat(" ", [
	"the mise configuration sets no min_version, so an older mise loads it and may resolve it differently;",
	"set min_version to the mise version CI and the dev container install",
])
