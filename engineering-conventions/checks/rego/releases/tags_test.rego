package conventions.checks.releases.tags_test

import data.conventions.checks.releases.tags as checks
import data.conventions.lib.testdata_test as td

config(contents) := td.file(".github/release-please/config.json", contents)

ruleset(name, contents) := td.file(concat("", [".github/rulesets/", name]), contents)

all_rules := [{"type": "creation"}, {"type": "update"}, {"type": "deletion"}, {"type": "non_fast_forward"}]

release_app := {"actor_id": 1, "actor_type": "Integration", "bypass_mode": "always"}

tag_ruleset(include) := {
	"target": "tag",
	"enforcement": "active",
	"bypass_actors": [release_app],
	"conditions": {"ref_name": {"include": include, "exclude": []}},
	"rules": all_rules,
}

single := config({"packages": {".": {}}})

several := config({"packages": {"a": {"component": "blueprint"}, "b": {"component": "listing"}}})

messages(results, id) := {f.message | some f in results; f.id == id}

test_protected_tags_have_no_findings if {
	flat := [single, ruleset("tags.json", tag_ruleset(["refs/tags/v*"]))]
	results_flat := checks.findings with input as flat with data.conventions.index as td.index
	count(results_flat) == 0
	nested := [several, ruleset("tags.json", tag_ruleset(["refs/tags/*/v*"]))]
	results_nested := checks.findings with input as nested with data.conventions.index as td.index
	count(results_nested) == 0
	everything := [several, ruleset("tags.json", tag_ruleset(["~ALL"]))]
	results_everything := checks.findings with input as everything with data.conventions.index as td.index
	count(results_everything) == 0
	named := [several, ruleset("tags.json", tag_ruleset(["refs/tags/blueprint/**", "refs/tags/listing/**"]))]
	results_named := checks.findings with input as named with data.conventions.index as td.index
	count(results_named) == 0
}

test_no_release_please_has_no_findings if {
	results := checks.findings with input as [td.inventory(["README.md"])] with data.conventions.index as td.index
	count(results) == 0
}

test_rel_12_uncovered_tags if {
	results := checks.findings with input as [single] with data.conventions.index as td.index
	messages(results, "REL-12") == {concat(" ", [
		"no active tag ruleset in .github/rulesets/ covers refs/tags/v1.0.0, so anyone who can push may",
		"create, move or delete it; add one with target \"tag\" whose ref_name includes refs/tags/v*",
	])}
	disabled := object.union(tag_ruleset(["refs/tags/v*"]), {"enforcement": "disabled"})
	results_disabled := checks.findings with input as [single, ruleset("t.json", disabled)]
		with data.conventions.index as td.index
	count(messages(results_disabled, "REL-12")) == 1
	branch := object.union(tag_ruleset(["refs/tags/v*"]), {"target": "branch"})
	results_branch := checks.findings with input as [single, ruleset("t.json", branch)]
		with data.conventions.index as td.index
	count(messages(results_branch, "REL-12")) == 1
	results_flat := checks.findings with input as [several, ruleset("t.json", tag_ruleset(["refs/tags/v*"]))]
		with data.conventions.index as td.index
	count(messages(results_flat, "REL-12")) == 2
	excluding := object.union(tag_ruleset(["refs/tags/*/v*"]), {"conditions": {"ref_name": {
		"include": ["refs/tags/*/v*"],
		"exclude": ["refs/tags/listing/*"],
	}}})
	results_excluding := checks.findings with input as [several, ruleset("t.json", excluding)]
		with data.conventions.index as td.index
	count(messages(results_excluding, "REL-12")) == 1
}

test_rel_13_rules_and_bypass if {
	weak := object.union(tag_ruleset(["refs/tags/v*"]), {
		"rules": [{"type": "deletion"}, {"type": "non_fast_forward"}, {"type": "update"}],
		"bypass_actors": [release_app, {"actor_id": 1, "actor_type": "OrganizationAdmin", "bypass_mode": "always"}],
	})
	results := checks.findings with input as [single, ruleset("tags.json", weak)] with data.conventions.index as td.index
	{[f.path, f.message] | some f in results; f.id == "REL-13"} == {
		[".github/rulesets/tags.json", concat(" ", [
			"the tag ruleset protecting release tags has no creation rule; add creation so a release tag can",
			"be neither created by hand nor moved or deleted after it is cut",
		])],
		[".github/rulesets/tags.json", concat(" ", [
			"the tag ruleset protecting release tags lets a OrganizationAdmin bypass it; only the release App",
			"(actor_type \"Integration\") may create a release tag",
		])],
	}
	unrelated := object.union(weak, {"conditions": {"ref_name": {"include": ["refs/tags/other-*"]}}})
	docs := [single, ruleset("tags.json", tag_ruleset(["refs/tags/v*"])), ruleset("other.json", unrelated)]
	results_unrelated := checks.findings with input as docs with data.conventions.index as td.index
	count(messages(results_unrelated, "REL-13")) == 0
}
