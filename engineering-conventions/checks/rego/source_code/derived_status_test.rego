package conventions.checks.source_code.derived_status_test

import data.conventions.checks.source_code.derived_status as status
import data.conventions.lib.testdata_test as td

ids_at(found) := {[f.id, f.path] | some f in found}

test_exhaustiveness_left_on if {
	docs := [
		td.file("pyproject.toml", {"tool": {"basedpyright": {"typeCheckingMode": "strict"}}}),
		td.file("service/pyproject.toml", {"tool": {"pyright": {"reportMatchNotExhaustive": true}}}),
		td.file("tools/pyproject.toml", {"tool": {"basedpyright": {"reportMatchNotExhaustive": "warning"}}}),
		td.file("lib/pyrightconfig.json", {"reportMatchNotExhaustive": "error"}),
		td.file("other/pyproject.toml", {"tool": {"ruff": {"reportMatchNotExhaustive": false}}}),
	]
	count(status.findings) == 0 with input as docs
}

test_status_06_exhaustiveness_turned_off if {
	docs := [
		td.file("pyproject.toml", {"tool": {"pyright": {"reportMatchNotExhaustive": false}}}),
		td.file("service/pyproject.toml", {"tool": {"basedpyright": {"reportMatchNotExhaustive": "none"}}}),
		td.file("tools/pyproject.toml", {"tool": {"basedpyright": {"reportMatchNotExhaustive": "Hint"}}}),
		td.file("lib/pyrightconfig.json", {"reportMatchNotExhaustive": "information"}),
	]
	found := status.findings with input as docs
	ids_at(found) == {
		["STATUS-06", "pyproject.toml"],
		["STATUS-06", "service/pyproject.toml"],
		["STATUS-06", "tools/pyproject.toml"],
		["STATUS-06", "lib/pyrightconfig.json"],
	}
}

test_status_06_message_names_the_value if {
	docs := [td.file("pyproject.toml", {"tool": {"pyright": {"reportMatchNotExhaustive": "none"}}})]
	some f in status.findings with input as docs
	contains(f.message, `reportMatchNotExhaustive to "none"`)
}
