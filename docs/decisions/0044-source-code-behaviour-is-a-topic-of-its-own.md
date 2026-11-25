---
title: Conventions about what source code does live in a source-code topic, with a family per concern
date: 2026-11-18
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0044 — Conventions about what source code does live in a source-code topic, with a family per concern

## Context

The [charter](0000-charter.md) makes this repository the home of "shared engineering language, repository structures
and implementation expectations". Every topic so far governs a repository's structure: a file surface such as
`.github/workflows/` or `.devcontainer/`, or a tool such as OpenAPI or OpenTofu, as
[docs/authoring.md](../authoring.md) defines a topic ("the part of a repository a group of conventions governs, named
for its file surface or tool"). None governs what the code in a repository does, so there is nowhere to put an
implementation expectation.

Two such expectations are general enough to belong here. Status that several places derive differently contradicts
itself exactly when something is wrong, and a retry or a wait without a bound hides a failure as activity. Both recur
across services, libraries and tools, and one repository already enforces stricter local checks for them under
prefixes of its own, which need an upstream requirement to cite.

A first draft put them in a topic named `reliability`. That is a concern, not a surface: the same code could as well be
filed under observability, correctness or resilience, and a topic named for a concern gives a new requirement no test
for whether it belongs. Every earlier new family or topic came with a decision record
([0006](0006-github-actions-naming-vocabulary.md), [0016](0016-adopted-rules-get-new-families.md),
[0020](0020-dev-container-files-get-their-own-family.md)), and this one does too.

[Decision 0016](0016-adopted-rules-get-new-families.md) left rules that "need code parsing, execution or network
access" upstream, because the engines consumers run cannot check them. That was about rules adopted from another
repository's CLI; requirements written here can still be judged in review (`engine: review`), as GHA-34 to GHA-37 are.

## Decision

**Conventions about what source code does live in one topic, `source-code`, named for the surface it governs: the
source files of any language.** Each concern within it is a family, named for the concern:

| Prefix | Title | Convention |
| --- | --- | --- |
| STATUS | Derived status | [EC-0045](../../engineering-conventions/definitions/conventions/source-code/derived-status.md) |
| RETRY | Bounded retries and waits | [EC-0046](../../engineering-conventions/definitions/conventions/source-code/bounded-retries.md) |
| TRUST | Trust boundaries | [EC-0047](../../engineering-conventions/definitions/conventions/source-code/trust-boundaries.md) |

- **The definition of a topic is unchanged.** Source files are a file surface, so the topic fits the definition in
  [docs/authoring.md](../authoring.md) as written; only the family, which [decision 0004](0004-identifiers-and-diagnostic-urls.md)
  already leaves free to name a concern, carries the concern. A later concern about code, such as error handling or
  logging, is a new family in this topic, not a new topic.
- **A requirement about code may read the configuration that enforces it.** STATUS-06 reads a pyright setting because
  it is the one machine check behind STATUS-05, as TOOL-08 reads a `devcontainer.json`. A requirement whose subject is
  the configuration itself belongs to that configuration's topic.
- **Requirements are judged in review unless a portable check exists.** Code is written in too many forms for a check
  every consumer can run. A repository may hold itself to a stricter local check, under a prefix of its own that
  collides with no family here, citing the requirement it implements; the charter allows a stricter local rule.
- **Every kind of repository is checked.** The three families are in the `base-repo` profile, not only `service`: a
  library retries and honours `Retry-After`, a command-line tool shows a status, and a site receives untrusted input.
  Each requirement applies only where its code exists, as OAS, COPY and IMAGE already do.
- **Every requirement starts `proposed` at `warning`** ([decision 0005](0005-status-severity-and-versioning.md)), so
  the families arrive in a patch release of the 0.x series.

## Consequences

### Positive

- An implementation expectation has a home, and a new one has a test for where it goes: if its subject is what code
  does, it is a family in `source-code`.
- No existing rule or definition changes, so no earlier decision is amended.
- Repositories that already enforce these concerns locally have one upstream ID to cite.

### Negative

- One topic will hold many unrelated families as code concerns are added, so its README carries more of the reading
  order than other topics' do.
- Review-only requirements produce no findings; a consumer sees them only in the documentation and its own review.

### Neutral

- A link to the first draft's `reliability/` path breaks; the IDs, which every waiver and citation resolves against,
  are unchanged.

## Enforcement

- `task cli:invariants` fails when a convention's directory differs from its `topic`, when the topic has no README
  or a missing or stale row in the root README, and when a family is unregistered.
- STATUS-06 is a conftest check with a fixture and a near-miss; the rest are `review-only`. A reviewer rejects a
  requirement placed in `source-code` whose subject is a file other than source code, and a new topic named for a
  concern rather than a surface or a tool.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| A `reliability` topic | The first draft | rejected: a concern, not a surface; it gives the next requirement no test for whether it belongs |
| Amend the definition of a topic to admit concerns | Topics named for a surface, a tool or a concern | rejected: changes the vocabulary every topic is judged by, to admit one case the current definition already fits |
| A `source-code` topic, a family per concern | This decision | **chosen**: the smallest change, no existing rule amended |
| Only in the `service` profile | Code behaviour as a service concern | rejected: SDKs, tools and sites retry, wait, show status and receive untrusted input too |

## References

- [Decision 0000: Charter](0000-charter.md)
- [Decision 0004: Identifiers and diagnostic URLs](0004-identifiers-and-diagnostic-urls.md)
- [Decision 0005: Status, severity and versioning](0005-status-severity-and-versioning.md)
- [Decision 0016: Rules adopted from other repositories get new families](0016-adopted-rules-get-new-families.md)
- [Decision 0020: Dev container files get their own family](0020-dev-container-files-get-their-own-family.md)
- [Authoring conventions](../authoring.md), the definition of a topic
