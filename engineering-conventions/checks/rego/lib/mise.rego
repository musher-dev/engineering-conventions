# METADATA
# title: Tool pins
# description: >-
#   Reads the repository's mise configuration into the version it pins for
#   each tool, and the places that pin a tool outside mise: Dockerfiles, dev
#   container Features, package.json, setup actions and version files. The
#   maps say which tool an image, a Feature or an action installs (EC-0017).
package conventions.lib.mise

import data.conventions.lib.files

# mise's own project location, the one EC-0017 allows (TOOL-01).
project_config := ".config/mise/config.toml"

# Every mise configuration conftest read, keyed by its path.
configs[doc.path] := doc.contents if {
	some doc in files.own_documents
	doc.path in files.mise_config_paths
	is_object(doc.contents)
}

configured if count(configs) > 0

default tool_table(_) := {}

tool_table(config) := config.tools if is_object(config.tools)

# Every [tools] entry, one per version it names: `tool = "1.2.3"`,
# `tool = ["1.2.3", "2.0.0"]` or `tool = { version = "1.2.3" }`.
entries contains {"path": path, "key": key, "tool": tool_name(key), "version": version} if {
	some path, config in configs
	some key, value in tool_table(config)
	some version in versions_of(value)
}

versions_of(value) := {value} if is_string(value)

versions_of(value) := {version | some item in value; version := item_version(item)} if is_array(value)

versions_of(value) := {item_version(value)} if is_object(value)

item_version(item) := item if is_string(item)

item_version(item) := item.version if is_string(item.version)

# A backend-qualified key names the same tool as its short form:
# `aqua:nodejs/node`, `core:node` and `node` are all node.
tool_name(key) := name if {
	bare := regex.replace(regex.replace(key, `\[.*\]$`, ""), `^[a-z0-9-]+:`, "")
	last := lower(regex.replace(bare, `^.*/`, ""))
	name := object.get(tool_aliases, last, last)
}

# Repository names that differ from the tool's own name.
tool_aliases := {
	"nodejs": "node",
	"golang": "go",
	"go-task": "task",
	"cpython": "python",
}

# `v1.2.3` and `1.2.3` are the same pin: some places carry the `v`.
normalise(version) := trim_prefix(trim_space(version), "v")

# The versions mise pins for each tool, normalised.
pins[tool] := {normalise(entry.version) | some entry in entries; entry.tool == tool} if {
	some tool in {entry.tool | some entry in entries}
}

pinned(tool) if pins[tool]

matches_pin(tool, version) if normalise(version) in pins[tool]

# The pinned versions for a message: `24.21.0`, or `20.0.0 or 22.0.0`.
pin_text(tool) := concat(" or ", sort(pins[tool]))

# mise's core tools: a bare name resolves to mise's built-in implementation,
# never through the registry (https://mise.jdx.dev/core-tools.html).
core_tools := {
	"bun", "deno", "dotnet", "elixir", "erlang", "go", "java",
	"node", "python", "ruby", "rust", "swift", "zig",
}

# The hard minimum mise version a configuration requires, if it sets one.
min_version(config) := normalise(config.min_version) if is_string(config.min_version)

min_version(config) := normalise(config.min_version.hard) if is_string(config.min_version.hard)

min_versions contains version if {
	some config in configs
	version := min_version(config)
}

# A version that resolves to one release. Keywords, ranges, prefixes and a
# version of one or two numeric parts (`24`, `3.13`) all float
# (https://mise.jdx.dev/configuration.html).
exact(version) if {
	is_string(version)
	not floating(normalise(version))
}

floating("")

floating(version) if lower(version) in floating_keywords

floating(version) if startswith(lower(version), "lts")

floating(version) if regex.match(`^(prefix|ref|path|sub-[0-9]+):`, version)

floating(version) if regex.match(`[\^~*<>=|, ]`, version)

floating(version) if regex.match(`(^|\.)[xX](\.|$)`, version)

floating(version) if regex.match(`^[0-9]+(\.[0-9]+)?$`, version)

floating_keywords := {"latest", "stable", "system", "nightly", "beta", "current", "edge", "main", "master"}

# --- Dockerfiles ----------------------------------------------------------

# The runner's DOCKERFILES pattern (bin/conventions), which pre-parses each.
dockerfile_pattern := `(^|/)([^/]+\.)?([Dd]ockerfile|[Cc]ontainerfile)(\.[A-Za-z0-9_-]+)?$`

