---
title: A few organization-wide repositories keep a single-token name, from a reviewed list in EC-0010
date: 2026-11-07
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
amends: ["0012"]
---

# 0042: A few organization-wide repositories keep a single-token name, from a reviewed list in EC-0010

## Context

[Decision 0012](0012-repository-names.md) made the grammar strict: every repository is `<system>-<component>`, and
REPO-08 reports a name with one token. A repository named before the grammar existed declares its current name and
waives REPO-08 until it is renamed ([EC-0010, Legacy names](../../engineering-conventions/definitions/conventions/repository/repository-names.md#legacy-names)).

Four repositories will not be renamed: `specifications`, `pelorus`, `infra` and `platform`. Each name is already the
repository's identity in more places than a rename could reach (pinned release assets, the organization's design
model), or is the name of the system the repository founds. A waiver for them tracks a rename nobody plans, expires
within 180 days and has to be renewed for ever. ADOPT-05 says a requirement a repository will never meet is a case for
changing the requirement, not for a long waiver
([issue #132](https://github.com/musher-dev/engineering-conventions/issues/132)).

## Decision

We will keep a short list of **kept names** in EC-0010, the single-token names REPO-08 accepts permanently, starting
with `infra`, `pelorus`, `platform` and `specifications`. Only REPO-08 is lifted. A name joins the list only through a
reviewed change to this repository, never through a consumer's declaration, and a new repository never joins it.

## Consequences

### Positive

- The four repositories conform without a waiver, and their rename issues can close.
- The exception is visible in one place, with a reason for each name, instead of spread across waivers in each
  repository.

### Negative

- A reader can no longer assume every name has a system token; for a kept name the system is read from the
  declaration.

### Neutral

- REPO-07, REPO-09 to REPO-11, REPO-04 and REPO-13 are unchanged: the last four already judge only a name that follows
  the grammar.
- A consumer that waived REPO-08 for a kept name drops the waiver when it pins the release that carries the list.

## Enforcement

`kept_names` in `engineering-conventions/checks/rego/lib/repository.rego` is the list the REPO-08 check reads. The
Rego tests and the fixture `repo-08-passes-kept-name` prove a kept name produces no finding, and `repo-08-legacy-name`
proves another single-token name still does. That the table in EC-0010 and `kept_names` agree is `review-only`: a
reviewer checks that a change to one changes the other.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Rename the four | Give each a component | rejected: each name is its identity, and a rename breaks consumers for no reader's benefit |
| Waivers renewed every 180 days | Keep the waiver model | rejected: ADOPT-05 rules out a waiver for a requirement a repository will never meet |
| A consumer-side permanent waiver | Let a declaration mark a waiver as permanent | rejected: every repository could declare its own exception, and nobody reviews the list |
| A reviewed list in EC-0010 | Name each kept repository, with its reason, in the convention | **chosen** |

## References

- [Decision 0012: Repository names](0012-repository-names.md)
- [EC-0010 Repository names](../../engineering-conventions/definitions/conventions/repository/repository-names.md)
- [EC-0001 Conventions declaration, ADOPT-05](../../engineering-conventions/definitions/conventions/adoption/conventions-declaration.md#adopt-05)
