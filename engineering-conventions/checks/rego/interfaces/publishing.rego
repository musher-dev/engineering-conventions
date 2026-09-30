# METADATA
# title: Publishing interfaces
# description: >-
#   A repository that declares interfaces defines the tasks that keep them
#   honest (IFACE-11), runs the drift and breaking-change tasks in a validate
#   workflow (IFACE-12), and builds each bundle that delivers them, with its
#   release record, in the workflow that publishes it (IFACE-13).
# scope: package
# custom:
#   convention: EC-0031
package conventions.checks.interfaces.publishing

import data.conventions.lib.contracts
import data.conventions.lib.filenames
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.steps
import data.conventions.lib.taskfiles

default root_path := "Taskfile.yml"

root_path := taskfiles.root_path

# IFACE-11
findings contains lib.finding("IFACE-11", root_path, message) if {
	count(contracts.interfaces) > 0
	missing := [name | some name in sort(required_tasks); not name in taskfiles.root_names]
	count(missing) > 0
	message := sprintf(
		concat(" ", [
			"the repository declares interfaces in %s but its root Taskfile does not define %s; add",
			"them, so every producer regenerates, checks, compares and bundles its interfaces the same way",
		]),
		[files.outputs_path, concat(", ", [sprintf("%q", [name]) | some name in missing])],
	)
}

# IFACE-12
findings contains lib.finding("IFACE-12", files.outputs_path, message) if {
	count(contracts.interfaces) > 0
	some name in validated_tasks
	not validates(name)
	message := sprintf(
		concat(" ", [
			"the repository declares interfaces but no validate workflow runs `task %s`; run it in a",
			"validate workflow, so a change that drifts from or breaks an interface cannot merge",
		]),
		[name],
	)
}

# IFACE-13. Reported on the workflow that publishes the bundle.
findings contains lib.finding("IFACE-13", path, message) if {
	some id in bundles
	some output in files.outputs_declaration.outputs
	output.id == id
	path := concat("", [".github/workflows/", output.publish_workflow])
	workflow := files.workflows[path]
	not steps.runs_task(workflow, "contracts:bundle")
	message := sprintf(
		concat(" ", [
			"%s publishes bundle %q, which delivers interfaces, but does not run `task contracts:bundle`;",
			"build the bundle and its release.json with that task in the workflow that publishes it",
		]),
		[files.basename(path), id],
	)
}

validated_tasks := ["contracts:check", "contracts:breaking"]

# The bundle outputs that deliver an interface.
bundles contains output.id if {
	some entry in contracts.interfaces
	some output in files.outputs_declaration.outputs
	is_object(output)
	output.id == entry.delivered_by
	output.kind == "bundle"
}

required_tasks contains name if some name in validated_tasks

required_tasks contains "contracts:bundle" if count(bundles) > 0

required_tasks contains "contracts:generate" if {
	some entry in contracts.interfaces
	entry.generated == true
}

validates(name) if {
	some path, workflow in files.workflows
	filenames.slot(lower(files.stem(path))) == "validate"
	steps.runs_task(workflow, name)
}
