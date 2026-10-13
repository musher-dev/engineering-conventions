# METADATA
# title: Deployment environments
# description: >-
#   The registered deployment environments (data.conventions.index.vocabulary
#   .deployment_environments, name -> slug) and the other words a workflow
#   uses for them, each mapped to the name to write instead (GHA-49 to
#   GHA-51).
package conventions.lib.environments

# name -> slug, from the terminology's deployment.environment terms.
registered := object.get(data.conventions.index.vocabulary, "deployment_environments", {})

names := object.keys(registered)

# Common words for a deployment environment that are neither its name nor
# its slug, by the name they stand for. A word stands only for a registered
# environment.
common_synonyms := {
	"prd": "production",
	"live": "production",
	"stg": "staging",
	"stage": "staging",
	"preprod": "staging",
	"local": "development",
}

# Every word, other than a name, that stands for a deployment environment:
# its slug, where that differs from the name, or a common synonym.
other_words[slug] := name if {
	some name, slug in registered
	slug != name
}

other_words[word] := name if {
	some word, name in common_synonyms
	name in names
	not word in object.keys(registered)
}

# A word for production: its name and its slug.
default production_words := {"production"}

production_words := {"production", slug} if {
	slug := registered.production
}

# The words that, inside a secret or variable name, scope it to a
# deployment environment: every name, slug and synonym, less those that
# usually mean a service's own mode there (a payment provider's test or
# live keys, TestPyPI), a developer's machine, or a tool's own dev mode (a
# dev database URL, a dev server), as ENVS-30 does.
name_words := (names | object.keys(other_words)) - {"test", "live", "local", "dev", "development"}
