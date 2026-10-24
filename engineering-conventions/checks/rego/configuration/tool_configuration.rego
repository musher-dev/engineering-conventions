# METADATA
# title: Tool configuration
# description: >-
#   Tool configuration lives in .config/, bucketed by concern and indexed in
#   .config/README.md (CONF-01..03, 05..08); every file there has a caller
#   that names it (CONF-04), every .config/ path a caller names exists
#   (CONF-09), and every pattern in the root .gitattributes matches a file
#   (CONF-13).
# scope: package
# custom:
#   convention: EC-0011
package conventions.checks.configuration.tool_configuration

import data.conventions.lib.doublestar
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.gitignore
import data.conventions.lib.values

index_path := ".config/README.md"

# Every file under .config/ outside the declared fixtures.
config_files contains path if {
	some path in files.repository_files
	startswith(path, ".config/")
}

relative(path) := trim_prefix(path, ".config/")

readme(path) if files.basename(path) == "README.md"

# lefthook-local.yml is one person's hook overrides, kept out of git: it is
# never indexed and never named.
local_override(path) if regex.match(`^\.config/lefthook-local\.ya?ml$`, path)

# CONF-01. A known tool's configuration at the root, where the tool finds it
# by searching instead of being told.
findings contains lib.finding("CONF-01", path, message) if {
	some path in files.repository_files
	tool := root_configs[path]
	message := sprintf(
		concat(" ", [
			"%s configuration sits at the repository root; move it to .config/<concern>/%s",
			"and pass that path to %s explicitly",
		]),
		[tool, suggested_name(path), tool],
	)
}

# CONF-02
findings contains lib.finding("CONF-02", index_path, message) if {
	count(indexable) > 0
	not index_path in files.repository_files
	message := concat(" ", [
		".config/ holds tool configuration but no index; add .config/README.md with one row",
		"per file naming the tool, what it configures and its caller",
	])
}

# CONF-03. The index names a file by its path under .config/, its name, or a
# directory that holds it.
findings contains lib.finding("CONF-03", path, message) if {
	text := files.texts[index_path]
	tokens := indexed_tokens(text)
	some path in indexable
	not indexed(tokens, relative(path))
	message := sprintf(
		"%s is not listed in .config/README.md; add a row for `%s` naming its tool and caller",
		[path, relative(path)],
	)
}

# CONF-04
findings contains lib.finding("CONF-04", path, message) if {
	some path in config_files
	not readme(path)
	not self_discovered(path)
	not called(path)
	message := sprintf(
		concat(" ", [
			"nothing names %s; pass it by path from a Taskfile, the lefthook configuration,",
			"a workflow, an action or devcontainer.json, or delete it",
		]),
		[path],
	)
}

# CONF-05
findings contains lib.finding("CONF-05", path, message) if {
	some path in config_files
	name := files.basename(path)
	startswith(name, ".")
	message := sprintf(
		"%s has a leading dot inside .config/; rename it to %s and update its callers",
		[path, trim_left(name, ".")],
	)
}

# CONF-06
findings contains lib.finding("CONF-06", path, message) if {
	some path in files.repository_files
	regex.match(`^\.?lefthook\.(ya?ml|jsonc?|toml)$`, path)
	message := sprintf(
		concat(" ", [
			"%s at the root wins lefthook's search over .config/lefthook.yml, so the hooks",
			"you edit there never run; move its jobs into .config/lefthook.yml and delete it",
		]),
		[path],
	)
}

# CONF-07
findings contains lib.finding("CONF-07", path, message) if {
	some path in config_files
	regex.match(`^\.config/[^/]+$`, path)
	not files.basename(path) in top_level_allowed
	message := sprintf(
		concat(" ", [
			"%s sits at the top level of .config/, which holds only README.md, lefthook.yml",
			"and lefthook-local.yml; move it to .config/<concern>/%s",
		]),
		[path, trim_left(files.basename(path), ".")],
	)
}

# CONF-08
findings contains lib.finding("CONF-08", path, message) if {
	some path in config_files
	lower(files.extension(path)) in program_extensions
	message := sprintf(
		concat(" ", [
			"%s is a program, and .config/ holds only declarations; move it beside",
			"what runs it, such as a scripts/ directory",
		]),
		[path],
	)
}

# CONF-09
findings contains lib.finding("CONF-09", reference.caller, message) if {
	some reference in references
	not local_override(reference.path)
	not exists(reference.path)
	message := sprintf(
		"names %s, which does not exist; correct the path or remove the reference",
		[reference.path],
	)
}

