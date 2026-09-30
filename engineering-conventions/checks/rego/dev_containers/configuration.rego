# METADATA
# title: Dev container configuration
# description: >-
#   A dev container's configuration lives where tools look for it (DEVC-01),
#   locks its Features (DEVC-02, DEVC-03), builds on a fixed image (DEVC-04),
#   runs as a user other than root (DEVC-05), runs lifecycle scripts that
#   exist (DEVC-06), commits no secret (DEVC-07), names its volumes for the
#   container (DEVC-08), and is kept current and built in CI (DEVC-09,
#   DEVC-10); it fixes no container name (DEVC-14), and mounts volumes
#   under the remote user's home (DEVC-15).
# scope: package
# custom:
#   convention: EC-0027
package conventions.checks.dev_containers.configuration

import data.conventions.lib.env
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.mise
import data.conventions.lib.steps

devcontainers := mise.devcontainers

# DEVC-01. The root form is one the specification allows, but it cannot sit
# beside a Dockerfile, scripts or a lockfile, and a second configuration
# cannot join it.
findings contains lib.finding("DEVC-01", ".devcontainer.json", message) if {
	".devcontainer.json" in files.repository_files
	message := "move the dev container configuration to .devcontainer/devcontainer.json, beside the files it names"
}

findings contains lib.finding("DEVC-01", path, message) if {
	message := concat(" ", [
		"editors look for a dev container configuration only at .devcontainer/devcontainer.json",
		"or .devcontainer/<name>/devcontainer.json; move this one to one of them",
	])
	some path in files.repository_files
	startswith(path, ".devcontainer/")
	files.basename(path) == "devcontainer.json"
	not regex.match(mise.devcontainer_pattern, path)
}

# DEVC-02
findings contains lib.finding("DEVC-02", path, message) if {
	some path, devcontainer in devcontainers
	count(feature_references(devcontainer)) > 0
	lock := lock_path(path)
	not lock in files.all_files
	message := sprintf(
		"the Features are not locked; commit %s, written by `devcontainer build` or `devcontainer upgrade`",
		[lock],
	)
}

# DEVC-03. A Feature another pulls in through dependsOn is locked without
# being named in the configuration.
findings contains lib.finding("DEVC-03", lock, message) if {
	some path, devcontainer in devcontainers
	lock := lock_path(path)
	locked := lock_features(lock)
	some reference in feature_references(devcontainer)
	not reference in object.keys(locked)
	message := sprintf(
		"the Feature %s is not in the lockfile; run `devcontainer upgrade` to record it",
		[reference],
	)
}

findings contains lib.finding("DEVC-03", lock, message) if {
	some path, devcontainer in devcontainers
	lock := lock_path(path)
	locked := lock_features(lock)
	some reference in object.keys(locked)
	not reference in feature_references(devcontainer)
	not reference in dependencies(locked)
	message := sprintf(
		"the lockfile records %s, which %s no longer uses; run `devcontainer upgrade` to drop it",
		[reference, path],
	)
}

# DEVC-04
findings contains lib.finding("DEVC-04", path, message) if {
	some path, devcontainer in devcontainers
	is_string(devcontainer.image)
	mise.floating_image(devcontainer.image)
	message := sprintf(
		"the image %s moves without a commit; name a fixed tag such as a version, or add a digest",
		[devcontainer.image],
	)
}

findings contains lib.finding("DEVC-04", dockerfile, message) if {
	some path, devcontainer in devcontainers
	dockerfile := build_dockerfile(path, devcontainer)
	some image in mise.images
	image.path == dockerfile
	not stage_reference(dockerfile, image.reference)
	mise.floating_image(image.reference)
	message := sprintf(
		"the dev container builds from %s, which moves without a commit; name a fixed tag, or add a digest",
		[image.reference],
	)
}

# DEVC-05
findings contains lib.finding("DEVC-05", path, message) if {
	message := concat(" ", [
		"remoteUser is not set, so the user depends on the image;",
		`set it to a user other than root, such as "vscode"`,
	])
	some path, devcontainer in devcontainers
	not files.has_string(devcontainer, "remoteUser")
}

findings contains lib.finding("DEVC-05", path, message) if {
	some path, devcontainer in devcontainers
	some key in ["remoteUser", "containerUser"]
	devcontainer[key] == "root"
	message := sprintf(
		"%s is root, so every file the container writes is owned by root; set it to a user such as \"vscode\"",
		[key],
	)
}

# DEVC-06
findings contains lib.finding("DEVC-06", path, message) if {
	some path, devcontainer in devcontainers
	some hook in lifecycle_hooks
	some command in commands(object.get(devcontainer, hook, null))
	some script in scripts(command)
	not script in files.all_files
	message := sprintf(
		"%s runs %s, which the repository does not hold; correct the path, or add the script",
		[hook, script],
	)
}

