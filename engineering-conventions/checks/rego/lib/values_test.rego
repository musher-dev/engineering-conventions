package conventions.lib.values_test

import data.conventions.lib.values

test_within_reaches_every_depth if {
	document := {
		"vars": {"CONFIG": ".config/yaml/yamllint.yaml"},
		"tasks": {"lint": {"cmds": ["yamllint -c {{.CONFIG}} .", {"task": "fmt"}]}},
		"count": 3,
		"enabled": true,
	}
	values.string_values(document) == {".config/yaml/yamllint.yaml", "yamllint -c {{.CONFIG}} .", "fmt"}
}

test_within_a_string_is_itself if {
	values.string_values("one") == {"one"}
}

test_within_nothing if {
	values.string_values({"a": [1, null, false]}) == set()
}
