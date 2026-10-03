# Branch protection

These conventions govern the rulesets a repository commits under `.github/rulesets/` to protect its default branch.

The governing rule, in one sentence:

> **Commit an active ruleset that keeps the default branch from being deleted or rewritten and lets a change in only
> through a reviewed pull request whose validation passed.**

## Status

The convention is a **draft**, owned by this repository, and every requirement is `proposed` at severity `warning`.

## Who is checked

`base-repo` selects the family, so every repository is checked.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0041 Default-branch protection](default-branch-protection.md) | BRANCH-01 – BRANCH-04 | The ruleset, its rules, the review it requires and the check it requires |

## Quick reference

| Rule in the ruleset | Requirement |
| --- | --- |
| `target: branch`, `enforcement: active`, `ref_name.include: ["~DEFAULT_BRANCH"]` | BRANCH-01 |
| `deletion`, `non_fast_forward`, `pull_request`, `required_status_checks` | BRANCH-02 |
| `required_approving_review_count` ≥ 1, or `require_code_owner_review` with a CODEOWNERS | BRANCH-03 |
| `required_status_checks` names the validate workflow's aggregate | BRANCH-04 |
