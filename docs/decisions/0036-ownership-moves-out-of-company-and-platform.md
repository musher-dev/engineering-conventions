---
title: musher-dev/company's ownership moves to the repositories that hold it, the governance words are defined here, and the org graph is assembled in musher-dev/pelorus
date: 2026-10-13
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
amends: ["0000", "0007", "0022"]
---

# 0036 — musher-dev/company's ownership moves to the repositories that hold it, the governance words are defined here, and the org graph is assembled in musher-dev/pelorus

## Context

The charter ([decision 0000](0000-charter.md)) names `musher-dev/company` as the owner of how the company operates,
of part of the product vocabulary, and, in the README, of teams and their membership. That repository is being
deleted ([#100](https://github.com/musher-dev/engineering-conventions/issues/100)). What it held has already moved:
the purpose and the vocabulary to `musher-dev/pelorus`, the model of why Musher exists and what it decides, designs
and ships, with the site that renders it; the roster to `musher-dev/foundation-bootstrap`; and teams and their
members to `musher-dev/infra-github`, which holds them as code rather than applying someone else's list.

`company` is also a registered system, and its only repository is the one being deleted. Every registered system
gets a team in the organization, so the system keeps an empty team alive for as long as it is registered.

[Decision 0007](0007-terminology-and-generated-artifacts.md) recorded that the platform owns "audit", "drift", "gate"
and "conformance", and the terminology points at the platform's rule for them. Those are not platform domain nouns:
they are the engineering-governance words this repository's own checks and documents use (`task generate:check` fails
on drift; `task check` runs every gate CI runs; `clean/` is a conforming repository). A reader of a diagnostic should
not need access to a private repository to learn what one of them means.

[Decision 0022](0022-interfaces-and-dependencies.md) said the org-wide graph of declared edges is computed outside
this repository and that `musher-dev/platform` runs it for now. Pelorus is where the design model of the whole
estate is assembled, and the graph belongs to that model. The charter also names the conventions declaration
`.repo/conventions.yaml`; [decision 0011](0011-declarations-are-toml.md) made it `.repo/conventions.toml` without
amending the charter.

## Decision

**What is not owned here is owned by the repository that holds it.** The charter's "does not own" table now reads:

| Not owned here | Owned by |
| --- | --- |
| Why Musher exists and what it decides, designs and ships: its purpose, its vocabulary and the design model | `musher-dev/pelorus` |
| The roster: who is in the organization | `musher-dev/foundation-bootstrap` |
| Teams and their membership, and applying names, custom properties and rulesets to the organization | `musher-dev/infra-github` |
| Telemetry names: spans, metrics, attributes, events | `musher-dev/observability-schema-registry` |
| Document specifications: the component, blueprint and catalog formats | `musher-dev/specifications` |
| Positioning, product vocabulary and the customer glossary | `musher-dev/platform` and `musher-dev/pelorus` |
| Platform domain nouns: bounded contexts and their ubiquitous language | `musher-dev/platform` and `musher-dev/pelorus` |
| Rules local to one repository | That repository |
| The development-container scaffold: the container, its toolchain setup, its stacks | `musher-dev/development-container` |

The format the charter says this repository owns is the conventions declaration in `.repo/conventions.toml`.

**The `company` system is retired.** `repository.system.company` keeps its ID and is marked `deprecated`, so it drops
out of the registered systems and REPO-03 and REPO-09 report a repository that names it. Removing a token is a
breaking change ([decision 0005](0005-status-severity-and-versioning.md#change-classification)). After the release,
`musher-dev/infra-github` raises its pin, regenerates its systems and removes the empty team in one change.

**`audit`, `drift`, `gate` and `conformance` are defined here**, in this repository's own words and as its checks
use them. The narrower GitHub Actions senses keep their own IDs (`gha.responsibility.audit` and the `drift` alias of
`gha.responsibility.monitor`).

**The org graph is assembled in `musher-dev/pelorus`**, from what `conventions graph` reports for each repository
(graph logic this repository will ship in its command-line tool), joined with the linked-artifact records of
[decision 0035](0035-published-and-deployed-artifacts-are-recorded.md). Decision 0010's rule still holds: the
logic is published here and runs elsewhere. A cycle between two repositories' vendored dependencies is DEPS-14,
checked by review until the graph runs it.

## Consequences

### Positive

- Every owner the charter names exists and holds what it is named for.
- No term here needs a private repository to be understood.
- One repository assembles the graph and the design model it describes.

### Negative

- A repository named `company-*` is a finding after the release; none exists once `musher-dev/company` is deleted.

### Neutral

- Earlier decisions that mention `musher-dev/company` in passing (0003, 0007, 0012, 0021) are left as written: they
  record what was true when they were accepted.

## Enforcement

- REPO-03 and REPO-09 read the registered systems from `vocabulary.repository_systems` in `checks/data/index.json`,
  which leaves out deprecated terms; `task generate:check` keeps it current.
- `terminology.schema.json` allows a term either a `definition` or an `authority`, never both.
- The ownership table is `review-only`: a reviewer rejects a change that names `musher-dev/company` as an owner or
  restates a definition owned by a repository in the table.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Keep the `company` system for a future repository | Nothing breaks | rejected: no repository would be in it, and its empty team would stay |
| Delete the term | Simplest | rejected: term IDs are never deleted; a deprecated term keeps its ID |
| Keep the governance words as pointers to the platform | No new definitions | rejected: they are this repository's own working vocabulary |
| Run the graph in the platform | Decision 0022's interim | rejected: the design model, and so the graph, is assembled in Pelorus |

## References

- [#100: Retire the company system](https://github.com/musher-dev/engineering-conventions/issues/100)
- [Decision 0000: Charter](0000-charter.md)
- [Decision 0007: Terminology and generated artifacts](0007-terminology-and-generated-artifacts.md)
- [Decision 0022: Interfaces and dependencies](0022-interfaces-and-dependencies.md)
- [EC-0010 Repository names](../../engineering-conventions/definitions/conventions/repository/repository-names.md)
