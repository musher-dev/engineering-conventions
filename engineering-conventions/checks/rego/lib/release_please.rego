# METADATA
# title: release-please
# description: >-
#   The release-please config and release-please manifest under
#   .github/release-please/, each package's effective settings, the steps that
#   run release-please, and the shell a workflow uses to upload to, publish or
#   delete a GitHub Release (EC-0024 to EC-0026).
package conventions.lib.release_please

import data.conventions.lib.files
import data.conventions.lib.steps

config_path := ".github/release-please/config.json"

manifest_path := ".github/release-please/manifest.json"

schema_url := "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json"

actions := {"googleapis/release-please-action", "google-github-actions/release-please-action"}

# The file names release-please and its action look for by default, wherever
# they are kept.
default_names := {"release-please-config.json", ".release-please-manifest.json"}

configured if config_path in files.repository_files

manifest_present if manifest_path in files.repository_files

# A config or manifest under a name or place other than the standard one.
stray_files contains path if {
	some path in files.repository_files
	files.basename(path) in default_names
}

stray_files contains path if {
	some path in files.repository_files
	startswith(path, ".github/release-please/")
	endswith(path, ".json")
	not path in {config_path, manifest_path}
}

default config := {}

config := doc.contents if {
	some doc in files.documents
	doc.path == config_path
	is_object(doc.contents)
}

default manifest := {}

manifest := doc.contents if {
	some doc in files.documents
	doc.path == manifest_path
	is_object(doc.contents)
}

packages[path] := pkg if {
	some path, pkg in config.packages
	is_object(pkg)
}

several if count(packages) > 1

# release-please's own defaults for the keys the checks read, as its config
# file (not the action's inputs) applies them.
defaults := {
	"draft": false,
	"force-tag-creation": false,
	"include-component-in-tag": true,
	"include-v-in-tag": true,
	"tag-separator": "-",
	"separate-pull-requests": false,
	"bump-minor-pre-major": false,
	"bump-patch-for-minor-pre-major": false,
}

# Each package's effective settings: its own, else the config's top level,
# else release-please's default.
settings[path] := object.union_n([defaults, object.remove(config, ["packages"]), pkg]) if {
	some path, pkg in packages
}

# How a message names a package: by its path, which is how the config keys it.
label(path) := sprintf("package %q", [path])

# Every step that runs release-please.
entries contains entry if {
	some entry in steps.entries
	steps.action(entry.step) in actions
}

# The default token, however a workflow spells it.
default_token(value) if regex.match(`(?i)(secrets\.github_token|github\.token)\b`, value)

# Actions that attach files to a GitHub Release.
upload_actions := {
	"softprops/action-gh-release",
	"actions/upload-release-asset",
	"svenstaro/upload-release-action",
	"ncipollo/release-action",
}

# A step that uploads assets to a GitHub Release: gh release upload, a POST to
# the release's upload URL, or an action that attaches files.
uploads(step) if {
	some line in steps.lines(step)
	regex.match(`\bgh\s+release\s+upload\b|upload_url|uploads\.github\.com`, line)
}

uploads(step) if steps.action(step) in upload_actions

# A step that turns a draft release into a published one.
publishes(step) if {
	some line in steps.lines(step)
	regex.match(`\bgh\s+release\s+edit\b.*--draft(=|\s+)false\b`, line)
}

publishes(step) if {
	some line in steps.lines(step)
	regex.match(`\bgh\s+api\b.*\bdraft=false\b`, line)
}

deletes(step) if {
	some line in steps.lines(step)
	regex.match(`\bgh\s+release\s+delete\b`, line)
}

# Any step that changes a release or its assets.
writes(step) if uploads(step)

writes(step) if publishes(step)

writes(step) if deletes(step)

writes(step) if {
	some line in steps.lines(step)
	regex.match(`\bgh\s+release\s+(edit|create)\b`, line)
}

writes(step) if {
	some line in steps.lines(step)
	regex.match(`\bgh\s+api\b.*(-X|--method)\s*(POST|PATCH|DELETE)\b.*\breleases\b`, line)
}

default token(_, _) := ""

# The token a step's gh calls use: GH_TOKEN, else GITHUB_TOKEN, from the step,
# else from its job. Empty when none is set, which gh reads as no token.
token(job, step) := [value |
	some source in [step, job]
	some name in ["GH_TOKEN", "GITHUB_TOKEN"]
	value := object.get(source, ["env", name], null)
	is_string(value)
][0]
