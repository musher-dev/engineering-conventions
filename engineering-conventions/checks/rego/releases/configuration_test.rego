package conventions.checks.releases.configuration_test

import data.conventions.checks.releases.configuration as checks
import data.conventions.lib.testdata_test as td

schema := "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json"

title := "chore(release): release${component} ${version}"

# A conforming single-package config.
single := {
	"$schema": schema,
	"release-type": "simple",
	"include-component-in-tag": false,
	"pull-request-title-pattern": title,
	"draft": true,
	"force-tag-creation": true,
	"bump-minor-pre-major": true,
	"bump-patch-for-minor-pre-major": true,
	"packages": {".": {}},
}

# A conforming config with several packages.
several := {
	"$schema": schema,
	"release-type": "simple",
	"tag-separator": "/",
	"separate-pull-requests": true,
	"pull-request-title-pattern": title,
	"draft": true,
	"force-tag-creation": true,
	"packages": {
		"schemas/blueprint": {"component": "blueprint"},
		"schemas/listing": {"component": "listing"},
	},
}

config(contents) := td.file(".github/release-please/config.json", contents)

manifest(contents) := td.file(".github/release-please/manifest.json", contents)

one_manifest := manifest({".": "1.0.0"})

release_step(given) := {"name": "Release", "uses": "googleapis/release-please-action@x", "with": given}

standard_inputs := {
	"token": "${{ steps.app_token.outputs.token }}",
	"config-file": ".github/release-please/config.json",
	"manifest-file": ".github/release-please/manifest.json",
}

workflow(step) := td.file(".github/workflows/release.yml", {
	"name": "Release",
	"on": {"push": {"branches": ["main"]}},
	"jobs": {"release_please": {"name": "Release", "steps": [step]}},
})

messages(results, id) := {f.message | some f in results; f.id == id}

paths(results, id) := {f.path | some f in results; f.id == id}

has(found, fragment) if {
	some message in found
	contains(message, fragment)
}

# The base with each changed key replaced whole: object.union alone merges
# nested objects, which would keep the base's other packages.
replaced(base, changes) := object.union(object.remove(base, object.keys(changes)), changes)

test_conforming_configs_have_no_findings if {
	single_docs := [config(single), manifest({".": "0.6.1"}), workflow(release_step(standard_inputs))]
	results_single := checks.findings with input as single_docs with data.conventions.index as td.index
	count(results_single) == 0
	several_docs := [config(several), manifest({"schemas/blueprint": "1.6.0", "schemas/listing": "1.0.0"})]
	results_several := checks.findings with input as several_docs with data.conventions.index as td.index
	count(results_several) == 0
}

test_nothing_to_release_has_no_findings if {
	results_empty := checks.findings with input as [td.inventory(["README.md"])] with data.conventions.index as td.index
	count(results_empty) == 0
	results_image := checks.findings with input as [td.outputs([td.image_output])]
		with data.conventions.index as td.index
	count(results_image) == 0
}

test_rel_01_versioned_output_without_release_please if {
	bundle := object.union(td.image_output, {"id": "rules", "kind": "bundle"})
	results := checks.findings with input as [td.outputs([bundle, td.image_output])]
		with data.conventions.index as td.index
	messages(results, "REL-01") == {concat(" ", [
		"the repository declares versioned outputs (rules) but has no release-please config at",
		".github/release-please/config.json; release them with release-please in manifest mode so every",
		"version has a tag, a changelog and a GitHub Release",
	])}
	released := [td.outputs([bundle]), config(single), one_manifest]
	results_released := checks.findings with input as released with data.conventions.index as td.index
	count(results_released) == 0
}

test_rel_02_location if {
	strays := [td.inventory([
		"release-please-config.json",
		".release-please-manifest.json",
		"a/release-please-config.json",
	])]
	results_stray := checks.findings with input as strays with data.conventions.index as td.index
	paths(results_stray, "REL-02") == {
		"release-please-config.json",
		".release-please-manifest.json",
		"a/release-please-config.json",
	}
	notes := [td.inventory([".github/release-please/notes.json"])]
	results_notes := checks.findings with input as notes with data.conventions.index as td.index
	paths(results_notes, "REL-02") == {".github/release-please/notes.json"}
	results_alone := checks.findings with input as [config(single)] with data.conventions.index as td.index
	messages(results_alone, "REL-02") == {concat(" ", [
		"the release-please config has no release-please manifest beside it; add",
		".github/release-please/manifest.json with each package's current version",
	])}
	results_orphan := checks.findings with input as [one_manifest] with data.conventions.index as td.index
	paths(results_orphan, "REL-02") == {".github/release-please/manifest.json"}
	unconfigured := [workflow(release_step(standard_inputs))]
	results_unconfigured := checks.findings with input as unconfigured with data.conventions.index as td.index
	paths(results_unconfigured, "REL-02") == {".github/workflows/release.yml"}
}

test_rel_03_action_inputs if {
	docs := [config(single), one_manifest, workflow(release_step({"token": "t", "release-type": "simple"}))]
	results := checks.findings with input as docs with data.conventions.index as td.index
	found := messages(results, "REL-03")
	count(found) == 3
	has(found, "passes release-type, which makes release-please ignore its config")
	has(found, "without config-file: .github/release-please/config.json")
}

