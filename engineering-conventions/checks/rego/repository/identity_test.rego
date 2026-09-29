package conventions.checks.repository.identity_test

import data.conventions.checks.repository.identity
import data.conventions.lib.testdata_test as td

messages(found, id) := {f.message | some f in found; f.id == id}

declared(fields) := [td.repository(object.union(td.identity, fields))]

test_conforming_declaration if {
	count(identity.findings) == 0 with input as declared({}) with data.conventions.index as td.index
}

test_repo_01_missing_declaration if {
	found := identity.findings with input as [td.inventory([])] with data.conventions.index as td.index
	td.pairs(found) == {["REPO-01", ".repo/repository.toml"]}
	messages(found, "REPO-01") == {concat(" ", [
		"the repository does not declare its identity; add .repo/repository.toml with its name,",
		"system, component, kind, owner, lifecycle, audience and tier",
	])}
}

test_repo_01_quiet_when_only_the_inventory_lists_it if {
	count(identity.findings) == 0 with input as [td.inventory([".repo/repository.toml"])]
		with data.conventions.index as td.index
}

test_repo_02_one_finding_with_a_count if {
	docs := declared({"tier": 5, "team": "platform"})
	found := identity.findings with input as docs with data.conventions.index as td.index
	td.pairs(found) == {["REPO-02", ".repo/repository.toml"]}
	messages(found, "REPO-02") == {
		"the declaration: Additional property team is not allowed. (1 more problem in the declaration)",
	}
}

test_repo_02_a_declaration_that_is_not_a_table if {
	found := identity.findings with input as [td.file(".repo/repository.toml", ["junk"])]
		with data.conventions.index as td.index
	"REPO-02" in td.ids(found)
}

test_repo_03_unregistered_values if {
	docs := declared({"system": "widgets", "name": "widgets-api", "kind": "microservice"})
	found := identity.findings with input as docs with data.conventions.index as td.index
	messages(found, "REPO-03") == {
		`system "widgets" is not a registered system; use one of "engineering", "platform", "sdk"`,
		`kind "microservice" is not a registered kind; use one of "library", "service", "specification"`,
	}
	not "REPO-04" in td.ids(found)
}

test_repo_03_lifecycle_and_audience if {
	docs := declared({"lifecycle": "beta", "audience": "everyone"})
	found := identity.findings with input as docs with data.conventions.index as td.index
	count(messages(found, "REPO-03")) == 2
}

test_repo_04_name_is_system_and_component if {
	found := identity.findings with input as declared({"component": "server"})
		with data.conventions.index as td.index
	td.pairs(found) == {["REPO-04", ".repo/repository.toml"]}
	messages(found, "REPO-04") == {concat("", [
		`name is "platform-api", but system and component make "platform-server"; `,
		"a repository's name is <system>-<component>, so correct whichever is wrong",
	])}
}

test_repo_04_leaves_a_malformed_name_to_repo_08 if {
	docs := declared({"name": "gadgets", "component": "gadgets"})
	count(identity.findings) == 0 with input as docs with data.conventions.index as td.index
}

test_repo_04_exempts_reserved_names if {
	docs := declared({"name": ".github", "system": "engineering", "component": "github"})
	count(identity.findings) == 0 with input as docs with data.conventions.index as td.index
}
