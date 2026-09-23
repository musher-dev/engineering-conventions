# METADATA
# title: Router
# description: >-
#   Collects every check's raw findings and reports those the effective
#   convention profile enforces and no unexpired waiver covers: `deny` at
#   effective severity error, `warn` at warning. Checks never decide severity,
#   time or waivers, so changing a severity is a catalog edit, not a Rego one.
package main

import data.conventions.lib.findings
import data.conventions.lib.profile
import data.conventions.lib.waivers

# The ref must end in `.findings`: binding a whole package to a variable would
# evaluate every rule in it, and the `_test` packages sit beside the checks.
raw contains finding if {
	some family, convention
	package_findings := data.conventions.checks[family][convention].findings
	some finding in package_findings
}

# ADOPT findings pass the profile filter like any other but are never waivable
# (waivers.suppressed consults waivable).
reported contains [finding, severity] if {
	some finding in raw
	profile.in_profile(finding.id)
	not waivers.suppressed(finding)
	severity := profile.severity(finding.id)
}

# METADATA
# entrypoint: true
deny contains findings.result(finding, "error") if {
	some [finding, "error"] in reported
}

# METADATA
# entrypoint: true
warn contains findings.result(finding, "warning") if {
	some [finding, "warning"] in reported
}
