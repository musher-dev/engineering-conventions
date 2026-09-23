# METADATA
# title: Conventions declaration
# description: >-
#   A repository declares its conventions in .repo/conventions.yaml, and every
#   waiver there is known, time-boxed, in force and still needed. ADOPT-02
#   (schema validity) is checked by the runner, not here.
# scope: package
# custom:
#   convention: EC-0001
package conventions.checks.adoption.declaration

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.names
import data.conventions.lib.profile
import data.conventions.lib.waivers

# ADOPT-01
findings contains lib.finding("ADOPT-01", files.declaration_path, message) if {
	not files.declared
	message := sprintf(
		concat(" ", [
			"the repository has no %s; add one naming the release it pins and its profile, e.g.",
			"schema_version: 1, conventions: {version: \"<release>\"}, profile: base-repo, waivers: []",
		]),
		[files.declaration_path],
	)
}

# ADOPT-03. The router already stops honouring the waiver, so its finding is
# reported again; this names the waiver that has to be renewed or removed.
findings contains lib.finding("ADOPT-03", files.declaration_path, message) if {
	some index, waiver in waivers.declared
	known(waiver.requirement)
	waivers.expired(waiver)
	message := sprintf(
		concat(" ", [
			"%s expired on %s and no longer suppresses its finding; fix the finding and delete the",
			"waiver, or renew it with a new expires date and a tracking link",
		]),
		[waivers.label(index, waiver), waiver.expires],
	)
}

# ADOPT-04
findings contains lib.finding("ADOPT-04", files.declaration_path, message) if {
	some index, waiver in waivers.declared
	not requirements[waiver.requirement]
	message := sprintf(
		"%s names a requirement that does not exist; %s",
		[waivers.label(index, waiver), unknown_hint(waiver.requirement)],
	)
}

findings contains lib.finding("ADOPT-04", files.declaration_path, message) if {
	some index, waiver in waivers.declared
	requirements[waiver.requirement].status == "retired"
	message := sprintf(
		"%s names %s, which is retired and never reported; delete the waiver",
		[waivers.label(index, waiver), waiver.requirement],
	)
}

# ADOPT-05
findings contains lib.finding("ADOPT-05", files.declaration_path, message) if {
	some index, waiver in waivers.declared
	known(waiver.requirement)
	waivers.too_long(waiver)
	message := sprintf(
		concat(" ", [
			"%s expires on %s, more than %d days away; set expires: to %s or earlier and renew it if",
			"the work is still open then",
		]),
		[waivers.label(index, waiver), waiver.expires, waivers.max_term_days, waivers.latest_allowed_date],
	)
}

# ADOPT-06. Expired and unknown waivers are already reported above, and a
# waiver of an ADOPT requirement is a schema error the runner reports as
# ADOPT-02.
findings contains lib.finding("ADOPT-06", files.declaration_path, message) if {
	some index, waiver in waivers.declared
	known(waiver.requirement)
	not startswith(waiver.requirement, "ADOPT-")
	waivers.active(waiver)
	not covers_a_finding(waiver)
	message := sprintf("%s %s; delete it", [waivers.label(index, waiver), stale_reason(waiver)])
}

# ADOPT-07. The router still applies the default profile, so a typo never
# switches every check off; this is what names the typo.
findings contains lib.finding("ADOPT-07", files.declaration_path, message) if {
	files.declared
	name := files.declaration.profile
	is_string(name)
	not profile.catalog[name]
	message := sprintf(
		"profile %q is not defined by this release, so %s applies instead; use one of %s",
		[name, profile.name, names.quoted_list(object.keys(profile.catalog))],
	)
}

# ADOPT-08. Only a released bundle knows its version; a checkout of the
# source carries no release data and reports nothing.
findings contains lib.finding("ADOPT-08", files.declaration_path, message) if {
	running := data.conventions.release.version
	is_string(running)
	declared := files.declaration.conventions.version
	is_string(declared)
	declared != running
	message := sprintf(
		concat(" ", [
			"conventions.version is %q but this is release %s, so the findings are this release's;",
			"set conventions.version to %q, or run the %s bundle",
		]),
		[declared, running, running, declared],
	)
}

# Waiver checks judge the findings a waiver could cover, before any waiver is
# applied. They are read from each family's check packages by name: reading
# all of data.conventions.checks would include this package and recurse.
raw_findings contains finding if {
	some convention
	package_findings := data.conventions.checks.github_actions[convention].findings
	some finding in package_findings
}

requirements := object.get(data.conventions.index, "requirements", {})

known(id) if requirements[id].status != "retired"

# A waiver copied from a repo-local rule often carries the legacy ID the
# requirement records as an alias (`platform:CI-14` or bare `CI-14`). One
# legacy rule may have been split into several requirements.
alias_targets(name) := {id |
	some id, requirement in requirements
	some alias in object.get(requirement, "aliases", [])
	name in {alias, regex.replace(alias, `^[^:]*:`, "")}
}

unknown_hint(name) := sprintf("it is an alias of %s; name that instead", [targets[0]]) if {
	targets := sort(alias_targets(name))
	count(targets) == 1
}

unknown_hint(name) := sprintf("it is an alias of %s; name one of those", [concat(", ", targets)]) if {
	targets := sort(alias_targets(name))
	count(targets) > 1
}

unknown_hint(name) := "use a requirement ID from the conventions catalog, such as GHA-07" if {
	count(alias_targets(name)) == 0
}

covers_a_finding(waiver) if {
	waivers.waivable(waiver.requirement)
	some finding in raw_findings
	waivers.matches(waiver, finding)
}

stale_reason(waiver) := "names a requirement that cannot be waived" if not waivers.waivable(waiver.requirement)

stale_reason(waiver) := "matches no finding, so it suppresses nothing" if waivers.waivable(waiver.requirement)
