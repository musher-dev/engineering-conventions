---
title: Repositories release with release-please from a draft, and tag vX.Y.Z or <component>/vX.Y.Z
date: 2026-09-29
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
amends: ["0005", "0014"]
---

# 0017 — Repositories release with release-please from a draft, and tag vX.Y.Z or \<component\>/vX.Y.Z

## Context

Ten of the organization's repositories cut releases with release-please, and no two configure it the same way. An
inventory taken on 2026-09-29 of the public ones (this repository, `musher-dev/specifications`,
`musher-dev/musher-cli`, `musher-dev/python-sdk`, `musher-dev/typescript-sdk`) and the private ones found:

- **Five tag grammars:** `vX.Y.Z`, bare `X.Y.Z`, `<component>/vX.Y.Z`, `<component>-vX.Y.Z` and a product-prefixed
  `<product>-vX.Y.Z`. Two repositories also give their GitHub Releases a name that differs from the tag.
- **Four release pull request titles:** `chore(release): release X`, `chore(repo): release <component> X`,
  `chore: release main` and `chore(main): release X`. Two of those use a scope the repository's own commit rules do
  not declare.
- **Three workflow layouts:** release-please and publishing in one `release.yml`; `release.yml` plus a `publish.yml`
  triggered by `release: published`; and a `release-pr.yml` plus a tag-triggered `release.yml`.
