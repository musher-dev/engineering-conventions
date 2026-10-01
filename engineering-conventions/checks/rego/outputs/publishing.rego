# METADATA
# title: Publishing outputs
# description: >-
#   An image a workflow publishes to GHCR names the repository it comes from
#   in its org.opencontainers.image.source label (OUT-13).
# scope: package
# custom:
#   convention: EC-0008
package conventions.checks.outputs.publishing

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.mise
import data.conventions.lib.steps

source_label := "org.opencontainers.image.source"

# OUT-13. A publishing step with no source label from any place the check
# recognises.
findings contains lib.finding("OUT-13", group.path, message) if {
	some group in groups
	some index, step in group.steps
	publishes(group, step)
	not labelled(group, step)
	message := sprintf(
		concat(" ", [
			"%s %s publishes an image to ghcr.io without the label %s=%s, so GHCR connects the",
			"package to no repository; add the label to the build, take the labels from",
			"docker/metadata-action, or set it with LABEL in the Dockerfile",
		]),
		[group.where, files.step_label(step, index), source_label, repository_url],
	)
}

# OUT-13. A source label, on a publishing step or in its job, that names
# another repository.
findings contains lib.finding("OUT-13", group.path, message) if {
	some group in groups
	publishes_from(group)
	some index, step in group.steps
	some value in step_sources(step)
	mismatched(value, repository_url)
	message := sprintf(
		concat(" ", [
			"%s %s labels the image %s=%s, but this repository is %s; GHCR connects the package",
			"to the repository the label names, so set it to %s",
		]),
		[group.where, files.step_label(step, index), source_label, value, repository_url, repository_url],
	)
}

findings contains lib.finding("OUT-13", path, message) if {
	some group in groups
	publishes_from(group)
	some path, value in dockerfile_sources
	mismatched(value, repository_url)
	message := sprintf(
		concat(" ", [
			"the Dockerfile labels the image %s=%s, but this repository is %s and publishes to GHCR,",
			"which connects the package to the repository the label names; set it to %s",
		]),
		[source_label, value, repository_url, repository_url],
	)
}

# The repository's own URL: its organization, from the team that owns it,
# and its declared name (EC-0009).
repository_url := sprintf("https://github.com/%s/%s", [org, name]) if {
	name := files.repository_declaration.name
	is_string(name)
	owner := files.repository_declaration.owner
	is_string(owner)
	some match in regex.find_all_string_submatch_n(`^@([A-Za-z0-9-]+)/`, owner, 1)
	org := match[1]
}

# The steps that run together: a workflow job with the env it inherits, or
# a composite action.
groups contains {
	"path": path,
	"where": sprintf("job %q", [job_id]),
	"steps": files.steps(job),
	"env": object.union(env_of(workflow), env_of(job)),
} if {
	some path, workflow in files.workflows
	some job_id, job in files.jobs(workflow)
}

groups contains {"path": path, "where": "the action", "steps": files.action_steps(action), "env": {}} if {
	some path, action in files.actions
}

default env_of(_) := {}

env_of(value) := value.env if is_object(value.env)

publishes_from(group) if {
	some step in group.steps
	publishes(group, step)
}

# --- What publishes to GHCR -----------------------------------------------

build_push(step) if steps.action(step) == "docker/build-push-action"

metadata(step) if steps.action(step) == "docker/metadata-action"

# A docker/build-push-action step that pushes, whether always or on some
# events, and tags the image for ghcr.io directly or through a
# docker/metadata-action step's tags.
publishes(group, step) if {
	build_push(step)
	pushes(steps.inputs(step).push)
	ghcr_tags(group, step)
}

# A run: line that pushes an image tagged for ghcr.io.
publishes(group, step) if {
	some line in steps.command_lines(step)
	push_line(resolved(group, step, line))
}

pushes(true)

pushes("true")

pushes(value) if {
	is_string(value)
	contains(value, "${{")
}

ghcr_tags(group, step) if contains(resolved(group, step, text(steps.inputs(step).tags)), "ghcr.io/")

