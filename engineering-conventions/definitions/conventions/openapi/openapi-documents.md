---
id: EC-0037
title: OpenAPI documents
summary: >-
  Every OpenAPI document a repository offers as an interface passes the
  Spectral ruleset these conventions ship. The repository's own ruleset in
  .config/openapi/spectral.yaml extends it, a validate workflow runs
  `conventions openapi`, and the link to the shipped ruleset stays out of
  the repository.
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
    - .conventions/**
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
  - title: "RFC 9457: Problem Details for HTTP APIs"
    url: https://www.rfc-editor.org/rfc/rfc9457
  - title: "AIP-126: Enumerations"
    url: https://google.aip.dev/126
  - title: "AIP-136: Custom methods"
    url: https://google.aip.dev/136
requirements:
  - id: OAS-01
    title: Every OpenAPI interface document passes the conventions' Spectral ruleset
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: delegated
      tool: spectral
      check: conventions openapi
  - id: OAS-02
    title: A repository that declares an OpenAPI interface keeps a Spectral ruleset that extends the conventions' ruleset
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.openapi.documents
  - id: OAS-03
    title: A validate workflow runs conventions openapi
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.openapi.documents
  - id: OAS-04
    title: The link to the conventions' ruleset is not part of the repository
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.openapi.documents
---

# OpenAPI documents

An OpenAPI document is what a client generator, a documentation site and a consumer's reviewer read instead of the
code. A name in the wrong case, an enum that cannot be told apart, an error body in a private format or a union a
generator cannot dispatch is then copied into every SDK and every consumer, and a fix is a breaking change. The rules
that prevent those are mechanical, so a linter checks them. This convention ships them as one
[Spectral](https://github.com/stoplightio/spectral) ruleset, and asks each repository that offers an OpenAPI
interface to run it.

## Scope

This convention covers the OpenAPI documents of every interface declared with `format = "openapi"` in
`.repo/outputs.toml` ([EC-0030](../interfaces/interfaces-declaration.md)), and the ruleset, task and workflow step
that lint them. A repository with no such interface meets every requirement. What a document describes, and how a
resource is modelled, stays with the repository that owns the API: a reviewer judges that, and this convention only
checks the shapes a machine can.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirements are `proposed` at
severity `warning`, like every requirement in the 0.x series, and every rule in the ruleset is a warning too. Spectral
is the engine, and the reasons are in
[decision 0023](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0023-openapi-documents-delegate-to-spectral.md).

## How it fits together

```text
checks/openapi/musher.spectral.yaml        shipped in the release; extends spectral:oas recommended
        ▲  linked by `conventions openapi`
.conventions/openapi.spectral.yaml         a link, refreshed on every run, ignored by git (OAS-04)
        ▲  extends
.config/openapi/spectral.yaml              the repository's ruleset (OAS-02): its own rules and exemptions
        ▲  --ruleset
conventions openapi                        run by a validate workflow (OAS-03); fails on any warning (OAS-01)
```

`conventions openapi` refreshes the link so it names the release the repository pins, then runs
`spectral lint --ruleset .config/openapi/spectral.yaml --fail-severity warn` over every document the `openapi`
interfaces cover, or over the files it is given. The repository's ruleset is ordinary Spectral:

```yaml
# .config/openapi/spectral.yaml
extends:
  - ../../.conventions/openapi.spectral.yaml
rules:
  # Our operationIds carry the surface first (agent_list_runs); the rule's verb-first reading rejects them.
  musher-operation-id-snake-case: "off"
overrides:
  # Lower-case values the published API already returns; tracked in https://github.com/your-org/your-api/issues/1
  - files: ["../../api/contracts/openapi/public.json#/components/schemas/Visibility/enum"]
    rules:
      musher-enum-upper-snake-case: "off"
```

A rule is turned off for the whole repository under `rules`, or for one place under `overrides`, whose `files` are
paths or globs relative to the ruleset with a JSON pointer after the `#`. The pointer is a URI fragment, so a path key
is escaped twice: `/` as `~1`, then `{`, `}` and `:` as `%7B`, `%7D` and `%3A`
(`#/paths/~1v1~1orders~1%7Bid%7D%3Acancel/post`); an unencoded one matches nothing, silently. Wherever a rule is
turned off, the reason goes beside it, as for any suppression ([EC-0012](../configuration/suppressions.md)). The
repository's own rules, stricter or about its own vocabulary, go in the same file.

## Requirements

### OAS-01

**Every OpenAPI interface document passes the conventions' Spectral ruleset.**

The ruleset is `checks/openapi/musher.spectral.yaml`. It extends Spectral's `spectral:oas` recommended rules, which
already check the document's structure, `operationId` presence and uniqueness, typed and duplicate-free enums, tags
and path keys, and adds the ten rules below. Each one is a warning; `conventions openapi` fails on any of them, so the
repository decides each exemption in its ruleset rather than in review.

#### musher-enum-upper-snake-case

An enum of two or more values is `UPPER_SNAKE_CASE`, as [AIP-126](https://google.aip.dev/126) asks. Generated clients
turn values into constants, and a document that mixes `published` with `DRAFT` gives every language a different
spelling to guess. A one-value enum is a constant, such as a discriminator's tag, and is not checked.

**Correct:** `enum: [PENDING, SHIPPED, DELIVERED]` · **Incorrect:** `enum: [pending, shipped, delivered]`

#### musher-enum-no-unspecified

No enum value is an `UNSPECIFIED` sentinel. AIP-126 asks for one because a protobuf enum always has a zero value; JSON
does not, and an unset value is omitted or `null`. A sentinel in a JSON API is a value every client must handle and
no server should send.

**Correct:** `enum: [STANDARD, EXPRESS]`, with the property optional · **Incorrect:**
`enum: [PRIORITY_UNSPECIFIED, STANDARD, EXPRESS]`

#### musher-oneof-discriminator

A `oneOf` carries a `discriminator`. Without one, a client must try each schema in turn, and two schemas that both
validate a body make it ambiguous; with one, every generator dispatches on a single property.

**Correct:**

```yaml
Payment:
  oneOf: [{$ref: "#/components/schemas/CardPayment"}, {$ref: "#/components/schemas/InvoicePayment"}]
  discriminator: {propertyName: kind}
```

**Incorrect:**

```yaml
Payment:
  oneOf: [{$ref: "#/components/schemas/CardPayment"}, {$ref: "#/components/schemas/InvoicePayment"}]
```

#### musher-no-anyof-union

`anyOf` only makes a schema nullable: one schema and `{type: "null"}`. A union of two or more non-null schemas is a
`oneOf` with a discriminator, because `anyOf` lets a body match several at once and generators type it as the loosest
of them.

**Correct:** `anyOf: [{type: string}, {type: "null"}]` · **Incorrect:** `anyOf: [{type: string}, {type: object}]`

#### musher-error-problem-json

Every 4xx and 5xx response declares `application/problem+json` ([RFC 9457](https://www.rfc-editor.org/rfc/rfc9457)).
One error format lets every client handle every error the same way, and lets a gateway or a proxy add its own errors
in the same shape. Frameworks that generate a validation error response in their own format, such as a 422 with
`application/json`, are the usual finding.

**Correct:**

```yaml
"404":
  description: No such order.
  content:
    application/problem+json: {schema: {$ref: "#/components/schemas/Problem"}}
```

**Incorrect:**

```yaml
"404":
  description: No such order.
  content:
    application/json: {schema: {$ref: "#/components/schemas/Error"}}
```

#### musher-boolean-prefix

A boolean property is named `is`, `has`, `can` or `should`, then a capital: `isPaid`, `hasChildren`, `canRetry`. The
prefix makes a flag read as a question at every call site, and tells it apart from a noun that holds an object or a
timestamp (`paid` could be either).

**Correct:** `isPaid: {type: boolean}` · **Incorrect:** `paid: {type: boolean}`

#### musher-property-camel-case

Property names are `lowerCamelCase`. An initialism inside a name may stay upper case (`receiptURL`), which is why the
rule is a pattern rather than Spectral's stricter `casing: camel`. One case across every API means a client never
maps names, and a generated model reads the same in every language.

**Correct:** `orderId`, `receiptURL` · **Incorrect:** `order_id`, `OrderId`

#### musher-operation-id-snake-case

An `operationId` is `snake_case`, a verb then the resource: `list_orders`, `batch_create_orders`. Generators make it
the method name, and a predictable form lets a reader find the method from the endpoint. A repository with its own
stricter form, such as a surface prefix or a list of verbs, adds that rule beside this one.

**Correct:** `operationId: list_orders` · **Incorrect:** `operationId: listOrders`

#### musher-named-body-schema

A request or response body's schema is a `$ref` to a named component, or an array, `allOf`, `oneOf` or `anyOf` of
them. An inline schema has no name, so each generator invents one (`InlineResponse2001`), and the name changes when
the endpoints are reordered.

**Correct:** `schema: {$ref: "#/components/schemas/BatchCreateOrdersRequest"}` · **Incorrect:**
`schema: {type: object, properties: {orders: {type: array}}}`

#### musher-batch-207

A batch custom method ([AIP-136](https://google.aip.dev/136)), a `POST` to a path ending `:batch` and a verb such as
`:batchCreate`, declares `207 Multi-Status` and no `200`. Each item in a batch can succeed or fail on its own; `200`
tells a client every item succeeded, and a client that trusts it loses the failures.

**Correct:** `/v1/orders:batchCreate` responds `"207"` with one result per item · **Incorrect:** it responds `"200"`

The ruleset uses Spectral's core functions only, so it runs on the standalone Spectral binary. The conventions runner
does not run it: `conventions openapi` does, in the repository's own validation (OAS-03).

Checked by: spectral (delegated) · Severity: warning · Since: 0.7.1

### OAS-02

**A repository that declares an OpenAPI interface keeps a Spectral ruleset that extends the conventions' ruleset.**

The repository's ruleset is where it says which rules it adds and which it exempts, and why. Extending the shipped
ruleset, rather than copying it, is what keeps a repository on the rules of the release it pins: Renovate raises the
pin, and the rules move with it. The ruleset is `.config/openapi/spectral.yaml` (or `.yml`), where tool configuration
lives ([EC-0011](../configuration/tool-configuration.md)), and lists `../../.conventions/openapi.spectral.yaml` under
`extends`, as a path or as the first item of a `[path, mode]` pair. Spectral resolves the path from the ruleset's
directory, and fails when it is missing, so a broken link fails the run instead of skipping the rules.

**Correct:**

```yaml
# .config/openapi/spectral.yaml
extends:
  - ../../.conventions/openapi.spectral.yaml
```

**Incorrect:**

```yaml
# .config/openapi/spectral.yaml
extends: [[spectral:oas, recommended]]   # the conventions' rules never run
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### OAS-03

**A validate workflow runs `conventions openapi`.**

A document that breaks the ruleset is found when it changes, before it is released and copied into clients, only if a
check that a pull request must pass runs the linter. The step may run `conventions openapi` itself, or run a task
that does, directly or through the tasks it calls, such as the repository's `check`. Name the ruleset with
`--ruleset` in the task, so the file has a caller ([CONF-04](../configuration/tool-configuration.md#conf-04)).

**Correct:**

```yaml
# Taskfile.yml
tasks:
  openapi:
    desc: Lint the OpenAPI interfaces with the conventions' Spectral ruleset.
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
      - run: spectral lint api/contracts/openapi/public.json   # the conventions' rules never run
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### OAS-04

**The link to the conventions' ruleset is not part of the repository.**

`conventions openapi` writes `.conventions/openapi.spectral.yaml` on every run, as a link to the ruleset in the
installed release, at a path that differs on each machine. Committed, it points at a path that does not exist on the
next checkout; left untracked and not ignored, it is one `git add -A` away from that. Add the directory to
`.gitignore`. The check reports any file under `.conventions/` that git does not ignore.

**Correct:**

```text
# .gitignore
.conventions/
```

**Incorrect:**

```text
$ git status --short
?? .conventions/
```

Checked by: conftest · Severity: warning · Since: 0.7.1

## References

- [Decision 0023: OpenAPI documents are checked by Spectral, with a ruleset the conventions ship](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0023-openapi-documents-delegate-to-spectral.md)
- [EC-0030 Interfaces declaration](../interfaces/interfaces-declaration.md)
- [Spectral: Rulesets](https://docs.stoplight.io/docs/spectral/e5b9616d6d50c-rulesets)
- [RFC 9457: Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457)
- [AIP-126: Enumerations](https://google.aip.dev/126)
- [AIP-136: Custom methods](https://google.aip.dev/136)
- `checks/openapi/musher.spectral.yaml`
