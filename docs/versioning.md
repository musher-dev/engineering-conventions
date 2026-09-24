# Versioning

What a release number of `musher-dev/engineering-conventions` promises, and how to upgrade. The reasoning is in
[decision 0005](decisions/0005-status-severity-and-versioning.md).

## What a version covers

One version covers the whole product: conventions, terminology, profiles, checks, schemas and the conventions
declaration format. Releases are tagged `v<major>.<minor>.<patch>`, and the tag is immutable. `version.txt` and
`CHANGELOG.md` at the repository root are maintained by release-please.

## What each bump means

The bump is chosen by the strongest change in the release, measured by its effect on a consumer. The classification,
with the commit type for each kind of change, is the table in
[decision 0005](decisions/0005-status-severity-and-versioning.md#change-classification); it is kept in that one place.
In short:

| Bump | A consumer upgrading should expect |
| --- | --- |
| **Major** | builds that passed can fail |
| **Minor** | new warnings; no new failures |
| **Patch** | fewer or clearer findings |

A prose clarification that changes nothing checked is not released on its own; it arrives with the next release that
is.

## The 0.x series

Until 1.0.0:

- Every requirement is `proposed` at severity `warning`. No finding fails a build unless the consumer asks for it
  (`--fail-on warning`, or a profile that raises severity).
- A breaking change bumps the **minor** version, following the SemVer convention for initial development. Read the
  notes of every minor release.
- A `provisional` term may still change in a minor release. From 1.0.0, removing any term is a major change.
- The GitHub Actions conventions remain owned by `musher-dev/platform` until the handoff in
  [decision 0002](decisions/0002-authority-and-migration.md).

The first release is 0.1.0. The first release that makes any requirement `error` is a major-class change.

## How to upgrade

1. Read the changelog entries between your pinned version and the target.
2. Change the version in `mise.toml`, or merge the pull request Renovate opened for it. A repository without mise
   changes `conventions.version` in `.repo/conventions.yaml` and the version its CI downloads together; ADOPT-08
   reports the two disagreeing.
3. Run the checks. New warnings are the migration the release asks for; fix them, or add waivers with tracking issues.
4. Remove waivers the new release makes stale (ADOPT-06 reports them).

Skipping versions is fine. Requirement IDs are permanent, so a waiver written against an older release still names
the same requirement, and a retired requirement's tombstone names its replacement.

## Diagnostic links

A diagnostic from a release bundle links to `blob/v<version>/...`, the text of the release the repository pinned. A
diagnostic from a checkout of this repository, which has no release data, links to `blob/main/...`.
