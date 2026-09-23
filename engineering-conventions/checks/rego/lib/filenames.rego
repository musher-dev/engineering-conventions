# METADATA
# title: Workflow filenames
# description: >-
#   What GHA-01 to GHA-05 require of a workflow filename, as predicates on a
#   name, so the checks that report those requirements, the checks that wait
#   for a rename (GHA-07, GHA-12, GHA-16) and every suggested filename agree.
package conventions.lib.filenames

import data.conventions.lib.files
import data.conventions.lib.names

grammar_ok(basename) if regex.match(names.workflow_filename_pattern, basename)

# The responsibility slot: the first token after an optional `reusable-`.
slot(stem) := names.meaningful_tokens(stem)[0]

# GHA-05. A synonym is banned only in the responsibility slot, because as a
# scope it can be the thing acted on (`release-pr`); a schedule token names
# when the workflow runs wherever it appears.
banned_at(0, token) if names.banned_tokens[token]

banned_at(_, token) if token in names.schedule_tokens

offending_tokens(stem) := [token |
	some position, token in names.meaningful_tokens(stem)
	banned_at(position, token)
]

has_offending_token(stem) if count(offending_tokens(stem)) > 0

# The tokens that may fill the responsibility slot: a reusable workflow may
# also name a capability.
leading_tokens(stem) := names.responsibility_tokens | names.capability_tokens if names.is_reusable_name(stem)

leading_tokens(stem) := names.responsibility_tokens if not names.is_reusable_name(stem)

# GHA-02 and GHA-04. A banned token in the slot is left to GHA-05, which can
# say what replaces it.
slot_unknown(stem) if {
	token := slot(stem)
	not token in leading_tokens(stem)
	not names.banned_tokens[token]
}

# GHA-03: the prefix is present exactly when workflow_call is the only trigger.
prefix_mismatch(stem, workflow) if {
	names.is_reusable_name(stem)
	not files.is_reusable(workflow)
}

prefix_mismatch(stem, workflow) if {
	not names.is_reusable_name(stem)
	files.is_reusable(workflow)
}

# A filename no check among GHA-01 to GHA-05 reports.
valid(basename, workflow) if {
	grammar_ok(basename)
	stem := files.stem(basename)
	not has_offending_token(stem)
	slot(stem) in leading_tokens(stem)
	not prefix_mismatch(stem, workflow)
}

# The workflows whose filename has to change. Their name, job qualifiers and
# aggregate are derived from a stem that is about to be replaced, so the
# checks that derive from it wait for the rename.
renaming contains path if {
	some path, workflow in files.workflows
	not valid(files.basename(path), workflow)
}

prefix_for(workflow) := names.reusable_prefix if files.is_reusable(workflow)

prefix_for(workflow) := "" if not files.is_reusable(workflow)

# Schedule tokens are dropped and a synonym in the slot is replaced, but only
# by a single token: a choice between responsibilities is the author's.
normalised_tokens(tokens) := array.concat([replacement], array.slice(kept, 1, count(kept))) if {
	kept := [token | some token in tokens; not token in names.schedule_tokens]
	replacement := names.banned_tokens[kept[0]]
	regex.match(`^[a-z][a-z0-9]*$`, replacement)
}

normalised_tokens(tokens) := kept if {
	kept := [token | some token in tokens; not token in names.schedule_tokens]
	not names.banned_tokens[kept[0]]
}

# The one filename suggested for a workflow, whichever requirement a message
# is about. It is offered only when it satisfies GHA-01 to GHA-05 together
# and no other workflow file already has its stem; otherwise none is.
suggestion(path, workflow) := candidate if {
	tokens := normalised_tokens(names.meaningful_tokens(names.kebab_case(files.stem(path))))
	stem := concat("", [prefix_for(workflow), concat("-", tokens)])
	candidate := concat(".", [stem, lower(files.extension(path))])
	candidate != files.basename(path)
	valid(candidate, workflow)
	not collides(stem, path)
}

collides(stem, path) if {
	some other in files.workflow_files
	other != path
	lower(files.stem(other)) == stem
}
