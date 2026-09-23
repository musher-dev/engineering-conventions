package conventions.lib.waivers_test

import data.conventions.lib.testdata_test as td
import data.conventions.lib.waivers

finding := {"id": "GHA-07", "path": ".github/workflows/ci.yml", "message": "m"}

test_now_from_runtime_data if {
	waivers.now_ns == time.parse_rfc3339_ns(td.now) with data.conventions.runtime.now as td.now
}

test_now_falls_back_to_clock if {
	waivers.now_ns > time.parse_rfc3339_ns("2020-01-01T00:00:00Z")
}

test_expiry_parsing if {
	waivers.expires_ns({"expires": "2026-09-23"}) == time.parse_rfc3339_ns("2026-09-23T00:00:00Z")
	waivers.expires_ns({"expires": "2026-09-23T12:00:00Z"}) == time.parse_rfc3339_ns("2026-09-23T12:00:00Z")
}

test_expired_and_active if {
	waivers.expired({"expires": "2026-09-22"}) with data.conventions.runtime.now as td.now
	waivers.active({"expires": "2026-09-23"}) with data.conventions.runtime.now as td.now
	not waivers.expired({"expires": "2026-09-23"}) with data.conventions.runtime.now as td.now
}

test_too_long if {
	waivers.too_long({"expires": "2027-03-23"}) with data.conventions.runtime.now as td.now
	not waivers.too_long({"expires": "2027-03-22"}) with data.conventions.runtime.now as td.now
	waivers.latest_allowed_date == "2027-03-22" with data.conventions.runtime.now as td.now
}

test_matches_with_and_without_paths if {
	waivers.matches({"requirement": "GHA-07"}, finding)
	waivers.matches({"requirement": "GHA-07", "paths": [".github/workflows/*.yml"]}, finding)
	not waivers.matches({"requirement": "GHA-07", "paths": [".github/actions/**"]}, finding)
	not waivers.matches({"requirement": "GHA-08"}, finding)
}

test_suppressed_only_by_active_waivable_waiver if {
	active := [td.declaration({"waivers": [{"requirement": "GHA-07", "expires": "2026-12-01"}]})]
	waivers.suppressed(finding) with input as active
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	expired := [td.declaration({"waivers": [{"requirement": "GHA-07", "expires": "2026-09-01"}]})]
	not waivers.suppressed(finding) with input as expired
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	adopt := [td.declaration({"waivers": [{"requirement": "ADOPT-01", "expires": "2026-12-01"}]})]
	adopt_finding := {"id": "ADOPT-01", "path": ".repo/conventions.yaml", "message": "m"}
	not waivers.suppressed(adopt_finding) with input as adopt
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
}

test_declared_ignores_malformed if {
	docs := [td.declaration({"waivers": [{"requirement": "GHA-07"}, "junk"]})]
	waivers.declared == [{"requirement": "GHA-07"}] with input as docs
	waivers.declared == [] with input as [td.declaration({"waivers": "junk"})]
}

test_label if {
	waivers.label(0, {"requirement": "GHA-07"}) == "waiver 1 (GHA-07)"
	waivers.label(1, {}) == "waiver 2"
}
