# METADATA
# title: Release configuration
# description: >-
#   A repository that publishes versioned outputs releases them with
#   release-please, configured in .github/release-please/: tags vX.Y.Z or
#   <component>/vX.Y.Z, one titled release pull request for every package, drafts
#   with their tag, explicit 0.x bumps, a changelog that shows what releases,
#   and no one-off overrides left behind.
# scope: package
# custom:
#   convention: EC-0024
package conventions.checks.releases.configuration

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.release_please as rp
import data.conventions.lib.steps

# The output kinds a release versions; images and sites are addressed by
# digest or served continuously, not cut as releases.
versioned_kinds := {"bundle", "cli", "contract", "library"}

# The release pull request's title: one package's names its version; a
# grouped one names the branch, since release-please fills ${version} in a
# grouped title only from a root "." package.
title_pattern := "chore(release): release${component} ${version}"

group_title_pattern := "chore(release): release ${branch}"

# REL-01
findings contains lib.finding("REL-01", files.outputs_path, message) if {
	not rp.configured
	count(rp.stray_files) == 0
	versioned := {output.id |
		some output in files.as_list(files.outputs_declaration.outputs)
		is_object(output)
		output.kind in versioned_kinds
		is_string(output.id)
	}
	count(versioned) > 0
	message := sprintf(
		concat(" ", [
			"the repository declares versioned outputs (%s) but has no release-please config at %s;",
			"release them with release-please in manifest mode so every version has a tag, a changelog",
			"and a GitHub Release",
		]),
		[concat(", ", sort(versioned)), rp.config_path],
	)
}

# REL-02
findings contains lib.finding("REL-02", path, message) if {
	some path in rp.stray_files
	message := sprintf(
		concat(" ", [
			"release-please's config and release-please manifest live at %s and %s; move %s there,",
			"so every repository keeps them in one place and the release workflow names them",
		]),
		[rp.config_path, rp.manifest_path, path],
	)
}

findings contains lib.finding("REL-02", rp.config_path, message) if {
	rp.configured
	not rp.manifest_present
	message := sprintf(
		concat(" ", [
			"the release-please config has no release-please manifest beside it; add %s with each",
			"package's current version",
		]),
		[rp.manifest_path],
	)
}

findings contains lib.finding("REL-02", rp.manifest_path, message) if {
	rp.manifest_present
	not rp.configured
	message := sprintf(
		"the release-please manifest has no release-please config beside it; add %s",
		[rp.config_path],
	)
}

findings contains lib.finding("REL-02", entry.path, message) if {
	not rp.configured
	count(rp.stray_files) == 0
	some entry in rp.entries
	message := sprintf(
		"%s in %s runs release-please, but the repository has no release-please config; add %s and %s",
		[entry.label, entry.where, rp.config_path, rp.manifest_path],
	)
}

# REL-03
findings contains lib.finding("REL-03", entry.path, message) if {
	some entry in rp.entries
	some [name, expected] in [["config-file", rp.config_path], ["manifest-file", rp.manifest_path]]
	object.get(steps.inputs(entry.step), name, "") != expected
	message := sprintf(
		concat(" ", [
			"%s in %s runs release-please without %s: %s; pass it so the action reads the",
			"repository's release-please files",
		]),
		[entry.label, entry.where, name, expected],
	)
}

findings contains lib.finding("REL-03", entry.path, message) if {
	some entry in rp.entries
	"release-type" in object.keys(steps.inputs(entry.step))
	message := sprintf(
		concat(" ", [
			"%s in %s passes release-type, which makes release-please ignore its config and",
			"release-please manifest; remove it and set release-type in %s",
		]),
		[entry.label, entry.where, rp.config_path],
	)
}

# REL-04
findings contains lib.finding("REL-04", rp.config_path, message) if {
	rp.configured
	object.get(rp.config, "$schema", "") != rp.schema_url
	message := sprintf(
		concat(" ", [
			"the release-please config does not declare \"$schema\": %q; add it so editors and",
			"reviewers catch a mistyped key",
		]),
		[rp.schema_url],
	)
}

findings contains lib.finding("REL-04", rp.config_path, message) if {
	rp.configured
	count(rp.packages) == 0
	message := concat(" ", [
		"the release-please config lists no packages; add a packages entry for each thing the",
		"repository versions, \".\" for the whole repository",
	])
}

findings contains lib.finding("REL-04", rp.config_path, message) if {
	some path, settings in rp.settings
	not files.has_string(settings, "release-type")
	message := sprintf(
		"%s has no release-type; set it on the package or at the top level, such as simple, node, python or go",
		[setter(path, "release-type")],
	)
}

findings contains lib.finding("REL-04", rp.manifest_path, message) if {
	rp.manifest_present
	some path, _ in rp.packages
	not versioned(object.get(rp.manifest, path, null))
	message := sprintf(
		concat(" ", [
			"the release-please manifest has no version for %s; add \"%s\": \"<its current version>\"",
			"so release-please does not release its history again",
		]),
		[rp.label(path), path],
	)
}

