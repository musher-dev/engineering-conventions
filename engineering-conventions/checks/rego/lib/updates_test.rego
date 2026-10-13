package conventions.lib.updates_test

import data.conventions.lib.testdata_test as td
import data.conventions.lib.updates

dependabot(path, entries) := td.file(path, {"version": 2, "updates": entries})

test_dependabot_path_defaults_and_follows_the_file if {
	updates.dependabot_path == ".github/dependabot.yml" with input as []
	updates.dependabot_path == ".github/dependabot.yaml" with input as [dependabot(".github/dependabot.yaml", [])]
}

test_dependabot_updates_keep_only_objects if {
	documents := [dependabot(".github/dependabot.yml", [{"package-ecosystem": "npm", "directory": "/"}, "stray"])]
	found := updates.dependabot_updates with input as documents
	found == {{"path": ".github/dependabot.yml", "update": {"package-ecosystem": "npm", "directory": "/"}}}
}

test_update_directories if {
	updates.update_directories({"directories": ["/", "/web", 3]}) == ["/", "/web"]
	updates.update_directories({"directory": "/api"}) == ["/api"]
	updates.update_directories({}) == ["/"]
}

test_covers_a_directory_by_name_or_glob if {
	documents := [dependabot(".github/dependabot.yml", [
		{"package-ecosystem": "npm", "directory": "/web/"},
		{"package-ecosystem": "gomod", "directories": ["/services/*"]},
		{"package-ecosystem": "cargo", "directory": "/"},
	])]
	updates.covers({"npm", "bun"}, "web") with input as documents
	updates.covers({"gomod"}, "services/orders") with input as documents
	updates.covers({"cargo"}, "") with input as documents
	not updates.covers({"npm"}, "api") with input as documents
	not updates.covers({"pip"}, "web") with input as documents
	not updates.covers({"gomod"}, "services/orders/nested") with input as documents
}

test_renovate_is_any_of_its_config_paths if {
	updates.renovate with input as [td.inventory([".github/renovate.json5"])]
	not updates.renovate with input as [td.inventory(["docs/renovate.json"])]
}
