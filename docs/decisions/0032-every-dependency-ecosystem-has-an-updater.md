---
title: Every dependency ecosystem a repository pins has Renovate or Dependabot proposing its updates
date: 2026-10-03
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0032 — Every dependency ecosystem a repository pins has Renovate or Dependabot proposing its updates

## Context

The conventions pin everything: actions to a commit (GHA-24), base images to a tag or a digest (DEVC-04), tools to one
version (TOOL-03), packages through their lockfiles. A pin nothing moves turns into a stale dependency with known
vulnerabilities. Only the dev container's Features had to have an updater (DEVC-09), and REPO-20 and REPO-22 checked
where a Dependabot update looks without asking whether one exists. A repository could pin every action to a SHA and
never hear of a new release.

## Decision

**Something proposes every update: Renovate, or a Dependabot update for each ecosystem the repository pins.**

[EC-0042](../../engineering-conventions/definitions/conventions/dependencies/automated-updates.md), DEPS-11 to DEPS-13,
in the existing `dependencies` topic:

- DEPS-11: the actions of the workflows, and of each composite action under `.github/actions/`, which Dependabot
  scans only when named.
- DEPS-12: the base images of the Dockerfiles in every directory that holds one, `.devcontainer/` included.
- DEPS-13: the product's manifest, in the product directory.

A Renovate configuration satisfies all three, because Renovate's managers find each of these by themselves. The tools
in `.config/mise/config.toml` have no Dependabot ecosystem; the convention says so, and requires nothing for them.

The Dependabot and Renovate readers that REPO-20, REPO-22 and DEVC-09 used move to `lib/updates.rego`, unchanged, so
all of them read the configuration the same way.

## Consequences

### Positive

- Every pin a convention asks for has something moving it, as OpenSSF Scorecard's Dependency-Update-Tool check
  expects.
- A composite action's pins, which Dependabot silently skips from the root, are named.

### Negative

- A repository on Dependabot lists its Dockerfile directories and composite actions, and keeps the list current.

### Neutral

- Schedules, grouping and cooldowns stay the repository's.

## Enforcement

- DEPS-11 to DEPS-13 in `checks/rego/dependencies/updates.rego`, with fixtures `deps-11-*` to `deps-13-*`, each with a
  near-miss.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Require Renovate | One updater for everything, mise included | rejected: Dependabot is built in and already configured in most repositories |
| Only require that an updater exists | Any Dependabot file passes | rejected: a file that updates one ecosystem leaves the others pinned forever |
| Each pinned ecosystem has an updater | This decision | **chosen** |

## References

- [GitHub Docs: Dependabot options reference](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference)
- [OpenSSF Scorecard: Dependency-Update-Tool](https://github.com/ossf/scorecard/blob/main/docs/checks.md#dependency-update-tool)
