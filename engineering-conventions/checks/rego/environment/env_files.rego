# METADATA
# title: Local environment files
# description: >-
#   A developer's local .env is generated beside its environment schema by
#   conventions env-file and never committed (decision 0029): no environment
#   file is committed beside a schema or at the root (ENVS-26), and git
#   ignores the .env beside the product's schema (ENVS-27).
# scope: package
# custom:
#   convention: EC-0019
package conventions.checks.environment.env_files

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.paths

# ENVS-26
findings contains lib.finding("ENVS-26", path, message) if {
	some path in files.repository_files
	environment_file(path)
	directory := paths.directory(path)
	directory in env_directories
	message := sprintf(
		concat(" ", [
			"%s is an environment file in the repository; delete it from git, keep the variables in",
			"env.schema.yaml, and write a local .env with conventions env-file%s",
		]),
		[files.basename(path), schema_hint(directory)],
	)
}

# ENVS-27
findings contains lib.finding("ENVS-27", schema, message) if {
	some schema in schemas
	not startswith(schema, ".devcontainer/")
	target := concat("", [paths.directory(schema), ".env"])
	not ignored(target)
	message := sprintf(
		concat(" ", [
			"git does not ignore %s, where conventions env-file writes this schema's local values and",
			"secrets; add /%s to the root .gitignore",
		]),
		[target, target],
	)
}

# The environment schemas at the root, in the product directory and in
# .devcontainer/: where ENVS-02 allows one, and where it would report one.
# A vendored copy sits deeper and is not a schema of this repository.
schemas contains path if {
	some path in files.repository_files
	regex.match(`^([^/]+/)?env\.schema\.ya?ml$`, path)
}

# The directories, with a trailing slash ("" for the root), that an
# environment file must not be committed to: the root and each schema's.
env_directories contains ""

env_directories contains paths.directory(path) if some path in schemas

# .env, and every .env.<suffix>: .env.example, .env.local, .env.sample.
environment_file(path) if regex.match(`^\.env(\..+)?$`, files.basename(path))

schema_hint(directory) := sprintf(" %senv.schema.yaml", [directory]) if {
	some schema in schemas
	paths.directory(schema) == directory
} else := ""

# Whether git ignores PATH, by the .gitignore at the root and in each
# directory above PATH: the last pattern that matches decides, and a
# pattern starting with ! un-ignores. This covers the patterns a repository
# writes for a .env, and a bare name that ignores a parent directory; it does
# not follow git's rule that nothing inside an ignored directory can be
# un-ignored.
ignored(path) if {
	decisions := [[rank, negated] |
		some source in gitignores
		startswith(path, source.base)
		relative := substring(path, count(source.base), -1)
		some index, raw in split(source.text, "\n")
		line := trim_right(raw, " \r\t")
		line != ""
		not startswith(line, "#")
		negated := startswith(line, "!")
		pattern := trim_prefix(line, "!")
		matches(pattern, relative)
		rank := (source.depth * 1000000) + index
	]
	count(decisions) > 0
	last := max({decision[0] | some decision in decisions})
	some decision in decisions
	decision[0] == last
	not decision[1]
}

gitignores contains {"base": paths.directory(path), "depth": count(split(path, "/")), "text": text} if {
	some path, text in files.texts
	files.basename(path) == ".gitignore"
	not files.fixture(path)
}

# A pattern with no slash, or only a trailing one, matches a name at any
# depth; a pattern with a slash is anchored to the .gitignore's directory,
# and a leading **/ matches at any depth.
matches(pattern, relative) if {
	clean := trim_suffix(pattern, "/")
	not contains(clean, "/")
	some name in split(relative, "/")
	glob.match(clean, [], name)
}

matches(pattern, relative) if {
	contains(trim_suffix(pattern, "/"), "/")
	clean := trim_prefix(trim_suffix(pattern, "/"), "/")
	glob.match(clean, ["/"], relative)
}

matches(pattern, relative) if {
	startswith(pattern, "**/")
	rest := substring(pattern, 3, -1)
	glob.match(rest, ["/"], files.basename(relative))
}
