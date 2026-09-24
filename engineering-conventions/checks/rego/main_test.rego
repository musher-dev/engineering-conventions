package main_test

import data.conventions.lib.testdata_test as td
import data.main

misnamed := td.file(".github/workflows/validate.yml", object.union(td.validate, {"name": "CI"}))

pairs(results) := {[r.id, r.path, r.severity] | some r in results}

declaration(extra) := td.declaration(object.union({"profile": "base-repo", "waivers": []}, extra))

waiver(requirement, expires) := {"requirement": requirement, "reason": "r", "tracking": "t", "expires": expires}

test_warn_at_warning_severity if {
	docs := [misnamed, td.pin, declaration({})]
	warnings := main.warn with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	pairs(warnings) == {["GHA-07", ".github/workflows/validate.yml", "warning"]}
	denials := main.deny with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	count(denials) == 0
}

test_result_object_shape if {
	docs := [misnamed, td.pin, declaration({})]
	warnings := main.warn with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	url := concat("", [
		"https://github.com/musher-dev/engineering-conventions/blob/main/engineering-conventions/",
		"definitions/conventions/github-actions/workflow-files.md#gha-07",
	])
	message := `name "CI" should be "Validate": a workflow's name is its filename stem in Title Case`
	some result in warnings
	result == {
		"msg": sprintf("warning [GHA-07] .github/workflows/validate.yml — %s %s", [message, url]),
		"id": "GHA-07",
		"path": ".github/workflows/validate.yml",
		"message": message,
		"severity": "warning",
		"url": url,
		"convention": "EC-0002",
	}
}

test_deny_at_error_severity if {
	docs := [misnamed, td.pin, declaration({"profile": "strict"})]
	warnings := main.warn with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	denials := main.deny with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	pairs(denials) == {["GHA-07", ".github/workflows/validate.yml", "error"]}
	count(warnings) == 0
}

test_profile_filters_requirements if {
	extra := td.file(".github/workflows/validate-x.yml", object.union(td.validate, {"name": "CI"}))
	docs := [misnamed, extra, td.pin, declaration({"profile": "narrow"})]
	warnings := main.warn with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	{r.id | some r in warnings} == {"GHA-07"}
}

test_active_waiver_suppresses if {
	docs := [misnamed, td.pin, declaration({"waivers": [waiver("GHA-07", "2026-12-01")]})]
	warnings := main.warn with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	count(warnings) == 0
}

test_expired_waiver_reports_finding_and_adopt_03 if {
	docs := [misnamed, td.pin, declaration({"waivers": [waiver("GHA-07", "2026-09-01")]})]
	warnings := main.warn with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	pairs(warnings) == {
		["GHA-07", ".github/workflows/validate.yml", "warning"],
		["ADOPT-03", ".repo/conventions.yaml", "warning"],
	}
}

test_adopt_findings_are_never_waived if {
	docs := [td.inventory([]), td.declaration({"waivers": [waiver("ADOPT-09", "2026-12-01")]})]
	warnings := main.warn with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	pairs(warnings) == {
		["ADOPT-09", "mise.toml", "warning"],
		["ADOPT-02", ".repo/conventions.yaml", "warning"],
	}
}