# DEVC-07
findings contains lib.finding("DEVC-07", path, message) if {
	some path, devcontainer in devcontainers
	some block in ["containerEnv", "remoteEnv"]
	some name, value in object.get(devcontainer, block, {})
	name in secret_names
	is_string(value)
	value != ""
	not regex.match(`^\$\{(localEnv|containerEnv):[^}]+\}$`, value)
	message := sprintf(
		"%s.%s commits a value for a secret; pass it from the host as \"${localEnv:%s}\", or leave it empty",
		[block, name, name],
	)
}

# DEVC-08
findings contains lib.finding("DEVC-08", path, message) if {
	some path, devcontainer in devcontainers
	some mount in object.get(devcontainer, "mounts", [])
	fields := mount_fields(mount)
	fields.type == "volume"
	source := object.get(fields, "source", "")
	source != ""
	not regex.match(volume_pattern, source)
	message := sprintf(
		"the volume %s is not named musher-${devcontainerId}-<purpose>; rename it so it belongs to this container",
		[source],
	)
}

# DEVC-14. The name is the argument after --name, or follows --name=.
findings contains lib.finding("DEVC-14", path, message) if {
	some path, devcontainer in devcontainers
	some name in container_names(object.get(devcontainer, "runArgs", []))
	message := sprintf(
		"runArgs names the container %q; remove --name, %s",
		[name, "because a fixed name collides across rebuilds, worktrees and second clones of the repository"],
	)
}

# DEVC-15. Silent when remoteUser is unset or root, which DEVC-05 reports;
# root's home is not under /home.
findings contains lib.finding("DEVC-15", path, message) if {
	some path, devcontainer in devcontainers
	user := devcontainer.remoteUser
	is_string(user)
	user != "root"
	some mount in object.get(devcontainer, "mounts", [])
	fields := mount_fields(mount)
	fields.type == "volume"
	target := mount_target(fields)
	some match in regex.find_all_string_submatch_n(`^/home/([^/]+)(/|$)`, target, 1)
	owner := match[1]
	owner != user
	message := sprintf(
		"the volume %s is mounted under /home/%s, but remoteUser is %s; mount it under /home/%s, %s",
		[volume_label(fields, target), owner, user, user, "where the remote user's tools look"],
	)
}

# DEVC-09
findings contains lib.finding("DEVC-09", dependabot_path, message) if {
	count(devcontainers) > 0
	not devcontainer_updates
	not renovate
	message := concat(" ", [
		"nothing updates the dev container's image and Features; add a devcontainers entry to",
		"Dependabot, or configure Renovate",
	])
}

# DEVC-10
findings contains lib.finding("DEVC-10", path, message) if {
	not builds_in_ci
	message := concat(" ", [
		"no workflow builds the dev container; add a step that runs",
		"`devcontainer build --workspace-folder . --frozen-lockfile`",
	])
	some path in object.keys(devcontainers)
}

findings contains lib.finding("DEVC-10", path, message) if {
	builds_in_ci
	not frozen_in_ci
	message := concat(" ", [
		"the workflow that builds the dev container does not check its lockfile;",
		"pass --frozen-lockfile to `devcontainer build` or `devcontainer up`",
	])
	some path in object.keys(devcontainers)
	lock_path(path) in files.all_files
}

# --- Features and the lockfile ---------------------------------------------

default feature_references(_) := set()

feature_references(devcontainer) := object.keys(devcontainer.features) if {
	is_object(devcontainer.features)
}

# The lockfile beside a configuration: .devcontainer-lock.json for the root
# form, devcontainer-lock.json beside any other.
lock_path(".devcontainer.json") := ".devcontainer-lock.json"

lock_path(path) := concat("/", [directory(path), "devcontainer-lock.json"]) if path != ".devcontainer.json"

lock_features(lock) := doc.contents.features if {
	some doc in files.own_documents
	doc.path == lock
	is_object(doc.contents.features)
}

# The Features a locked Feature depends on, listed or keyed by reference.
dependencies(locked) := {dependency |
	some entry in locked
	some dependency in depends_on(object.get(entry, "dependsOn", []))
}

depends_on(value) := {reference | some reference in value; is_string(reference)} if is_array(value)

depends_on(value) := object.keys(value) if is_object(value)

directory(path) := regex.replace(path, `/[^/]+$`, "")

# --- Images ---------------------------------------------------------------

# The Dockerfile a `build` names, relative to the configuration's directory.
build_dockerfile(path, devcontainer) := resolve(directory(path), name) if {
	some key in ["dockerfile", "dockerFile"]
	name := devcontainer.build[key]
	is_string(name)
}

build_dockerfile(path, devcontainer) := resolve(directory(path), devcontainer.dockerFile) if {
	is_string(devcontainer.dockerFile)
}

resolve(base, name) := join(parent(base), trim_prefix(name, "../")) if startswith(name, "../")

