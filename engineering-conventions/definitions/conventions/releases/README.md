# Releases

These conventions govern how a repository cuts releases: its release-please configuration, the ruleset that protects
its release tags, and the workflow that turns a merged release pull request into a published, immutable release.

The governing rule, in one sentence:

> **Release with release-please from `.github/release-please/`, tag `vX.Y.Z` or `<component>/vX.Y.Z`, and let
> `release.yml` draft each release, attach and attest its assets, and publish it last with the release App.**

## Status

The conventions are a **draft**, owned by this repository, and every requirement is `proposed` at severity `warning`.
[Decision 0017](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0017-releases-from-drafts.md)
records why each choice was made.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0024 Release configuration](release-configuration.md) | REL-01 – REL-11 | Where the config and release-please manifest live, the tag grammar, release pull requests, drafts, 0.x bumps, changelog sections, one-off overrides, version files |
| [EC-0025 Release tags](release-tags.md) | REL-12 – REL-14 | The tag ruleset and immutable releases |
| [EC-0026 Release workflows](release-workflows.md) | REL-15 – REL-20 | The one release workflow, its App token, attested assets, publishing the draft, recovery |

## Quick reference

| What | The convention | Requirement |
| --- | --- | --- |
| Config and release-please manifest | `.github/release-please/config.json`, `manifest.json` | REL-02 |
| Tag, one package | `vX.Y.Z` (`include-component-in-tag: false`) | REL-05 |
| Tag, several packages | `<component>/vX.Y.Z` (`tag-separator: "/"`) | REL-05 |
| Release pull request | `chore(release): release${component} ${version}`, one per package | REL-06 |
| Releases | `draft: true`, `force-tag-creation: true` | REL-07 |
| 0.x | `bump-minor-pre-major`, `bump-patch-for-minor-pre-major` | REL-08 |
| Changelog | `feat`, `fix` shown; `chore`, `ci`, `test`, `build`, `style`, `refactor` hidden | REL-09 |
| Tag ruleset | `creation`, `update`, `deletion`, `non_fast_forward`; the App bypasses | REL-12, REL-13 |
| Token | `client-id: ${{ vars.RELEASE_APP_CLIENT_ID }}`, `private-key: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}` | REL-16 |
| Assets | `SHA256SUMS`, attested with `actions/attest` `subject-checksums` unless the repository is private | REL-18 |
| Consuming a component tag with mise | `version_prefix = "<component>/v"` | |
