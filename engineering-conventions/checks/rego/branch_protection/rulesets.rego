# METADATA
# title: Default-branch protection
# description: >-
#   An active branch ruleset committed under .github/rulesets/ covers the
#   default branch (BRANCH-01), forbids deleting it and force-pushing to it,
#   and requires a pull request and status checks (BRANCH-02); the pull
#   request needs a review (BRANCH-03), and a validate workflow's check is
#   required (BRANCH-04).
# scope: package
# custom:
#   convention: EC-0041
package conventions.checks.branch_protection.rulesets

import data.conventions.lib.contexts
import data.conventions.lib.filenames
import data.conventions.lib.files
import data.conventions.lib.findings as lib

ruleset_path := ".github/rulesets/main-branch.json"

# The rules that keep the default branch's history and require review and
# checks before anything reaches it.
required_rules := ["deletion", "non_fast_forward", "pull_request", "required_status_checks"]

# BRANCH-01
findings contains lib.finding("BRANCH-01", ruleset_path, uncovered_message) if count(protecting) == 0

# BRANCH-02
findings contains lib.finding("BRANCH-02", first_path, message) if {
	missing := [rule | some rule in required_rules; not rule in protected_rule_types]
	count(missing) > 0
	message := sprintf(
		concat(" ", [
			"the rulesets covering the default branch have no %s rule; add %s, so the branch is",
			"never deleted or rewritten and every change reaches it through a checked pull request",
		]),
		[concat(", ", missing), concat(", ", missing)],
	)
}

# BRANCH-03
findings contains lib.finding("BRANCH-03", first_path, unreviewed_message) if {
	count(pull_request_rules) > 0
	not reviewed
}

# BRANCH-04
findings contains lib.finding("BRANCH-04", first_path, unvalidated_message) if {
	count(required_contexts) > 0
	not validate_required
}

# The active branch rulesets that cover the default branch, by path. A
# ruleset without a target is a branch ruleset.
protecting[path] := ruleset if {
	some path, ruleset in files.rulesets
	object.get(ruleset, "target", "branch") == "branch"
	ruleset.enforcement == "active"
	includes_default(ruleset)
	not excludes_default(ruleset)
}

default_patterns := {"~DEFAULT_BRANCH", "~ALL", "refs/heads/main", "refs/heads/master"}

includes_default(ruleset) if {
	some pattern in files.as_list(ruleset.conditions.ref_name.include)
	pattern in default_patterns
}

excludes_default(ruleset) if {
	some pattern in files.as_list(ruleset.conditions.ref_name.exclude)
	pattern in default_patterns
}

first_path := sort(object.keys(protecting))[0]

protected_rules contains rule if {
	some ruleset in protecting
	some rule in files.as_list(ruleset.rules)
	is_object(rule)
}

protected_rule_types contains rule.type if {
	some rule in protected_rules
	is_string(rule.type)
}

pull_request_rules contains rule if {
	some rule in protected_rules
	rule.type == "pull_request"
}

# A review: at least one approval, or a code owner's, which needs a
# CODEOWNERS for GitHub to read.
reviewed if {
	some rule in pull_request_rules
	rule.parameters.required_approving_review_count >= 1
}

reviewed if {
	some rule in pull_request_rules
	rule.parameters.require_code_owner_review == true
	some path in [".github/CODEOWNERS", "CODEOWNERS", "docs/CODEOWNERS"]
	path in files.repository_files
}

required_contexts contains check.context if {
	some rule in protected_rules
	rule.type == "required_status_checks"
	some check in files.as_list(rule.parameters.required_status_checks)
	is_string(check.context)
}

# A required context a job of a validate workflow reports.
validate_required if {
	some entry in contexts.emitted
	entry.context in required_contexts
	validate_workflow(entry.workflow)
}

validate_required if {
	some entry in contexts.patterned
	some context in required_contexts
	regex.match(entry.pattern, context)
	validate_workflow(entry.workflow)
}

validate_workflow(path) if filenames.slot(lower(files.stem(path))) == "validate"

uncovered_message := concat(" ", [
	"no active branch ruleset in .github/rulesets/ covers the default branch, so anyone who can push may",
	"delete it, force-push to it, or merge without review or checks; add one whose ref_name includes",
	"~DEFAULT_BRANCH",
])

unreviewed_message := concat(" ", [
	"the pull_request rule requires no review: set required_approving_review_count to 1 or more, or",
	"set require_code_owner_review and keep a CODEOWNERS that names an owner for every path",
])

unvalidated_message := concat(" ", [
	"the default branch requires no check a validate workflow reports, so a change can merge without",
	"its validation; require the validate workflow's aggregate, such as \"Validate / Required\"",
])
