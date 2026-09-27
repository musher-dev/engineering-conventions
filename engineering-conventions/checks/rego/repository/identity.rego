# METADATA
# title: Identity declaration
# description: >-
#   A repository declares its identity in .repo/repository.toml (REPO-01),
#   and the declaration is valid (REPO-02), names registered values
#   (REPO-03) and a name made of its system and component (REPO-04).
# scope: package
# custom:
#   convention: EC-0009
package conventions.checks.repository.identity

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.names
import data.conventions.lib.repository
import data.conventions.lib.schema

# REPO-01
findings contains lib.finding("REPO-01", files.repository_path, message) if {
	not files.repository_declared
	message := sprintf(
		concat(" ", [
			"the repository does not declare its identity; add %s with its name, system,",
			"component, kind, owner, lifecycle, audience and tier",
		]),
		[files.repository_path],
	)
}

# REPO-02. One finding per declaration: the first problem, and how many more.
findings contains lib.finding("REPO-02", files.repository_path, schema.summary(problems)) if {
	problems := schema.problems(files.repository_documents, data.conventions.index.repository_schema)
	count(problems) > 0
}

# REPO-03
findings contains lib.finding("REPO-03", files.repository_path, message) if {
	some field, values in registered
	value := files.repository_declaration[field]
	is_string(value)
	not value in values
	message := sprintf(
		"%s %q is not a registered %s; use one of %s",
		[field, value, field, names.quoted_list(values)],
	)
}

# REPO-04. A reserved name (.github) cannot be <system>-<component>.
findings contains lib.finding("REPO-04", files.repository_path, message) if {
	not repository.exempt
	declaration := files.repository_declaration
	is_string(declaration.name)
	is_string(declaration.system)
	is_string(declaration.component)
	expected := concat("-", [declaration.system, declaration.component])
	declaration.name != expected
	message := sprintf(
		concat(" ", [
			"name is %q, but system and component make %q; a repository's name is",
			"<system>-<component>, so correct whichever is wrong",
		]),
		[declaration.name, expected],
	)
}

registered := {
	"system": repository.systems,
	"kind": repository.kinds,
	"lifecycle": repository.lifecycles,
	"audience": repository.audiences,
}
