# METADATA
# title: Repository identity and name
# description: >-
#   The registered systems, kinds, lifecycles and audiences, the tokens a
#   repository name may not hold, and the name the naming checks judge: the
#   actual name when the runner knows it, else the declared one (EC-0010).
package conventions.lib.repository

import data.conventions.lib.files

vocabulary := object.get(data.conventions.index, "vocabulary", {})

systems := {token | some token in object.get(vocabulary, "repository_systems", [])}

kinds := {token | some token in object.get(vocabulary, "repository_kinds", [])}

lifecycles := {token | some token in object.get(vocabulary, "repository_lifecycles", [])}

audiences := {token | some token in object.get(vocabulary, "repository_audiences", [])}

# Each banned token with the advice REPO-10 prints.
banned_tokens := object.get(vocabulary, "banned_repository_tokens", {})

declared_name := files.repository_declaration.name if is_string(files.repository_declaration.name)

judged_name := files.actual_repository_name

judged_name := declared_name if not files.actual_repository_name

# GitHub reserves these names for an organization's default community
# health files and profile, so they cannot follow the grammar.
exempt_names := {".github", ".github-private"}

exempt if judged_name in exempt_names

# Lowercase kebab-case with at least two tokens: a system, then a component.
name_pattern := `^[a-z][a-z0-9]*(-[a-z0-9]+)+$`

# GitHub allows 100 characters; 63 is the DNS label limit that image names,
# Kubernetes objects and hostnames derived from a repository name meet.
max_length := 63

preferred_length := 40

well_formed(name) if {
	regex.match(name_pattern, name)
	count(name) <= max_length
}

tokens(name) := split(name, "-")

system_token(name) := tokens(name)[0]

version_pattern := `^v[0-9]+$`

banned(token) if banned_tokens[token]

banned(token) if regex.match(version_pattern, token)

advice(token) := banned_tokens[token]

advice(token) := concat(" ", [
	"Names a version, which changes while the name must not; drop the token",
	"and version what the repository publishes instead.",
]) if {
	regex.match(version_pattern, token)
	not banned_tokens[token]
}
