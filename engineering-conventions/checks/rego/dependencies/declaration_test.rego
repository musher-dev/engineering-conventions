package conventions.checks.dependencies.declaration_test

import data.conventions.checks.dependencies.declaration
import data.conventions.lib.testdata_test as td

messages(found, id) := {f.message | some f in found; f.id == id}

identity := td.repository(object.union(td.identity, {"name": "platform-web", "layout": {"product": "web"}}))

sha(n) := concat("", [n, substring("0000000000000000000000000000000000000000000000000000000000000000", 0, 63)])

copy := "web/contracts/vendor/platform-api/contracts"

record := {
	"schema_version": 1,
	"repository": "platform-api",
	"output": "contracts",
	"version": "0.36.1",
	"tag": "v0.36.1",
	"commit": "0123456789abcdef0123456789abcdef01234567",
	"interfaces": [
		recorded("public-http", "openapi/public.json", sha("a")),
		recorded("agent-http", "openapi/agent.json", sha("b")),
	],
}

recorded(id, path, digest) := {
	"id": id,
	"format": "openapi",
	"compatibility": "gated",
	"files": [{"path": path, "sha256": digest}],
}

dependency := {"repository": "platform-api", "output": "contracts", "interfaces": ["public-http"], "version": "0.36.1"}

declared(deps) := td.file(".repo/dependencies.toml", {"schema_version": 1, "dependencies": deps})

vendored_files := {
	concat("/", [copy, "release.json"]): sha("f"),
	concat("/", [copy, "openapi/public.json"]): sha("a"),
}

inventory(files, digests) := td.file("/tmp/inventory.json", {"conventions_inventory": {
	"files": array.concat([".repo/dependencies.toml", ".repo/repository.toml"], files),
	"digests": digests,
}})

repo(deps, rec, digests) := [
	identity,
	inventory([path | some path, _ in digests], digests),
	declared(deps),
	td.file(concat("/", [copy, "release.json"]), rec),
]

test_conforming_dependency if {
	found := declaration.findings with input as repo([dependency], record, vendored_files)
		with data.conventions.index as td.index
	count(found) == 0
}

test_deps_01_undeclared_copy if {
	found := declaration.findings with input as [
		identity,
		inventory([concat("/", [copy, "release.json"])], {}),
		td.file(concat("/", [copy, "release.json"]), record),
	]
		with data.conventions.index as td.index
	td.pairs(found) == {["DEPS-01", copy]}
	messages(found, "DEPS-01") == {concat(" ", [
		`web/contracts/vendor/platform-api/contracts/ is a vendored copy of platform-api's "contracts", but`,
		".repo/dependencies.toml declares no such dependency; declare it with the release it is, or remove the copy",
	])}
}

test_deps_02_schema if {
	given := repo([object.union(dependency, {"path": "config/vendor/"})], record, vendored_files)
	found := declaration.findings with input as given
		with data.conventions.index as td.index
	messages(found, "DEPS-02") == {"`dependencies.0`: Additional property path is not allowed."}
}

test_deps_03_twice_and_self if {
	self := object.union(dependency, {"repository": "platform-web", "output": "site"})
	given := repo([dependency, object.union(dependency, {"version": "0.35.0"}), self], record, vendored_files)
	found := declaration.findings with input as given
		with data.conventions.index as td.index
	messages(found, "DEPS-03") == {
		`platform-api's "contracts" is declared more than once; declare each vendored output once, with one version`,
		concat(" ", [
			`the repository declares a dependency on itself ("site"); a repository reads its own`,
			"interfaces from its source, never from a release of itself",
		]),
	}
}

test_deps_04_not_a_release if {
	commit := {"version": "4b1c0e9"}
	given := repo([object.union(dependency, commit)], object.union(record, commit), vendored_files)
	found := declaration.findings with input as given
		with data.conventions.index as td.index
	messages(found, "DEPS-04") == {concat(" ", [
		`platform-api's "contracts" is pinned to "4b1c0e9", which is not an exact release; pin the version the`,
		"producer released, such as 1.4.0, never a commit, branch or range",
	])}
}

test_deps_04_package_ranges if {
	found := declaration.findings with input as [
		td.inventory(["web/package.json"]),
		td.file("web/package.json", {
			"dependencies": {"@musher-dev/ui": "^1.0.2", "@musher-dev/brand": "1.0.0", "left-pad": "^1.0.0"},
			"devDependencies": {"@musher-dev/tokens": "workspace:*"},
		}),
	]
		with data.conventions.index as td.index
	td.pairs(found) == {["DEPS-04", "web/package.json"]}
	messages(found, "DEPS-04") == {concat(" ", [
		`web/package.json pins @musher-dev/ui to "^1.0.2" in dependencies; pin the exact version it released,`,
		"so the repository builds against one release until it chooses another",
	])}
}

