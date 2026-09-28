# METADATA
# title: Steps and their shell code
# description: >-
#   Every step a workflow job or a composite action runs, with where a reader
#   finds it, and the code of a run: block without its comments, so a check
#   that reads shell text does not flag the comment that explains a rule.
package conventions.lib.steps

import data.conventions.lib.files

# Each step as {"path", "where", "label", "step"}: `where` names the job, or
# the action, that holds it.
entries contains {"path": entry.path, "where": where, "label": label, "step": entry.step} if {
	some entry in files.workflow_steps
	where := sprintf("job %q", [entry.job])
	label := files.step_label(entry.step, entry.index)
}

entries contains {"path": entry.path, "where": "the action", "label": label, "step": entry.step} if {
	some entry in files.action_step_entries
	label := files.step_label(entry.step, entry.index)
}

# The step's action, without its version, when it runs one.
action(step) := regex.replace(step.uses, `@.*$`, "") if is_string(step.uses)

default inputs(_) := {}

inputs(step) := step["with"] if is_object(step["with"])

# The code of a run: block, one command line per line: comment lines dropped
# and backslash continuations joined.
code(step) := regex.replace(without_comments(step.run), `[ \t]*\\\r?\n[ \t]*`, " ") if is_string(step.run)

without_comments(text) := concat("\n", [line |
	some line in split(text, "\n")
	not regex.match(`^\s*#`, line)
])

# Each non-empty line of a step's code.
lines(step) := [trim_space(line) | some line in split(code(step), "\n"); trim_space(line) != ""]

# A value written into the file, not computed when the workflow runs.
literal(value) if {
	is_string(value)
	not contains(value, "${{")
}

literal(value) if is_number(value)

literal(value) if is_boolean(value)
