# Decisions

These conventions govern a repository's decision records: the short documents that say what was decided, why, and
what follows. They apply only to a repository that keeps such records.

The governing rule, in one sentence:

> **Keep decision records as numbered, linked MADR records in one directory, with valid frontmatter, an Enforcement
> section and an index that links them all.**

## Status

The convention is a **draft**, owned by this repository, and every requirement is `proposed` at severity `warning`.
It adopts the decision-record checks of `musher-dev/platform`, DC-10 to DC-16.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0021 Decision records](decision-records.md) | DEC-01 – DEC-07 | Where records are and how they are named, their frontmatter, numbering, links, sections and index |

## Quick reference

| What | Default | Declared in `.repo/conventions.toml` |
| --- | --- | --- |
| Directory | `docs/decisions/` | `[decisions] path` |
| Record | `NNNN-kebab-slug.md` | `form = "directory"`: `NNNN-kebab-slug/<page>` |
| Index | `README.md` | the `page` in the `directory` form |
| Frontmatter | `title`, `date`, `status`; optional `deciders`, `consulted`, `informed`, `supersedes`, `superseded_by`, `amends`, `amended_by` | |
| Sections | `## Context`, `## Decision`, `## Consequences`, `## Enforcement` | |
