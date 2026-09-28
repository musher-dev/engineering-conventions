---
id: EC-0021
title: Decision records
summary: >-
  A repository's decision records live in one directory, docs/decisions/ by
  default, as NNNN-kebab-slug records numbered without gaps. Each carries
  frontmatter valid against the decision schema, links to the records it
  supersedes or amends in both directions, has Context, Decision,
  Consequences and Enforcement sections, and is linked from the directory's
  index.
status: draft
topic: decisions
applies_to:
  paths:
    - docs/decisions/**
    - .repo/conventions.toml
created: 2026-09-28
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
implementations:
  - repo: musher-dev/platform
    check: DC-10
    mode: blocking
  - repo: musher-dev/platform
    check: DC-11
    mode: blocking
  - repo: musher-dev/platform
    check: DC-12
    mode: blocking
  - repo: musher-dev/platform
    check: DC-13
    mode: blocking
  - repo: musher-dev/platform
    check: DC-14
    mode: blocking
  - repo: musher-dev/platform
    check: DC-16
    mode: blocking
references:
  - title: "MADR: Markdown Architectural Decision Records"
    url: https://adr.github.io/madr/
  - title: "Michael Nygard: Documenting Architecture Decisions"
    url: https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions
requirements:
  - id: DEC-01
    title: A decision record is named NNNN-kebab-slug in the repository's decisions directory
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.decisions.records
    aliases: ["platform:DC-10", "platform:DC-15"]
  - id: DEC-02
    title: A decision record's frontmatter is valid against the decision schema
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.decisions.records
    aliases: ["platform:DC-12"]
  - id: DEC-03
    title: Decision numbers are unique and contiguous from 0000 or 0001
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.decisions.records
    aliases: ["platform:DC-11"]
  - id: DEC-04
    title: Supersede and amend links agree in both directions, and only a superseded record names its successors
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.decisions.records
    aliases: ["platform:DC-14"]
  - id: DEC-05
    title: A decision record has Context, Decision and Consequences sections
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.decisions.records
    aliases: ["platform:DC-13"]
  - id: DEC-06
    title: A decision record says how it is enforced in an Enforcement section
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.decisions.records
    aliases: ["platform:DC-16"]
  - id: DEC-07
    title: The decisions directory's index links every record
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.decisions.records
---

# Decision records

A decision record says what was decided, why, and what follows from it, at the time it was decided. Records are only
useful as a set: a reader follows a decision to the one that replaced it, finds every decision from the index, and
trusts that a number names one record forever. This convention fixes the shape that makes the set navigable and
checkable, in every repository that keeps one.

## Scope

This convention covers the decision records of any repository checked against a release of
`musher-dev/engineering-conventions`. A repository with no decisions directory is not asked to create one: every
requirement here reads only the records that exist. What a repository decides, and when a decision deserves a record,
is that repository's own business.

The records follow [MADR](https://adr.github.io/madr/), which this convention cites rather than restates. Where it
differs from MADR 4.0, the difference is listed [below](#differences-from-madr-4).

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). It adopts the decision-record checks of
`musher-dev/platform` (DC-10 to DC-16), which retires them once it pins a release that carries this convention; each
requirement lists the check it replaces in `aliases`. Its requirements are `proposed` at severity `warning`, like
every requirement in the 0.x series.

## Where the records are

By default the records are Markdown files in `docs/decisions/`, the directory MADR suggests, with an index beside
them:

```text
docs/decisions/
├── README.md                      the index (DEC-07)
├── template.md                    optional; not a record
├── 0000-charter.md
└── 0001-use-one-queue-for-background-work.md
```

A repository that keeps its records elsewhere, or as pages of a documentation site, says so in its conventions
declaration, `.repo/conventions.toml` ([EC-0001](../adoption/conventions-declaration.md)):

```toml
# .repo/conventions.toml
[decisions]
path = "docs/site/(docs)/adrs"
form = "directory"
page = "+page.md"
```

| Field | Meaning | Default |
| --- | --- | --- |
| `path` | The directory that holds the records, relative to the repository root. Its last segment is `decisions` or `adrs`: the runner reads Markdown as text only under a directory with one of those names. | `docs/decisions` |
| `form` | `file`: each record is `<path>/NNNN-slug.md`, and the index is `<path>/README.md`. `directory`: each record is `<path>/NNNN-slug/<page>`, and the index is `<path>/<page>`, which suits a site generator that routes a directory to a page. | `file` |
| `page` | In the `directory` form, the file each record's directory holds, and the index's name. | `README.md` |

In either form, `template.md` (or a `template/` directory) is a template, not a record. In the `directory` form, other
files inside a record's directory, such as images, are not checked.

## The record

```markdown
---
title: Use one queue for background work
date: 2026-01-15
status: accepted
deciders: ["@example-dev"]
supersedes: ["0002"]
---

# 0003 — Use one queue for background work

## Context
## Decision
## Consequences
## Enforcement
```

The frontmatter's authoritative shape is `checks/schemas/decision.schema.json`, and DEC-02 checks it:

| Field | Meaning |
| --- | --- |
| `title` | The decision, in sentence case. Required. |
| `date` | When the decision reached its current status, as `YYYY-MM-DD`. Required. |
| `status` | `proposed`, `accepted`, `rejected`, `deprecated` or `superseded`. Required. |
| `deciders`, `consulted`, `informed` | Who decided, whose opinion was sought, who is kept up to date. |
| `supersedes`, `superseded_by` | Records this one replaces, and the records that replace it. |
| `amends`, `amended_by` | Records this one changes in part, and the records that change it. An amended record stays in force, and its status does not change. |

The record's number is its name's; the frontmatter does not repeat it. A number in a link field is quoted (`"0009"`),
since YAML reads an unquoted `0009` as a number and drops its leading zeros.

## Differences from MADR 4

| MADR 4.0 | Here | Why |
| --- | --- | --- |
| `decision-makers` | `deciders` | The name MADR 2 and 3 used, and the one existing records carry. The schema rejects `decision-makers`, so a record copied from the MADR template is caught rather than silently missing its deciders. |
| `status: superseded by ADR-0123` | `status: superseded` with `superseded_by: ["0123"]` | A list a check can follow in both directions (DEC-04), and room for more than one successor. |
| No amendment field | `amends`, `amended_by` | A decision that changes part of another is linked like one that replaces it, without marking the other superseded. |
| `## Context and Problem Statement`, `## Decision Outcome` with `### Consequences` | `## Context`, `## Decision`, `## Consequences` | A level-2 heading that starts with the word passes, so MADR's `Context and Problem Statement` and `Decision Outcome` do; its level-3 `Consequences` does not (DEC-05). |
| `### Confirmation`, optional | `## Enforcement`, required | The same idea, required, because a decision nothing holds decays unnoticed (DEC-06). |

## Requirements

### DEC-01

**A decision record is named NNNN-kebab-slug in the repository's decisions directory.**

The number orders the records and is how every other record, commit and review cites one. The slug says what the
record decides to a reader scanning a listing. A record named any other way has no number to cite, and a file nested
where no record belongs is missed by the index and every check. `README.md` and `template.md` are not records.

**Correct:**

```text
docs/decisions/0007-store-sessions-in-the-database.md
docs/site/(docs)/adrs/0007-store-sessions-in-the-database/+page.md    # form = "directory"
```

**Incorrect:**

```text
docs/decisions/0007_Store_Sessions.md          # not kebab-case
docs/decisions/store-sessions.md               # no number
docs/decisions/archive/0002-old.md             # nested below the records
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform DC-10, DC-15

### DEC-02

**A decision record's frontmatter is valid against the decision schema.**

The frontmatter is what tools read: an index generator, the link checks of DEC-04, a search for every accepted
decision. A missing status, an unquoted number or a field MADR renamed is a value those tools cannot use. One finding
reports the first problem and how many more there are.

**Correct:**

```yaml
---
title: Store sessions in the database
date: 2026-02-01
status: accepted
amends: ["0001"]
---
```

**Incorrect:**

```yaml
---
title: Store sessions in the database
status: done                                   # not a status
amends: [0001]                                 # a number, not "0001"
decision-makers: ["@example-dev"]              # MADR 4's name; the field is deciders
---
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform DC-12

### DEC-03

**Decision numbers are unique and contiguous from 0000 or 0001.**

A number is a record's permanent address. Two records with one number make every citation of it ambiguous, and a gap
means a record was deleted or renumbered, which breaks every link to it. A decision that no longer holds keeps its
record and its number, with its status changed: `rejected`, `deprecated` or `superseded`.

**Correct:**

```text
0000-charter.md
0001-use-one-queue.md
0002-store-sessions-in-the-database.md
```

**Incorrect:**

```text
0001-use-one-queue.md
0001-use-a-cache.md                            # 0001 twice
0004-store-sessions-in-the-database.md         # 0002 and 0003 missing
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform DC-11

### DEC-04

**Supersede and amend links agree in both directions, and only a superseded record names its successors.**

A reader of an old decision must learn that it no longer holds, and a reader of the new one must find what it
replaced. When only one side records the link, whichever record the reader starts from may be the one that says
nothing. A record listed in `superseded_by` has status `superseded`; the schema (DEC-02) requires `superseded_by` once
the status is `superseded`. The finding is on the record that lacks the link, the file to change.

**Correct:**

```yaml
# 0002-store-sessions-in-memory.md
status: superseded
superseded_by: ["0004"]

# 0004-store-sessions-in-the-database.md
status: accepted
supersedes: ["0002"]
```

**Incorrect:**

```yaml
# 0002-store-sessions-in-memory.md
status: accepted                               # but superseded_by is set
superseded_by: ["0004"]

# 0004-store-sessions-in-the-database.md
status: accepted
amends: ["0003"]                               # 0003 does not list 0004 in amended_by
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform DC-14

### DEC-05

**A decision record has Context, Decision and Consequences sections.**

These are the parts that make a record worth keeping: the forces that made a decision necessary, the decision
itself, and what it costs. A record without its context cannot be re-evaluated when the context changes, and one
without consequences hides the price that was accepted. Each is a level-2 heading that starts with the word, so
`## Context and Problem Statement` counts as Context.

**Correct:**

```markdown
## Context
## Decision
## Consequences
```

**Incorrect:**

```markdown
## Background
## Decision
### Consequences                               # level 3, under Decision
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform DC-13

### DEC-06

**A decision record says how it is enforced in an Enforcement section.**

A decision that nothing checks is kept only as long as people remember it. The `## Enforcement` section names the
check that holds the decision (a requirement ID, a test, a lint rule, a CI job) and what it fails on, or says
`review-only` and what a reviewer looks for. `review-only` is an honest answer; an empty or missing section is not.
The check finds the section and that it is not empty; the reviewer checks that it names a real check. A repository
whose older records predate the section waives this requirement for them by path.

**Correct:**

```markdown
## Enforcement

GHA-07, checked by conftest, fails a workflow whose name is not its filename stem.
```

**Incorrect:**

```markdown
## Enforcement

## References
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform DC-16

### DEC-07

**The decisions directory's index links every record.**

The index is where a reader starts: what has been decided, in order, and what is still in force. A record it omits is
one nobody finds by reading. The index is `README.md` in the decisions directory, or the `page` of the `directory`
form, and a Markdown link, inline or reference-style, whose target holds the record's name counts.

**Correct:**

```markdown
| ID | Decision | Status |
| --- | --- | --- |
| [0000](0000-charter.md) | Charter | accepted |
| [0001](0001-use-one-queue.md) | Use one queue for background work | accepted |
```

**Incorrect:**

```markdown
| ID | Decision | Status |
| --- | --- | --- |
| [0000](0000-charter.md) | Charter | accepted |
```

Checked by: conftest · Severity: warning · Since: 0.6.0

## References

- [MADR: Markdown Architectural Decision Records](https://adr.github.io/madr/)
- [Michael Nygard: Documenting Architecture Decisions](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [EC-0001 Conventions declaration](../adoption/conventions-declaration.md)
- `checks/schemas/decision.schema.json`
