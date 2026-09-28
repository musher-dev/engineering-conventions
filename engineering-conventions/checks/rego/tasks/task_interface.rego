# METADATA
# title: Task interface
# description: >-
#   The root Taskfile defines the verbs every repository answers to: setup,
#   check and lint (TASK-10), build and test where the kind builds something
#   (TASK-11), and dev for a service (TASK-12). A verb counts when `task
#   <verb>` runs it from the repository root: a task, an alias, or a task a
#   flattened or namespaced include brings in.
# scope: package
# custom:
#   convention: EC-0016
package conventions.checks.tasks.task_interface

import data.conventions.lib.findings as lib
import data.conventions.lib.taskfiles

verbs := {
	"TASK-10": ["setup", "check", "lint"],
	"TASK-11": ["build", "test"],
	"TASK-12": ["dev"],
}

default root_path := "Taskfile.yml"

root_path := taskfiles.root_path

findings contains lib.finding(id, root_path, message) if {
	some id, required in verbs
	missing := [verb | some verb in required; not verb in taskfiles.root_names]
	count(missing) > 0
	message := missing_message(missing)
}

missing_message(missing) := sprintf(
	concat(" ", [
		"the repository has no root Taskfile; add Taskfile.yml defining %s, so `task <verb>`",
		"works the same in every repository",
	]),
	[listed(missing)],
) if {
	not taskfiles.root_path
}

missing_message(missing) := sprintf(
	concat(" ", [
		"the root Taskfile does not define %s; add %s, or an alias of an existing task, so",
		"`task <verb>` works the same in every repository",
	]),
	[listed(missing), plural(missing)],
) if {
	taskfiles.root_path
}

listed(missing) := concat(", ", [sprintf("%q", [verb]) | some verb in missing])

plural(missing) := "that task" if count(missing) == 1

plural(missing) := "those tasks" if count(missing) > 1
