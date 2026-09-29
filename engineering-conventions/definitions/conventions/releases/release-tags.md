---
id: EC-0025
title: Release tags
summary: >-
  An active tag ruleset committed under .github/rulesets/ covers every tag
  release-please creates, blocks creating, moving and deleting them, and lets
  only the release App bypass it; and published releases are immutable.
status: draft
topic: releases
applies_to:
  paths:
    - .github/rulesets/*.json
    - .github/release-please/config.json
created: 2026-09-29
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "GitHub Docs: About rulesets"
    url: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets
  - title: "GitHub Docs: Creating rulesets for a repository (fnmatch syntax)"
    url: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository
  - title: "GitHub Docs: Immutable releases"
    url: https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/immutable-releases
requirements:
  - id: REL-12
    title: An active tag ruleset covers every release tag
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.releases.tags
  - id: REL-13
    title: The ruleset blocks creating, moving and deleting a release tag, and only an App may bypass it
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.releases.tags
  - id: REL-14
    title: Published releases are immutable
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: review
---

# Release tags

A consumer pins a tag and verifies what it downloads. Both are worth something only if the tag cannot move and the
bytes cannot change: a tag someone re-pointed, or an asset someone replaced, turns every verification made before it
into a false statement. These requirements make a release tag something only the release process creates, and a
published release something nobody changes.

## Scope

This convention governs the rulesets committed under `.github/rulesets/` of a repository that has a release-please
config ([EC-0024](release-configuration.md)), and the repository's immutable-releases setting. A ruleset takes effect
when it is applied to the repository; the committed JSON is what reviewers read and what these checks read.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`), and every requirement is `proposed` at
severity `warning`. [Decision 0017](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0017-releases-from-drafts.md)
records the choices.

## Requirements

### REL-12

**An active tag ruleset covers every release tag.**

Without a tag ruleset, anyone who can push to the repository can create `v1.4.3` by hand, or delete and recreate
`v1.4.2` on another commit. A ruleset that exists but is disabled, or whose pattern misses the tags release-please
makes, protects nothing. The check takes each tag the release-please config creates, `refs/tags/v1.0.0` for a single
package and `refs/tags/<component>/v1.0.0` for each of several, and reports it when no ruleset with `target` `tag` and
`enforcement` `active` includes it (GitHub's fnmatch patterns: `*` stops at a slash, `**` does not, `~ALL` matches
everything) without also excluding it.

**Correct:**

```json
{ "name": "Release Tags", "target": "tag", "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/tags/v*"], "exclude": [] } } }
```

**Incorrect:** no tag ruleset, or one with `"enforcement": "disabled"`, or, for component tags, `"include":
["refs/tags/v*"]`.

Checked by: conftest · Severity: warning · Since: 0.6.2

### REL-13

**The ruleset blocks creating, moving and deleting a release tag, and only an App may bypass it.**

Each rule closes one way a tag changes under a consumer: `creation` stops a person pushing a release tag by hand,
`update` and `non_fast_forward` stop one being moved, and `deletion` stops one being removed and reused. The release
App creates tags, so it is the ruleset's one bypass actor; an organization admin, a repository role or a deploy key
that may bypass it can also move a tag, and none of them goes through a release pull request. The check reports each
of the four rules missing from a tag ruleset that covers a release tag, and each bypass actor whose `actor_type` is not
`Integration`.

**Correct:**

```json
{ "bypass_actors": [{ "actor_id": 1234567, "actor_type": "Integration", "bypass_mode": "always" }],
  "rules": [{ "type": "creation" }, { "type": "update" }, { "type": "deletion" }, { "type": "non_fast_forward" }] }
```

**Incorrect:**

```json
{ "bypass_actors": [{ "actor_id": 1, "actor_type": "OrganizationAdmin", "bypass_mode": "always" }],
  "rules": [{ "type": "deletion" }] }
```

Checked by: conftest · Severity: warning · Since: 0.6.2

### REL-14

**Published releases are immutable.**

GitHub's immutable releases lock a release when it is published: its tag cannot move, its assets cannot be added,
replaced or deleted, and GitHub attests the release. A consumer who verified a release once can trust it later. Turn
it on for the organization, or for the repository, before the first release made with a draft
([REL-07](release-configuration.md#rel-07)). The setting is in no file, so the release workflow proves it: after
publishing, it reads the release back and fails unless `immutable` is `true`. A reviewer looks for that step.

**Correct:**

```yaml
- name: Check the published release is immutable
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    immutable="$(gh api "repos/$GITHUB_REPOSITORY/releases/tags/$TAG" --jq .immutable)"
    [[ "$immutable" == "true" ]] || { echo "::error::release $TAG is not immutable"; exit 1; }
```

**Incorrect:** a release workflow that publishes and stops there, in a repository where the setting is off.

Checked by: review · Severity: warning · Since: 0.6.2

## References

- [GitHub Docs: About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [GitHub Docs: Creating rulesets for a repository](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository)
- [GitHub Docs: Immutable releases](https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/immutable-releases)
- [EC-0024 Release configuration](release-configuration.md)
- [EC-0026 Release workflows](release-workflows.md)
