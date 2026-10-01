---
title: OpenAPI documents are linted by Spectral's own OpenAPI and OWASP rulesets, from each repository's ruleset
date: 2026-10-01
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0023 — OpenAPI documents are linted by Spectral's own OpenAPI and OWASP rulesets, from each repository's ruleset

## Context

Any repository that offers an OpenAPI interface ([decision 0022](0022-interfaces-and-dependencies.md)) produces
documents that generators and consumers read, and some mistakes cost the same everywhere: a document that does not
validate, an operation with no security scheme, an unbounded array, an undeclared error response. Linters that catch
those already exist, with rule languages, `$ref` resolution, source positions and maintained rulesets.

These rules are about the *contents* of a document, not about the files a repository keeps. The engines of
[decision 0001](0001-validation-engines.md) do not fit them well. Rego sees a parsed document, so each rule would need
JSONPath-like traversal, `$ref` resolution and source positions reimplemented, and its findings would point at a file
rather than a line. JSON Schema can describe a document's shape but not "every operation has a security scheme".
Decision 0001 already allows a requirement to be `delegated` to such a tool, as GHA-33 delegates to actionlint and
zizmor.

Other rules are not mechanical safety but API design: how enum values are cased, how an `operationId` reads, which
media type an error body uses, when a `oneOf` needs a discriminator. Those are choices about a product's surface. The
charter ([decision 0000](0000-charter.md)) keeps product decisions with the repository that owns them, and a shared
ruleset that encoded one product's choices would make every other repository exempt them one by one.

Two linters were compared: Spectral 6.16 and vacuum 0.30. They differ where a ruleset meets a real repository:
Spectral fails when an `extends` cannot be loaded and supports `overrides`, a file and JSON pointer that turns a rule
off in one place. vacuum has no overrides, so every exemption would be a rule turned off everywhere, and a missing
`extends` is silently skipped, so a broken setup would report a clean document. Spectral's maintainers also publish
`spectral:oas`, built in, and an OWASP API security ruleset, released to npm with exact versions.

## Decision

We will check OpenAPI documents with **Spectral** as a delegated engine, using **its own maintained rulesets**,
under a new family `OAS` and convention
[EC-0037](../../engineering-conventions/definitions/conventions/openapi/openapi-documents.md) in a new topic
`openapi`, named for the document format as decision 0009 names topics.

- **The conventions author no OpenAPI rules.** The requirement is that the mechanism exists and is wired: every
  OpenAPI interface document passes the repository's Spectral ruleset (OAS-01, `engine: delegated`, `tool:
  spectral`).
- **Each repository's ruleset extends two upstream rulesets.** `.config/openapi/spectral.yaml` lists `spectral:oas`
  and `@stoplight/spectral-owasp-ruleset` by an exact-release URL,
  `https://unpkg.com/@stoplight/spectral-owasp-ruleset@<x.y.z>/dist/ruleset.mjs` (OAS-02). Spectral fetches it at
  load time, so the standalone binary needs nothing installed beside it, and an exact release changes only in a
  reviewed pull request. An unversioned URL or a range is rejected, because it changes what passes without a change
  in the repository.
- **API design lives in the producing repository.** Its own rules, such as casing, error media types or
  discriminators, go in the same ruleset beside the two it extends, and so do its exemptions, each with its reason.
- **Validation runs it.** A validate workflow runs `conventions openapi` or `spectral lint` with the repository's
  ruleset, directly or through a task (OAS-03). `conventions check` does not run Spectral: like GHA-33, the delegated
  requirement is enforced by the repository's own validation, and the conftest requirements check that the wiring
  exists.
- **The launcher is thin glue.** `conventions openapi [--ruleset FILE] [FILE...]` runs `spectral lint` with the
  repository's ruleset over the given files, or every document an `openapi` interface in `.repo/outputs.toml` covers.
  Spectral is pinned in the launcher, like conftest, jq and Vale, so the bundle pin stays the only tool pin. The
  bundle ships no ruleset.
- **The family is in `base-repo`.** An API can be offered by a service, a library or a specification, so every
  kind selects OAS. OAS-02 and OAS-03 find nothing until an `openapi` interface is declared.

## Consequences

### Positive

- Every repository that offers an OpenAPI interface is linted by rules maintained upstream, with findings that point
  at a line, and gets their fixes by raising one pin.
- Nothing here has to be kept in step with Spectral's or OWASP's rules, and no repository exempts another product's
  design choices.
- An exemption is written once, in the repository's ruleset, with its reason, and is visible in review.

### Negative

- Loading the OWASP ruleset needs the network, on every run, unless the repository installs the npm package and
  extends it by name, which OAS-02 does not accept.
- `conventions check` reports nothing about a document's contents: a repository that never lints its documents sees
  only OAS-03.
- Repositories that share API-design rules each write them; a shared design ruleset, if one emerges, is published by
  the repository that owns that design.

### Neutral

- The OWASP ruleset reports many findings on a document written without it, most at `error`. A repository adopting it
  decides each one in its ruleset.

## Enforcement

- OAS-02 and OAS-03 are conftest checks in `conventions.checks.openapi.documents`, with fixture repositories and
  near-misses.
- OAS-01 is delegated: Spectral fails on a finding at `error` severity in the repository's validation.
- `task checks:openapi`, part of `task check` and the `Checks` job, lints a document that should pass and one that
  should fail with a ruleset shaped as OAS-02 asks, and fails unless both upstream rulesets load and report as
  expected.
- `tests/test_launcher.py` fails when `SPECTRAL_VERSION` in the launcher differs from the pin in
  `.config/mise/config.toml`, and runs `conventions openapi` against a repository.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Reimplement the rules in Rego | One engine for everything | rejected: `$ref` resolution, traversal and line positions would be rebuilt by hand |
| vacuum as the engine | Faster, same rule format | rejected: no `overrides`, so exemptions are all or nothing, and a missing `extends` is skipped silently |
| Ship a ruleset of API-design rules each repository extends | One house style | rejected: design rules are product decisions, owned where the API is; each other repository would exempt them |
| Require only `spectral:oas` | Fewer findings to adopt | rejected: it checks shape, not the security risks the OWASP ruleset covers |
| Extend the OWASP ruleset as an npm package | Works offline | rejected for now: it needs Node and a lockfile in every repository that lints a document |
| Spectral, `spectral:oas` and the OWASP ruleset at an exact release, from the repository's ruleset | This decision | **chosen** |

## References

- [Decision 0000: Charter](0000-charter.md)
- [Decision 0001: Validation engines](0001-validation-engines.md)
- [Decision 0009: Definitions and checks](0009-definitions-and-checks.md)
- [Decision 0022: Interfaces and dependencies](0022-interfaces-and-dependencies.md)
- [Spectral: Rulesets](https://docs.stoplight.io/docs/spectral/e5b9616d6d50c-rulesets)
- [Spectral OWASP API Security ruleset](https://github.com/stoplightio/spectral-owasp-ruleset)
- [vacuum](https://quobix.com/vacuum/)