# CONF-13
findings contains lib.finding("CONF-13", gitattributes_path, message) if {
	some entry in gitattributes_patterns
	not attributed(entry.pattern)
	message := sprintf(
		concat(" ", [
			"line %d: the pattern %s matches no file in the repository, so its attributes apply to",
			"nothing; point it at the files it is meant for, or delete the line",
		]),
		[entry.line, entry.pattern],
	)
}

# CONF-14
findings contains lib.finding("CONF-14", concat("/", [".config", concern]), message) if {
	some concern in concerns_in_use
	not concern in registered_concerns
	message := sprintf(
		concat(" ", [
			".config/%s/ is not a registered concern; name the directory for the files its tool reads",
			"(%s) or, for a tool that reads every file, for what it looks for (%s)",
		]),
		[concern, concat(", ", sort(file_concerns)), concat(", ", sort(whole_repository_concerns))],
	)
}

# CONF-15
findings contains lib.finding("CONF-15", path, message) if {
	some path in config_files
	not startswith(path, ".config/mise/locks/")
	parts := split(path, "/")
	count(parts) > 2
	some tool in concern_tools
	regex.match(tool.pattern, files.basename(path))
	parts[1] != tool.concern
	message := sprintf(
		concat(" ", [
			"%s is %s configuration, which belongs in the %s concern;",
			"move it to .config/%s/%s and update its callers",
		]),
		[path, tool.tool, tool.concern, tool.concern, trim_left(files.basename(path), "._")],
	)
}

# The first directory under .config/ of every file in a subdirectory.
concerns_in_use contains parts[1] if {
	some path in config_files
	parts := split(path, "/")
	count(parts) > 2
}

# The concerns, in one list. Most name the files a tool reads; a tool that
# reads every file is named for what it looks for; mise is where mise looks.
file_concerns := {
	"actions", "commits", "docker", "json", "markdown", "openapi", "opentofu",
	"python", "rego", "shell", "sql", "toml", "typescript", "yaml",
}

whole_repository_concerns := {"prose", "security", "spelling"}

registered_concerns := (file_concerns | whole_repository_concerns) | {"mise"}

# Each known tool's configuration file, by name with or without a leading dot
# or underscore, and the concern it belongs in.
concern_tools := [
	{"tool": "Vale", "concern": "prose", "pattern": `^[._]?vale\.ini$`},
	{"tool": "gitleaks", "concern": "security", "pattern": `^\.?gitleaks(\.toml|ignore)$`},
	{"tool": "Trivy", "concern": "security", "pattern": `^\.?trivy(ignore(\.ya?ml)?|\.ya?ml)$`},
	{"tool": "typos", "concern": "spelling", "pattern": `^[._]?typos\.toml$`},
	{"tool": "codespell", "concern": "spelling", "pattern": `^\.?codespell(rc|\.cfg)$`},
	{"tool": "cspell", "concern": "spelling", "pattern": `^\.?cspell(\.config)?\.(jsonc?|ya?ml)$`},
	{"tool": "yamllint", "concern": "yaml", "pattern": `^\.?yamllint(\.ya?ml)?$`},
	{"tool": "markdownlint", "concern": "markdown", "pattern": `^\.?markdownlint(-cli2)?\.(jsonc?|ya?ml)$`},
	{"tool": "actionlint", "concern": "actions", "pattern": `^\.?actionlint\.ya?ml$`},
	{"tool": "zizmor", "concern": "actions", "pattern": `^\.?zizmor\.ya?ml$`},
	{"tool": "hadolint", "concern": "docker", "pattern": `^\.?hadolint\.ya?ml$`},
	{"tool": "Regal", "concern": "rego", "pattern": `^\.?regal\.ya?ml$`},
	{"tool": "Taplo", "concern": "toml", "pattern": `^\.?taplo\.toml$`},
	{"tool": "committed", "concern": "commits", "pattern": `^\.?committed\.toml$`},
	{"tool": "Spectral", "concern": "openapi", "pattern": `^\.?spectral\.(ya?ml|json)$`},
]

gitattributes_path := ".gitattributes"

# Each pattern of the root .gitattributes with its line number. A blank
# line, a comment, a macro ([attr]), a negation (which git rejects) and a
# quoted or bracketed pattern, which the matcher does not read, are skipped.
gitattributes_patterns contains {"line": index + 1, "pattern": pattern} if {
	some index, raw in split(files.texts[gitattributes_path], "\n")
	line := trim_space(raw)
	line != ""
	not startswith(line, "#")
	pattern := regex.split(`\s+`, line)[0]
	checkable_attribute_pattern(pattern)
}

