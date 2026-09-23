---
title: Requirements start as warnings, and a release's version says what it can break
date: 2026-09-23
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0005 — Status, severity and versioning

## Context

A consumer adopts a release of these conventions by pinning its version. For that to be safe, the version number has
to say whether upgrading can fail the consumer's build. A new requirement that fails builds on arrival would teach
every consumer to stop upgrading.

Conventions also need a way to be published before they are enforced. The GitHub Actions conventions are owned by the
platform until a handoff ([decision 0002](0002-authority-and-migration.md)); consumers should be able to see the
findings they will face before any of them can fail.

## Decision

**Three lifecycle axes, kept separate.** A convention and its requirements each carry a status, and a convention also
records how far its authority has moved. The three fields answer different questions and change independently:

| Axis | Field | Values | Answers |
| --- | --- | --- | --- |
| Convention status | a convention's `status` | `draft`, `active`, `deprecated`, `retired` | Is this document the settled description of its topic? |
| Requirement status | a requirement's `status` | `proposed`, `active`, `deprecated`, `retired` | Do profiles enforce this statement, and may it still change? |
| Migration | a convention's `migration` | `proposed`, `mirrored`, `authoritative` | Which repository's text governs ([decision 0002](0002-authority-and-migration.md))? |

A convention can therefore be `active` while every requirement in it is `proposed`. EC-0001 (the conventions
declaration) is the example: the file format it defines is this repository's own interface, in use and governed here
(`authority: self`, `migration: authoritative`), so the document is `active`; its requirements are `proposed` because,
like every requirement, they start as warnings that consumers see before any of them is enforced. The GitHub Actions
conventions are `draft` with `migration: proposed`, because the platform still governs them.

**Requirement status and severity are separate.** A requirement's `status` is its lifecycle; its `severity` is how a
finding is reported.

| Status | Meaning | Checked |
| --- | --- | --- |
| `proposed` | Published for comment; the migration it implies is visible | only by profiles with `include_proposed: true` |
| `active` | In force | by every profile that includes it |
| `deprecated` | In force, scheduled for retirement | by every profile that includes it |
| `retired` | A tombstone; never checked; the ID is never reused | never |

| Severity | Reported as | Fails `conventions check` by default |
| --- | --- | --- |
| `warning` | `warn` | no (`--fail-on warning` makes it fail) |
| `error` | `deny` | yes |

**Warning first.** Every new requirement ships at `warning`. It becomes `error` in a later release, after consumers
have seen its findings. A profile may raise a requirement's severity for the repositories that choose it; it may never
lower one.

### Change classification

**Semantic versioning, by consumer impact.** The version of a release is chosen by the strongest change it contains,
and the pull request title's Conventional Commit type is what tells release-please which change that is. **This table
is the one authoritative classification**; every other document links here rather than restating it.

| Change | Commit type | Bump from 1.0.0 | Bump in 0.x |
| --- | --- | --- | --- |
| A requirement becomes `error`; a check changes so code that passed now fails at `error`; a term, token or display form is removed or renamed; an alias is banned where its finding is an error (a prose alias in the Vale style); the declaration schema tightens so a valid declaration becomes invalid | `feat!` | major | minor |
| A new requirement at `warning`; a proposed requirement activated at `warning`; a new term, token, display form or profile; an alias newly banned where its finding is a warning; the declaration schema relaxed to accept something new | `feat` | minor | minor |
| A false positive fixed; a check relaxed so it reports less; a diagnostic message changed without changing when it fires | `fix` | patch | patch |
| Prose clarified without changing what is checked or reported | `docs` | none | none |
| Authoring tooling, tests or CI of this repository | `chore`, `test`, `ci`, `refactor` | none | none |

A `docs` change cuts no release; it reaches consumers with the next release that does. That is why a change to what a
requirement checks, to a diagnostic message or to the terminology is never `docs`: a consumer could not pin it.

**Term stability.** A term in `terminology/` is `stable` or `provisional`. In the 0.x series a `provisional` term may
still be changed or removed in a minor release, as any breaking change may be; a `stable` term is not expected to
change. From 1.0.0, removing or renaming any term, provisional or stable, is a major change like every other row in
the first line of the table.

**Start at 0.1.0.** Until 1.0.0 the repository follows the SemVer convention for initial development. release-please
is configured with `initial-version: 0.1.0`, so the first release is 0.1.0 whatever it contains, and with
`bump-minor-pre-major`, so a breaking change bumps the minor version while the major is 0; a `feat` also bumps the
minor. 0.x consumers should therefore read every minor release's notes. In 0.x every requirement is `proposed` at
`warning`. The first release that makes any requirement `error` is the first major-class change.

## Consequences

### Positive

- A consumer can upgrade patch and minor releases without reading every change: at most, new warnings appear.
- Findings can be seen long before they can fail a build.
- Changing a severity is a frontmatter edit; the Rego checks carry no severity.

### Negative

- Warnings can be ignored. The `--fail-on warning` flag and profile-raised severities exist for repositories that
  want to hold themselves to more.
- A tightening needs two releases (warning, then error), so enforcement is slower.

### Neutral

- This repository holds itself to every warning: `task conventions:self` fails on any finding.

## Enforcement

- The profile schema and `conventions generate` refuse a profile that lowers a severity.
- `conventions invariants` fails when a released requirement is removed rather than retired.
- The pull request template asks for the change class and whether it is breaking, and links the table above; the pull
  request title check requires a Conventional Commit type, which release-please turns into the version bump.
- Classifying a change correctly is `review-only` for now. An automated semver classifier that compares a change's
  `index.json` against the last release is planned.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Errors from the start | Enforce everything immediately | rejected: consumers would pin old versions to avoid breaking builds, and never upgrade |
| Calendar versions | Date-stamped releases | rejected: a date says nothing about whether an upgrade can break a build |
| Semantic versions keyed to consumer impact, warning first | This decision | **chosen** |

## References

- [Semantic Versioning 2.0.0](https://semver.org/)
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
- [Versioning](../versioning.md)
- [Decision 0004: Identifiers and diagnostic URLs](0004-identifiers-and-diagnostic-urls.md)
