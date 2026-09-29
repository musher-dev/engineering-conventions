package conventions.lib.enforcement_test

import data.conventions.lib.enforcement
import data.conventions.lib.testdata_test as td

staged(adoption) := [td.declaration({"adoption": adoption})]

adoption(families, expires) := {
	"enforce": families,
	"tracking": "https://github.com/example/repo/issues/1",
	"expires": expires,
}

test_every_family_is_enforced_without_a_declaration if {
	enforcement.enforced("GHA-07") with input as [td.pin]
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	not enforcement.staged with input as [td.pin]
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
}

test_a_staged_adoption_enforces_the_listed_families if {
	docs := staged(adoption(["OUT"], "2026-12-01"))
	enforcement.staged with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	enforcement.enforced("OUT-06") with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	not enforcement.enforced("GHA-07") with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
}

test_adopt_is_always_enforced if {
	enforcement.enforced("ADOPT-06") with input as staged(adoption(["OUT"], "2026-12-01"))
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
}

test_the_last_day_is_still_staged if {
	enforcement.staged with input as staged(adoption(["OUT"], "2026-09-23"))
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
}

test_an_expired_adoption_enforces_every_family if {
	docs := staged(adoption(["OUT"], "2026-09-01"))
	enforcement.expired with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
	enforcement.enforced("GHA-07") with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
}

test_an_adoption_without_a_date_stages_nothing if {
	docs := staged({"enforce": ["OUT"]})
	enforcement.enforced("GHA-07") with input as docs
		with data.conventions.index as td.index
		with data.conventions.runtime.now as td.now
}

test_known_families_come_from_the_requirement_ids if {
	families := enforcement.known_families with data.conventions.index as td.index
	{"ADOPT", "GHA", "OUT"} & families == {"ADOPT", "GHA", "OUT"}
	not "CI" in families
}
