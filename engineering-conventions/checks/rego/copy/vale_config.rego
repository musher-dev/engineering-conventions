# METADATA
# title: Vale config for public copy
# description: >-
#   A repository that publishes a site has a Vale config (COPY-01) that
#   installs the MusherProse package from the release the repository pins and
#   no package by a bare name (COPY-02), applies MusherCopy, proselint and
#   write-good with a format for each template extension (COPY-03). The
#   configs are read from their raw text, because conftest's ini parser drops
#   the global keys Packages lives in.
# scope: package
# custom:
#   convention: EC-0038
package conventions.checks.copy.vale_config

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.ini

copy := data.conventions.index.copy

# COPY-01
findings contains lib.finding("COPY-01", site_source, message) if {
	publishes_site
	count(config_files) == 0
	message := concat(" ", [
		"the repository publishes a site but has no Vale config to lint its copy; add .config/markdown/vale.ini",
		sprintf("that installs %s and applies %s to the site's sources", [expected_url, based_on_text]),
	])
}

# COPY-02. The package is missing.
findings contains lib.finding("COPY-02", path, message) if {
	message := sprintf(
		"Packages does not install the %s Vale package; add %s, the release this repository pins",
		[copy.package, expected_url],
	)
	some path in judged
	not installs_package(configs[path])
}

# COPY-02. The package is named, but not at the pinned release's URL.
findings contains lib.finding("COPY-02", path, message) if {
	some path in judged
	some entry in packages(configs[path])
	names_package(entry)
	not acceptable(entry)
	message := sprintf("%s; use %s", [package_problem(entry), expected_url])
}

# COPY-02. Another package named without a URL.
findings contains lib.finding("COPY-02", path, message) if {
	some path in judged
	some entry in packages(configs[path])
	bare(entry)
	not names_package(entry)
	message := sprintf(
		"Packages names %s by name, %s; name its release asset's URL instead",
		[entry, floats],
	)
}

# COPY-03. Nothing applies the style.
findings contains lib.finding("COPY-03", path, message) if {
	message := sprintf(
		"no section applies %s; add a section whose glob matches the site's sources, with BasedOnStyles = %s",
		[copy.style, based_on_text],
	)
	some path in judged
	count(copy_sections(configs[path])) == 0
}

# COPY-03. A section applies the style without the adopted packages.
findings contains lib.finding("COPY-03", path, message) if {
	some path in judged
	text := configs[path]
	some section in copy_sections(text)
	missing := [style | some style in copy.based_on; not style in styles(text, section)]
	count(missing) > 0
	message := sprintf(
		"[%s] applies %s without %s; set BasedOnStyles = %s",
		[section, copy.style, concat(", ", missing), based_on_text],
	)
}

# COPY-03. A template extension Vale would skip.
findings contains lib.finding("COPY-03", path, message) if {
	some path in judged
	text := configs[path]
	some section in copy_sections(text)
	some extension in extensions(section)
	template_formats[lower(extension)]
	not ini.value(text, "formats", extension)
	message := sprintf(
		"[%s] matches .%s files, which Vale skips without a format; add %s = %s under [formats]",
		[section, extension, extension, template_formats[lower(extension)]],
	)
}

# Where Vale finds a config by itself, and where EC-0011 puts one.
config_pattern := `^((\.|_)?vale\.ini|\.config/(.+/)?vale\.ini)$`

configs[path] := text if {
	some path, text in files.texts
	regex.match(config_pattern, path)
}

config_files contains path if {
	some path in files.repository_files
	regex.match(config_pattern, path)
}

# A repository publishes a site when it declares one, or when its kind is
# one whose product is a site.
site_kinds := {"website", "documentation"}

site_outputs contains output.id if {
	some output in files.outputs_declaration.outputs
	is_object(output)
	output.kind == "site"
}

publishes_site if count(site_outputs) > 0

publishes_site if files.repository_declaration.kind in site_kinds

