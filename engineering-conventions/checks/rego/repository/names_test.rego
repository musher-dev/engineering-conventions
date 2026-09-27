package conventions.checks.repository.names_test

import data.conventions.checks.repository.names
import data.conventions.lib.testdata_test as td

messages(found, id) := {f.message | some f in found; f.id == id}

# A declaration whose name is <system>-<component>, so REPO-04 stays quiet.
declared(system, component) := td.repository(object.union(td.identity, {
	"name": concat("-", [system, component]),
	"system": system,
	"component": component,
}))

platform_api := declared("platform", "api")

test_conforming_name if {
	count(names.findings) == 0 with input as [platform_api] with data.conventions.index as td.index
	count(names.findings) == 0 with input as [platform_api, td.named_inventory([], "platform-api")]
		with data.conventions.index as td.index
}

test_repo_07_declared_name_is_the_actual_name if {
	found := names.findings with input as [platform_api, td.named_inventory([], "platform-web")]
		with data.conventions.index as td.index
	td.pairs(found) == {["REPO-07", ".repo/repository.toml"]}
	messages(found, "REPO-07") == {concat(" ", [
		`the declaration names the repository "platform-api", but it is "platform-web"; set name to`,
		`"platform-web", with system and component to match, or rename the repository and its`,
		"declaration together",
	])}
}

test_repo_07_needs_the_actual_name if {
	count(names.findings) == 0 with input as [platform_api, td.inventory([])] with data.conventions.index as td.index
}

test_repo_08_grammar if {
	found := names.findings with input as [declared("platform", "API")]
		with data.conventions.index as td.index
	td.pairs(found) == {["REPO-08", ".repo/repository.toml"]}
	messages(found, "REPO-08") == {concat("", [
		`repository name "platform-API" is not lowercase kebab-case; `,
		`rename it to "platform-api"`,
	])}
}

test_repo_08_missing_component if {
	found := names.findings with input as [td.named_inventory([], "platform"), platform_api]
		with data.conventions.index as td.index
	messages(found, "REPO-08") == {concat(" ", [
		`repository name "platform" is not <system>-<component>: a registered system, a hyphen`,
		"and a component, in lowercase letters, digits and hyphens",
	])}
}

test_repo_08_too_long if {
	component := concat("", ["a" | some _ in numbers.range(1, 60)])
	found := names.findings with input as [declared("platform", component)]
		with data.conventions.index as td.index
	td.ids(found) == {"REPO-08"}
	messages(found, "REPO-08") == {sprintf(
		"repository name %q is 69 characters, more than 63; shorten the component",
		[concat("-", ["platform", component])],
	)}
}

test_repo_09_registered_system if {
	found := names.findings with input as [platform_api, td.named_inventory([], "widgets-api")]
		with data.conventions.index as td.index
	td.ids(found) == {"REPO-07", "REPO-09"}
	messages(found, "REPO-09") == {concat("", [
		`repository name "widgets-api" starts with "widgets", which is not a registered system; `,
		`start it with one of "engineering", "platform", "sdk"`,
	])}
}

test_repo_09_leaves_an_unregistered_declared_system_to_repo_03 if {
	count(names.findings) == 0 with input as [declared("widgets", "api")] with data.conventions.index as td.index
}

test_repo_10_banned_token_and_version if {
	found := names.findings with input as [declared("platform", "utils-v2")]
		with data.conventions.index as td.index
	messages(found, "REPO-10") == {
		concat(" ", [
			`repository name "platform-utils-v2" holds the token "utils".`,
			"Says nothing about what it holds; name what it holds.",
		]),
		concat(" ", [
			`repository name "platform-utils-v2" holds the token "v2". Names a version, which changes while`,
			"the name must not; drop the token and version what the repository publishes instead.",
		]),
	}
}

test_repo_10_banned_first_token_is_not_also_repo_09 if {
	found := names.findings with input as [platform_api, td.named_inventory([], "musher-cli")]
		with data.conventions.index as td.index
	td.ids(found) == {"REPO-07", "REPO-10"}
}

test_repo_11_short_name if {
	found := names.findings with input as [declared("platform", "organization-membership-reconciler")]
		with data.conventions.index as td.index
	td.pairs(found) == {["REPO-11", ".repo/repository.toml"]}
	messages(found, "REPO-11") == {concat(" ", [
		`repository name "platform-organization-membership-reconciler" is 43 characters, more than 40;`,
		"shorten the component so the name stays readable in paths, image names and URLs",
	])}
}

test_reserved_names_are_exempt if {
	count(names.findings) == 0 with input as [platform_api, td.named_inventory([], ".github")]
		with data.conventions.index as td.index
	count(names.findings) == 0 with input as [platform_api, td.named_inventory([], ".github-private")]
		with data.conventions.index as td.index
}

test_nothing_to_judge_without_a_name if {
	count(names.findings) == 0 with input as [td.inventory([])] with data.conventions.index as td.index
}
