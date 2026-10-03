package conventions.checks.branch_protection.rulesets_test

import data.conventions.checks.branch_protection.rulesets
import data.conventions.lib.testdata_test as td

path := ".github/rulesets/main-branch.json"

pull_request := {"type": "pull_request", "parameters": {
	"required_approving_review_count": 0,
	"require_code_owner_review": true,
}}

checks(contexts) := {"type": "required_status_checks", "parameters": {
	"required_status_checks": [{"context": context} | some context in contexts],
}}

ruleset(rules) := {
	"name": "Main Branch",
	"target": "branch",
	"enforcement": "active",
	"conditions": {"ref_name": {"include": ["~DEFAULT_BRANCH"], "exclude": []}},
	"rules": rules,
}

full := ruleset([{"type": "deletion"}, {"type": "non_fast_forward"}, pull_request, checks(["Validate / Required"])])

validate := td.file(".github/workflows/validate.yml", {
	"name": "Validate",
	"on": {"pull_request": {}},
	"jobs": {"required": {"name": "Validate / Required", "runs-on": "ubuntu-24.04", "steps": [{"run": "true"}]}},
})

listed := [path, ".github/workflows/validate.yml", ".github/CODEOWNERS"]

repo(document, paths) := [td.file(path, document), validate, td.inventory(paths)]

test_conforming if {
	count(rulesets.findings) == 0 with input as repo(full, listed)
}

test_branch_01_no_ruleset if {
	found := rulesets.findings with input as [validate, td.inventory([".github/workflows/validate.yml"])]
	td.pairs(found) == {["BRANCH-01", path]}
}

test_branch_01_disabled_or_excluded if {
	disabled := object.union(full, {"enforcement": "disabled"})
	found := rulesets.findings with input as repo(disabled, listed)
	td.pairs(found) == {["BRANCH-01", path]}
	excluded := object.union(full, {"conditions": {"ref_name": {"include": ["~ALL"], "exclude": ["~DEFAULT_BRANCH"]}}})
	td.pairs(rulesets.findings) == {["BRANCH-01", path]} with input as repo(excluded, listed)
}

test_branch_01_tag_ruleset_does_not_count if {
	tags := object.union(full, {"target": "tag"})
	td.pairs(rulesets.findings) == {["BRANCH-01", path]} with input as repo(tags, listed)
}

test_branch_01_all_and_named_branch if {
	every include in ["~ALL", "refs/heads/main"] {
		document := object.union(full, {"conditions": {"ref_name": {"include": [include]}}})
		count(rulesets.findings) == 0 with input as repo(document, listed)
	}
}

test_branch_02_missing_rules if {
	document := ruleset([pull_request, checks(["Validate / Required"])])
	found := rulesets.findings with input as repo(document, listed)
	td.pairs(found) == {["BRANCH-02", path]}
	concat(" ", [
		"the rulesets covering the default branch have no deletion, non_fast_forward rule; add",
		"deletion, non_fast_forward, so the branch is never deleted or rewritten and every change",
		"reaches it through a checked pull request",
	]) in {f.message | some f in found}
}

test_branch_02_rules_across_rulesets if {
	second := ".github/rulesets/history.json"
	history := ruleset([{"type": "deletion"}, {"type": "non_fast_forward"}])
	reviews := ruleset([pull_request, checks(["Validate / Required"])])
	docs := [
		td.file(path, reviews), td.file(second, history), validate,
		td.inventory(array.concat(listed, [second])),
	]
	count(rulesets.findings) == 0 with input as docs
}

test_branch_03_no_review if {
	unreviewed := {"type": "pull_request", "parameters": {"required_approving_review_count": 0}}
	document := ruleset([{"type": "deletion"}, {"type": "non_fast_forward"}, unreviewed, checks(["Validate / Required"])])
	found := rulesets.findings with input as repo(document, listed)
	td.pairs(found) == {["BRANCH-03", path]}
}

test_branch_03_code_owner_review_needs_codeowners if {
	found := rulesets.findings with input as repo(full, [path, ".github/workflows/validate.yml"])
	td.pairs(found) == {["BRANCH-03", path]}
}

test_branch_03_one_approval if {
	approved := {"type": "pull_request", "parameters": {"required_approving_review_count": 1}}
	document := ruleset([{"type": "deletion"}, {"type": "non_fast_forward"}, approved, checks(["Validate / Required"])])
	count(rulesets.findings) == 0 with input as repo(document, [path, ".github/workflows/validate.yml"])
}

test_branch_04_validate_not_required if {
	document := ruleset([{"type": "deletion"}, {"type": "non_fast_forward"}, pull_request, checks(["Build"])])
	found := rulesets.findings with input as repo(document, listed)
	td.pairs(found) == {["BRANCH-04", path]}
}
