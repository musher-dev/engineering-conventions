package conventions.lib.findings_test

import data.conventions.lib.findings
import data.conventions.lib.testdata_test as td

f := findings.finding("GHA-07", ".github/workflows/ci.yml", `name "CI" should be "Validate"`)

url := concat("", [
	"https://github.com/musher-dev/engineering-conventions/blob/main/engineering-conventions/",
	"conventions/github-actions/workflow-files.md#gha-07",
])

test_url_points_at_main_without_release if {
	findings.urls["GHA-07"] == url with data.conventions.index as td.index
}

test_url_points_at_release_tag if {
	findings.ref == "v0.1.0" with data.conventions.release.version as "0.1.0"
}

test_result_object_and_line if {
	r := findings.result(f, "warning") with data.conventions.index as td.index
	r.msg == sprintf(`warning [GHA-07] .github/workflows/ci.yml — name "CI" should be "Validate" %s`, [url])
	r.id == "GHA-07"
	r.severity == "warning"
	r.convention == "EC-0002"
	r.path == ".github/workflows/ci.yml"
	r.message == `name "CI" should be "Validate"`
}
