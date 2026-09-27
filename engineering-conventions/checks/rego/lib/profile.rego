# METADATA
# title: Effective convention profile
# description: >-
#   Resolves which convention profile applies, which requirements it enforces
#   and at what severity: the profile the conventions declaration names, else
#   the one named for the repository's kind, else base-repo. The index has
#   already flattened inheritance, so this only selects.
package conventions.lib.profile

import data.conventions.lib.files

catalog := object.get(data.conventions.index, "profiles", {})

declared_name := files.declaration.profile if is_string(files.declaration.profile)

# Every kind has a profile of the same name (the kinds_have_profiles
# invariant), so the identity declaration selects one without a
# conventions declaration (EC-0009).
kind_name := files.repository_declaration.kind if is_string(files.repository_declaration.kind)

default name := "base-repo"

# An unknown profile name falls back to the next choice rather than
# enforcing nothing: a typo must not silently switch every check off.
# ADOPT-07 names an unknown declared profile, REPO-03 an unknown kind.
name := declared_name if {
	catalog[declared_name]
} else := kind_name if {
	catalog[kind_name]
}

requirements := {id | some id in object.get(catalog, [name, "requirements"], [])}

in_profile(id) if id in requirements

default severity(_) := "warning"

# The index stores the effective severity per requirement; the catalog's own
# severity covers a requirement the profile does not restate.
severity(id) := catalog[name].severity[id]

severity(id) := data.conventions.index.requirements[id].severity if not catalog[name].severity[id]
