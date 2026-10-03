# METADATA
# title: Dependency updaters
# description: >-
#   What keeps a repository's dependencies current: the updates in its
#   Dependabot configuration, each with the directories it scans, whether it
#   has a Renovate configuration, and the Dependabot ecosystems that read
#   each kind of product manifest (REPO-20, REPO-22, DEVC-09, DEPS-11 to
#   DEPS-13).
package conventions.lib.updates

import data.conventions.lib.files

dependabot_pattern := `^\.github/dependabot\.ya?ml$`

dependabot_paths contains doc.path if {
	some doc in files.own_documents
	regex.match(dependabot_pattern, doc.path)
}

default dependabot_path := ".github/dependabot.yml"

dependabot_path := sort(dependabot_paths)[0] if count(dependabot_paths) > 0

# Every update in the Dependabot configuration, with the file it is in.
dependabot_updates contains {"path": doc.path, "update": update} if {
	some doc in files.own_documents
	regex.match(dependabot_pattern, doc.path)
	some update in doc.contents.updates
	is_object(update)
}

default update_directories(_) := ["/"]

update_directories(update) := [d | some d in update.directories; is_string(d)] if has_directories(update)

update_directories(update) := [update.directory] if {
	not has_directories(update)
	is_string(update.directory)
}

# Negated through a rule: `not is_array(update.directories)` is undefined, not
# true, when the key is missing.
has_directories(update) if is_array(update.directories)

# Whether an update of one of the ecosystems scans a directory, given as a
# repository path ("" for the root). Dependabot's directories may be globs.
covers(ecosystems, directory) if {
	some entry in dependabot_updates
	entry.update["package-ecosystem"] in ecosystems
	some scanned in update_directories(entry.update)
	scans(trim(scanned, "/ "), directory)
}

scans(pattern, directory) if pattern == directory

scans(pattern, directory) if {
	regex.match(`[*?\[]`, pattern)
	glob.match(pattern, ["/"], directory)
}

renovate_paths := {
	"renovate.json",
	"renovate.json5",
	".renovaterc",
	".renovaterc.json",
	".renovaterc.json5",
	".github/renovate.json",
	".github/renovate.json5",
	".gitlab/renovate.json",
	".gitlab/renovate.json5",
}

# Renovate's managers find every manifest, Dockerfile and workflow by
# themselves, so a Renovate configuration covers every ecosystem.
renovate if {
	some path in files.repository_files
	path in renovate_paths
}

# What a product is built from, by ecosystem: the manifests that mark a
# product directory as one, and the Dependabot ecosystems that read them.
ecosystems := {
	"rust": {"manifests": ["Cargo.toml"], "dependabot": ["cargo"]},
	"node": {"manifests": ["package.json"], "dependabot": ["npm", "bun"]},
	"python": {"manifests": ["pyproject.toml"], "dependabot": ["pip", "uv"]},
	"go": {"manifests": ["go.mod"], "dependabot": ["gomod"]},
	"deno": {"manifests": ["deno.json", "deno.jsonc"], "dependabot": []},
	"java": {
		"manifests": ["pom.xml", "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"],
		"dependabot": ["maven", "gradle"],
	},
}
