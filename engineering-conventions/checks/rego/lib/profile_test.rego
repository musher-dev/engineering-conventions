package conventions.lib.profile_test

import data.conventions.lib.profile
import data.conventions.lib.testdata_test as td

test_default_profile_without_declaration if {
	profile.name == "base-repo" with data.conventions.index as td.index with input as []
	profile.in_profile("GHA-07") with data.conventions.index as td.index with input as []
}

test_declared_profile if {
	docs := [td.declaration({"profile": "narrow"})]
	profile.name == "narrow" with data.conventions.index as td.index with input as docs
	profile.in_profile("GHA-07") with data.conventions.index as td.index with input as docs
	not profile.in_profile("GHA-08") with data.conventions.index as td.index with input as docs
}

test_unknown_profile_falls_back_to_default if {
	docs := [td.declaration({"profile": "no-such-profile"})]
	profile.name == "base-repo" with data.conventions.index as td.index with input as docs
}

test_severity_from_profile_then_catalog if {
	strict := [td.declaration({"profile": "strict"})]
	profile.severity("GHA-07") == "error" with data.conventions.index as td.index with input as strict
	profile.severity("GHA-07") == "warning" with data.conventions.index as td.index with input as []
	profile.severity("NOPE-01") == "warning" with data.conventions.index as td.index with input as []
}