# The declaration that says so, for COPY-01's path.
site_source := files.outputs_path if count(site_outputs) > 0

else := files.repository_path

default packages(_) := []

packages(text) := ini.list(ini.value(text, ini.global, "Packages"))

styles(text, section) := ini.list(ini.value(text, section, "BasedOnStyles"))

# The sections whose BasedOnStyles names the copy style.
copy_sections(text) := {section |
	some section in ini.sections(text)
	copy.style in styles(text, section)
}

names_package(entry) if entry in {copy.package, concat("", [copy.package, ".zip"])}

names_package(entry) if endswith(entry, concat("", ["/", copy.package, ".zip"]))

installs_package(text) if {
	some entry in packages(text)
	names_package(entry)
}

# A config that is about copy: it applies the style or installs the package.
copy_configs contains path if {
	some path, text in configs
	count(copy_sections(text)) > 0
}

copy_configs contains path if {
	some path, text in configs
	installs_package(text)
}

# The configs COPY-02 and COPY-03 judge: those about copy, or, in a
# repository that publishes a site and has none, every config it has.
judged contains path if some path in copy_configs

judged contains path if {
	publishes_site
	count(copy_configs) == 0
	some path, _ in configs
}

# The release the repository pins: the mise pin, else the declaration's
# version without one (ADOPT-09 reports a repository with neither).
pin_version(pin) := pin if is_string(pin)

pin_version(pin) := pin.version if is_string(pin.version)

pinned_versions contains version if {
	some pin in files.mise_pins
	version := pin_version(pin)
	version != "latest"
}

pinned_versions contains version if {
	count(files.mise_pins) == 0
	version := files.declaration.conventions.version
	is_string(version)
}

package_url(version) := sprintf("%s/v%s/%s.zip", [copy.release_url, version, copy.package])

expected_urls contains package_url(version) if some version in pinned_versions

expected_url := url if {
	count(expected_urls) == 1
	some url in expected_urls
} else := package_url("<release>")

release_pattern := sprintf(
	`^%s/v([0-9]+\.[0-9]+\.[0-9]+)/%s\.zip$`,
	[regex_escape(copy.release_url), copy.package],
)

regex_escape(text) := regex.replace(text, `([.\\+*?()|\[\]{}^$])`, `\$1`)

# With no pin, any release's URL is pinned, which is all COPY-02 asks of it.
acceptable(entry) if entry in expected_urls

acceptable(entry) if {
	count(pinned_versions) == 0
	regex.match(release_pattern, entry)
}

# A package named without a URL or a path resolves to its latest release.
bare(entry) if {
	not contains(entry, "/")
	not endswith(entry, ".zip")
}

floats := "which installs whatever release is latest when vale sync runs"

package_problem(entry) := sprintf("Packages names %s by name, %s", [entry, floats]) if {
	bare(entry)
} else := sprintf(
	"Packages installs %s %s, but the repository pins %s",
	[copy.package, version, concat(", ", sort(pinned_versions))],
) if {
	some match in regex.find_all_string_submatch_n(release_pattern, entry, 1)
	version := match[1]
} else := sprintf("Packages installs %s from %s, not from a release of the conventions", [copy.package, entry])

based_on_text := concat(", ", copy.based_on)

# Template formats Vale skips unless [formats] says how to read them, and
# the format each one is read as (definitions/copy/style.yml).
template_formats := copy.template_formats

# The extensions a section's glob names: *.svelte, or *.{md,svelte}.
extensions(pattern) := {trim_space(extension) |
	some match in regex.find_all_string_submatch_n(`\.\{([^{}]*)\}$`, pattern, 1)
	some extension in split(match[1], ",")
} if {
	endswith(pattern, "}")
}

extensions(pattern) := {match[1] |
	some match in regex.find_all_string_submatch_n(`\.([A-Za-z0-9]+)$`, pattern, 1)
} if {
	not endswith(pattern, "}")
}
