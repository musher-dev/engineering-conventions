---
title: OpenAPI documents are checked by Spectral, with a ruleset the conventions ship and each repository extends
date: 2026-10-01
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0023 — OpenAPI documents are checked by Spectral, with a ruleset the conventions ship and each repository extends

## Context

The rules for REST request and response bodies live today as guidance in the API repository: enum values in
`UPPER_SNAKE_CASE`, every error as `application/problem+json`, a discriminator on every `oneOf`, named body schemas,
`207` from a batch method, and the casing of properties and `operationId`s. Most of them are mechanical, and they
matter beyond one repository: any repository that offers an OpenAPI interface
([decision 0022](0022-interfaces-and-dependencies.md)) produces documents that generators and consumers read, and the
same mistakes cost the same everywhere. The API repository already lints its documents with Spectral, with its own
ruleset.

These rules are about the *contents* of a document, not about the files a repository keeps. The engines of
[decision 0001](0001-validation-engines.md) do not fit them well. Rego sees a parsed document, so each rule would need
JSONPath-like traversal, `$ref` resolution and source positions reimplemented, and its findings would point at a file
rather than a line. JSON Schema can describe a document's shape but not "every property name anywhere in it".
OpenAPI linters exist that do exactly this, with rule languages, `$ref` resolution, positions, and hundreds of rules
already written. Decision 0001 already allows a requirement to be `delegated` to such a tool, as GHA-33 delegates to
actionlint and zizmor.

Two linters were tried against the API repository's four largest OpenAPI documents, with the same ten rules written
for each: Spectral 6.16 and vacuum 0.30. Both ran the rules with their core functions and agreed on the findings.
They differ where the rules meet a real repository: Spectral resolves a relative `extends` from the ruleset's own
file and fails when it is missing, and supports `overrides`, a file and JSON pointer that turns a rule off in one
place. vacuum has no overrides, so every exemption would be a rule turned off everywhere, and a missing `extends`
is silently skipped, so a broken setup would report a clean document.

## Decision

We will check OpenAPI documents with **Spectral** as a delegated engine, under a new family `OAS` and convention
[EC-0037](../../engineering-conventions/definitions/conventions/openapi/openapi-documents.md) in a new topic
`openapi`, named for the document format as decision 0009 names topics.

- **The conventions ship a ruleset.** `checks/openapi/musher.spectral.yaml` is in the release bundle. It extends
  `spectral:oas` recommended and adds ten `musher-*` rules, each a warning, using Spectral's core functions only, so
  the standalone binary runs it with nothing else installed. OAS-01 (`engine: delegated`, `tool: spectral`) asks
  every OpenAPI interface document to pass it.
- **Each repository extends it, never copies it.** The repository's own ruleset is `.config/openapi/spectral.yaml`
  and lists `../../.conventions/openapi.spectral.yaml` under `extends` (OAS-02). The repository turns a rule off
  there, or in `overrides` for one place, with the reason beside it. Its own stricter rules go in the same file.
- **The launcher links and runs.** `conventions openapi [--ruleset FILE] [FILE...]` writes
  `.conventions/openapi.spectral.yaml` as a link to the ruleset in the bundle it belongs to, then runs
  `spectral lint --fail-severity warn` with the repository's ruleset, over the given files or every document an
  `openapi` interface in `.repo/outputs.toml` covers. Spectral is pinned in the launcher at the version this
  repository tests the ruleset with, like conftest, jq and Vale, so the bundle pin stays the only pin. The link is
  refreshed on every run, so it always names the pinned release, and it is never committed (OAS-04).
- **Validation runs it.** A validate workflow runs `conventions openapi`, directly or through a task (OAS-03).
  `conventions check` does not run Spectral: like GHA-33, the delegated requirement is enforced by the repository's
  own validation, and the conftest requirements check that the wiring exists.
- **The family is in `base-repo`.** An API can be offered by a service, a library or a specification, so every
  kind selects OAS. OAS-02 and OAS-03 find nothing until an `openapi` interface is declared.

This repository tests the ruleset itself: `task checks:openapi` lints one document that breaks each `musher-*` rule
exactly once and one that breaks none, and fails on any other result.

## Consequences

### Positive

- Every repository that offers an OpenAPI interface is linted by the same rules, at the release it pins, with
  findings that point at a line.
- An exemption is written once, in the repository's ruleset, with its reason, and is visible in review.
- The ten rules are short declarations in a file people already know how to read, not Rego that reimplements a
  linter.

### Negative

- A consumer that runs `conventions openapi` needs Spectral, which mise installs on first use. Without mise it needs
  Spectral on PATH.
- `conventions check` reports nothing about a document's contents: a repository that never runs
  `conventions openapi` sees only OAS-03.
- The link is a file the repository must ignore. A repository that forgets sees OAS-04 after its first run.

### Neutral

- The API repository's existing rules stay its own. It extends the shipped ruleset beside them and turns off a
  shipped rule only where its own is stricter.

## Enforcement

- OAS-02, OAS-03 and OAS-04 are conftest checks in `conventions.checks.openapi.documents`, with fixture
  repositories and near-misses.
- OAS-01 is delegated: `conventions openapi` fails on any warning in the repository's validation.
- `task checks:openapi`, part of `task check` and the `Checks` job, fails when the shipped ruleset stops firing each
  `musher-*` rule exactly once on its fixture, or fires on the clean one.
- `tests/test_launcher.py` fails when `SPECTRAL_VERSION` in the launcher differs from the pin in
  `.config/mise/config.toml`, and runs `conventions openapi` against a repository.
- `task bundle:verify` fails when the bundle lacks the ruleset.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Reimplement the rules in Rego | One engine for everything | rejected: `$ref` resolution, traversal and line positions would be rebuilt by hand, for rules a linter already expresses in a line each |
| vacuum as the engine | Faster, same rule format | rejected: no `overrides`, so exemptions are all or nothing, and a missing `extends` is skipped silently |
| Ship the ruleset; each repository copies it | No link, no launcher command | rejected: copies drift from the release, and an upgrade never reaches them |
| Run Spectral inside `conventions check` | One command | rejected: every check would need Spectral and the documents, and the findings would leave the report's shape |
| Spectral, a shipped ruleset, extended through a link | This decision | **chosen** |

## References

- [Decision 0001: Validation engines](0001-validation-engines.md)
- [Decision 0009: Definitions and checks](0009-definitions-and-checks.md)
- [Decision 0022: Interfaces and dependencies](0022-interfaces-and-dependencies.md)
- [Spectral: Rulesets](https://docs.stoplight.io/docs/spectral/e5b9616d6d50c-rulesets)
- [vacuum](https://quobix.com/vacuum/)
- [RFC 9457: Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457)