findings contains lib.finding("REL-04", rp.manifest_path, message) if {
	rp.configured
	some path, _ in rp.manifest
	not path in object.keys(rp.packages)
	message := sprintf(
		concat(" ", [
			"the release-please manifest versions %q, which the release-please config does not list;",
			"remove it or add the package",
		]),
		[path],
	)
}

# REL-05
findings contains lib.finding("REL-05", rp.config_path, message) if {
	some path, settings in rp.settings
	settings["include-v-in-tag"] == false
	message := sprintf(
		concat(" ", [
			"%s tags without a v (include-v-in-tag: false); remove the setting so tags read",
			"vX.Y.Z, as Go, mise, aqua and Renovate expect",
		]),
		[setter(path, "include-v-in-tag")],
	)
}

findings contains lib.finding("REL-05", rp.config_path, message) if {
	not rp.several
	some path, settings in rp.settings
	settings["include-component-in-tag"] != false
	message := sprintf(
		concat(" ", [
			"%s tags the only package with its component; set \"include-component-in-tag\": false",
			"so tags read vX.Y.Z",
		]),
		[setter(path, "include-component-in-tag")],
	)
}

findings contains lib.finding("REL-05", rp.config_path, message) if {
	rp.several
	some path, settings in rp.settings
	settings["tag-separator"] != "/"
	message := sprintf(
		concat(" ", [
			"%s tags <component>%sv<version>; set \"tag-separator\": \"/\" so every package tags",
			"<component>/vX.Y.Z",
		]),
		[setter(path, "tag-separator"), settings["tag-separator"]],
	)
}

findings contains lib.finding("REL-05", rp.config_path, message) if {
	rp.several
	some path, settings in rp.settings
	settings["include-component-in-tag"] == false
	message := sprintf(
		concat(" ", [
			"%s leaves the component out of the tags of one of several packages; remove",
			"include-component-in-tag: false so each package tags <component>/vX.Y.Z",
		]),
		[setter(path, "include-component-in-tag")],
	)
}

findings contains lib.finding("REL-05", rp.config_path, message) if {
	rp.several
	some path, pkg in rp.packages
	not kebab(object.get(pkg, "component", null))
	message := sprintf(
		concat(" ", [
			"%s sets no kebab-case component; set \"component\" to the name its tags carry, such as",
			"\"api\" for api/v1.2.3",
		]),
		[rp.label(path)],
	)
}

findings contains lib.finding("REL-05", rp.config_path, message) if {
	rp.several
	some component in duplicate_components
	message := sprintf(
		"several packages set component %q, so their tags collide; give each package its own component",
		[component],
	)
}

# REL-06
findings contains lib.finding("REL-06", rp.config_path, message) if {
	not rp.several
	some path, settings in rp.settings
	pattern := object.get(settings, "pull-request-title-pattern", "")
	pattern != title_pattern
	message := sprintf(
		concat(" ", [
			"%s titles release pull requests %q; set \"pull-request-title-pattern\": %q so every",
			"release pull request reads the same",
		]),
		[setter(path, "pull-request-title-pattern"), pattern, title_pattern],
	)
}

findings contains lib.finding("REL-06", rp.config_path, message) if {
	rp.several
	some path, settings in rp.settings
	settings["separate-pull-requests"] == true
	message := sprintf(
		concat(" ", [
			"%s sets \"separate-pull-requests\": true, so each package opens its own release pull request;",
			"remove it so every package is released from one grouped pull request and one release run",
		]),
		[setter(path, "separate-pull-requests")],
	)
}

findings contains lib.finding("REL-06", rp.config_path, message) if {
	rp.several
	pattern := object.get(rp.config, "group-pull-request-title-pattern", "")
	pattern != group_title_pattern
	message := sprintf(
		concat(" ", [
			"the release-please config titles the grouped release pull request %s; set",
			"\"group-pull-request-title-pattern\": %q so every release pull request reads the same",
		]),
		[group_title_label(pattern), group_title_pattern],
	)
}

findings contains lib.finding("REL-06", path, message) if {
	rp.configured
	some path, commits in commit_types
	some [key, value] in [["types", "chore"], ["scopes", "release"]]
	is_array(commits[key])
	not value in commits[key]
	message := sprintf(
		concat(" ", [
			"the commit rules do not list %q under %s, so the release pull request's title",
			"chore(release): fails them; add it",
		]),
		[value, key],
	)
}

# REL-07
findings contains lib.finding("REL-07", rp.config_path, message) if {
	some path, settings in rp.settings
	some key in ["draft", "force-tag-creation"]
	settings[key] != true
	message := sprintf(
		concat(" ", [
			"%s does not set %q: true; release-please must create each release as a draft, with its tag,",
			"so the assets are attached before the release is published and becomes immutable",
		]),
		[setter(path, key), key],
	)
}

