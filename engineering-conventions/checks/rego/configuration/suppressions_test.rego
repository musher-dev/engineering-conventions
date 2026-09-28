package conventions.checks.configuration.suppressions_test

import data.conventions.checks.configuration.suppressions
import data.conventions.lib.testdata_test as td

trivy_path := ".config/security/trivyignore.yaml"

good_entry := {
	"id": "CVE-2026-0001",
	"statement": "The vulnerable parser is never reached.",
	"expired_at": "2026-12-01",
}

trivy(contents) := [td.file(trivy_path, contents)]

texts(entries) := [td.file(
	"/tmp/inventory.json",
	{"conventions_inventory": {"files": [path | some path, _ in entries], "texts": entries}},
)]

messages(found, id) := {f.message | some f in found; f.id == id}

pairs(found) := {[f.id, f.path] | some f in found}

test_conforming_trivyignore_yaml if {
	docs := trivy({
		"vulnerabilities": [good_entry],
		"misconfigurations": [object.union(good_entry, {"id": "AVD-DS-0002"})],
		"secrets": [],
	})
	count(suppressions.findings) == 0 with input as docs with data.conventions.runtime.now as td.now
}

test_conf_10_missing_fields if {
	docs := trivy({"vulnerabilities": [{"id": "CVE-2026-0002"}, {"statement": " ", "expired_at": "2026-12-01"}]})
	found := suppressions.findings with input as docs with data.conventions.runtime.now as td.now
	pairs(found) == {["CONF-10", trivy_path]}
	messages(found, "CONF-10") == {
		concat("", [
			"vulnerabilities CVE-2026-0002: add a statement saying why the finding is acceptable; ",
			"add an expired_at date, or Trivy ignores the finding forever",
		]),
		"vulnerabilities entry 2: add a statement saying why the finding is acceptable",
	}
}

test_conf_10_dates if {
	docs := trivy({"licenses": [
		object.union(good_entry, {"id": "GPL-3.0", "expired_at": "2026-09-01"}),
		object.union(good_entry, {"id": "AGPL-3.0", "expired_at": "2027-06-01"}),
		object.union(good_entry, {"id": "LGPL-2.1", "expired_at": "next quarter"}),
	]})
	found := suppressions.findings with input as docs with data.conventions.runtime.now as td.now
	messages(found, "CONF-10") == {
		concat("", [
			"licenses GPL-3.0: expired_at 2026-09-01 has passed; fix the finding and delete the entry,",
			" or renew it with a new statement",
		]),
		"licenses AGPL-3.0: expired_at 2027-06-01 is more than 180 days ahead; set it to 2027-03-22 or earlier",
		`licenses LGPL-2.1: expired_at "next quarter" is not a YYYY-MM-DD date`,
	}
}

test_conf_10_ignores_other_shapes if {
	docs := array.concat(
		trivy({"vulnerabilities": ["CVE-2026-0003"], "secrets": "none"}),
		[td.file("other.yaml", {"vulnerabilities": [{"id": "x"}]})],
	)
	count(suppressions.findings) == 0 with input as docs with data.conventions.runtime.now as td.now
}

trivyignore := concat("\n", [
	"# The parser is never reached in this image.",
	"CVE-2026-0001 exp:2026-12-01",
	"CVE-2026-0002 exp:2026-11-01",
	"",
	"# Build-only dependency, not shipped.",
	"GHSA-xxxx-yyyy-zzzz exp:2026-10-15",
	"",
])

test_conforming_trivyignore if {
	count(suppressions.findings) == 0 with input as texts({".config/security/trivyignore": trivyignore})
		with data.conventions.runtime.now as td.now
}

test_conf_11_problems if {
	text := concat("\n", [
		"CVE-2026-0010 exp:2026-12-01",
		"# Unreachable.",
		"CVE-2026-0011",
		"CVE-2026-0012 exp:2026-09-01",
		"",
		"CVE-2026-0013 exp:2027-12-01",
		"#",
		"CVE-2026-0014 exp:tomorrow",
	])
	found := suppressions.findings with input as texts({".trivyignore": text}) with data.conventions.runtime.now as td.now
	pairs(found) == {["CONF-11", ".trivyignore"]}
	messages(found, "CONF-11") == {
		"line 1 (CVE-2026-0010): add a # comment directly above it saying why the finding is acceptable",
		"line 3 (CVE-2026-0011): add exp:YYYY-MM-DD after the ID, or Trivy ignores the finding forever",
		concat("", [
			"line 4 (CVE-2026-0012): exp 2026-09-01 has passed; fix the finding and delete the entry,",
			" or renew it with a new statement",
		]),
		concat("", [
			"line 6 (CVE-2026-0013): exp 2027-12-01 is more than 180 days ahead; set it to 2027-03-22 or earlier; ",
			"add a # comment directly above it saying why the finding is acceptable",
		]),
		concat("", [
			`line 8 (CVE-2026-0014): exp "tomorrow" is not a YYYY-MM-DD date; `,
			"add a # comment directly above it saying why the finding is acceptable",
		]),
	}
}

test_conf_12_gitleaksignore if {
	text := concat("\r\n", [
		"# A test key from the vendor's documentation.",
		"a1b2c3:docs/example.md:generic-api-key:12",
		"",
		"d4e5f6:tests/fixture.json:generic-api-key:3",
	])
	found := suppressions.findings with input as texts({".gitleaksignore": text})
	pairs(found) == {["CONF-12", ".gitleaksignore"]}
	messages(found, "CONF-12") == {concat(" ", [
		"line 4 (d4e5f6:tests/fixture.json:generic-api-key:3) has no rationale; add a # comment",
		"directly above it saying why the finding is not a secret",
	])}
}
