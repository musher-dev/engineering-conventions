---
title: Conventions and requirements have permanent IDs, and every diagnostic links to one
date: 2026-09-23
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0004 — Identifiers and diagnostic URLs

## Context

A requirement is referred to from many places: a check's output, a waiver in a consumer's declaration, a pull request
discussion, another convention. Every one of those references breaks if the requirement's name changes, and a
reference by title or by file path breaks the first time a document is reorganized. The organization already has ID
families in use, such as `CI-14` in the platform, of the form `PREFIX-NN`.

A diagnostic also needs to lead somewhere. The platform's checks print `[CI-06] path — message`; that tells an
engineer which rule fired but not where to read it.

## Decision

**Two kinds of ID, both permanent.**

| Thing | Format | Example |
| --- | --- | --- |
| Convention (a document) | `EC-` and four digits | `EC-0002` |
| Requirement | `<FAMILY>-<NN>`, a registered family prefix and a two- or three-digit number | `GHA-07` |

- IDs are monotonic within their sequence and **never reused**. A convention ID survives the document moving or being
  renamed.
- A requirement is never deleted. A retired requirement stays in its convention as a tombstone with `status: retired`
  and `replaced_by` naming its successor.
- Family prefixes are registered in `conventions/families.yml` before first use. A prefix is registered when its
  first requirement is written, never claimed in advance.
- A requirement that ports an existing check records it in `aliases` as `<repo>:<ID>`, such as `platform:CI-14`.
- The ID a check emits **is** the requirement ID. There is no mapping table between them to drift.

**Every requirement has exactly one anchor.** In its convention, each requirement has exactly one heading
`### <ID>`, so its GitHub anchor is the lowercased ID (`#gha-07`), independent of the title.

**The diagnostic format.** One line per finding:

```text
<severity> [<ID>] <path> — <message> <url>
```

```text
warning [GHA-07] .github/workflows/ci.yml — name "CI" should be "Validate Code": a workflow's name is its filename stem in Title Case. https://github.com/musher-dev/engineering-conventions/blob/v0.1.0/engineering-conventions/conventions/github-actions/workflow-files.md#gha-07
```

The URL is
`https://github.com/musher-dev/engineering-conventions/blob/<ref>/engineering-conventions/<path>#<anchor>`, where
`<ref>` is `v<version>` when the check runs from a release bundle and `main` otherwise. A tag is immutable (the release
tags ruleset forbids moving or deleting one), so a link printed today resolves to the same text next year.

The Vale style is the one exception. Its `link:` fields, which point a Vale alert at the terminology documentation,
use `main`: the style is generated and committed before the release that ships it is tagged, so it cannot know which
release that will be. A Vale alert therefore links to the current text, while a diagnostic from the Rego checks links
to the tag.

## Consequences

### Positive

- A waiver, a discussion or a log line that cites `GHA-07` stays correct through any reorganization.
- Engineers who know the platform's `CI-14` find its successor by alias.
- The diagnostic extends the platform's `[ID] path — message` format, so the shape is already familiar.

### Negative

- Retired requirements accumulate as tombstones. That is intended: the history of a rule is part of its meaning.
- Two-digit numbers cap a family at 99 active numbers before it needs three digits. The pattern accepts three.

### Neutral

- The generated `conventions/README.md` lists every ID, retired ones included.

## Enforcement

- `conventions invariants` fails when an ID in the committed `index.json` disappears or changes meaning, when a
  requirement heading `### <ID>` is missing or appears more than once, when a family is not registered, and when a check
  emits an ID that no convention declares.
- The convention frontmatter schema enforces the ID patterns and requires `replaced_by` on a retired requirement.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Reference requirements by title or path | No IDs to manage | rejected: breaks on the first rename |
| One flat sequence (`R-0001`) | Simplest allocation | rejected: an ID says nothing about its area, and existing families could not migrate unchanged |
| Family-prefixed IDs with explicit anchors | Matches the organization's existing IDs | **chosen** |
| Link diagnostics to `main` | Always the latest text | rejected for releases: the text could change under an old finding. Used only without release data |

## References

- `engineering-conventions/conventions/families.yml`
- [Decision 0003: Public visibility and consumption](0003-public-visibility-and-consumption.md)
- [Decision 0005: Status, severity and versioning](0005-status-severity-and-versioning.md)
