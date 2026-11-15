# METADATA
# title: Automated dependency updates
# description: >-
#   Something proposes every dependency update: Renovate, or a Dependabot
#   update for the GitHub Actions in the workflows and each composite action
#   (DEPS-11), for every directory that holds a Dockerfile (DEPS-12), and for
#   the product's manifest in the product directory (DEPS-13); and each
#   Dependabot version update is quiet: monthly or rarer, every dependency in
#   one group (DEPS-17).
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

# DEPS-17
findings contains lib.finding("DEPS-17", entry.path, message) if {
	some entry in updates.dependabot_updates
	versions_updated(entry.update)
	problems := [problem |
		some problem in [interval_problem(entry.update), group_problem(entry.update)]
		problem != ""
	]
	count(problems) > 0
	message := sprintf(
		concat(" ", [
			"the %s update for %s %s; set schedule.interval to monthly and add a group whose patterns",
			"are [\"*\"], so it opens at most one pull request a month",
		]),
		[ecosystem_of(entry.update), concat(", ", updates.update_directories(entry.update)), concat(" and ", problems)],
	)
}

# The intervals that open at most one version-update pull request a month
# per group.
quiet_intervals := {"monthly", "quarterly", "semiannually", "yearly"}

# An entry with open-pull-requests-limit 0 runs only security updates.
versions_updated(update) if object.get(update, "open-pull-requests-limit", 5) != 0

default interval_problem(_) := ""

interval_problem(update) := sprintf("runs %s", [interval]) if {
	interval := object.get(object.get(update, "schedule", {}), "interval", "")
	is_string(interval)
	interval != ""
	not lower(interval) in quiet_intervals
}

interval_problem(update) := "has no schedule.interval" if {
	interval := object.get(object.get(update, "schedule", {}), "interval", "")
	not is_string(interval)
}

interval_problem(update) := "has no schedule.interval" if {
	object.get(object.get(update, "schedule", {}), "interval", "") == ""
}

default group_problem(_) := ""

group_problem(update) := "groups nothing" if not groups_everything(update)

# A group that takes every version update: patterns ["*"], and applies-to
# absent or version-updates.
groups_everything(update) if {
	some group in object.get(update, "groups", {})
	is_object(group)
	object.get(group, "applies-to", "version-updates") == "version-updates"
	"*" in object.get(group, "patterns", [])
}

default ecosystem_of(_) := "unnamed"

ecosystem_of(update) := update["package-ecosystem"] if is_string(update["package-ecosystem"])

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