dockerfiles[doc.path] := [instruction | some instruction in doc.contents; is_object(instruction)] if {
	some doc in files.own_documents
	regex.match(dockerfile_pattern, doc.path)
	is_array(doc.contents)
}

default instruction_values(_) := []

instruction_values(instruction) := [value | some value in instruction.Value; is_string(value)] if {
	is_array(instruction.Value)
}

# Every `ARG NAME=default` in order, as [name, default]. An ARG without a
# default is skipped: its value comes from the build.
arg_defaults(instructions) := [[name, unquote(fallback)] |
	some instruction in instructions
	lower(instruction.Cmd) == "arg"
	some value in instruction_values(instruction)
	contains(value, "=")
	name := split(value, "=")[0]
	fallback := substring(value, count(name) + 1, -1)
]

unquote(value) := trim(value, `"'`)

# The first default of each ARG, for resolving `${NAME}` in a FROM.
arg_values(instructions) := {name: values[0] |
	defaults := arg_defaults(instructions)
	some [name, _] in defaults
	values := [value | some [n, value] in defaults; n == name]
}

# `${NAME}` replaced by each ARG's default; undefined if any reference is
# left, since the build decides it.
resolve(reference, instructions) := resolved if {
	values := arg_values(instructions)
	resolved := strings.replace_n({sprintf("${%s}", [name]): value | some name, value in values}, reference)
	not contains(resolved, "$")
}

# Every image a Dockerfile runs or copies from: FROM, and COPY --from=<image>.
images contains {"path": path, "reference": resolved} if {
	some path, instructions in dockerfiles
	some instruction in instructions
	lower(instruction.Cmd) == "from"
	reference := instruction_values(instruction)[0]
	resolved := resolve(reference, instructions)
}

images contains {"path": path, "reference": resolved} if {
	some path, instructions in dockerfiles
	some instruction in instructions
	lower(instruction.Cmd) == "copy"
	some flag in instruction.Flags
	is_string(flag)
	startswith(flag, "--from=")
	resolved := resolve(substring(flag, 7, -1), instructions)
}

# An image reference split into its name, tag and digest: the tag follows the
# last colon after the last slash, so a registry port is part of the name.
image(reference) := {"name": name, "tag": parts[2], "digest": parts[3]} if {
	parts := regex.find_all_string_submatch_n(`^([^@]+?)(?::([^:/@]+))?(?:@(.+))?$`, reference, 1)[0]
	name := regex.replace(parts[1], `^(docker\.io/|index\.docker\.io/)?(library/)?`, "")
}

# The official images of runtimes mise pins, by image name.
image_tools := {
	"node": "node",
	"python": "python",
	"golang": "go",
	"rust": "rust",
	"ruby": "ruby",
	"oven/bun": "bun",
	"denoland/deno": "deno",
	"ghcr.io/astral-sh/uv": "uv",
}

# The version in an image tag: `24.21.0-slim` and `alpine-2.5.0` hold one,
# `latest` and `slim` do not.
tag_version(tag) := match[1] if {
	match := regex.find_all_string_submatch_n(`(?:^|-)v?([0-9]+(?:\.[0-9]+)*)(?:-|$)`, tag, 1)[0]
}

# --- Dev container Features -----------------------------------------------

devcontainer_pattern := `^(\.devcontainer(/[^/]+)?/devcontainer\.json|\.devcontainer\.json)$`

devcontainers[doc.path] := doc.contents if {
	some doc in files.own_documents
	regex.match(devcontainer_pattern, doc.path)
	is_object(doc.contents)
}

# The Features that install a runtime or CLI mise pins, by Feature ID without
# its version tag.
feature_tools := {
	"ghcr.io/devcontainers/features/node": "node",
	"ghcr.io/devcontainers/features/python": "python",
	"ghcr.io/devcontainers/features/go": "go",
	"ghcr.io/devcontainers/features/rust": "rust",
	"ghcr.io/devcontainers/features/ruby": "ruby",
	"ghcr.io/devcontainers/features/java": "java",
	"ghcr.io/devcontainers/features/dotnet": "dotnet",
	"ghcr.io/devcontainers-extra/features/bun": "bun",
	"ghcr.io/devcontainers-extra/features/deno": "deno",
	"ghcr.io/devcontainers-extra/features/uv": "uv",
	"ghcr.io/devcontainers-extra/features/go-task": "task",
	"ghcr.io/devcontainers-extra/features/pnpm": "pnpm",
	"ghcr.io/devcontainers-contrib/features/bun": "bun",
	"ghcr.io/devcontainers-contrib/features/deno": "deno",
	"ghcr.io/devcontainers-contrib/features/uv": "uv",
	"ghcr.io/devcontainers-contrib/features/go-task": "task",
	"ghcr.io/devcontainers-contrib/features/pnpm": "pnpm",
}

