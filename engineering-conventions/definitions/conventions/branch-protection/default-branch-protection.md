---
id: EC-0041
title: Default-branch protection
summary: >-
  An active branch ruleset committed under .github/rulesets/ covers the
  default branch: it forbids deleting the branch and force-pushing to it,
  requires a reviewed pull request, and requires a check that a validate
  workflow reports.
status: draft
topic: branch-protection
applies_to:
  paths:
    - .github/rulesets/*.json
    - .github/CODEOWNERS
    - .github/workflows/*.yml
    - .github/workflows/*.yaml
created: 2026-10-03
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "GitHub Docs: About rulesets"
    url: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets
  - title: "GitHub Docs: Available rules for rulesets"
    url: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
  - title: "OpenSSF Scorecard: Branch-Protection"
    url: https://github.com/ossf/scorecard/blob/main/docs/checks.md#branch-protection
requirements:
  - id: BRANCH-01
    title: An active branch ruleset committed under .github/rulesets/ covers the default branch
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.branch_protection.rulesets
  - id: BRANCH-02
    title: The default branch's rulesets block deletion and force pushes, and require a pull request and status checks
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.branch_protection.rulesets
  - id: BRANCH-03
    title: A pull request to the default branch needs an approval or a code owner's review
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.branch_protection.rulesets
  - id: BRANCH-04
    title: The default branch requires a check that a validate workflow reports
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.branch_protection.rulesets
---

# Default-branch protection

Every other gate in a repository, its validate workflow, its required checks, its code owners, guards the default
branch only if the branch requires them. Without a rule that says so, anyone who can push may commit to it directly,
rewrite its history, delete it, or merge a pull request whose checks never ran. A ruleset is that rule, and committed
under `.github/rulesets/` it is reviewed like any other change.

## Scope

This convention covers the branch rulesets a repository commits under `.github/rulesets/`, in the JSON shape GitHub's
API and its ruleset export use, and how they protect the default branch. It reads the committed files: applying them
to the repository, and checking that what is applied matches what is committed, is the work of whatever manages the
organization's settings. Which checks a ruleset names is [EC-0003](../github-actions/jobs-and-steps.md)'s (GHA-15,
GHA-16); the tag ruleset of a repository that releases is [EC-0025](../releases/release-tags.md)'s.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirements are `proposed` at severity
`warning`, like every requirement in the 0.x series. The reasons are in [decision
0031](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0031-the-default-branch-is-protected.md).

## How it fits together

```json
{
  "name": "Main Branch",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request",
      "parameters": { "required_approving_review_count": 1, "require_code_owner_review": true } },
    { "type": "required_status_checks",
      "parameters": { "required_status_checks": [{ "context": "Validate / Required" }] } }
  ]
}
```

The rules may be split across several rulesets; the checks read every active branch ruleset whose `ref_name` includes
the default branch (`~DEFAULT_BRANCH`, `~ALL`, or `refs/heads/main` or `master` by name) and does not exclude it.

## Requirements

### BRANCH-01

**An active branch ruleset committed under `.github/rulesets/` covers the default branch.**

A ruleset that is missing, disabled, or whose pattern misses the default branch protects nothing, and a ruleset
configured only in the repository's settings changes without review. The check reports a repository whose committed
rulesets include none with `target` `branch` (or no target), `enforcement` `active`, and a `ref_name` that includes
the default branch without excluding it.

**Correct:**

```json
{ "name": "Main Branch", "target": "branch", "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } }, "rules": [] }
```

**Incorrect:** no branch ruleset, or one with `"enforcement": "evaluate"` or `"disabled"`.

Checked by: conftest · Severity: warning · Since: 0.8.0

### BRANCH-02

**The default branch's rulesets block deletion and force pushes, and require a pull request and status checks.**

Each rule closes one way a change reaches the branch unchecked: `deletion` stops the branch being removed and
recreated, `non_fast_forward` stops its history being rewritten, `pull_request` stops a direct push, and
`required_status_checks` stops a merge before the checks pass. These are what OpenSSF Scorecard's Branch-Protection
check looks for. The check reports each rule that no ruleset covering the default branch has.

**Correct:**

```json
"rules": [{ "type": "deletion" }, { "type": "non_fast_forward" },
          { "type": "pull_request" }, { "type": "required_status_checks" }]
```

**Incorrect:**

```json
"rules": [{ "type": "pull_request" }]
```

Checked by: conftest · Severity: warning · Since: 0.8.0

### BRANCH-03

**A pull request to the default branch needs an approval or a code owner's review.**

A pull request that needs no review is a direct push with extra steps. The `pull_request` rule asks for at least one
approval (`required_approving_review_count` of 1 or more), or for a code owner's review
(`require_code_owner_review`) with a CODEOWNERS that GitHub reads. A code owner's review alone suits a repository
with one steward: GitHub waives it for a pull request its code owner opens, and asks the owner to review everyone
else's.

**Correct:**

```json
{ "type": "pull_request", "parameters": { "required_approving_review_count": 1 } }
```

```json
{ "type": "pull_request",
  "parameters": { "required_approving_review_count": 0, "require_code_owner_review": true } }
```

**Incorrect:**

```json
{ "type": "pull_request", "parameters": { "required_approving_review_count": 0 } }
```

Checked by: conftest · Severity: warning · Since: 0.8.0

### BRANCH-04

**The default branch requires a check that a validate workflow reports.**

Required status checks are only as good as what they name. A ruleset that requires a deploy preview, or a check no
workflow reports, lets a change merge without its validation. The check reports default-branch rulesets whose
required checks include none that a job of a validate workflow ([GHA-35](../github-actions/units-and-renames.md#gha-35))
reports; the aggregate, `Validate / Required`, is the one to require (GHA-16).

**Correct:**

```json
"required_status_checks": [{ "context": "Validate / Required" }]
```

**Incorrect:**

```json
"required_status_checks": [{ "context": "Preview" }]
```

Checked by: conftest · Severity: warning · Since: 0.8.0

## References

- [GitHub Docs: About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [OpenSSF Scorecard: Branch-Protection](https://github.com/ossf/scorecard/blob/main/docs/checks.md#branch-protection)
- [EC-0025 Release tags](../releases/release-tags.md)
