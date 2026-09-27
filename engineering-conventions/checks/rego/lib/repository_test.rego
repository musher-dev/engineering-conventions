package conventions.lib.repository_test

import data.conventions.lib.repository
import data.conventions.lib.testdata_test as td

declared(name) := [td.repository(object.union(td.identity, {"name": name}))]

test_vocabulary_is_read_from_the_index if {
	repository.systems == {"engineering", "platform", "sdk"} with data.conventions.index as td.index
	repository.kinds == {"library", "service", "specification"} with data.conventions.index as td.index
	repository.lifecycles == {"deprecated", "experimental", "production"} with data.conventions.index as td.index
	repository.audiences == {"internal", "public"} with data.conventions.index as td.index
	repository.systems == set() with data.conventions.index as {}
}

test_judged_name_prefers_the_actual_name if {
	docs := array.concat(declared("platform-api"), [td.named_inventory([], "platform-web")])
	repository.judged_name == "platform-web" with input as docs
	repository.judged_name == "platform-api" with input as declared("platform-api")
	not repository.judged_name with input as [td.inventory([])]
}

test_reserved_names_are_exempt if {
	repository.exempt with input as [td.named_inventory([], ".github")]
	repository.exempt with input as declared(".github-private")
	not repository.exempt with input as declared("platform-api")
}

test_well_formed if {
	repository.well_formed("platform-api")
	repository.well_formed("platform-operator-console")
	repository.well_formed("sdk-python3")
	not repository.well_formed("platform")
	not repository.well_formed("Platform-API")
	not repository.well_formed("platform_api")
	not repository.well_formed("platform--api")
	not repository.well_formed("3d-models")
	not repository.well_formed(concat("-", ["platform", letters(55)]))
	repository.well_formed(concat("-", ["platform", letters(54)]))
}

letters(n) := concat("", ["a" | some _ in numbers.range(1, n)])

test_banned_tokens_and_versions if {
	repository.banned("musher") with data.conventions.index as td.index
	repository.banned("v2") with data.conventions.index as td.index
	not repository.banned("api") with data.conventions.index as td.index
	not repository.banned("v2beta") with data.conventions.index as td.index
	advice := repository.advice("utils") with data.conventions.index as td.index
	advice == "Says nothing about what it holds; name what it holds."
	startswith(repository.advice("v10"), "Names a version") with data.conventions.index as td.index
}

test_tokens if {
	repository.tokens("platform-operator-console") == ["platform", "operator", "console"]
	repository.system_token("platform-operator-console") == "platform"
}
