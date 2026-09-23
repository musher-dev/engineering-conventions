# Decision record template

Copy the block below into `NNNN-kebab-title.md`, taking the next unused number from the [index](README.md), and add a
row to the index. The frontmatter is validated against
[`decision.schema.json`](decision.schema.json). The number is the filename's; the frontmatter does not repeat it.

- `status` is one of `proposed`, `accepted`, `rejected`, `deprecated` or `superseded`.
- A superseded decision keeps its file, gains `superseded_by`, and its status becomes `superseded`. The decision that
  replaces it lists it in `supersedes`.
- Numbers are never reused, including for rejected decisions.

````markdown
---
title: Short, decision-first title
date: YYYY-MM-DD
status: proposed
deciders: ["@handle"]
supersedes: []
---

# NNNN — Short, decision-first title

## Context

The forces in tension. What problem triggers the decision, and why now? Cite the evidence: issues, conventions,
requirement IDs, other decisions. Two to five short paragraphs.

## Decision

One unambiguous claim, stated as "We will ..." or as an imperative. Name the conventions, requirements, schemas or
files that change.

## Consequences

### Positive

- ...

### Negative

- ...

### Neutral

- ...

## Enforcement

How the decision is verified mechanically: a requirement ID and its check, an invariant in `conventions invariants`,
a schema, a CI job. Say what it fails on. If nothing enforces it, write `review-only` and say what a reviewer looks
for.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| A | ... | rejected: ... |
| B | ... | **chosen** |

## References

- ...
````
