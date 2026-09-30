# METADATA
# title: Keeping dependencies current
# description: >-
#   A repository that vendors dependencies defines the tasks that verify and
#   update them (DEPS-08), verifies its copies in a validate workflow
#   (DEPS-09), and updates them from a scheduled maintain-dependencies
#   workflow (DEPS-10).
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

# DEPS-10
findings contains lib.finding("DEPS-10", files.dependencies_path, message) if {
	vendors
	count(maintain_paths) == 0
	message := sprintf(
		concat(" ", [
			"the repository vendors dependencies but has no %s; add it, on a schedule, to run",
			"`task deps:sync` and open a pull request for each new release",
		]),
		[maintain_name],
	)
}

findings contains lib.finding("DEPS-10", path, message) if {
	vendors
	some path in maintain_paths
	workflow := files.workflows[path]
	not "schedule" in files.triggers(workflow)
	message := sprintf(
		concat(" ", [
			"%s does not run on a schedule; add a schedule trigger, so a new release is picked up",
			"even when its producer sends no notification",
		]),
		[files.basename(path)],
	)
}

findings contains lib.finding("DEPS-10", path, message) if {
	vendors
	some path in maintain_paths
	workflow := files.workflows[path]
	not steps.runs_task(workflow, "deps:sync")
	message := sprintf(
		"%s does not run `task deps:sync`; run it, so the workflow updates every vendored copy the same way",
		[files.basename(path)],
	)
}

maintain_name := "maintain-dependencies.yml"

maintain_paths contains path if {
	some path in files.workflow_files
	lower(files.stem(path)) == "maintain-dependencies"
}

vendors if {
	some dep in files.dependencies_declaration.dependencies
	is_object(dep)
}

validates if {
	some path, workflow in files.workflows
	filenames.slot(lower(files.stem(path))) == "validate"
	steps.runs_task(workflow, "deps:check")
}