resolve(base, name) := join(base, trim_prefix(name, "./")) if not startswith(name, "../")

parent(base) := directory(base) if contains(base, "/")

parent(base) := "" if not contains(base, "/")

join("", name) := name

join(base, name) := concat("/", [base, name]) if base != ""

# A FROM that names an earlier stage, not an image.
stage_reference(dockerfile, reference) if {
	some instruction in mise.dockerfiles[dockerfile]
	lower(instruction.Cmd) == "from"
	values := mise.instruction_values(instruction)
	count(values) == 3
	lower(values[1]) == "as"
	values[2] == reference
}

stage_reference(_, "scratch")

# --- Lifecycle commands ---------------------------------------------------

lifecycle_hooks := [
	"initializeCommand",
	"onCreateCommand",
	"updateContentCommand",
	"postCreateCommand",
	"postStartCommand",
	"postAttachCommand",
]

# A command is a string for the shell, an array of arguments, or an object
# of named commands of either form, which run in parallel.
default commands(_) := []

commands(value) := [value] if is_string(value)

commands(value) := [argv(value)] if is_array(value)

commands(value) := [command_text(named) | some named in value] if is_object(value)

command_text(named) := named if is_string(named)

command_text(named) := argv(named) if is_array(named)

argv(value) := concat(" ", [arg | some arg in value; is_string(arg)])

# The relative paths to scripts a command runs.
scripts(command) := {trim_prefix(token, "./") |
	some token in regex.split(`[\s;&|'"()]+`, command)
	regex.match(`^(\./)?([A-Za-z0-9._-]+/)+[A-Za-z0-9._-]+\.(sh|bash|py|js|mjs|cjs|ts|ps1)$`, token)
	not startswith(token, "../")
}

# --- Secrets and volumes --------------------------------------------------

secret_names contains entry.name if {
	some entry in env.bindings
	entry.binding.sensitivity == "secret"
}

volume_pattern := `^musher-\$\{devcontainerId\}-[a-z0-9]+(-[a-z0-9]+)*$`

# A mount is an object, or a string of comma-separated key=value pairs.
mount_fields(mount) := mount if is_object(mount)

mount_fields(mount) := {key: value |
	some pair in split(mount, ",")
	parts := split(trim_space(pair), "=")
	count(parts) >= 2
	key := mount_key(parts[0])
	value := concat("=", array.slice(parts, 1, count(parts)))
} if {
	is_string(mount)
}

mount_key("src") := "source"

mount_key(key) := key if key != "src"

# Where a mount lands: target, or its synonyms destination and dst.
mount_target(fields) := [value |
	some key in ["target", "destination", "dst"]
	value := fields[key]
	is_string(value)
][0]

# A named volume by its name, an anonymous one by where it lands.
volume_label(fields, target) := fields.source if {
	is_string(fields.source)
	fields.source != ""
} else := target

# --- Container names ------------------------------------------------------

# The fixed names runArgs gives the container.
default container_names(_) := set()

container_names(args) := {name |
	some i, arg in args
	arg == "--name"
	name := args[i + 1]
	is_string(name)
} | {trim_prefix(arg, "--name=") |
	some arg in args
	is_string(arg)
	startswith(arg, "--name=")
} if {
	is_array(args)
}

# --- Upkeep ---------------------------------------------------------------

dependabot_paths contains doc.path if {
	some doc in files.own_documents
	regex.match(`^\.github/dependabot\.ya?ml$`, doc.path)
}

default dependabot_path := ".github/dependabot.yml"

dependabot_path := sort(dependabot_paths)[0] if count(dependabot_paths) > 0

devcontainer_updates if {
	some doc in files.own_documents
	regex.match(`^\.github/dependabot\.ya?ml$`, doc.path)
	some update in doc.contents.updates
	update["package-ecosystem"] == "devcontainers"
}

renovate_paths := {
	"renovate.json",
	"renovate.json5",
	".renovaterc",
	".renovaterc.json",
	".renovaterc.json5",
	".github/renovate.json",
	".github/renovate.json5",
	".gitlab/renovate.json",
	".gitlab/renovate.json5",
}

renovate if {
	some path in files.repository_files
	path in renovate_paths
}

# A step that builds or starts the dev container: the Dev Container CLI, or
# the devcontainers/ci action.
build_lines contains line if {
	some entry in steps.entries
	some line in steps.command_lines(entry.step)
	regex.match(`(^|[\s/@])(devcontainer|devcontainers/cli(@\S+)?)\s+(build|up)(\s|$)`, line)
}

builds_in_ci if count(build_lines) > 0

builds_in_ci if {
	some entry in steps.entries
	steps.action(entry.step) == "devcontainers/ci"
}

frozen_in_ci if {
	some line in build_lines
	contains(line, "--frozen-lockfile")
}
