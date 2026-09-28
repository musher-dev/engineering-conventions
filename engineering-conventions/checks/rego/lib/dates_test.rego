package conventions.lib.dates_test

import data.conventions.lib.dates
import data.conventions.lib.testdata_test as td

test_now_from_runtime_data if {
	dates.now_ns == time.parse_rfc3339_ns(td.now) with data.conventions.runtime.now as td.now
}

test_now_falls_back_to_clock if {
	dates.now_ns > time.parse_rfc3339_ns("2020-01-01T00:00:00Z")
}

test_date_parsing if {
	dates.date_ns("2026-09-23") == time.parse_rfc3339_ns("2026-09-23T00:00:00Z")
	dates.date_ns("2026-09-23T12:00:00Z") == time.parse_rfc3339_ns("2026-09-23T12:00:00Z")
	dates.is_date("2026-09-23")
	not dates.is_date("soon")
	not dates.is_date(20260923)
}

test_past if {
	dates.past("2026-09-22") with data.conventions.runtime.now as td.now
	not dates.past("2026-09-23") with data.conventions.runtime.now as td.now
}

test_beyond_term if {
	dates.beyond_term("2027-03-23") with data.conventions.runtime.now as td.now
	not dates.beyond_term("2027-03-22") with data.conventions.runtime.now as td.now
	dates.latest_allowed_date == "2027-03-22" with data.conventions.runtime.now as td.now
}
