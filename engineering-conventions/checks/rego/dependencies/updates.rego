# METADATA
# title: Automated dependency updates
# description: >-
#   Something proposes every dependency update: Renovate, or a Dependabot
#   update for the GitHub Actions in the workflows and each composite action
#   (DEPS-11), for every directory that holds a Dockerfile (DEPS-12), and for
#   the product's manifest in the product directory (DEPS-13).
# scope: package
# custom:
#   convention: EC-0042
package conventions.checks.dependencies.updates

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.images
import data.conventions.lib.layout
import data.conventions.lib.paths
import data.conventions.lib.updates

# DEPS-11
findings contains lib.finding("DEPS-11", updates.dependabot_path, message) if {
	not updates.renovate
	some directory in action_directories
	not updates.covers({"github-actions"}, directory)
	message := sprintf(
		concat(" ", [
			"nothing updates the actions used by %s; add %q to the directories of a github-actions",
			"update in the Dependabot configuration, or configure Renovate",
		]),
		[action_owner(directory), slashed(directory)],
	)
}

# DEPS-12
findings contains lib.finding("DEPS-12", updates.dependabot_path, message) if {
	not updates.renovate
	some directory in docker_directories
	not updates.covers({"docker"}, directory)
	message := sprintf(
		concat(" ", [
			"nothing updates the base images of the Dockerfiles in %q; add a docker update for that",
			"directory to the Dependabot configuration, or configure Renovate",
		]),
		[slashed(directory)],
	)
}

# DEPS-13
findings contains lib.finding("DEPS-13", updates.dependabot_path, message) if {
	not updates.renovate
	some name, ecosystem in updates.ecosystems
	count(ecosystem.dependabot) > 0
	some manifest in ecosystem.manifests
	concat("/", [layout.product_dir, manifest]) in files.repository_files
	not updates.covers(ecosystem.dependabot, layout.product_dir)
	message := sprintf(
		concat(" ", [
			"nothing updates the %s dependencies %s/%s declares; add an update with package-ecosystem %s",
			"and directory %q to the Dependabot configuration, or configure Renovate",
		]),
		[name, layout.product_dir, manifest, concat(" or ", ecosystem.dependabot), slashed(layout.product_dir)],
	)
}

# The root, for the workflows and a root action, and each composite action's
# directory, which Dependabot does not scan from the root.
action_directories contains "" if {
	some path in files.repository_files
	regex.match(`^\.github/workflows/[^/]+\.ya?ml$`, path)
}

action_directories contains trim_suffix(paths.directory(path), "/") if {
	some path in files.repository_files
	regex.match(`^\.github/actions/[^/]+/action\.ya?ml$`, path)
}

docker_directories contains trim_suffix(paths.directory(path), "/") if some path in images.dockerfiles

slashed(directory) := concat("", ["/", directory])

action_owner("") := "the workflows"

action_owner(directory) := sprintf("the composite action in %s", [directory]) if directory != ""
