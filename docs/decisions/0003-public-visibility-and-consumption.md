---
title: The repository is public, and consumers vendor a verified, tagged bundle
date: 2026-09-23
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0003 — Public visibility and consumption

## Context

A convention has to be readable by everyone it binds, and the diagnostics that cite it have to link somewhere the
reader can open. Some of the repositories that will consume these conventions are public, some are private, and the
people reading a failed check include contributors from outside the organization. A private conventions repository
would put every diagnostic link behind a login that most readers do not have, and would need a credential in every
consumer's CI just to download the conventions and their checks.

A public repository has its own constraint: everything in it is published, including history.

How a consumer gets the checks matters as much as where they live. Reading them from `main` at run time means a change
here can fail a consumer's build without any change there. Copying files by hand is the template problem company
decision 0012 describes.

## Decision

**The repository is public.** Its content must be publishable: no secrets, no internal hostnames, no customer or
strategy material. Conventions describe how Musher builds software, not what it sells or to whom.

**Consumers vendor a tagged bundle.** Each release attaches:

| Asset | Contents |
| --- | --- |
| `engineering-conventions-<version>.tar.gz` | The product directory (conventions, terminology, profiles, `checks/` with its generated data, examples), without the authoring tooling, plus `checks/data/release.json` naming the version |
| `MusherConventions.zip` | The Vale style as a Vale package |
| `manifest.json` | The version, the source commit, and the SHA-256 of every file in the bundle |
| `SHA256SUMS` | Checksums of the three assets above, for `sha256sum -c` |

Every tarball and Vale package carries a build-provenance attestation made by the `Publish` workflow, verifiable with
`gh attestation verify`. Assets are uploaded without overwrite, so a published release never changes. A consumer pins a
version in its conventions declaration, downloads and verifies that release, and runs the checks against the vendored
copy. Nothing is fetched from `main` at check time.

**Diagnostics are self-sufficient.** A finding's message must say what to change without the link. The URL points at
the requirement's heading in the tagged release for the reader who wants the reasoning; it is never required to act.

**Some authority links point at private repositories.** A convention whose authority is another repository
([decision 0002](0002-authority-and-migration.md)) links to it, and some of those repositories are private. Those links
work for members of the organization and not for anyone else. The convention text here must therefore stand alone:
the link says where authority lives, not where the rule is explained.

## Consequences

### Positive

- Anyone can read a requirement from a diagnostic link without an account.
- A consumer's results change only when the consumer changes its pinned version.
- Integrity is checkable end to end: checksums for accidental corruption, provenance for where the bundle was built.
- Free GitHub features for public repositories apply: secret scanning with push protection, and artifact attestations.

### Negative

- Every contribution is public, including drafts and rejected proposals. Content that cannot be public cannot live here.
- Links to private upstream repositories fail for outside readers.

### Neutral

- Diagnostic URLs point at `blob/main` when checks run from a checkout without release data, and at `blob/v<version>`
  when they run from a bundle.

## Enforcement

- The `Repository / Secrets` job of the `Validate` workflow scans the full history with gitleaks on every change.
- `task bundle:verify` fails when the tarball holds anything but the allowed entries, lacks `release.json` for its
  version, or when any checksum does not match.
- The `Publish` workflow attests provenance and uploads without `--clobber`.
- Whether content is publishable is `review-only`: a reviewer rejects internal hostnames, customer names and strategy
  material.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Private repository | Keep conventions internal | rejected: diagnostic links would not open for most readers, and every consumer's CI would need a credential to fetch the checks |
| Read the checks from `main` at run time | Always current | rejected: a change here could fail any consumer's build without warning |
| Git submodule | Pin a commit | rejected: pins the whole repository including authoring tooling, and submodules are easy to leave uninitialized |
| Tagged bundle with checksums and provenance | Vendor what a release attaches | **chosen** |

## References

- [Consuming the conventions](../consuming.md)
- [GitHub Docs: Using artifact attestations](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds)
- [Vale: Packages](https://vale.sh/docs/keys/packages)
- [Decision 0004: Identifiers and diagnostic URLs](0004-identifiers-and-diagnostic-urls.md)
