# METADATA
# title: Input classification
# description: >-
#   Sorts the combined conftest input into the workflows, actions, rulesets,
#   conventions declaration and inventory that the checks read, and gives
#   every workflow the same view of its triggers and jobs.
package conventions.lib.files

declaration_path := ".repo/conventions.yaml"

# conftest keeps each path as the runner passed it, so `./x` and `x` must name
# the same file before any path comparison or waiver glob sees it.
normalise(path) := trim_prefix(path, "./")

documents := [{"path": normalise(doc.path), "contents": doc.contents} |
	is_array(input)
	some doc in input
	is_object(doc)
	is_string(doc.path)
]

# The inventory is identified by its top-level key, never by its path: the
# runner writes it to a temporary directory outside the repository.
is_inventory(contents) if is_array(contents.conventions_inventory.files)

inventory_documents := [doc | some doc in documents; is_inventory(doc.contents)]

inventory contains normalise(file) if {
	some doc in inventory_documents
	some file in doc.contents.conventions_inventory.files
	is_string(file)
}

passed_paths contains doc.path if {
	some doc in documents
	not is_inventory(doc.contents)
}

# Every file the repository holds, whether or not its contents were passed.
repository_files := inventory | passed_paths

# The extension is matched case-insensitively so that a `.YML` file is still
# seen as a workflow, and GHA-01 can ask for the lowercase extension.
workflow_path_pattern := `^\.github/workflows/[^/]+\.(?i:ya?ml)$`

workflows[doc.path] := doc.contents if {
	some doc in documents
	regex.match(workflow_path_pattern, doc.path)
	is_object(doc.contents)
}

actions[doc.path] := doc.contents if {
	some doc in documents
	regex.match(`^\.github/actions/.+/action\.ya?ml$`, doc.path)
	is_object(doc.contents)
}

rulesets[doc.path] := doc.contents if {
	some doc in documents
	regex.match(`^\.github/rulesets/[^/]+\.json$`, doc.path)
	is_object(doc.contents)
}

# Every workflow file the repository holds, including one whose contents
# could not be passed, so a suggested rename never collides with it.
workflow_files contains path if {
	some path in repository_files
	regex.match(workflow_path_pattern, path)
}

declared if declaration_path in repository_files

# An empty or non-mapping declaration reads as an empty one; ADOPT-02 (the
# schema check the runner performs) is what reports its shape.
default declaration := {}

declaration := doc.contents if {
	some doc in documents
	doc.path == declaration_path
	is_object(doc.contents)
}

basename(path) := regex.replace(path, `^.*/`, "")

stem(path) := regex.replace(basename(path), `\.(?i:ya?ml)$`, "")

extension(path) := regex.replace(basename(path), `^.*\.`, "")

# YAML 1.1 reads an unquoted `on:` key as the boolean true, which conftest
# serialises as the string key "true"; a quoted `"on":` stays "on".
on_value(workflow) := workflow.on

on_value(workflow) := workflow["true"] if not "on" in object.keys(workflow)

default triggers(_) := set()

triggers(workflow) := {value} if {
	value := on_value(workflow)
	is_string(value)
}

triggers(workflow) := {event | some event in on_value(workflow); is_string(event)} if is_array(on_value(workflow))

triggers(workflow) := {event | some event, _ in on_value(workflow)} if is_object(on_value(workflow))

# The configuration under one event, only when `on:` is the mapping form.
trigger_config(workflow, event) := on_value(workflow)[event] if is_object(on_value(workflow))

# The three workflow units, defined once for every check:
#   - an entry point has a trigger other than workflow_call, so it runs on
#     its own and GitHub reports its jobs' names verbatim;
#   - a callable workflow has a workflow_call trigger, so a caller can run it
#     and GitHub then prefixes its jobs with the caller's job name;
#   - a reusable workflow has workflow_call as its only trigger.
# A workflow with workflow_call and another trigger is both an entry point
# and callable.
is_entry_point(workflow) if count(triggers(workflow) - {"workflow_call"}) > 0

is_callable(workflow) if "workflow_call" in triggers(workflow)

is_reusable(workflow) if triggers(workflow) == {"workflow_call"}

default jobs(_) := {}

jobs(workflow) := {job_id: job |
	some job_id, job in workflow.jobs
	is_object(job)
} if {
	is_object(workflow.jobs)
}

default steps(_) := []

steps(container) := [step | some step in container.steps; is_object(step)] if is_array(container.steps)

default action_steps(_) := []

action_steps(action) := steps(action.runs) if is_object(action.runs)

# Every step a workflow or action holds, keyed by where a reader finds it.
workflow_steps contains {"path": path, "job": job_id, "index": index, "step": step} if {
	some path, workflow in workflows
	some job_id, job in jobs(workflow)
	some index, step in steps(job)
}

action_step_entries contains {"path": path, "index": index, "step": step} if {
	some path, action in actions
	some index, step in action_steps(action)
}

default as_list(_) := []

# `a` or `[a, b]`: both shapes occur for `needs` and `workflow_run.workflows`.
as_list(value) := [value] if is_string(value)

as_list(value) := value if is_array(value)

# `not is_string(x.key)` would be undefined, not true, for a missing key: OPA
# evaluates a call's arguments outside the negation. Negate this instead.
has_string(value, key) if is_string(value[key])

# The display of a step for messages: its id, else its name, else its position.
step_label(step, _) := sprintf("step %q", [step.id]) if has_string(step, "id")

step_label(step, _) := sprintf("step %q", [step.name]) if {
	not has_string(step, "id")
	has_string(step, "name")
}

step_label(step, index) := sprintf("step %d", [index + 1]) if {
	not has_string(step, "id")
	not has_string(step, "name")
}
