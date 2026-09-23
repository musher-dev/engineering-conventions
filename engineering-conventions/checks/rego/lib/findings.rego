# METADATA
# title: Findings and diagnostics
# description: >-
#   Builds a check's raw finding and renders a reported one into the result
#   object and the one-line diagnostic of the diagnostic contract.
package conventions.lib.findings

finding(id, path, message) := {"id": id, "path": path, "message": message}

index := data.conventions.index

default ref := "main"

# A released bundle links to its own tag so a diagnostic always points at the
# text that produced it; a checkout of the source links to main.
ref := concat("", ["v", data.conventions.release.version]) if is_string(data.conventions.release.version)

urls[id] := sprintf("%s/blob/%s/%s/%s#%s", [
	index.repository,
	ref,
	index.product_dir,
	requirement.path,
	requirement.anchor,
]) if {
	some id, requirement in index.requirements
}

line(severity, finding) := sprintf("%s [%s] %s — %s %s", [
	severity,
	finding.id,
	finding.path,
	finding.message,
	urls[finding.id],
])

result(finding, severity) := {
	"msg": line(severity, finding),
	"id": finding.id,
	"path": finding.path,
	"message": finding.message,
	"severity": severity,
	"url": urls[finding.id],
	"convention": index.requirements[finding.id].convention,
}
