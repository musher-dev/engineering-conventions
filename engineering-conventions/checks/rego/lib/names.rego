# METADATA
# title: Naming vocabulary
# description: >-
#   The token sets, display forms and identifier shapes the naming checks
#   share, read from the generated index and extended by the conventions
#   declaration.
package conventions.lib.names

import data.conventions.lib.files

vocabulary := object.get(data.conventions.index, "vocabulary", {})

responsibility_tokens := {token | some token in object.get(vocabulary, "responsibility_tokens", [])}

capability_tokens := {token | some token in object.get(vocabulary, "capability_tokens", [])}

action_tokens := {token | some token in object.get(vocabulary, "action_tokens", [])}

banned_tokens := object.get(vocabulary, "banned_identifier_tokens", {})

# The banned tokens that name when a workflow runs. They are wrong anywhere
# in a filename; every other banned token is a synonym, wrong only where the
# responsibility goes.
schedule_tokens := {token | some token in object.get(vocabulary, "schedule_tokens", [])}

default declared_display_forms := {}

# The declaration may give display forms as a mapping or as a list of
# {token, display} entries (the terminology file's shape). Both only add to
# the index: a release's form always wins, so every repository derives the
# same name from the same token. The runner reports an attempted override.
declared_display_forms := forms if {
	forms := files.declaration.vocabulary.display_forms
	is_object(forms)
}

declared_display_forms := {entry.token: entry.display |
	some entry in files.declaration.vocabulary.display_forms
	is_string(entry.token)
	is_string(entry.display)
} if {
	is_array(files.declaration.vocabulary.display_forms)
}

display_forms := object.union(declared_display_forms, object.get(vocabulary, "display_forms", {}))

display_word(token) := display_forms[token]

display_word(token) := concat("", [upper(substring(token, 0, 1)), substring(token, 1, -1)]) if {
	not display_forms[token]
}

# `deploy-production-api` -> `Deploy Production API`.
title_case(stem) := concat(" ", [display_word(token) | some token in split(stem, "-")])

# The name GHA-07 requires of a workflow.
expected_workflow_name(path) := title_case(files.stem(path))

# The workflow names a job qualifier may use: the required one, and the one
# actually declared, so one wrong `name:` is reported once (GHA-07) rather
# than again on every job.
accepted_workflow_names(path, workflow) := {expected_workflow_name(path), workflow.name} if is_string(workflow.name)

accepted_workflow_names(path, workflow) := {expected_workflow_name(path)} if not files.has_string(workflow, "name")

tokens(stem) := split(stem, "-")

reusable_prefix := "reusable-"

is_reusable_name(stem) if startswith(stem, reusable_prefix)

# The tokens that carry meaning: the `reusable-` marker is grammar, not a word.
meaningful_tokens(stem) := tokens(trim_prefix(stem, reusable_prefix)) if is_reusable_name(stem)

meaningful_tokens(stem) := tokens(stem) if not is_reusable_name(stem)

# Lowercase kebab-case; a leading digit is refused because a filename that
# sorts before every word reads as an ordering hack, not a responsibility.
workflow_filename_pattern := `^(reusable-)?[a-z][a-z0-9]*(-[a-z0-9]+)*\.(yml|yaml)$`

kebab_pattern := `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`

snake_pattern := `^[a-z][a-z0-9_]*$`

is_snake_case(identifier) if regex.match(snake_pattern, identifier)

# `buildImage` / `build-image` / `Build Image` -> `build_image`.
snake_case(identifier) := trim(
	regex.replace(
		lower(regex.replace(identifier, `([a-z0-9])([A-Z])`, "${1}_${2}")),
		`[^a-z0-9]+`,
		"_",
	),
	"_",
)

# `toolVersion` / `tool_version` -> `tool-version`, for an input or output.
kebab_identifier(identifier) := kebab_case(regex.replace(identifier, `([a-z0-9])([A-Z])`, "${1}-${2}"))

# `Deploy_API.YML` -> `deploy-api.yml`; used only to suggest a rename.
kebab_case(text) := trim(regex.replace(lower(text), `[^a-z0-9]+`, "-"), "-")

quoted_list(values) := concat(", ", [sprintf("%q", [value]) | some value in sort(values)])
