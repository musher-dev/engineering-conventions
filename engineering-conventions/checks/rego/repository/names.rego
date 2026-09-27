# METADATA
# title: Repository names
# description: >-
#   The declared name is the actual one (REPO-07), and the name is
#   <system>-<component> in lowercase kebab-case (REPO-08), starts with a
#   registered system (REPO-09), holds no banned token or version (REPO-10)
#   and is short (REPO-11). Every finding is on the identity declaration.
# scope: package
# custom:
#   convention: EC-0010
package conventions.checks.repository.names

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.names
import data.conventions.lib.repository

# REPO-07. Only when the runner knows the actual name.
findings contains lib.finding("REPO-07", files.repository_path, message) if {
	not repository.exempt
	actual := files.actual_repository_name
	declared := repository.declared_name
	declared != actual
	message := sprintf(
		concat(" ", [
			"the declaration names the repository %q, but it is %q; set name to %q, with system",
			"and component to match, or rename the repository and its declaration together",
		]),
		[declared, actual, actual],
	)
}

# REPO-08
findings contains lib.finding("REPO-08", files.repository_path, message) if {
	not repository.exempt
	name := repository.judged_name
	not repository.well_formed(name)
	message := sprintf("repository name %q %s", [name, malformed(name)])
}

# REPO-09. A name that starts with a banned token is REPO-10's, and a
# declared system that is not registered is already REPO-03's.
findings contains lib.finding("REPO-09", files.repository_path, message) if {
	not repository.exempt
	name := repository.judged_name
	repository.well_formed(name)
	system := repository.system_token(name)
	not system in repository.systems
	not repository.banned(system)
	not declares_system(system)
	message := sprintf(
		concat(" ", [
			"repository name %q starts with %q, which is not a registered system;",
			"start it with one of %s",
		]),
		[name, system, names.quoted_list(repository.systems)],
	)
}

# REPO-10
findings contains lib.finding("REPO-10", files.repository_path, message) if {
	not repository.exempt
	name := repository.judged_name
	repository.well_formed(name)
	some token in repository.tokens(name)
	repository.banned(token)
	message := sprintf("repository name %q holds the token %q. %s", [name, token, repository.advice(token)])
}

# REPO-11. A name over the hard limit is REPO-08's.
findings contains lib.finding("REPO-11", files.repository_path, message) if {
	not repository.exempt
	name := repository.judged_name
	repository.well_formed(name)
	count(name) > repository.preferred_length
	message := sprintf(
		concat(" ", [
			"repository name %q is %d characters, more than %d; shorten the component so the name",
			"stays readable in paths, image names and URLs",
		]),
		[name, count(name), repository.preferred_length],
	)
}

declares_system(system) if files.repository_declaration.system == system

malformed(name) := sprintf(
	"is %d characters, more than %d; shorten the component",
	[count(name), repository.max_length],
) if {
	count(name) > repository.max_length
} else := sprintf("is not lowercase kebab-case; rename it to %q", [suggestion]) if {
	suggestion := names.kebab_case(name)
	suggestion != name
	regex.match(repository.name_pattern, suggestion)
} else := concat(" ", [
	"is not <system>-<component>: a registered system, a hyphen and a component,",
	"in lowercase letters, digits and hyphens",
])
