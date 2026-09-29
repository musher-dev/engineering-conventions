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

# The lines of a step's code that the shell runs as commands: lines(step)
# without the body of a heredoc, and without a line that only prints text
# (echo, printf). A command a step shows its reader, such as the fix it asks
# for in an error message, is not a command it runs.
command_lines(step) := [line |
	code_lines := lines(step)
	quoted := heredoc_body(code_lines)
	some index, line in code_lines
	not index in quoted
	not printed(line)
]

# The indexes of the lines between a heredoc's opening line (`<<WORD`,
# `<<-WORD`, `<< 'WORD'`, not a `<<<` here-string) and its closing WORD,
# the closing line included.
heredoc_body(code_lines) := {index |
	some opening, line in code_lines
	some match in regex.find_all_string_submatch_n(`(?:^|[^<])<<-?\s*["']?([A-Za-z_][A-Za-z0-9_]*)["']?`, line, -1)
	some index, _ in code_lines
	index > opening
	not closed_before(code_lines, opening, index, match[1])
}

closed_before(code_lines, opening, index, word) if {
	some between, line in code_lines
	between > opening
	between < index
	line == word
}

# A line that only prints: it starts with echo or printf and chains no
# further command after it.
printed(line) if {
	regex.match(`^(echo|printf)(\s|$)`, line)
	not regex.match(`(&&|\|\||;)`, line)
}

# A value written into the file, not computed when the workflow runs.
literal(value) if {
	is_string(value)
	not contains(value, "${{")
}

literal(value) if is_number(value)

literal(value) if is_boolean(value)