feature_id(reference) := regex.replace(regex.replace(reference, `@sha256:[0-9a-f]+$`, ""), `:[^/:]*$`, "")

# Each Feature that installs a tool, with the version it asks for (or null
# when it asks for none, which is the Feature's floating default).
features contains {"path": path, "reference": reference, "tool": tool, "version": feature_version(options)} if {
	some path, devcontainer in devcontainers
	is_object(devcontainer.features)
	some reference, options in devcontainer.features
	tool := feature_tools[feature_id(reference)]
}

# A Feature's options, or a bare string that is its version.
feature_version(options) := options if is_string(options)

feature_version(options) := options.version if is_string(options.version)

feature_version(options) := null if {
	not is_string(options)
	not files.has_string(options, "version")
}

# --- package.json ---------------------------------------------------------

package_manifests[doc.path] := doc.contents if {
	some doc in files.own_documents
	regex.match(`(^|/)package\.json$`, doc.path)
	is_object(doc.contents)
}

# `packageManager: "bun@1.3.14+sha512.…"` as {"tool", "version"}.
package_manager(manifest) := {"tool": parts[1], "version": parts[2]} if {
	is_string(manifest.packageManager)
	parts := regex.find_all_string_submatch_n(`^(@?[^@]+)@([^+]+)`, manifest.packageManager, 1)[0]
}

# --- Setup actions --------------------------------------------------------

# What each setup action installs, the input that pins it, and the inputs
# that read the version from a file instead.
setup_actions := {
	"actions/setup-node": {"tool": "node", "input": "node-version", "file_inputs": ["node-version-file"]},
	"actions/setup-python": {"tool": "python", "input": "python-version", "file_inputs": ["python-version-file"]},
	"actions/setup-go": {"tool": "go", "input": "go-version", "file_inputs": ["go-version-file"]},
	"astral-sh/setup-uv": {"tool": "uv", "input": "version", "file_inputs": ["version-file"]},
	"arduino/setup-task": {"tool": "task", "input": "version", "file_inputs": []},
	"oven-sh/setup-bun": {"tool": "bun", "input": "bun-version", "file_inputs": ["bun-version-file"]},
	"denoland/setup-deno": {"tool": "deno", "input": "deno-version", "file_inputs": ["deno-version-file"]},
	"ruby/setup-ruby": {"tool": "ruby", "input": "ruby-version", "file_inputs": []},
	"pnpm/action-setup": {"tool": "pnpm", "input": "version", "file_inputs": []},
	"jdx/mise-action": {"tool": "mise", "input": "version", "file_inputs": []},
}

# The action a `uses:` names, without its ref: `actions/setup-node`.
action_name(uses) := lower(split(uses, "@")[0])

# Every step in a workflow or composite action that uses a setup action,
# with where to report it.
setup_steps contains step if {
	some entry in all_steps
	is_string(entry.step.uses)
	name := action_name(entry.step.uses)
	setup_actions[name]
	step := {
		"path": entry.path,
		"label": files.step_label(entry.step, entry.index),
		"action": name,
		"step": entry.step,
	}
}

all_steps := files.workflow_steps | files.action_step_entries

default step_inputs(_) := {}

step_inputs(step) := step.with if is_object(step.with)

# An input value as the text a reader would write; YAML reads `1.25` as a
# number.
input_text(value) := value if is_string(value)

input_text(value) := format_int(value, 10) if {
	is_number(value)
	value == floor(value)
}

input_text(value) := sprintf("%v", [value]) if {
	is_number(value)
	value != floor(value)
}

# A GitHub expression, which only the run can evaluate.
expression(value) if contains(value, "${{")

# --- Version files --------------------------------------------------------

# The runtime each version file pins; tools other than mise read them.
version_files := {".nvmrc": "node", ".node-version": "node", ".python-version": "python"}

# The version a version file holds: its first line that is not a comment.
file_version(text) := line if {
	lines := [trimmed |
		some raw in split(text, "\n")
		trimmed := trim_space(raw)
		trimmed != ""
		not startswith(trimmed, "#")
	]
	line := lines[0]
}
