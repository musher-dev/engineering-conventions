---
title: This repository is the home of shared engineering conventions, and owns nothing else
date: 2026-09-23
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0000 — Charter

## Context

Musher's repositories have drifted apart in vocabulary and structure. The same kind of workflow is `ci.yml` in one
repository, `validate.yaml` in another and `validate-code.yml` in a third, with required checks named `CI / required`,
`Validate / Required` or a bare `Lint`. Each repository that noticed wrote its own rules: the platform alone carries
about thirty governance checks that hardcode workflow names, and the development-container template carries its own
layout and configuration rules with their own IDs. None of them can be compared against the others, because none of
them is written anywhere the others can read.

A shared vocabulary needs a home that is not any one product repository. Putting it in the platform would make every
other repository depend on the platform's release cadence and its private visibility; copying it into each repository
is how the drift started.

Company decision 0012 argued against exactly this kind of repository. In paraphrase, it declined a shared template
repository for two reasons: every repository still has to apply the template, and each applied copy then drifts on its
own; and a new repository created to remove duplication across repositories is itself one more repository to keep in
step. That objection has to be answered before this repository is justified.

## Decision

**`musher-dev/engineering-conventions` is the authoritative home for Musher's shared engineering language,
repository structures and implementation expectations.** It defines what the conventions are, publishes the checks
that validate them, and releases both as a versioned bundle. It does not execute application code and does not host
CI for other repositories.

It owns:

- conventions: documents with stable IDs, each holding normative requirements with stable IDs;
- the terminology those conventions use, with display forms and banned aliases;
- convention profiles, which select requirements for a kind of repository;
- the checks that validate requirements: Rego policies, JSON Schemas and a Vale style;
- the format of the conventions declaration a consuming repository keeps in `.repo/conventions.yaml`;
- the release bundle, and the decisions in this directory.

It does not own:

| Not owned here | Owned by |
| --- | --- |
| How the company operates: rituals, planning, the operating model | `musher-dev/company` (process decisions 0001 and 0012) |
| Telemetry names: spans, metrics, attributes, events | `musher-dev/observability-schema-registry` |
| Document specifications: the component, blueprint and catalog formats | `musher-dev/specifications` |
| Positioning, product vocabulary and the customer glossary | `musher-dev/platform` and `musher-dev/company` |
| Platform domain nouns: bounded contexts and their ubiquitous language | `musher-dev/platform` |
| Rules local to one repository | That repository |
| The development-container scaffold: the container, its toolchain setup, its stacks | `musher-dev/development-container` |

A repository-local rule may be **stricter** than a convention here. It may never **contradict** one: a repository that
needs to deviate records a waiver, which is visible, dated and tracked. When a local rule turns out to be useful to more
than one repository, it is proposed here and the local copy is retired.

**The answer to company decision 0012.** Decision 0012 is right about templates: a template is applied, then forked,
and nothing tells a repository that its copy has fallen behind. This repository is not applied. It is a **versioned
contract consumed by pinning**, the pattern company decision 0022 chose for `purpose/`: a publisher releases a bundle
with a declared contract, and each reader pins a version and checks itself against it. A consumer's declaration names
the release it meets, so falling behind is visible as a version number; a new release is adopted by changing that
number, not by re-applying files. The fifth repository removes duplication rather than adding a copy, because the
rules live here once and are read, not copied.

## Consequences

### Positive

- One place to find what a name means and which requirement governs it, with a stable URL for every requirement.
- Checks travel with the conventions, so a repository adopts both at once, at a version it chooses.
- Upstream owners keep their authority: nothing here restates telemetry names, specifications or positioning.

### Negative

- Another repository to maintain, with its own release process.
- A convention that is still owned elsewhere (GitHub Actions naming, by the platform) exists here only as proposed
  requirements derived from the upstream checks until its handoff ([decision 0002](0002-authority-and-migration.md)),
  and the two must not drift in the meantime.

### Neutral

- Adoption is per repository and deliberate. This repository changes no other repository; migration work is filed as
  issues against the consumer.

## Enforcement

- `conventions invariants` fails when a convention or requirement ID is reused or removed.
- The "does not own" table is `review-only`: a reviewer rejects a proposal that restates a definition owned upstream.
  Terminology entries that need such a word point at the upstream definition (`authority`) instead of copying it, which
  the terminology schema enforces.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Conventions in the platform repository | The platform already has the checks | rejected: private, tied to the platform's release cadence, and other repositories would depend on the platform to read a naming rule |
| A template applied to each repository | The development-container model | rejected for conventions: company decision 0012's objection applies in full. The template remains the scaffold |
| Copy rules into each repository | No new repository | rejected: this is the status quo that drifted |
| A versioned contract consumed by pinning | This repository | **chosen** |

## References

- Company decision 0012, on how the company's work is divided across repositories (`musher-dev/company`, private)
- Company decision 0022, on publishing `purpose/` as a versioned bundle with a contract (`musher-dev/company`, private)
- [platform #2892: Organize GitHub Actions workflows by responsibility](https://github.com/musher-dev/platform/issues/2892)
- [Decision 0002: Authority and migration](0002-authority-and-migration.md)
- [Decision 0008: Repository layout](0008-repository-layout.md)