test_rel_04_config_shape if {
	bare := {"packages": {".": {}, "tools": {"release-type": "node"}}}
	docs := [config(bare), manifest({".": "1.0.0", "old": "2.0.0"})]
	results := checks.findings with input as docs with data.conventions.index as td.index
	found := messages(results, "REL-04")
	count(found) == 4
	has(found, "the release-please config has no release-type")
	has(found, `the release-please manifest has no version for package "tools"`)
	has(found, `the release-please manifest versions "old"`)
	has(found, "does not declare \"$schema\"")
	empty := [config({"$schema": schema}), manifest({})]
	results_empty := checks.findings with input as empty with data.conventions.index as td.index
	has(messages(results_empty, "REL-04"), "the release-please config lists no packages")
}

test_rel_05_single_tags if {
	unprefixed := object.union(single, {"include-v-in-tag": false, "include-component-in-tag": true})
	results := checks.findings with input as [config(unprefixed), one_manifest] with data.conventions.index as td.index
	found := messages(results, "REL-05")
	count(found) == 2
	has(found, "the release-please config tags without a v")
	has(found, "the release-please config tags the only package with its component")
}

test_rel_05_several_tags if {
	bad := replaced(several, {
		"tag-separator": "-",
		"packages": {
			"a": {"component": "Blue_print"},
			"b": {"component": "listing", "include-component-in-tag": false},
			"c": {"component": "listing"},
		},
	})
	docs := [config(bad), manifest({"a": "1.0.0", "b": "1.0.0", "c": "1.0.0"})]
	results := checks.findings with input as docs with data.conventions.index as td.index
	found := messages(results, "REL-05")
	count(found) == 4
	has(found, "the release-please config tags <component>-v<version>")
	has(found, `several packages set component "listing"`)
	has(found, `package "a" sets no kebab-case component`)
	has(found, `package "b" leaves the component out of the tags of one of several packages`)
}

test_rel_06_release_pull_requests if {
	grouped := object.union(several, {"separate-pull-requests": false, "pull-request-title-pattern": "chore: release"})
	rules := td.file(".config/commits/committed.toml", {"allowed_types": ["feat", "fix"], "allowed_scopes": ["repo"]})
	docs := [config(grouped), manifest({"schemas/blueprint": "1.0.0", "schemas/listing": "1.0.0"}), rules]
	results := checks.findings with input as docs with data.conventions.index as td.index
	count(messages(results, "REL-06")) == 4
	commit_rules := {f.message | some f in results; f.path == ".config/commits/committed.toml"}
	commit_rules == {
		concat(" ", [
			`the commit rules do not list "chore" under allowed_types, so the release pull request's title`,
			"chore(release): fails them; add it",
		]),
		concat(" ", [
			`the commit rules do not list "release" under allowed_scopes, so the release pull request's title`,
			"chore(release): fails them; add it",
		]),
	}
	accepting := td.file(".config/commits/committed.toml", {"allowed_types": ["chore"], "allowed_scopes": ["release"]})
	results_accepting := checks.findings with input as [config(single), one_manifest, accepting]
		with data.conventions.index as td.index
	count(messages(results_accepting, "REL-06")) == 0
}

test_rel_07_drafts if {
	published := object.remove(single, ["draft", "force-tag-creation"])
	results := checks.findings with input as [config(published), one_manifest] with data.conventions.index as td.index
	count(messages(results, "REL-07")) == 2
}

test_rel_08_pre_one_bumps if {
	plain := object.remove(single, ["bump-minor-pre-major", "bump-patch-for-minor-pre-major"])
	results_zero := checks.findings with input as [config(plain), manifest({".": "0.3.0"})]
		with data.conventions.index as td.index
	count(messages(results_zero, "REL-08")) == 2
	results_one := checks.findings with input as [config(plain), manifest({".": "1.3.0"})]
		with data.conventions.index as td.index
	count(messages(results_one, "REL-08")) == 0
}

test_rel_09_changelog if {
	sections := [
		{"type": "feat", "section": "Features"},
		{"type": "fix", "section": "Fixes", "hidden": true},
		{"type": "chore", "section": "Chores"},
		{"type": "docs", "section": "Docs"},
	]
	visible_docs := object.union(single, {"changelog-sections": sections})
	service := [config(visible_docs), one_manifest, td.repository({"kind": "service"})]
	results := checks.findings with input as service with data.conventions.index as td.index
	found := messages(results, "REL-09")
	count(found) == 3
	has(found, `the release-please config's changelog hides "fix"`)
	has(found, `the release-please config's changelog shows "chore"`)
	has(found, `kind is "service"`)
	specification := [config(visible_docs), one_manifest, td.repository({"kind": "specification"})]
	results_specification := checks.findings with input as specification with data.conventions.index as td.index
	count(messages(results_specification, "REL-09")) == 2
}

test_rel_10_one_off_overrides if {
	pinned := object.union(single, {"last-release-sha": "abc", "packages": {".": {"release-as": "2.0.0"}}})
	results := checks.findings with input as [config(pinned), one_manifest] with data.conventions.index as td.index
	found := messages(results, "REL-10")
	count(found) == 2
	has(found, `the release-please config still sets "last-release-sha"`)
	has(found, `package "." still sets "release-as"`)
}