checkable_attribute_pattern(pattern) if {
	not startswith(pattern, "!")
	not startswith(pattern, "\"")
	not contains(pattern, "[")
}

# Every tracked file counts, fixtures included: git applies attributes to
# them too.
attributed(pattern) if {
	some path in files.all_files
	gitignore.matches(pattern, path)
}

top_level_allowed := {"README.md", "lefthook.yml", "lefthook-local.yml"}

program_extensions := {
	"bash", "cjs", "cts", "js", "mjs", "mts", "pl",
	"ps1", "py", "rb", "sh", "ts", "zsh",
}

# Files the index describes: everything but READMEs, the personal override,
# and what a tool finds by itself (mise's and lefthook's own files), so a
# .config/ holding only those needs no index.
indexable contains path if {
	some path in config_files
	not readme(path)
	not local_override(path)
	not self_discovered(path)
}

# Files a tool finds inside .config/ without being told, so no caller names
# them: lefthook searches .config/lefthook.*, and mise reads its
# configuration, its lockfile and the per-tool locks the lockfile points to.
self_discovered(path) if path in {
	".config/lefthook.yml",
	".config/lefthook-local.yml",
	".config/mise/config.toml",
	".config/mise/mise.lock",
}

self_discovered(path) if startswith(path, ".config/mise/locks/")

called(path) if {
	some reference in references
	covers(reference.path, path)
}

# A file another file in .config/ names: a cspell dictionary its cspell.json
# lists, a Vale style its vale.ini points at. The naming file is judged on its
# own, so a chain nothing calls is still reported where it starts.
called(path) if {
	some reference in config_references
	reference.caller != path
	covers(reference.path, path)
}

# The paths a .config/ file names, by its .config/ path or relative to its own
# directory. Read from the file's text, since configuration comes in formats
# conftest does not parse; only a path that exists is taken, so a word that
# happens to match a file name elsewhere is never a reference.
config_references contains {"path": target, "caller": path} if {
	some path, text in files.texts
	startswith(path, ".config/")
	not readme(path)
	some token in regex.split(`[\s"'=:(,\[\]{}<>]+`, text)
	some target in named_targets(path, token)
	exists(target)
}

named_targets(_, token) := {target} if {
	startswith(token, ".config/")
	target := trim_suffix(token, "/")
}

named_targets(path, token) := {target} if {
	not startswith(token, ".config/")
	not startswith(token, "/")
	relative_token := trim_suffix(trim_prefix(token, "./"), "/")
	relative_token != ""
	not contains(relative_token, "..")
	target := concat("/", [regex.replace(path, `/[^/]*$`, ""), relative_token])
}

covers(reference, path) if reference == path

covers(reference, path) if startswith(path, concat("", [reference, "/"]))

covers(reference, path) if {
	glob_pattern(reference)
	doublestar.match(reference, path)
}

covers(reference, path) if {
	glob_pattern(reference)
	some directory in files.directories
	doublestar.match(reference, directory)
	startswith(path, concat("", [directory, "/"]))
}

exists(path) if path in files.repository_files

exists(path) if path in files.directories

# A glob, such as a workflow's paths filter, exists when it matches a file or
# a directory: one that matches nothing is a filter that never fires.
exists(path) if {
	glob_pattern(path)
	doublestar.matches_any(path, files.repository_files | files.directories)
}

glob_pattern(path) if regex.match(`[*?\[]`, path)

# The documents that run tools, and so name their configuration.
caller_patterns := [
	`(^|/)[Tt]askfile(\.dist)?\.ya?ml$`,
	`(^|/)taskfiles/[^/]+\.ya?ml$`,
	`^(\.config/)?\.?lefthook(-local)?\.ya?ml$`,
	`^\.github/workflows/[^/]+\.(?i:ya?ml)$`,
	`^\.github/actions/.+/action\.ya?ml$`,
	`(^|/)\.?devcontainer\.json$`,
	`(^|/)package\.json$`,
]

callers contains doc if {
	some doc in files.own_documents
	some pattern in caller_patterns
	regex.match(pattern, doc.path)
}

