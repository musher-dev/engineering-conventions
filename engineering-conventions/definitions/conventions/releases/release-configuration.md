---
id: EC-0024
title: Release configuration
summary: >-
  A repository that publishes versioned outputs releases them with
  release-please in manifest mode, configured in .github/release-please/. It
  tags vX.Y.Z, or <component>/vX.Y.Z when it releases several packages; opens
  one release pull request for all of them, titled the same way everywhere; drafts each release
  with its tag; bumps 0.x versions explicitly; shows in its changelog exactly
  the commits that cut a release; and keeps no one-off override.
status: draft
topic: releases
applies_to:
  paths:
    - .github/release-please/config.json
    - .github/release-please/manifest.json
    - .github/conventional-commits.yaml
    - .github/workflows/*.yml
    - .github/workflows/*.yaml
    - .repo/outputs.toml
created: 2026-09-29
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "release-please: manifest releaser"
    url: https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md
  - title: "release-please: customizing releases"
    url: https://github.com/googleapis/release-please/blob/main/docs/customizing.md
  - title: "release-please: config schema"
    url: https://github.com/googleapis/release-please/blob/main/schemas/config.json
  - title: "Go modules reference: versions"
    url: https://go.dev/ref/mod#versions
  - title: "Semantic Versioning 2.0.0"
    url: https://semver.org/
requirements:
  - id: REL-01
    title: A repository that declares a versioned output releases it with release-please
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.releases.configuration
  - id: REL-02
    title: The release-please config and release-please manifest are .github/release-please/config.json and manifest.json
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.releases.configuration
  - id: REL-03
    title: The release-please action reads those two files and sets no release type of its own
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.releases.configuration
  - id: REL-04
    title: The release-please config and release-please manifest agree on the packages, each with a release type and a version
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.releases.configuration
  - id: REL-05
    title: Release tags are vX.Y.Z, or <component>/vX.Y.Z when a repository releases several packages
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.releases.configuration
  - id: REL-06
    title: A repository releases every package from one release pull request, titled chore(release) with a set pattern
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.releases.configuration
  - id: REL-07
    title: release-please creates each release as a draft, together with its tag
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.releases.configuration
  - id: REL-08
    title: A package before 1.0 bumps the minor for a breaking change and the patch for anything else
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.releases.configuration
  - id: REL-09
    title: The changelog shows the commit types that cut a release and hides the rest
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.releases.configuration
  - id: REL-10
    title: No release-as or last-release-sha stays in the release-please config
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.releases.configuration
  - id: REL-11
    title: The version lives in the file release-please owns, and every other copy is marked for it
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: review
---

# Release configuration

A release is a promise: this tag names these bytes, and this changelog says what changed since the last one. That
promise breaks quietly. A release pull request titled differently in every repository, a tag grammar each tool parses
its own way, a release published before its assets exist, or a pinned version left in a config after the release that
needed it: each of these reads as a working release until someone depends on it. These requirements make every
repository configure release-please the same way, so a reader, a tool and a reviewer find the same thing everywhere.

## Scope

This convention governs `.github/release-please/`, the release-please steps in `.github/workflows/`, and the commit
rules in `.github/conventional-commits.yaml` where a repository keeps them. REL-01 also reads `.repo/outputs.toml`
([EC-0007](../outputs/outputs-declaration.md)). A repository that neither declares a versioned output nor runs
release-please gets no finding from it.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`), and every requirement is `proposed` at
severity `warning`. [Decision 0017](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0017-releases-from-drafts.md)
records why each choice was made and which alternatives were rejected.

## A conforming config

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "release-type": "simple",
  "include-component-in-tag": false,
  "pull-request-title-pattern": "chore(release): release${component} ${version}",
  "draft": true,
  "force-tag-creation": true,
  "bump-minor-pre-major": true,
  "bump-patch-for-minor-pre-major": true,
  "packages": { ".": {} }
}
```

A repository with several packages sets `"tag-separator": "/"` and `group-pull-request-title-pattern` instead of
`include-component-in-tag` and `pull-request-title-pattern`, leaves `separate-pull-requests` at its default, and gives
each package a `component`:

```json
{
  "tag-separator": "/",
  "group-pull-request-title-pattern": "chore(release): release ${branch}",
  "packages": {
    "schemas/blueprint": { "component": "blueprint" },
    "schemas/listing": { "component": "listing" }
  }
}
```

## Requirements

### REL-01

**A repository that declares a versioned output releases it with release-please.**

A bundle, command-line tool, contract or library is consumed by version: someone pins `1.4.2` and expects the next
release to say what changed. A version cut by hand has no changelog anyone can trust, no tag rule anyone reviewed, and
no record of why it is a minor rather than a patch. release-please derives all three from the commits and puts them in
a pull request a person merges. The check reports a `.repo/outputs.toml` that declares an output of kind `bundle`,
`cli`, `contract` or `library` when the repository has no release-please config. Images and sites are not versioned
this way and are not counted.

**Correct:** `.repo/outputs.toml` declares a `bundle`, and `.github/release-please/config.json` exists.

**Incorrect:** the same declaration, with releases tagged by hand.

Checked by: conftest · Severity: warning · Since: 0.6.2

### REL-02

**The release-please config and release-please manifest are `.github/release-please/config.json` and manifest.json.**

release-please's defaults are two root files, `release-please-config.json` and `.release-please-manifest.json`, and
repositories that keep them elsewhere name the place in their workflow. One location means a reader finds the release
setup without reading the workflow first, and the checks here find it at all. The config and release-please manifest
are one unit: a config without a release-please manifest re-releases the whole history, and a release-please manifest
without a config releases nothing. The check reports a file under either default name anywhere in the repository,
another JSON file in `.github/release-please/`, one of the pair without the other, and a workflow that runs
release-please when no config exists.

**Correct:**

```text
.github/release-please/config.json
.github/release-please/manifest.json
```

**Incorrect:**

```text
release-please-config.json
.release-please-manifest.json
```

Checked by: conftest · Severity: warning · Since: 0.6.2

### REL-03

**The release-please action reads those two files and sets no release type of its own.**

The action's `release-type` input switches it to a single-package mode that ignores both files silently: the config
is still there and still reviewed, and none of it applies. Without `config-file` and `manifest-file`, the action looks
for the root defaults, which REL-02 moves. The check reports a `googleapis/release-please-action` step whose
`config-file` or `manifest-file` is not the standard path, and one that passes `release-type`.

**Correct:**

```yaml
- uses: googleapis/release-please-action@<sha>  # v5
  with:
    token: ${{ steps.app_token.outputs.token }}
    config-file: .github/release-please/config.json
    manifest-file: .github/release-please/manifest.json
```

**Incorrect:**

```yaml
- uses: googleapis/release-please-action@<sha>  # v5
  with:
    token: ${{ steps.app_token.outputs.token }}
    release-type: simple  # the config files are now ignored
```

Checked by: conftest · Severity: warning · Since: 0.6.2

### REL-04

**The release-please config and release-please manifest agree on the packages, each with a release type and a version.**

`$schema` lets an editor and a reviewer see a mistyped key, such as `draft-pull-requests`, which release-please
otherwise ignores. A package without a `release-type` fails only when release-please runs on the default branch. And
the release-please manifest is how release-please knows where each package stands: a package missing from it starts
again from its initial version and releases its whole history, and an entry for a package the config no longer lists
is a release nobody will cut. The check reports a missing or different `$schema`, a config with no packages, a
package with no `release-type` of its own or at the top level, a package without a version in the release-please
manifest, and a release-please manifest entry the config does not list.

**Correct:**

```json
{ "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "release-type": "simple", "packages": { ".": {} } }
```

```json
{ ".": "0.6.1" }
```

**Incorrect:**

```json
{ "packages": { ".": {} } }
```

Checked by: conftest · Severity: warning · Since: 0.6.2

### REL-05

**Release tags are `vX.Y.Z`, or `<component>/vX.Y.Z` when a repository releases several packages.**

Every tool that reads a tag parses a version out of it, and each tool accepts a different set of forms. `vX.Y.Z` is
read natively by Go, mise, aqua and Renovate. For several packages, `<component>/vX.Y.Z` is the only form Go accepts
for a module in a subdirectory, and mise (`version_prefix = "<component>/v"`), aqua and Renovate read it with a plain
prefix. release-please's own default, `<component>-vX.Y.Z`, is not a Go tag, and its separator is also a character of
every kebab-case component. A tag without the `v` mixes with every other repository's tags in a tool's version list.

The check reports a package tagged without a `v`; a single package whose tag would carry its component (set
`include-component-in-tag: false`); and, when there are several packages, a separator other than `/`, a package whose
tag leaves out its component, a package without a kebab-case `component`, and two packages with the same one.

**Correct:** `v1.4.2`; `blueprint/v1.6.0`.

**Incorrect:** `1.4.2`; `engineering-conventions-v1.4.2`; `blueprint-v1.6.0`.

Checked by: conftest · Severity: warning · Since: 0.6.2

### REL-06

**A repository releases every package from one release pull request, titled `chore(release)` with a set pattern.**

One release pull request and one release run, however many packages a repository holds, is the simplest pipeline to
follow: one thing to review, one run to watch, and each package still gets its own version, `<component>/vX.Y.Z` tag
and draft release when it is merged. So a repository with several packages leaves `separate-pull-requests` at its
default, `false`, and release-please groups every package with releasable changes into one pull request whose body
lists each package's version.

The title becomes the commit on the default branch when the pull request squash-merges, so it is the line every
history and every changelog shows, and it reads the same everywhere:

| Packages | Setting | Title |
| --- | --- | --- |
| One | `pull-request-title-pattern`: `chore(release): release${component} ${version}` | `chore(release): release 1.4.2` |
| Several | `group-pull-request-title-pattern`: `chore(release): release ${branch}` | `chore(release): release main` |

A grouped title names the branch, not a version: release-please fills `${component}` and `${version}` in it only from a
root `"."` package. The title's type and scope must pass the repository's commit rules, or the release pull request is
the one pull request that cannot merge. A repository that switches from one pull request per package closes those pull
requests and removes their `autorelease: pending` labels, or release-please opens no grouped one.

The check reports a single package whose effective `pull-request-title-pattern` is not the one above; with several
packages, a `separate-pull-requests: true` at the top level or on a package, and a `group-pull-request-title-pattern`
that is not the one above; and a `.github/conventional-commits.yaml` whose `types` list leaves out `chore` or whose
`scopes` list leaves out `release`.

**Correct:**

```json
{ "group-pull-request-title-pattern": "chore(release): release ${branch}",
  "packages": { "schemas/blueprint": { "component": "blueprint" }, "schemas/listing": { "component": "listing" } } }
```

**Incorrect:**

```json
{ "separate-pull-requests": true,
  "packages": { "schemas/blueprint": { "component": "blueprint" }, "schemas/listing": { "component": "listing" } } }
```

Checked by: conftest · Severity: warning · Since: 0.6.2

### REL-07

**release-please creates each release as a draft, together with its tag.**

Once a release is published it is immutable ([REL-14](release-tags.md#rel-14)): its assets can no longer be added or
replaced. So assets are attached while the release is a draft, and the draft is published last
([REL-19](release-workflows.md#rel-19)). GitHub creates no tag for a draft; without one, release-please cannot find
its previous release and opens a release pull request with the entire history. `force-tag-creation` makes
release-please create the tag with the draft. The check reports a package whose effective `draft` or
`force-tag-creation` is not `true`.

**Correct:**

```json
{ "draft": true, "force-tag-creation": true }
```

**Incorrect:**

```json
{ "draft": true }
```

Checked by: conftest · Severity: warning · Since: 0.6.2

### REL-08

**A package before 1.0 bumps the minor for a breaking change and the patch for anything else.**

Semantic Versioning says anything may change in 0.x. Without its pre-major settings, release-please turns the first
breaking change into 1.0.0, a promise nobody decided to make. With `bump-minor-pre-major` and
`bump-patch-for-minor-pre-major`, the minor is the breaking axis in 0.x, which is how Cargo and npm's caret ranges
already read a 0.x version, so `^0.6.1` never pulls in a break. The check reports a package whose release-please
manifest version is below 1.0.0 (or absent) and that does not set both to `true`.

**Correct:**

```json
{ "bump-minor-pre-major": true, "bump-patch-for-minor-pre-major": true }
```

**Incorrect:**

```json
{ "bump-minor-pre-major": true }
```

Checked by: conftest · Severity: warning · Since: 0.6.2

### REL-09

**The changelog shows the commit types that cut a release and hides the rest.**

release-please cuts a release only when a commit lands in a visible changelog section, so which sections are visible
decides what releases. `feat` and `fix` change what a consumer receives and must be visible; `chore`, `ci`, `test`,
`build`, `style` and `refactor` change nothing a consumer receives and must be hidden. `docs` is hidden too, except in
a repository whose documents are what it publishes (kind `specification` or `documentation` in
`.repo/repository.toml`), where prose is what consumers pin. Section names are the repository's to choose. The check
reads the effective `changelog-sections`, or release-please's defaults when there are none, and reports each type
shown or hidden against this rule.

**Correct:**

```json
{ "changelog-sections": [
  { "type": "feat", "section": "Features" },
  { "type": "fix", "section": "Bug Fixes" },
  { "type": "chore", "section": "Miscellaneous", "hidden": true }
] }
```

**Incorrect:**

```json
{ "changelog-sections": [
  { "type": "feat", "section": "Features" },
  { "type": "chore", "section": "Miscellaneous" }
] }
```

Checked by: conftest · Severity: warning · Since: 0.6.2

### REL-10

**No `release-as` or `last-release-sha` stays in the release-please config.**

Both are one-off overrides: `release-as` forces the next version, and `last-release-sha` tells release-please where
the previous release was. Neither is ever ignored while it is set, so a `release-as` left behind pins every later
release to the same version, and a `last-release-sha` left behind builds every changelog from the same old commit.
Pin a version with a `Release-As: x.y.z` commit footer instead, which applies once. The check reports either key at
the top level or on a package.

**Correct:**

```sh
git commit --allow-empty -m "chore: release 2.0.0" -m "Release-As: 2.0.0"
```

**Incorrect:**

```json
{ "packages": { ".": { "release-as": "2.0.0" } } }
```

Checked by: conftest · Severity: warning · Since: 0.6.2

### REL-11

**The version lives in the file release-please owns, and every other copy is marked for it.**

release-please updates the file its release type owns: `version.txt` for `simple`, `package.json` for `node`,
`pyproject.toml` for `python`, and so on. Any other file that states the version, such as a README's install line or
an example's pin, drifts from the tag unless release-please updates it too: list it in `extra-files`, and mark the line
with `x-release-please-version` (or a `x-release-please-start-version` block). A reviewer checks that each version
string in the repository is either owned or marked. This is review-only: the checks cannot select the files a config
names.

**Correct:**

```toml
"github:musher-dev/engineering-conventions" = "0.6.1"  # x-release-please-version
```

**Incorrect:** a README that says `0.4.0` in a repository at `0.6.1`.

Checked by: review · Severity: warning · Since: 0.6.2

## References

- [release-please: manifest releaser](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md)
- [release-please: customizing releases](https://github.com/googleapis/release-please/blob/main/docs/customizing.md)
- [release-please: config schema](https://github.com/googleapis/release-please/blob/main/schemas/config.json)
- [Go modules reference: versions](https://go.dev/ref/mod#versions)
- [Semantic Versioning 2.0.0](https://semver.org/)
- [EC-0025 Release tags](release-tags.md)
- [EC-0026 Release workflows](release-workflows.md)