test_deps_05_no_copy if {
	found := declaration.findings with input as [identity, inventory([], {}), declared([dependency])]
		with data.conventions.index as td.index
	messages(found, "DEPS-05") == {concat(" ", [
		`platform-api's "contracts" at 0.36.1 has no vendored copy with a release record at`,
		"web/contracts/vendor/platform-api/contracts/release.json; vendor the release with `task deps:sync`",
	])}
}

test_deps_05_another_release if {
	given := repo([dependency], object.union(record, {"version": "0.35.0"}), vendored_files)
	found := declaration.findings with input as given
		with data.conventions.index as td.index
	td.pairs(found) == {["DEPS-05", concat("/", [copy, "release.json"])]}
	messages(found, "DEPS-05") == {concat(" ", [
		`the release record says version "0.35.0", but .repo/dependencies.toml declares "0.36.1"; vendor the`,
		"declared release with `task deps:sync`, or declare the one that is vendored",
	])}
}

test_deps_05_invalid_record if {
	given := repo([dependency], object.union(record, {"commit": "main"}), vendored_files)
	found := declaration.findings with input as given
		with data.conventions.index as td.index
	messages(found, "DEPS-05") == {concat(" ", [
		"`commit`: Does not match pattern '^[0-9a-f]{40}$'.",
		"Vendor the release again with `task deps:sync`.",
	])}
}

test_deps_06_unknown_interface if {
	given := repo([object.union(dependency, {"interfaces": ["public-http", "admin-http"]})], record, vendored_files)
	found := declaration.findings with input as given
		with data.conventions.index as td.index
	messages(found, "DEPS-06") == {
		`platform-api's "contracts" 0.36.1 delivers no interface "admin-http"; name one of "agent-http", "public-http"`,
	}
}

test_deps_06_edited_missing_and_extra_files if {
	digests := {
		concat("/", [copy, "release.json"]): sha("f"),
		concat("/", [copy, "openapi/public.json"]): sha("c"),
		concat("/", [copy, "notes.txt"]): sha("d"),
	}
	given := repo([object.union(dependency, {"interfaces": ["public-http", "agent-http"]})], record, digests)
	found := declaration.findings with input as given
		with data.conventions.index as td.index
	td.pairs(found) == {
		["DEPS-06", concat("/", [copy, "openapi/public.json"])],
		["DEPS-06", concat("/", [copy, "openapi/agent.json"])],
		["DEPS-06", concat("/", [copy, "notes.txt"])],
	}
}

test_deps_06_every_interface_when_none_named if {
	given := repo([object.remove(dependency, ["interfaces"])], record, vendored_files)
	found := declaration.findings with input as given
		with data.conventions.index as td.index
	td.pairs(found) == {["DEPS-06", concat("/", [copy, "openapi/agent.json"])]}
}

test_fetched_dependency_needs_no_copy if {
	fetched := object.union(dependency, {"fetched": true})
	found := declaration.findings with input as [identity, inventory([], {}), declared([fetched])]
		with data.conventions.index as td.index
	count(found) == 0
}

test_fetched_false_is_vendored if {
	vendored := object.union(dependency, {"fetched": false})
	found := declaration.findings with input as [identity, inventory([], {}), declared([vendored])]
		with data.conventions.index as td.index
	td.pairs(found) == {["DEPS-05", ".repo/dependencies.toml"]}
}

test_deps_01_fetched_with_a_copy if {
	given := repo([object.union(dependency, {"fetched": true})], object.union(record, {"version": "0.35.0"}), {
		concat("/", [copy, "release.json"]): sha("f"),
		concat("/", [copy, "openapi/public.json"]): sha("c"),
	})
	found := declaration.findings with input as given
		with data.conventions.index as td.index
	td.pairs(found) == {["DEPS-01", copy]}
	messages(found, "DEPS-01") == {concat(" ", [
		`web/contracts/vendor/platform-api/contracts/ is a vendored copy of platform-api's "contracts", but`,
		".repo/dependencies.toml declares it fetched, so no check proves the copy; remove the copy, or drop",
		"`fetched` so the release record proves it",
	])}
}

test_deps_07_pin_files if {
	given := [td.inventory(["config/platform-api.ref", "api/config/specifications.lock.json", "docs/x.ref"])]
	found := declaration.findings with input as given
		with data.conventions.index as td.index
	td.pairs(found) == {["DEPS-07", "config/platform-api.ref"], ["DEPS-07", "api/config/specifications.lock.json"]}
}