# A .config/ path in a string, with whatever is written before it in the same
# word: nothing, ./, or a variable for the repository root. A path under a
# home directory (~/.config/gh, /home/vscode/.config, $HOME/.config) is the
# user's, not the repository's. The path may be a glob (`*`, `?`, `[...]`).
reference_pattern := `([^\s"'=:(,\[]*)\.config/([A-Za-z0-9_./*?\[\]-]*[A-Za-z0-9_*?\]])`

references contains {"path": concat("", [".config/", match[2]]), "caller": doc.path} if {
	some doc in callers
	some value in values.string_values(doc.contents)
	contains(value, ".config/")
	some match in regex.find_all_string_submatch_n(reference_pattern, value, -1)
	in_repository(match[1])
}

in_repository("")

in_repository("./")

in_repository(prefix) if {
	regex.match(`^(\{\{[^{}]*\}\}|\}\}|\$\{[A-Za-z_][A-Za-z0-9_]*\}|\$[A-Za-z_][A-Za-z0-9_]*)/$`, prefix)
	not regex.match(`(?i)home`, prefix)
}

# Every backticked token in the index, without a leading .config/ or a
# trailing slash, so a row may cite a path, a name or a directory.
indexed_tokens(text) := {token |
	some match in regex.find_all_string_submatch_n(`\x60([^\x60\n]+)\x60`, text, -1)
	token := trim_suffix(trim_prefix(trim_space(match[1]), ".config/"), "/")
	token != ""
}

indexed(tokens, relative_path) if relative_path in tokens

indexed(tokens, relative_path) if files.basename(relative_path) in tokens

indexed(tokens, relative_path) if {
	some token in tokens
	startswith(relative_path, concat("", [token, "/"]))
}

default suggested_name(_) := "<tool>.<ext>"

suggested_name(path) := trim_left(path, "._") if not contains(path, "/")

suggested_name(path) := concat(".", [lower(root_configs[path]), files.extension(path)]) if contains(path, "/")

# Tool configuration that belongs in .config/: the root file names each tool
# searches for. Absent on purpose: files only their tool's root search can
# find and that no flag replaces (Taskfile.yml, .gitattributes, .gitignore,
# Docker ignore files, which EC-0039 places beside their Dockerfile,
# .editorconfig, package manifests and lockfiles), and a
# configuration written as a program (eslint.config.js), which .config/ does
# not hold (CONF-08).
root_configs := {
	".markdownlint.json": "markdownlint",
	".markdownlint.jsonc": "markdownlint",
	".markdownlint.yaml": "markdownlint",
	".markdownlint.yml": "markdownlint",
	".markdownlint-cli2.jsonc": "markdownlint",
	".markdownlint-cli2.yaml": "markdownlint",
	".yamllint": "yamllint",
	".yamllint.yaml": "yamllint",
	".yamllint.yml": "yamllint",
	".codespellrc": "codespell",
	"codespell.cfg": "codespell",
	"_typos.toml": "typos",
	".typos.toml": "typos",
	"typos.toml": "typos",
	"actionlint.yaml": "actionlint",
	"actionlint.yml": "actionlint",
	"zizmor.yml": "zizmor",
	"zizmor.yaml": "zizmor",
	".prettierrc": "Prettier",
	".prettierrc.json": "Prettier",
	".prettierrc.json5": "Prettier",
	".prettierrc.toml": "Prettier",
	".prettierrc.yaml": "Prettier",
	".prettierrc.yml": "Prettier",
	".eslintrc": "ESLint",
	".eslintrc.json": "ESLint",
	".eslintrc.yaml": "ESLint",
	".eslintrc.yml": "ESLint",
	".stylelintrc": "Stylelint",
	".stylelintrc.json": "Stylelint",
	".stylelintrc.yaml": "Stylelint",
	".stylelintrc.yml": "Stylelint",
	".shellcheckrc": "ShellCheck",
	".hadolint.yaml": "hadolint",
	".hadolint.yml": "hadolint",
	".gitleaks.toml": "gitleaks",
	"gitleaks.toml": "gitleaks",
	".gitleaksignore": "gitleaks",
	".trivyignore": "Trivy",
	".trivyignore.yaml": "Trivy",
	"trivy.yaml": "Trivy",
	".vale.ini": "Vale",
	"_vale.ini": "Vale",
	"vale.ini": "Vale",
	".regal.yaml": "Regal",
	".regal/config.yaml": "Regal",
	".taplo.toml": "Taplo",
	"taplo.toml": "Taplo",
	".ruff.toml": "Ruff",
	"ruff.toml": "Ruff",
	".lychee.toml": "lychee",
	"lychee.toml": "lychee",
}
