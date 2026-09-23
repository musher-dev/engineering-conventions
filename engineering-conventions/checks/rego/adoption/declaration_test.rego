package conventions.checks.adoption.declaration_test

import data.conventions.checks.adoption.declaration
import data.conventions.lib.testdata_test as td

messages(found, id) := {f.message | some f in found; f.id == id}

# A workflow with one GHA-07 finding for waivers to match.
misnamed := td.file(".github/workflows/validate.yml", object.union(td.validate, {"name": "CI"}))

with_waivers(waivers) := [misnamed, td.declaration({"profile": "base-repo", "waivers": waivers})]

waiver(requirement, expires) := {
	"requirement": requirement,
	"reason": "Renaming waits for the release branch to close.",
	"tracking": "https://github.com/example/repo/issues/1",
	"expires": expires,
}

test_adopt_01_missing_declaration if {
	missing := [td.inventory([".github/workflows/validate.yml"])]
	present := [td.declaration({"profile": "base-repo"})]
	found := declaration.findings with input as missing
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	td.pairs(found) == {["ADOPT-01", ".repo/conventions.yaml"]}
	count(declaration.findings) == 0 with input as present
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
}

test_active_matching_waiver_is_quiet if {
	docs := with_waivers([waiver("GHA-07", "2026-12-01")])
	count(declaration.findings) == 0 with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
}

test_adopt_03_expired_waiver if {
	docs := with_waivers([waiver("GHA-07", "2026-09-01")])
	found := declaration.findings with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	not "ADOPT-06" in td.ids(found)
	some message in messages(found, "ADOPT-03")
	startswith(message, "waiver 1 (GHA-07) expired on 2026-09-01 and no longer suppresses its finding;")
}

test_adopt_04_unknown_retired_and_alias if {
	docs := with_waivers([
		waiver("GHA-00", "2026-12-01"),
		waiver("GHA-99", "2026-12-01"),
		waiver("CI-15", "2026-12-01"),
		waiver("platform:CI-14", "2026-12-01"),
	])
	found := declaration.findings with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	messages(found, "ADOPT-04") == {
		concat(" ", [
			"waiver 1 (GHA-00) names a requirement that does not exist;",
			"use a requirement ID from the conventions catalog, such as GHA-07",
		]),
		"waiver 2 (GHA-99) names GHA-99, which is retired and never reported; delete the waiver",
		"waiver 3 (CI-15) names a requirement that does not exist; it is an alias of GHA-07; name that instead",
		concat(" ", [
			"waiver 4 (platform:CI-14) names a requirement that does not exist; it is an alias of GHA-01,",
			"GHA-02; name one of those",
		]),
	}
	not "ADOPT-06" in td.ids(found)
}

test_adopt_05_expiry_too_far if {
	docs := with_waivers([waiver("GHA-07", "2027-06-01")])
	found := declaration.findings with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	some message in messages(found, "ADOPT-05")
	startswith(message, "waiver 1 (GHA-07) expires on 2027-06-01, more than 180 days away;")
	contains(message, "set expires: to 2027-03-22 or earlier")
}

test_adopt_06_stale_waivers if {
	scoped := object.union(waiver("GHA-07", "2026-12-01"), {"paths": [".github/actions/**"]})
	docs := with_waivers([
		scoped,
		waiver("GHA-08", "2026-12-01"),
		waiver("ADOPT-01", "2026-12-01"),
		waiver("GHA-09", "2026-12-01"),
	])
	unwaivable := json.patch(td.index, [{"op": "replace", "path": "/requirements/GHA-09/waivable", "value": false}])
	found := declaration.findings with input as docs
		with data.conventions.index as unwaivable
		with data.conventions.runtime.now as td.now
	messages(found, "ADOPT-06") == {
		"waiver 1 (GHA-07) matches no finding, so it suppresses nothing; delete it",
		"waiver 2 (GHA-08) matches no finding, so it suppresses nothing; delete it",
		"waiver 4 (GHA-09) names a requirement that cannot be waived; delete it",
	}
}

test_adopt_07_unknown_profile if {
	docs := [td.declaration({"profile": "strcit"})]
	found := declaration.findings with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	messages(found, "ADOPT-07") == {concat(" ", [
		`profile "strcit" is not defined by this release, so base-repo applies instead;`,
		`use one of "base-repo", "narrow", "strict"`,
	])}
	known := [td.declaration({"profile": "strict"})]
	count(declaration.findings) == 0 with input as known
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
}

test_adopt_08_version_mismatch if {
	docs := [td.declaration({"profile": "base-repo", "conventions": {"version": "0.1.0"}})]
	found := declaration.findings with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
		with data.conventions.release.version as "0.2.0"
	messages(found, "ADOPT-08") == {concat(" ", [
		`conventions.version is "0.1.0" but this is release 0.2.0, so the findings are this release's;`,
		`set conventions.version to "0.2.0", or run the 0.1.0 bundle`,
	])}
	count(declaration.findings) == 0 with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
		with data.conventions.release.version as "0.1.0"
	count(declaration.findings) == 0 with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
}
