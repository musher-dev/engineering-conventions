---
title: The default branch is protected by a committed ruleset with a review gate, and every repository has a CODEOWNERS
date: 2026-10-03
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0031 — The default branch is protected by a committed ruleset with a review gate, and every repository has a CODEOWNERS

## Context

The GitHub Actions conventions make a validate workflow's aggregate the one required check (GHA-14 to GHA-16), and
the release conventions protect release tags with a committed ruleset (REL-12, REL-13). Nothing required the default
branch itself to be protected. A repository could commit a perfect `Validate / Required` and still let anyone push to
`main`, rewrite it, or merge without the check, because the gate that makes the check required was never asked for.
Some repositories commit their branch ruleset under `.github/rulesets/` (this one, `host-agent`, `host-config`); others
rely on whatever was set by hand.

CODEOWNERS was optional (COMM-03 applies only where one exists), so a ruleset that requires a code owner's review had
nothing to read in a repository without one.

## Decision

**Every repository commits an active ruleset that protects its default branch, and keeps a CODEOWNERS.**

- [EC-0041](../../engineering-conventions/definitions/conventions/branch-protection/default-branch-protection.md),
  BRANCH-01 to BRANCH-04, in a new family `BRANCH` and topic `branch-protection`: an active branch ruleset under
  `.github/rulesets/` covers the default branch; together the rulesets forbid deletion and force pushes and require a
  pull request and status checks; the pull request needs at least one approval or a code owner's review backed by a
  CODEOWNERS; and a validate workflow's check is required.
- COMM-08 in [EC-0036](../../engineering-conventions/definitions/conventions/community-files/community-files.md): every
  repository has a CODEOWNERS.
- A code owner's review is enough on its own, so a repository with one steward, whose own pull requests GitHub exempts
  from code-owner review, passes without a second reviewer. This repository does.

The checks read the committed rulesets. Applying them to the repository stays with whatever manages the
organization's settings.

## Consequences

### Positive

- The required check the GitHub Actions conventions build is required in fact, and a reviewer sees the ruleset that
  requires it.
- The rules OpenSSF Scorecard's Branch-Protection check looks for are written down in every repository.

### Negative

- A repository whose protection is set only in the GitHub settings, or by an organization ruleset, gets findings until
  it commits the ruleset or records a waiver.
- A committed ruleset can drift from the one applied; nothing here compares them.

### Neutral

- Which checks are required, beyond one of the validate workflow's, stays the repository's choice, held to GHA-15 and
  GHA-16.

## Enforcement

- BRANCH-01 to BRANCH-04 in `checks/rego/branch_protection/rulesets.rego`, with fixtures `branch-01-*` to
  `branch-04-*`, each with a near-miss.
- COMM-08 in `checks/rego/community_files/community_files.rego`, with its fixture.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Require one approval always | The strictest review gate | rejected: a repository with one steward cannot merge its own work; a code owner's review covers it |
| Check the live settings through the API | What GitHub enforces, not what is committed | rejected for now: the checks run offline and need no token; the committed file is what a reviewer sees |
| A committed ruleset with a review gate | This decision | **chosen** |

## References

- [GitHub Docs: About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [OpenSSF Scorecard: Branch-Protection](https://github.com/ossf/scorecard/blob/main/docs/checks.md#branch-protection)