- **Two GitHub Apps with three spellings** of their credentials, and four repositories still running release-please
  with the default `GITHUB_TOKEN`, which [GHA-47](../../engineering-conventions/definitions/conventions/github-actions/releases-and-deployments.md#gha-47)
  already reports.
- **Different 0.x bump rules.** Six repositories set both of release-please's pre-major flags; this repository sets
  only `bump-minor-pre-major`.
- **Immutable releases** enabled in one repository. Five repositories that publish releases have no tag ruleset.
- **Three checksum file names:** `SHA256SUMS`, `checksums.txt` and per-file `.sha256`, where there is one at all.

Two platform changes make the choice more than taste.

- **Immutable releases** became generally available on 2025-10-28. Once a release is published, its tag cannot move
  and its assets cannot be added, replaced or deleted. GitHub's documented order is to create a draft, attach every
  asset, and then publish. A workflow triggered by `release: published` that uploads assets, which is how this
  repository's `publish.yml` works, fails against an immutable release.
- **release-please drafts with a tag.** GitHub creates no tag for a draft release. Without one, release-please cannot
  find the previous release and opens a release pull request containing the whole history. release-please 17.2.0
  added `force-tag-creation`, which creates the tag when it creates the draft. release-please-action v5.0.0 bundles
  release-please 17.6.0.

The tokens matter too. A pull request or release created with `GITHUB_TOKEN` starts no workflow: its runs need a
human's approval, and a release it publishes never triggers `release: published`. An App installation token has none
of these limits, expires within the hour, and can be scoped when it is minted.

## Decision

Every repository that releases versioned artifacts releases them this way. The release conventions (the `REL`
family) carry the checkable parts. Until they ship, this decision is the reference.

**Tool and configuration.** release-please, pinned release-please-action v5, in manifest mode, reading
`.github/release-please/config.json` and `.github/release-please/manifest.json` through the action's `config-file`
and `manifest-file` inputs. The action's `release-type` input is never set, because it makes the action ignore both
files. The config declares release-please's `$schema`.

**Tags.** A repository with one package tags `vX.Y.Z` (`include-component-in-tag: false`). A repository with several
independently versioned packages tags `<component>/vX.Y.Z` (`tag-separator: "/"`), where every package sets a
kebab-case `component`. Tags always carry the `v`.

| Tag form | Go module | mise `github:` | aqua | Renovate | Outcome |
| --- | --- | --- | --- | --- | --- |
| `vX.Y.Z` | root module | native | native | native | **single package** |
| `<component>/vX.Y.Z` | the only form valid for a module in a subdirectory | `version_prefix = "<component>/v"` | `version_prefix` | `extractVersion`, derived from mise's `version_prefix` | **several packages** |
| `<component>-vX.Y.Z` | not valid | `version_prefix` | yes | `extractVersion` | rejected: the separator is also a character of kebab-case components |
| `X.Y.Z` | not valid | stripped | yes | yes | rejected: not a Go tag; mixes with other repositories' `v` tags |

**Release pull requests.** Each package gets its own release pull request (`separate-pull-requests: true`), titled
`chore(release): release${component} ${version}`. release-please substitutes `${component}` with a leading space, or
with nothing for a single package, so one pattern serves both. The repository's commit rules declare the `release`
scope. The title is the commit subject when the pull request squash-merges.

**The release is drafted, filled, then published.** The config sets `draft: true` and `force-tag-creation: true`. The
repository's `release.yml` then does everything in the run that created the release:

1. The release-please job, with the release App's token, creates the tag and the draft release.
2. A job gated on the release having been created checks out the tag and builds. It writes a `SHA256SUMS` over the
   assets, attests them with `actions/attest` using `subject-checksums`, and uploads them to the draft without
   overwriting anything.
3. A last job publishes the draft with the release App's token, and fails unless the published release reports
   `immutable: true`.

A `workflow_dispatch` input `tag` re-runs steps 2 and 3 for a release that is still a draft, and refuses one that is
published. Artifacts pushed somewhere other than the GitHub Release (a package registry, a site) are published by a
`publish-<output>.yml` or `deploy-<output>.yml` triggered by `release: published`. Those workflows never write to the
release itself.

**One release App.** Every repository mints its release token from one dedicated GitHub App, identified by the
organization variable `RELEASE_APP_CLIENT_ID` and the secret `RELEASE_APP_PRIVATE_KEY`, through
`actions/create-github-app-token`'s `client-id` input. The App's permissions are contents and pull requests. It is
the only actor that may bypass a repository's tag ruleset, and immutable releases are enabled as an organization
policy.

**Versions before 1.0.** release-please sets both `bump-minor-pre-major` and `bump-patch-for-minor-pre-major`. In 0.x,
a breaking change bumps the minor version, and a `feat` or `fix` bumps the patch. This is the reading Cargo and npm
caret ranges already give 0.x versions: the minor is the breaking axis.

**Changelogs follow the release.** release-please cuts a release only for commits in a visible changelog section. So
`feat` and `fix` are visible, and `chore`, `ci`, `test`, `build`, `style` and `refactor` are hidden. `docs` is hidden,
except in a repository whose documents are its product (kind `specification` or `documentation`), where prose is what
consumers pin. Section names are the repository's choice. `release-as` and `last-release-sha` never stay in a config
after the release they were needed for; a `Release-As:` commit footer pins a version instead.

### What this changes in earlier decisions

- **[Decision 0005](0005-status-severity-and-versioning.md).** Its change-classification table stays this repository's
  own: other repositories define consumer impact for what they publish. Its "Bump in 0.x" column changes: a `feat`
  bumps the patch in 0.x, as a `fix` does, and a `feat!` still bumps the minor.
- **[Decision 0014](0014-release-workflows-may-publish.md).** A release workflow may still publish what it releases,
  and now must, for its GitHub Release assets: it attaches them to the draft before publishing. A `publish` workflow
  triggered by `release: published` may no longer write release assets.

## Consequences

### Positive

- One tag grammar that Go, mise, aqua and Renovate all read, and one release pull request title across the
  organization.
- A release is never visible without its assets: a draft is hidden from `releases/latest`, from mise and from
  Renovate until it is published.
- Published bytes and tags cannot change under a consumer who verified them.
- A 0.x version says something: a minor bump is where to look for breaking changes.

### Negative

- Repositories on another tag grammar migrate. release-please finds the previous release by its tag, so each migration
  needs a one-release `last-release-sha` or alias tags in the new form.
- The provenance of assets attested in `release.yml` records the push to the default branch, not the tag. Consumers
  who verify with `gh attestation verify --source-ref` or `--signer-workflow` change their command at the first release
  made this way. mise checks only the repository, and is unaffected.
- A repository with several packages can have several release pull requests open at once.
- A broken published release cannot be repaired, only superseded by the next version.

### Neutral

- Version-file placement is left to the release type: `version.txt` for `simple`, the ecosystem manifest otherwise,
  with every other copy listed in `extra-files` and marked `x-release-please-version`.
- Content-addressed artifacts (images tagged by digest or date, machine snapshots) are not release-please releases and
  are out of scope.

## Enforcement

The release conventions (topic `releases`, family `REL`) check the configuration, the tag ruleset and the release
workflow with conftest over `.github/release-please/*.json`, `.github/rulesets/*.json` and `.github/workflows/`, and
report the rest in review. Whether immutable releases are enabled is not visible in any file. The release workflow's
last job asserts it, and a reviewer looks for that assertion. Until the family ships, conformance is `review-only`
against this record.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| release-please, from a draft | A reviewable release pull request, many ecosystems and monorepos, drafts with tags since 17.2.0 | **chosen**; every releasing repository already uses it |
| changesets | An intent file per pull request; tags `pkg@X.Y.Z` | rejected: JavaScript-centred, and breaks "the commit type is the release" |
| semantic-release | Releases on every merge, without a release pull request | rejected: no review step before a version is cut; plugins for monorepos |
| Tag separator `-` | release-please's default, `<component>-vX.Y.Z` | rejected: not a Go module tag; ambiguous with kebab-case components |
| Tag separator `/` | `<component>/vX.Y.Z` | **chosen** |
| Publish assets on `release: published` | A `publish.yml` uploads to the published release | rejected: fails once releases are immutable |
| Publish from a tag-triggered workflow | Provenance records the tag | rejected: has to wait for the draft and re-derive what release-please already knows |
| Attach, attest and publish in `release.yml` | One run from tag to published release | **chosen** |
| Pre-1.0: minor bump for `feat` | This repository's rule until now | rejected: the minor stops meaning "may break" |
| Pre-1.0: both flags | Breaking bumps the minor, `feat` and `fix` bump the patch | **chosen**; the rule most repositories already use |
| One grouped release pull request | `separate-pull-requests: false` | rejected: packages could not be released on their own |

## References

- [Immutable releases are now generally available](https://github.blog/changelog/2025-10-28-immutable-releases-are-now-generally-available/)
- [Immutable releases (GitHub Docs)](https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/immutable-releases)
- [release-please manifest releaser](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md)
- [release-please changelog](https://github.com/googleapis/release-please/blob/main/CHANGELOG.md), 17.2.0: `force-tag-creation`
- [release-please-action releases](https://github.com/googleapis/release-please-action/releases)
- [`GITHUB_TOKEN`: triggering a workflow from a workflow](https://docs.github.com/en/actions/concepts/security/github_token)
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
- [actions/attest](https://github.com/actions/attest)
- [Go modules reference: module paths and versions](https://go.dev/ref/mod)
- [mise: the github backend](https://mise.jdx.dev/dev-tools/backends/github.html)
- [Semantic Versioning 2.0.0, item 4](https://semver.org/#spec-item-4)
- [Decision 0005: Status, severity and versioning](0005-status-severity-and-versioning.md)
- [Decision 0014: A release workflow may publish what it releases](0014-release-workflows-may-publish.md)