# REL-08
findings contains lib.finding("REL-08", rp.config_path, message) if {
	some path, settings in rp.settings
	not released_at_one(object.get(rp.manifest, path, null))
	some key in ["bump-minor-pre-major", "bump-patch-for-minor-pre-major"]
	settings[key] != true
	message := sprintf(
		concat(" ", [
			"%s is before 1.0 and does not set %q: true; in 0.x a breaking change bumps the minor",
			"version and anything else bumps the patch",
		]),
		[rp.label(path), key],
	)
}

# REL-09
findings contains lib.finding("REL-09", rp.config_path, message) if {
	some path, settings in rp.settings
	sections := changelog_sections(settings)
	some type in ["feat", "fix"]
	not visible(sections, type)
	message := sprintf(
		concat(" ", [
			"%s's changelog hides %q, so a %s commit cuts no release; list it in changelog-sections",
			"without hidden: true",
		]),
		[setter(path, "changelog-sections"), type, type],
	)
}

findings contains lib.finding("REL-09", rp.config_path, message) if {
	some path, settings in rp.settings
	sections := changelog_sections(settings)
	some type in hidden_types
	visible(sections, type)
	message := sprintf(
		"%s's changelog shows %q, so a %s commit cuts a release; mark its section hidden: true",
		[setter(path, "changelog-sections"), type, type],
	)
}

findings contains lib.finding("REL-09", rp.config_path, message) if {
	kind := files.repository_declaration.kind
	is_string(kind)
	not kind in prose_kinds
	some path, settings in rp.settings
	visible(changelog_sections(settings), "docs")
	message := sprintf(
		concat(" ", [
			"%s's changelog shows \"docs\", so a documentation change cuts a release, but the repository's",
			"kind is %q; mark the docs section hidden: true (only a specification or documentation",
			"repository releases its prose)",
		]),
		[setter(path, "changelog-sections"), kind],
	)
}

# REL-10
findings contains lib.finding("REL-10", rp.config_path, message) if {
	some where, holder in holders
	some key in ["release-as", "last-release-sha"]
	key in object.keys(holder)
	message := sprintf(
		concat(" ", [
			"%s still sets %q, which pins every later release; remove it now that the release it was for",
			"is cut, and pin a version with a Release-As: commit footer instead",
		]),
		[where, key],
	)
}

# Where a package's setting comes from: the package, when it sets the key
# itself, else the config's top level, so a top-level setting is reported once
# however many packages inherit it.
setter(path, key) := rp.label(path) if key in object.keys(rp.packages[path])

setter(path, key) := "the release-please config" if not key in object.keys(rp.packages[path])

group_title_label("") := "with release-please's default, \"chore: release ${branch}\""

group_title_label(pattern) := sprintf("%q", [pattern]) if pattern != ""

versioned(value) if {
	is_string(value)
	semver.is_valid(value)
}

released_at_one(version) if {
	versioned(version)
	not startswith(version, "0.")
}

kebab(value) if {
	is_string(value)
	regex.match(`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`, value)
}

duplicate_components contains component if {
	some path, pkg in rp.packages
	component := pkg.component
	is_string(component)
	some other, other_pkg in rp.packages
	other != path
	other_pkg.component == component
}

# The commit rules a repository keeps in .github/conventional-commits.yaml.
commit_types[doc.path] := doc.contents if {
	some doc in files.documents
	regex.match(`^\.github/conventional-commits\.ya?ml$`, doc.path)
	is_object(doc.contents)
}

# release-please's default sections show feat, fix, perf and revert, and hide
# everything else; an explicit list replaces them, and a type it leaves out is
# hidden.
default_sections := [
	{"type": "feat"}, {"type": "fix"}, {"type": "perf"}, {"type": "revert"},
	{"type": "docs", "hidden": true}, {"type": "style", "hidden": true},
	{"type": "chore", "hidden": true}, {"type": "refactor", "hidden": true},
	{"type": "test", "hidden": true}, {"type": "build", "hidden": true},
	{"type": "ci", "hidden": true},
]

changelog_sections(settings) := settings["changelog-sections"] if has_array(settings, "changelog-sections")

changelog_sections(settings) := default_sections if not has_array(settings, "changelog-sections")

# `not is_array(x.key)` would be undefined, not true, for a missing key: OPA
# evaluates a call's arguments outside the negation. Negate this instead.
has_array(value, key) if is_array(value[key])

visible(sections, type) if {
	some section in sections
	is_object(section)
	section.type == type
	object.get(section, "hidden", false) != true
}

# Commit types that change nothing a consumer receives.
hidden_types := ["chore", "ci", "test", "build", "style", "refactor"]

# The repository kinds whose documents are what they publish.
prose_kinds := {"specification", "documentation"}

holders["the release-please config"] := rp.config if rp.configured

holders[rp.label(path)] := pkg if {
	some path, pkg in rp.packages
}
