package conventions.checks.copy.vale_config_test

import data.conventions.checks.copy.vale_config
import data.conventions.lib.testdata_test as td

# The tests read the copy block of the generated index, so they hold the
# check to the package name, style and locked rules a release ships.
url := "https://github.com/musher-dev/engineering-conventions/releases/download/v0.2.0/MusherProse.zip"

copy_section := "[apps/site/src/**/*.{md,svelte}]"

conforming := concat("\n", [
	"StylesPath = styles",
	sprintf("Packages = %s", [url]),
	"",
	"[formats]",
	"svelte = html",
	"",
	copy_section,
	"BasedOnStyles = MusherCopy, proselint, write-good",
])

site := td.outputs([{"id": "site", "kind": "site"}])

website := td.repository(object.union(td.identity, {"kind": "website"}))

# The inventory, with the text of each Vale config the runner embeds.
texts(configs) := td.file("/tmp/inventory.json", {"conventions_inventory": {
	"files": [path | some path, _ in configs],
	"texts": configs,
}})

messages(found, id) := {f.message | some f in found; f.id == id}

# A site repository pinned at 0.2.0, with these Vale configs.
repo(configs) := [site, td.pin, texts(configs)]

floats := "which installs whatever release is latest when vale sync runs"

test_a_conforming_config_passes if {
	count(vale_config.findings) == 0 with input as repo({".config/markdown/vale.ini": conforming})
}

test_a_site_without_a_config_is_reported_on_its_outputs_declaration if {
	found := vale_config.findings with input as [site, td.pin, texts({})]
	td.pairs(found) == {["COPY-01", ".repo/outputs.toml"]}
}

test_a_website_kind_without_a_config_is_reported_on_its_identity if {
	found := vale_config.findings with input as [website, td.pin, texts({})]
	td.pairs(found) == {["COPY-01", ".repo/repository.toml"]}
}

test_a_repository_without_a_site_needs_no_config if {
	count(vale_config.findings) == 0 with input as [td.pin, texts({})]
}

test_a_root_config_counts if {
	count(vale_config.findings) == 0 with input as repo({".vale.ini": conforming})
}

test_a_missing_package_is_reported if {
	text := replace(conforming, url, "https://example.com/Other.zip")
	found := vale_config.findings with input as repo({".vale.ini": text})
	messages(found, "COPY-02") == {sprintf(
		"Packages does not install the MusherProse Vale package; add %s, the release this repository pins",
		[url],
	)}
}

test_a_bare_package_name_is_reported if {
	text := replace(conforming, url, "MusherProse")
	found := vale_config.findings with input as repo({".vale.ini": text})
	messages(found, "COPY-02") == {sprintf("Packages names MusherProse by name, %s; use %s", [floats, url])}
}

test_another_release_is_reported if {
	text := replace(conforming, "v0.2.0", "v0.1.0")
	found := vale_config.findings with input as repo({".vale.ini": text})
	messages(found, "COPY-02") == {sprintf(
		"Packages installs MusherProse 0.1.0, but the repository pins 0.2.0; use %s",
		[url],
	)}
}

test_a_copy_from_elsewhere_is_reported if {
	text := replace(conforming, url, "vendor/MusherProse.zip")
	found := vale_config.findings with input as repo({".vale.ini": text})
	messages(found, "COPY-02") == {sprintf(
		"Packages installs MusherProse from vendor/MusherProse.zip, not from a release of the conventions; use %s",
		[url],
	)}
}

test_another_bare_package_is_reported if {
	text := replace(conforming, url, concat(", ", [url, "Google"]))
	found := vale_config.findings with input as repo({".vale.ini": text})
	messages(found, "COPY-02") == {sprintf(
		"Packages names Google by name, %s; name its release asset's URL instead",
		[floats],
	)}
}

test_the_declared_version_is_the_pin_without_mise if {
	declared := td.declaration({"conventions": {"version": "0.2.0"}})
	count(vale_config.findings) == 0 with input as [site, declared, texts({".vale.ini": conforming})]
}

test_any_release_passes_without_a_pin if {
	text := replace(conforming, "v0.2.0", "v9.9.9")
	count(vale_config.findings) == 0 with input as [site, texts({".vale.ini": text})]
}

