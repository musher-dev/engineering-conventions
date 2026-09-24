---
title: The product separates what is defined from what checks it, in definitions/ and checks/
date: 2026-09-24
status: accepted
deciders: ["@justinmerrell"]
supersedes: ["0008"]
---

# 0009 — Definitions and checks

## Context

[Decision 0008](0008-repository-layout.md) split the repository into two levels: the machinery at the root and the
product in `engineering-conventions/`. Inside the product, though, the source of truth and its implementations sat side
by side: `conventions/`, `terminology/` and `profiles/` next to `checks/`, `examples/`, `bin/` and `src/`. A reader
could not tell from a path whether a file *decides* something or *validates* something already decided, and that is the
first question someone new to the repository asks.

The distinction is real and already load-bearing. Conventions, terminology and profiles are authored and reviewed as
decisions, and every generated file is derived from them. Rego policies, schemas and generated data implement checks
of those decisions ([decision 0001](0001-validation-engines.md)). One can change without the other: a false positive
is fixed in `checks/` alone, and prose is clarified in the definitions alone.

## Decision

**The product has a definition layer and a check layer.** Conventions, terminology and profiles live under
`engineering-conventions/definitions/`. Everything that implements a check stays in `checks/`. The layout and the
placement test are in [How this repository is organized](../repository.md).

**Tooling stays where its tools look.** `bin/` stays at the product root because mise puts a released tool's `bin/` on
PATH; `src/` and `tests/` follow the Python layout that uv, ruff and pytest expect beside `pyproject.toml`. They are
labeled as tooling in the documentation rather than moved under a wrapper directory.

The rest of decision 0008 is carried forward unchanged:

- **Two levels.** The repository root holds the machinery; `engineering-conventions/`, named after the repository,
  holds the product.
- **The product directory is the bundle**, minus the authoring tooling and the Rego unit tests, plus
  `checks/data/release.json` naming the version.
- **The product never reaches upward.** No product file references a path above the product directory.
- **Everything that implements a check lives in `checks/`**, named for the idea it holds rather than `rules/`.
- **Generated files are marked** `linguist-generated` in `.gitattributes`, and `task generate:check` fails on drift.
- **Topics are created when they have content**, never empty in anticipation of one.
- **Diagnostic URLs include the product directory**: `.../blob/<ref>/engineering-conventions/<path>#<anchor>`, with
  `<path>` relative to the product directory. A convention's path now starts `definitions/conventions/`.

## Consequences

### Positive

- A path says what a file is: `definitions/` is decided, `checks/` validates, `examples/` shows, `bin/` and `src/`
  run.
- The README can draw the flow from definitions to checks to consumers with one directory per box.

### Negative

- Every document path gains a `definitions/` segment. A link to a convention on `main` from outside the repository
  breaks; a link printed by a released bundle does not, because it names the release tag.
- One more level of nesting under an already nested product directory.

### Neutral

- Requirement IDs, anchors and waivers are unaffected: they resolve by ID, not path.

## Enforcement

- `task bundle:verify` fails when the tarball's top level under `engineering-conventions/` holds anything outside
  `README.md bin checks definitions examples`.
- `conventions invariants` fails when a convention's directory under `definitions/conventions/` differs from its
  `topic`.
- `task generate:check` fails when a generated file is stale.
- That a file sits in the right layer, and that the product never reaches upward, is `review-only`.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Keep decision 0008's flat product | Definitions beside checks | rejected: a path does not say whether a file decides or validates |
| `definitions/` and `checks/` | Two layers, tooling labeled | **chosen** |
| Also wrap `checks/`, `bin/` and `src/` in `enforcement/` | Three wrapper directories | rejected: mise finds `bin/` at the root, `src/` is the Python layout, and in 0.x nothing is enforced |

## References

- [Decision 0008: Repository layout](0008-repository-layout.md), superseded
- [Decision 0001: Validation engines](0001-validation-engines.md)
- [How this repository is organized](../repository.md)
