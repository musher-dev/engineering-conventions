# METADATA
# title: Keeping dependencies current
# description: >-
#   A repository that vendors dependencies defines the tasks that verify and
#   update them (DEPS-08) and verifies its copies in a validate workflow
#   (DEPS-09). A repository that pins another Musher release, vendored or the
#   conventions bundle, shows each pin's currency as a README badge (DEPS-15)
#   that a maintain-dependency-badges workflow keeps fresh (DEPS-16). DEPS-10,
#   the scheduled pull request per release, is retired (decision 0042).
# scope: package
# custom:
#   convention: EC-0033
package conventions.checks.dependencies.currency

import data.conventions.lib.filenames
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.steps
import data.conventions.lib.taskfiles

default root_path := "Taskfile.yml"

root_path := taskfiles.root_path

# DEPS-08
findings contains lib.finding("DEPS-08", root_path, message) if {
	vendors
	missing := [name | some name in ["deps:check", "deps:sync"]; not name in taskfiles.root_names]
	count(missing) > 0
	message := sprintf(
		concat(" ", [
			"the repository declares dependencies in %s but its root Taskfile does not define %s; add",
			"them, so every consumer verifies and updates its vendored copies the same way",
		]),
		[files.dependencies_path, concat(", ", [sprintf("%q", [name]) | some name in missing])],
	)
}

# DEPS-09
findings contains lib.finding("DEPS-09", files.dependencies_path, message) if {
	vendors
	not validates
	message := concat(" ", [
		"the repository vendors dependencies but no validate workflow runs `task deps:check`; run it",
		"in a validate workflow, so an edited or half-updated copy cannot merge",
	])
}

# DEPS-15
findings contains lib.finding("DEPS-15", readme_path, message) if {
	some pin in pins
	not contains(readme_text, concat("", ["raw/badges/", pin.badge]))
	message := sprintf(
		concat(" ", [
			"%s pins %s but %s shows no currency badge for it; add",
			"![%s](https://github.com/musher-dev/<this-repository>/raw/badges/%s), so a reader sees",
			"when the pin falls behind",
		]),
		[pin.source, pin.label, readme_path, pin.label, pin.badge],
	)
}

# DEPS-16
findings contains lib.finding("DEPS-16", anchor_path, message) if {
	count(pins) > 0
	count(badge_workflow_paths) == 0
	message := sprintf(
		concat(" ", [
			"the repository pins %s but has no %s; add it, on a schedule and on a",
			"dependency-released repository_dispatch, calling %s, so its currency badges stay fresh",
		]),
		[concat(", ", sort({pin.label | some pin in pins})), badge_workflow_name, reusable_workflow],
	)
}

findings contains lib.finding("DEPS-16", path, message) if {
	count(pins) > 0
	some path in badge_workflow_paths
	not "schedule" in files.triggers(files.workflows[path])
	message := sprintf(
		concat(" ", [
			"%s does not run on a schedule; add a schedule trigger, so a badge turns when a release",
			"is published without a notification",
		]),
		[files.basename(path)],
	)
}

findings contains lib.finding("DEPS-16", path, message) if {
	count(pins) > 0
	some path in badge_workflow_paths
	not dispatched(files.workflows[path])
	message := sprintf(
		concat(" ", [
			"%s does not run on a repository_dispatch of type dependency-released; add it, so a",
			"producer's notification refreshes the badges at once",
		]),
		[files.basename(path)],
	)
}

findings contains lib.finding("DEPS-16", path, message) if {
	count(pins) > 0
	some path in badge_workflow_paths
	not renders(files.workflows[path])
	message := sprintf(
		concat(" ", [
			"%s does not render the badges; add a job that uses %s@<sha>, or a step",
			"that runs `conventions dependencies badges`",
		]),
		[files.basename(path), reusable_workflow],
	)
}

badge_workflow_name := "maintain-dependency-badges.yml"

reusable_workflow := "musher-dev/engineering-conventions/.github/workflows/reusable-maintain-dependency-badges.yml"

badge_workflow_paths contains path if {
	some path in files.workflow_files
	lower(files.stem(path)) == "maintain-dependency-badges"
}

dispatched(workflow) if {
	"repository_dispatch" in files.triggers(workflow)
	config := files.trigger_config(workflow, "repository_dispatch")
	"dependency-released" in files.as_list(config.types)
}

renders(workflow) if {
	some job in files.jobs(workflow)
	is_string(job.uses)
	startswith(job.uses, concat("", [reusable_workflow, "@"]))
}

renders(workflow) if {
	some job in files.jobs(workflow)
	some step in files.steps(job)
	some line in steps.command_lines(step)
	regex.match(`(^|[\s;&|(])conventions\s+dependencies\s+badges(\s|$)`, line)
}

readme_path := "README.md"

default readme_text := ""

readme_text := files.texts[readme_path]

mise_path := ".config/mise/config.toml"

# Every pin a badge shows: each vendored dependency, and the conventions
# bundle the mise configuration pins.
pins contains {
	"label": sprintf("%s %s", [dep.repository, dep.output]),
	"badge": sprintf("%s-%s.svg", [dep.repository, dep.output]),
	"source": files.dependencies_path,
} if {
	some dep in files.dependencies_declaration.dependencies
	is_string(dep.repository)
	is_string(dep.output)
}

pins contains {
	"label": "engineering-conventions",
	"badge": "engineering-conventions.svg",
	"source": mise_path,
} if {
	files.mise_pins[mise_path]
}

default anchor_path := ".config/mise/config.toml"

anchor_path := files.dependencies_path if vendors

vendors if {
	some dep in files.dependencies_declaration.dependencies
	is_object(dep)
}

validates if {
	some path, workflow in files.workflows
	filenames.slot(lower(files.stem(path))) == "validate"
	steps.runs_task(workflow, "deps:check")
}