test_without_a_pin_the_message_names_a_placeholder_release if {
	text := replace(conforming, url, "MusherProse")
	found := vale_config.findings with input as [site, texts({".vale.ini": text})]
	some message in messages(found, "COPY-02")
	contains(message, "/v<release>/MusherProse.zip")
}

test_a_config_that_applies_nothing_is_reported if {
	text := concat("\n", [sprintf("Packages = %s", [url]), "[*.md]", "BasedOnStyles = Vale"])
	found := vale_config.findings with input as repo({".vale.ini": text})
	td.ids(found) == {"COPY-03"}
}

test_a_site_config_with_neither_package_nor_style_is_judged if {
	text := concat("\n", ["[*.md]", "BasedOnStyles = Vale"])
	found := vale_config.findings with input as repo({".config/markdown/vale.ini": text})
	td.ids(found) == {"COPY-02", "COPY-03"}
}

test_a_section_without_the_adopted_packages_is_reported if {
	text := replace(conforming, "MusherCopy, proselint, write-good", "MusherCopy, proselint")
	found := vale_config.findings with input as repo({".vale.ini": text})
	messages(found, "COPY-03") == {sprintf(
		"%s applies MusherCopy without write-good; set BasedOnStyles = MusherCopy, proselint, write-good",
		[copy_section],
	)}
}

test_an_unmapped_template_extension_is_reported if {
	text := replace(conforming, "svelte = html", "")
	found := vale_config.findings with input as repo({".vale.ini": text})
	messages(found, "COPY-03") == {sprintf(
		"%s matches .svelte files, which Vale skips without a format; add svelte = html under [formats]",
		[copy_section],
	)}
}

test_a_single_extension_glob_is_read if {
	text := concat("\n", [
		sprintf("Packages = %s", [url]),
		"[src/**/*.vue]",
		"BasedOnStyles = MusherCopy, proselint, write-good",
	])
	found := vale_config.findings with input as repo({".vale.ini": text})
	some message in messages(found, "COPY-03")
	contains(message, "vue = html")
}

test_markdown_needs_no_format if {
	text := concat("\n", [
		sprintf("Packages = %s", [url]),
		"[docs/**/*.{md,mdx}]",
		"BasedOnStyles = MusherCopy, proselint, write-good",
	])
	count(vale_config.findings) == 0 with input as repo({".vale.ini": text})
}

test_an_unrelated_config_is_not_judged_beside_a_copy_config if {
	other := concat("\n", ["StylesPath = styles", "[*.md]", "BasedOnStyles = MusherConventions"])
	configs := {".vale.ini": conforming, ".config/prose/vale.ini": other}
	count(vale_config.findings) == 0 with input as repo(configs)
}

test_an_unrelated_config_is_not_judged_without_a_site if {
	other := concat("\n", ["Packages = Google", "[*.md]", "BasedOnStyles = Google"])
	count(vale_config.findings) == 0 with input as [td.pin, texts({".config/prose/vale.ini": other})]
}

test_turning_off_a_locked_rule_is_reported if {
	text := concat("\n", [conforming, "[apps/site/src/legal/*.md]", "MusherCopy.Banned = no"])
	found := vale_config.findings with input as repo({".vale.ini": text})
	td.pairs(found) == {["COPY-04", ".vale.ini"]}
	messages(found, "COPY-04") == {concat(" ", [
		"line 10 turns off MusherCopy.Banned for [apps/site/src/legal/*.md]; remove it, and waive COPY-04",
		"with a reason and an expiry if a page must keep the word",
	])}
}

test_turning_off_an_unlocked_rule_passes if {
	text := concat("\n", [conforming, "[docs/reference/**/*.md]", "MusherCopy.SentenceAverage = NO"])
	count(vale_config.findings) == 0 with input as repo({".vale.ini": text})
}

test_turning_off_a_locked_rule_is_reported_without_a_site if {
	text := concat("\n", ["[*.md]", "MusherCopy.Placeholders = NO"])
	found := vale_config.findings with input as [td.pin, texts({".vale.ini": text})]
	td.ids(found) == {"COPY-04"}
}

test_a_locked_rule_turned_on_passes if {
	text := concat("\n", [conforming, "[*.md]", "MusherCopy.Banned = YES"])
	count(vale_config.findings) == 0 with input as repo({".vale.ini": text})
}
