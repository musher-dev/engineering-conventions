# METADATA
# title: Effective convention profile
# description: >-
#   Resolves which convention profile applies, which requirements it enforces
#   and at what severity. The index has already flattened inheritance, so this
#   only selects.
package conventions.lib.profile

import data.conventions.lib.files

catalog := object.get(data.conventions.index, "profiles", {})

declared_name := files.declaration.profile if is_string(files.declaration.profile)

default name := "base-repo"

# An unknown profile name falls back to the default rather than enforcing
# nothing: a typo must not silently switch every check off. ADOPT-02 (the
# declaration schema) is what names the typo.
name := declared_name if catalog[declared_name]

requirements := {id | some id in object.get(catalog, [name, "requirements"], [])}

in_profile(id) if id in requirements

default severity(_) := "warning"

# The index stores the effective severity per requirement; the catalog's own
# severity covers a requirement the profile does not restate.
severity(id) := catalog[name].severity[id]

severity(id) := data.conventions.index.requirements[id].severity if not catalog[name].severity[id]
