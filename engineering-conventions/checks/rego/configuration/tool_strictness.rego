# METADATA
# title: Tool strictness
# description: >-
#   Each tool's configuration starts from the tool's own preset and builds
#   on it: yamllint extends default (CONF-16), markdownlint keeps its
#   default rules (CONF-17), pyright and basedpyright check at strict or
#   above (CONF-18), a tsconfig.json turns strict on (CONF-19), Biome keeps
#   its recommended rules (CONF-20), and a gitleaks [extend] keeps the
#   default rules (CONF-21).
# scope: package
# custom:
#   convention: EC-0044
package conventions.checks.configuration.tool_strictness

import data.conventions.lib.files
import data.conventions.lib.findings as lib

# CONF-16. Without extends, yamllint runs only the rules the file lists;
# relaxed turns most of the rest into warnings or off. A path to another
# configuration is not followed.
findings contains lib.finding("CONF-16", path, yamllint_unextended) if {
	some path, contents in configurations(yamllint_pattern)
	not contents.extends
}

findings contains lib.finding("CONF-16", path, yamllint_relaxed) if {
	some path, contents in configurations(yamllint_pattern)
	contents.extends == "relaxed"
}

# CONF-17. markdownlint's own files hold the rules at the top level;
# markdownlint-cli2's hold them under config.
findings contains lib.finding("CONF-17", path, markdownlint_message) if {
	some path, contents in configurations(markdownlint_pattern)
	contents["default"] == false
}

findings contains lib.finding("CONF-17", path, markdownlint_message) if {
	some path, contents in configurations(markdownlint_cli2_pattern)
	contents.config["default"] == false
}

# CONF-18. The type-checking mode of each pyright section.
findings contains lib.finding("CONF-18", path, pyright_message(section, mode)) if {
	some path, contents in configurations(pyproject_pattern)
	some section in ["pyright", "basedpyright"]
	settings := contents.tool[section]
	is_object(settings)
	mode := pyright_mode(section, settings)
	not mode in strict_modes
}

findings contains lib.finding("CONF-18", path, pyright_message("pyright", mode)) if {
	some path, contents in configurations(pyrightconfig_pattern)
	mode := pyright_mode("pyright", contents)
	not mode in strict_modes
}

# CONF-19
findings contains lib.finding("CONF-19", path, tsconfig_message) if {
	some path, contents in configurations(tsconfig_pattern)
	not strict_on(contents)
}

# CONF-20
findings contains lib.finding("CONF-20", path, biome_message) if {
	some path, contents in configurations(biome_pattern)
	contents.linter.rules.recommended == false
}

# CONF-21. An [extend] that names neither the default rules nor another
# configuration to extend.
findings contains lib.finding("CONF-21", path, gitleaks_message) if {
	some path, contents in configurations(gitleaks_pattern)
	is_object(contents.extend)
	not contents.extend.useDefault == true
	not contents.extend.path
}

# The configurations each check reads, by path. bin/conventions passes or
# parses exactly these.
yamllint_pattern := `^(\.config/(.+/)?)?\.?yamllint\.ya?ml$`

markdownlint_pattern := `^(\.config/(.+/)?)?\.?markdownlint\.(jsonc?|ya?ml)$`

markdownlint_cli2_pattern := `^(\.config/(.+/)?)?\.?markdownlint-cli2\.(jsonc?|ya?ml)$`

pyproject_pattern := `(^|/)pyproject\.toml$`

pyrightconfig_pattern := `(^|/)pyrightconfig\.json$`

tsconfig_pattern := `(^|/)tsconfig\.json$`

biome_pattern := `(^|/)biome\.jsonc?$`

gitleaks_pattern := `^(\.config/(.+/)?)?\.?gitleaks\.toml$`

configurations(pattern) := {doc.path: doc.contents |
	some doc in files.own_documents
	regex.match(pattern, doc.path)
	is_object(doc.contents)
}

# basedpyright's own section defaults to recommended, which is above the
# floor; pyright's, and pyrightconfig.json, which either may read, default
# to standard.
strict_modes := {"strict", "recommended", "all"}

pyright_mode(_, settings) := settings.typeCheckingMode if is_string(settings.typeCheckingMode)

pyright_mode("pyright", settings) := "standard" if not settings.typeCheckingMode

pyright_mode("basedpyright", settings) := "recommended" if not settings.typeCheckingMode

# A tsconfig.json that extends another inherits its strict, which is not
# followed.
strict_on(contents) if contents.compilerOptions.strict == true

strict_on(contents) if {
	contents.extends
	not contents.compilerOptions.strict == false
}

yamllint_unextended := concat(" ", [
	"the yamllint configuration does not extend a preset, so only the rules it lists run;",
	"add `extends: default` and turn off or relax a rule beside its reason",
])

yamllint_relaxed := concat(" ", [
	"the yamllint configuration extends relaxed, which drops rules default keeps;",
	"extend default and turn off or relax a rule beside its reason",
])

markdownlint_message := concat(" ", [
	"the markdownlint configuration sets default to false, so only the rules it names run;",
	"remove it and turn off a rule by name beside its reason",
])

pyright_message(section, mode) := sprintf(
	concat(" ", [
		"%s checks types at typeCheckingMode %s, below the floor;",
		"set it to strict (or basedpyright's recommended or all) and turn off a rule beside its reason",
	]),
	[section, mode],
)

tsconfig_message := concat(" ", [
	"the TypeScript configuration does not turn strict on, so the compiler skips its strict checks;",
	"set compilerOptions.strict to true and turn off a strict option beside its reason",
])

biome_message := concat(" ", [
	"the Biome configuration sets linter.rules.recommended to false, so only the rules it names run;",
	"remove it and turn off a rule by name beside its reason",
])

gitleaks_message := concat(" ", [
	"the gitleaks configuration has an [extend] without useDefault = true, so the default rules",
	"are dropped; set useDefault = true and allowlist a finding beside its reason",
])
