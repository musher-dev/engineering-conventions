package conventions.checks.github_actions.composite_actions_test

import data.conventions.checks.github_actions.composite_actions
import data.conventions.lib.testdata_test as td

messages(found, id) := {f.message | some f in found; f.id == id}

good := {
	"name": "Setup Tools",
	"description": "Install the pinned tools.",
	"inputs": {"version": {"description": "Which release."}},
	"runs": {"using": "composite", "steps": []},
}

test_conforming_action_has_no_findings if {
	path := ".github/actions/setup-tools/action.yml"
	docs := [td.file(path, good), td.inventory([path, ".github/actions/README.md"])]
	count(composite_actions.findings) == 0 with input as docs with data.conventions.index as td.index
}

test_gha_20_directory_grammar if {
	paths := [
		".github/actions/registry-auth/action.yml",
		".github/actions/setup/action.yml",
		".github/actions/Setup_Node/action.yml",
		".github/actions/auth-registry/action.yml",
		".github/actions/verify-signature/action.yml",
		".github/actions/Install_Tools/action.yml",
	]
	found := composite_actions.findings with input as [td.inventory(paths)] with data.conventions.index as td.index
	suggestions := {regex.find_n(`e\.g\. "[^"]+"$`, m, 1)[0] | some m in messages(found, "GHA-20")}
	suggestions == {`e.g. "setup-node"`, `e.g. "authenticate-registry"`, `e.g. "check-signature"`, `e.g. "install-tools"`}
	count(messages(found, "GHA-20")) == 6
	concat(" ", [
		`action directory "registry-auth" is not <action-token>-<object> in lowercase kebab-case; start it with`,
		`one of "authenticate", "check", "install", "setup" followed by what it acts on`,
	]) in messages(found, "GHA-20")
}

test_gha_22_waits_for_the_directory if {
	path := ".github/actions/registry-auth/action.yml"
	docs := [td.file(path, object.union(good, {"name": "Registry Login"})), td.inventory([path])]
	found := composite_actions.findings with input as docs with data.conventions.index as td.index
	td.ids(found) == {"GHA-20"}
}

test_gha_21_metadata_location if {
	paths := [
		".github/actions/setup-node/action.yaml",
		".github/actions/setup-group/setup-go/action.yml",
		".github/actions/setup-empty/README.md",
		".github/actions/setup-ok/action.yml",
	]
	found := composite_actions.findings with input as [td.inventory(paths)] with data.conventions.index as td.index
	td.pairs(found) == {
		["GHA-21", ".github/actions/setup-node/action.yaml"],
		["GHA-21", ".github/actions/setup-group/setup-go/action.yml"],
		["GHA-21", ".github/actions/setup-empty"],
	}
	some message in messages(found, "GHA-21")
	contains(message, `move the action to ".github/actions/setup-go/action.yml"`)
}

test_gha_22_name_is_title_cased_directory if {
	path := ".github/actions/authenticate-registry/action.yml"
	misnamed := [td.file(path, object.union(good, {"name": "Registry Auth"})), td.inventory([path])]
	unnamed := [td.file(path, object.remove(good, ["name"])), td.inventory([path])]
	rule := "an action's name is its directory name in Title Case"
	found := composite_actions.findings with input as misnamed with data.conventions.index as td.index
	messages(found, "GHA-22") == {sprintf(`name "Registry Auth" should be "Authenticate Registry": %s`, [rule])}
	missing := composite_actions.findings with input as unnamed with data.conventions.index as td.index
	messages(missing, "GHA-22") == {sprintf(`name "" should be "Authenticate Registry": %s`, [rule])}
}

test_gha_23_descriptions if {
	path := ".github/actions/setup-tools/action.yml"
	action := {"name": "Setup Tools", "inputs": {"version": {"required": true}, "token": {"description": "A token."}}}
	docs := [td.file(path, action), td.inventory([path])]
	found := composite_actions.findings with input as docs with data.conventions.index as td.index
	messages(found, "GHA-23") == {
		"the action has no description; add description: saying what capability it provides",
		`input "version" has no description; add description: saying what the caller passes`,
	}
}

test_gha_38_kebab_case_inputs_and_outputs if {
	action := object.union(good, {
		"inputs": {"tool-version": {"description": "x"}, "toolVersion": {"description": "x"}},
		"outputs": {"cache_hit": {"description": "x", "value": "y"}},
	})
	callable := {"on": {"workflow_call": {
		"inputs": {"service-slug": {"type": "string"}, "SERVICE": {"type": "string"}},
		"outputs": {"commit_sha": {"value": "x"}},
		"secrets": {"app_key": {"required": true}},
	}}}
	path := ".github/actions/setup-tools/action.yml"
	docs := [
		td.file(path, action),
		td.file(".github/workflows/reusable-build.yml", callable),
		td.file(".github/workflows/validate.yml", {"on": {"workflow_call": null}}),
		td.inventory([path]),
	]
	found := composite_actions.findings with input as docs with data.conventions.index as td.index
	messages(found, "GHA-38") == {
		`input "toolVersion" is not kebab-case; rename it to "tool-version" and update every inputs.toolVersion reference`,
		`output "cache_hit" is not kebab-case; rename it to "cache-hit" and update every outputs.cache_hit reference`,
		`input "SERVICE" is not kebab-case; rename it to "service" and update every inputs.SERVICE reference`,
		`output "commit_sha" is not kebab-case; rename it to "commit-sha" and update every outputs.commit_sha reference`,
		concat(" ", [
			`secret "app_key" is not kebab-case; declare it as "app-key" under on.workflow_call.secrets, read`,
			"secrets.app-key, and have each caller pass app-key: ${{ secrets.app_key }} instead of secrets: inherit",
			"(the repository secret keeps its name, since GitHub allows no - in one)",
		]),
	}
}

test_gha_38_secret_of_a_workflow_that_also_runs_on_its_own if {
	both := {"on": {"push": null, "workflow_call": {"secrets": {"CF_TOKEN": {"required": true}}}}}
	docs := [td.file(".github/workflows/deploy-production.yml", both)]
	found := composite_actions.findings with input as docs with data.conventions.index as td.index
	messages(found, "GHA-38") == {concat(" ", [
		`secret "CF_TOKEN" is not kebab-case, but this workflow also runs on its own, where it reads the repository`,
		"secret by that name and GitHub allows no - in one; split the callable part into a reusable workflow",
		`that declares "cf-token" (EC-0006), or waive GHA-38 for this file`,
	])}
}
