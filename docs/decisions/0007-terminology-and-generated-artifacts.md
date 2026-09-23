---
id: "0007"
title: Terminology is structured data, and the artifacts generated from it are committed
date: 2026-09-23
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0007 — Terminology model and committed generated artifacts

## Context

The conventions depend on words: the responsibility tokens, the display forms, the aliases a check rejects. The same
list is needed in four places: the prose that explains it, the Rego checks that enforce it, the Vale style that flags
it in documentation, and the index a reader browses. Written four times, it drifts, and nothing notices until a check
and its documentation disagree in front of a contributor.

Some words are not this repository's to define. The platform owns the meaning of "audit", "drift", "gate" and
"conformance" in its governance vocabulary; the observability registry owns telemetry names; positioning and the
customer glossary belong to the platform and the company. A copy of their definitions here would be a second
authority.

Consumers must not need Python, yet generating four artifacts from one source needs a program.

## Decision

**Terminology is structured data in `terminology/`, validated by `terminology.schema.json`.** `global.yml` holds the
terms every convention uses. Each term has an ID (`gha.responsibility.validate`), a display name, tags that say which
token set it belongs to (`gha.responsibility`, `gha.capability`, `gha.action`), a stability, and either:

- a `definition`, when this repository owns the meaning, or
- an `authority` (`{repo, path}`), when another repository does. The term is listed so it can be found and linked, and
  its definition is never restated.

Each term may carry `aliases`, each with a `status` (`banned` or `discouraged`) and a `scope`: `identifier` (filenames
and names that checks read) or `prose` (Markdown that Vale reads). The two scopes are separate because a word can be
wrong in one and right in the other: `pr` is rejected as a filename token and is ordinary in a sentence. Display forms
(`api` → `API`) live beside the terms.

**Areas overlay the global terms.** An area (`terminology/areas/<area>.yml`) is a bounded-context overlay for a group
of repositories. It may add terms and aliases. It may never redefine a global term.

**Not mirrored here:** positioning vocabulary, the customer glossary, platform domain nouns and telemetry names. They
stay with their owners, and this repository does not ship rules about them.

**Generated artifacts are committed.** `conventions generate` writes:

| Artifact | Read by |
| --- | --- |
| `checks/data/index.json` | The Rego router and checks, as `data.conventions.index`: requirements, profiles, token sets, banned identifier tokens, display forms |
| `checks/vale/MusherConventions/{Terms,Discouraged}.yml` | Vale, for prose-scope aliases |
| `conventions/README.md` | Readers: every convention and requirement ID, retired ones included |

All three are deterministic (sorted keys, fixed formatting) and committed. `conventions generate --check` fails when
a committed artifact differs from what the sources produce. The Python package that generates them is authoring
tooling; a consumer uses the committed output and never runs it.

## Consequences

### Positive

- One list feeds the prose, the checks, the Vale style and the index; they cannot disagree.
- A pull request that changes a term shows the effect on the generated data in its own diff.
- Consumers need no Python and no build step: the bundle contains the generated files.

### Negative

- Contributors must run `task generate` after editing a convention or a term, or the drift check fails. The error names
  the command.
- Generated files in the diff add review noise.

### Neutral

- The Vale style is named `MusherConventions`, distinct from the platform's customer-glossary style.

## Enforcement

- `task generate:check` (in the `Content` job of `Validate`) fails on any drift between sources and committed artifacts.
- `conventions invariants` fails when an area overlay redefines a global term.
- `terminology.schema.json` requires a term to have exactly one of `definition` and `authority`.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Hand-maintained lists in each place | No generator | rejected: four copies drift |
| Generate at consumer check time | Nothing generated committed | rejected: every consumer would need the generator and its runtime |
| Structured source, committed generated artifacts, drift check | This decision | **chosen** |

## References

- `engineering-conventions/terminology/README.md`
- `engineering-conventions/checks/schemas/terminology.schema.json`
- [Decision 0001: Validation engines](0001-validation-engines.md)
- [Decision 0006: GitHub Actions naming vocabulary](0006-github-actions-naming-vocabulary.md)