ghcr_tags(group, step) if {
	some meta in metadata_steps(group, text(steps.inputs(step).tags))
	contains(resolved(group, meta, text(steps.inputs(meta).images)), "ghcr.io/")
}

push_line(line) if {
	regex.match(`(^|[\s;&|(])docker\s+(image\s+)?push\s`, line)
	contains(line, "ghcr.io/")
}

push_line(line) if {
	regex.match(`(^|[\s;&|(])docker\s+(buildx\s+)?build\s(.*\s)?--push(\s|=|$)`, line)
	contains(line, "ghcr.io/")
}

# --- Where the source label comes from ------------------------------------

# A build-push step's labels input sets the label, or takes the labels of a
# docker/metadata-action step, which sets it to the repository the workflow
# runs in.
labelled(_, step) if {
	build_push(step)
	count(label_values(text(steps.inputs(step).labels))) > 0
}

labelled(group, step) if {
	build_push(step)
	count(metadata_steps(group, text(steps.inputs(step).labels))) > 0
}

# A run: line in the same job passes the label, or reads a
# docker/metadata-action step's labels.
labelled(group, step) if {
	not build_push(step)
	some other in group.steps
	some line in steps.command_lines(other)
	count(label_values(line)) > 0
}

labelled(group, step) if {
	not build_push(step)
	some other in group.steps
	some line in steps.command_lines(other)
	count(metadata_steps(group, line)) > 0
}

labelled(group, step) if {
	not build_push(step)
	some meta in group.steps
	metadata(meta)
	some other in group.steps
	some line in steps.command_lines(other)
	contains(line, "DOCKER_METADATA_OUTPUT_LABELS")
}

# A Dockerfile in the repository sets it.
labelled(_, _) if count(dockerfile_sources) > 0

# The docker/metadata-action steps whose outputs a text reads.
metadata_steps(group, value) := [meta |
	some match in regex.find_all_string_submatch_n(`steps\.([A-Za-z0-9_-]+)\.outputs\.`, value, -1)
	some meta in group.steps
	meta.id == match[1]
	metadata(meta)
]

# The source label values a text sets: `org.opencontainers.image.source=<value>`,
# as a labels input line or a --label flag.
label_values(value) := {trim(match[1], `"'`) |
	some match in regex.find_all_string_submatch_n(label_pattern, value, -1)
}

label_pattern := `org\.opencontainers\.image\.source=("[^"]*"|'[^']*'|[^\s"']+)`

step_sources(step) := label_values(text(steps.inputs(step).labels)) if build_push(step)

step_sources(step) := {value |
	some line in steps.command_lines(step)
	some value in label_values(line)
} if {
	not build_push(step)
}

# Each Dockerfile's source label, from LABEL key=value pairs.
dockerfile_sources[path] := mise.unquote(values[index + 1]) if {
	some path, instructions in mise.dockerfiles
	some instruction in instructions
	lower(instruction.Cmd) == "label"
	values := mise.instruction_values(instruction)
	some index, key in values
	mise.unquote(key) == source_label
	index + 1 < count(values)
}

# A literal URL for another repository. A value computed when the workflow
# or the build runs, such as ${{ github.server_url }}/${{ github.repository }}
# or a build argument, is not judged.
mismatched(value, expected) if {
	not contains(value, "$")
	normalised(value) != normalised(expected)
}

normalised(url) := lower(trim_suffix(trim_suffix(url, "/"), ".git"))

# --- Text --------------------------------------------------------------------

default text(_) := ""

text(value) := value if is_string(value)

text(value) := concat("\n", [item | some item in value; is_string(item)]) if is_array(value)

# A text with each ${{ env.NAME }} replaced by the literal value the
# workflow, job or step sets, so a registry kept in env is still seen.
resolved(group, step, value) := strings.replace_n(
	{match[0]: env[match[1]] |
		some match in regex.find_all_string_submatch_n(`\$\{\{\s*env\.([A-Za-z_][A-Za-z0-9_]*)\s*\}\}`, value, -1)
		is_string(env[match[1]])
	},
	value,
) if {
	env := object.union(group.env, env_of(step))
}
