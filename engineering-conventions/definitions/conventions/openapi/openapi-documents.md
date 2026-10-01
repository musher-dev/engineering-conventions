---
id: EC-0037
title: OpenAPI documents
summary: >-
  Every OpenAPI document a repository offers as an interface passes the
  repository's Spectral ruleset, which extends Spectral's own OpenAPI
  ruleset and the OWASP API security ruleset at an exact release, and a
  validate workflow runs it.
status: draft
topic: openapi
applies_to:
  paths:
    - .repo/outputs.toml
    - .config/openapi/spectral.yaml
    - .config/openapi/spectral.yml
    - Taskfile.yml
    - .github/workflows/*.yml
    - .github/workflows/*.yaml
created: 2026-10-01
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "Spectral: Rulesets"
    url: https://docs.stoplight.io/docs/spectral/e5b9616d6d50c-rulesets
  - title: "Spectral: The OpenAPI ruleset"
    url: https://docs.stoplight.io/docs/spectral/4dec24461f3af-open-api-rules
  - title: "Spectral OWASP API Security ruleset"
    url: https://github.com/stoplightio/spectral-owasp-ruleset
  - title: "OWASP API Security Top 10 (2023)"
    url: https://owasp.org/API-Security/editions/2023/en/0x11-t10/
requirements:
  - id: OAS-01
    title: Every OpenAPI interface document passes the repository's Spectral ruleset
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: delegated
      tool: spectral
      check: conventions openapi
  - id: OAS-02
    title: The Spectral ruleset extends spectral:oas and the OWASP API security ruleset at an exact release
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.openapi.documents
  - id: OAS-03
    title: A validate workflow lints the OpenAPI interfaces with the repository's ruleset
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.openapi.documents
---

# OpenAPI documents

An OpenAPI document is what a client generator, a documentation site and a consumer's reviewer read instead of the
code. A malformed document breaks every generator, and a document that leaves an operation unauthenticated, an array
unbounded or an error undeclared is copied into every SDK and every consumer. Those mistakes are mechanical, and
established linters already check them: [Spectral](https://github.com/stoplightio/spectral)'s own OpenAPI ruleset
and the [OWASP API security ruleset](https://github.com/stoplightio/spectral-owasp-ruleset) its maintainers publish.
This convention asks each repository that offers an OpenAPI interface to run both, and checks that it does.

## Scope

This convention covers the OpenAPI documents of every interface declared with `format = "openapi"` in
`.repo/outputs.toml` ([EC-0030](../interfaces/interfaces-declaration.md)), and the ruleset, task and workflow step
that lint them. A repository with no such interface meets every requirement.

It sets no API-design rules of its own. How enums are cased, how an `operationId` reads, which media type an error
uses, and how a resource is modelled are decisions of the product that owns the API. They belong in that repository's
own ruleset, which extends the two required ones and adds its rules beside them.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirements are `proposed` at severity
`warning`, like every requirement in the 0.x series. The rules themselves belong to their upstream rulesets, at the
release each repository pins. The reasons are in [decision
0023](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0023-openapi-documents-delegate-to-spectral.md).

## How it fits together

```text
spectral:oas                               built into Spectral
@stoplight/spectral-owasp-ruleset@X.Y.Z    by an exact-release URL
        ▲  extends
.config/openapi/spectral.yaml              the repository's ruleset (OAS-02): its own rules and exemptions
        ▲  --ruleset
conventions openapi | spectral lint        run by a validate workflow (OAS-03); fails on an error (OAS-01)
```

The repository's ruleset is ordinary Spectral:

```yaml
# .config/openapi/spectral.yaml
extends:
  - spectral:oas
  - https://unpkg.com/@stoplight/spectral-owasp-ruleset@2.0.1/dist/ruleset.mjs
rules:
  # The gateway in front of the API adds rate-limit headers to every response.
  owasp:api4:2023-rate-limit: "off"
overrides:
  # The health check is public by design.
  - files: ["../../api/contracts/openapi/public.yaml#/paths/~1healthz/get"]
    rules:
      owasp:api2:2023-read-restricted: "off"
```

A rule is turned off for the whole repository under `rules`, or for one place under `overrides`, whose `files` are
paths or globs relative to the ruleset with a JSON pointer after the `#`. Wherever a rule is turned off, the reason
goes beside it, as for any suppression ([EC-0012](../configuration/suppressions.md)). A rule's severity is raised or
lowered the same way.

`conventions openapi` is a convenience: it finds the documents every `openapi` interface covers and runs
`spectral lint --ruleset .config/openapi/spectral.yaml` over them. A repository may run Spectral itself instead.

## Requirements

### OAS-01

**Every OpenAPI interface document passes the repository's Spectral ruleset.**

`spectral:oas` checks the document's structure, `operationId` presence and uniqueness, typed and duplicate-free
enums, tags, servers and path keys. The OWASP ruleset checks for the risks in the [OWASP API Security Top
10](https://owasp.org/API-Security/editions/2023/en/0x11-t10/): authentication on every operation, bounded strings
and arrays, declared error and rate-limit responses, and no secrets in URLs. The repository's ruleset adds its own
rules and exemptions. A document passes when Spectral reports no finding at `error` severity, which is Spectral's own
default for a failing run.

The conventions runner does not run Spectral: the repository's validation does (OAS-03).

Checked by: spectral (delegated) · Severity: warning · Since: 0.7.1

### OAS-02

**The Spectral ruleset extends spectral:oas and the OWASP API security ruleset at an exact release.**

A repository that declares an OpenAPI interface keeps a Spectral ruleset. The ruleset is where a repository says which
rules it adds and which it exempts, and why. Extending the upstream rulesets, rather than copying their rules, keeps a
repository on their fixes. Naming the OWASP ruleset by an exact release keeps a run reproducible: an unversioned URL, a
range such as `@2` or `@latest` changes what passes without a change in the repository, while an exact release changes
only in a reviewed pull request.

The ruleset is `.config/openapi/spectral.yaml` (or `.yml`), where tool configuration lives
([EC-0011](../configuration/tool-configuration.md)). Its `extends` lists `spectral:oas` and
`https://unpkg.com/@stoplight/spectral-owasp-ruleset@<x.y.z>/dist/ruleset.mjs`, each as a string or as the first item
of a `[ruleset, mode]` pair whose mode is not `off`. Spectral fetches the URL when it loads the ruleset, so the
standalone binary needs nothing else installed.

**Correct:**

```yaml
# .config/openapi/spectral.yaml
extends:
  - spectral:oas
  - https://unpkg.com/@stoplight/spectral-owasp-ruleset@2.0.1/dist/ruleset.mjs
```

**Incorrect:**

```yaml
# .config/openapi/spectral.yaml
extends:
  - spectral:oas
  - https://unpkg.com/@stoplight/spectral-owasp-ruleset/dist/ruleset.mjs   # whatever release unpkg serves today
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### OAS-03

**A validate workflow lints the OpenAPI interfaces with the repository's ruleset.**

A document that breaks the ruleset is found when it changes, before it is released and copied into clients, only if a
check that a pull request must pass runs the linter. The step may run `conventions openapi`, or
`spectral lint --ruleset .config/openapi/spectral.yaml` (or `-r`), itself or through a task, directly or through the
tasks that task calls, such as the repository's `check`. Name the ruleset in the task, so the file has a caller
([CONF-04](../configuration/tool-configuration.md#conf-04)).

**Correct:**

```yaml
# Taskfile.yml
tasks:
  openapi:
    desc: Lint the OpenAPI interfaces with the repository's Spectral ruleset.
    cmds: [conventions openapi --ruleset .config/openapi/spectral.yaml]
  check:
    cmds: [{task: lint}, {task: openapi}, {task: test}]
```

```yaml
# .github/workflows/validate.yml
      - run: task check
```

**Incorrect:**

```yaml
# .github/workflows/validate.yml
      - run: spectral lint api/contracts/openapi/public.json   # Spectral's default ruleset, not the repository's
```

Checked by: conftest · Severity: warning · Since: 0.7.1

## References

- [Decision 0023: OpenAPI documents are linted by Spectral's own OpenAPI and OWASP rulesets](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0023-openapi-documents-delegate-to-spectral.md)
- [EC-0030 Interfaces declaration](../interfaces/interfaces-declaration.md)
- [Spectral: Rulesets](https://docs.stoplight.io/docs/spectral/e5b9616d6d50c-rulesets)
- [Spectral: The OpenAPI ruleset](https://docs.stoplight.io/docs/spectral/4dec24461f3af-open-api-rules)
- [Spectral OWASP API Security ruleset](https://github.com/stoplightio/spectral-owasp-ruleset)
