package conventions.lib.release_please_test

import data.conventions.lib.release_please as rp
import data.conventions.lib.testdata_test as td

config(contents) := td.file(".github/release-please/config.json", contents)

test_settings_fall_back_from_package_to_top_level_to_default if {
	docs := [config({"draft": true, "tag-separator": "/", "packages": {"a": {"draft": false}, "b": {}}})]
	settings := rp.settings with input as docs
	settings.a.draft == false
	settings.b.draft == true
	settings.a["tag-separator"] == "/"
	settings.b["include-v-in-tag"] == true
	not "packages" in object.keys(settings.a)
}

test_packages_skip_what_is_not_an_object if {
	packages := rp.packages with input as [config({"packages": {"a": {}, "b": "c"}})]
	object.keys(packages) == {"a"}
	several := rp.several with input as [config({"packages": {"a": {}, "b": {}}})]
	several
}

test_stray_files if {
	docs := [td.inventory([
		"release-please-config.json",
		"tools/.release-please-manifest.json",
		".github/release-please/config.json",
		".github/release-please/manifest.json",
		".github/release-please/other.json",
		".github/release-please/README.md",
	])]
	stray := rp.stray_files with input as docs
	stray == {"release-please-config.json", "tools/.release-please-manifest.json", ".github/release-please/other.json"}
}

test_release_writes if {
	rp.uploads({"run": "gh release upload v1 dist/*"})
	rp.uploads({"run": "curl -X POST \"$upload_url?name=a\""})
	rp.uploads({"uses": "softprops/action-gh-release@x"})
	not rp.uploads({"run": "gh release view v1"})
	rp.publishes({"run": "gh release edit v1 --draft=false"})
	rp.publishes({"run": "gh release edit v1 --draft false"})
	rp.publishes({"run": "gh api -X PATCH \"$api\" -F draft=false"})
	not rp.publishes({"run": "gh release edit v1 --notes x"})
	rp.deletes({"run": "gh release delete v1 --yes"})
	rp.writes({"run": "gh release create v1"})
	rp.writes({"run": "gh api --method DELETE repos/o/r/releases/assets/1"})
	not rp.writes({"run": "# gh release delete v1\ngh release view v1"})
}

test_token if {
	rp.token({}, {"env": {"GH_TOKEN": "a", "GITHUB_TOKEN": "b"}}) == "a"
	rp.token({}, {"env": {"GITHUB_TOKEN": "b"}}) == "b"
	rp.token({"env": {"GH_TOKEN": "c"}}, {}) == "c"
	rp.token({}, {}) == ""
	rp.default_token("${{ github.token }}")
	rp.default_token("${{ secrets.GITHUB_TOKEN }}")
	not rp.default_token("${{ steps.app_token.outputs.token }}")
}
