# Interfaces

These conventions govern the interfaces a repository offers: each surface another repository builds or runs against,
such as one OpenAPI document of an API, a family of event schemas, a registry of problem types, a protobuf package or
an environment schema. They cover how a repository declares its interfaces, where their files live, and the tasks and
workflow steps that keep each one current, compatible and delivered byte for byte.

The governing rule, in one sentence:

> **Declare every surface another repository depends on as its own interface, keep its files in the contracts
> directory, and prove in CI that each change is current and keeps its compatibility promise.**

An interface is not an output. An output is what a consumer downloads (a bundle, a site, a library); an interface is
what it builds against, and one bundle usually delivers several. A server that offers a public API, an agent API and
an event stream has three interfaces, so a consumer can depend on exactly the one it uses, and a change to one is
judged against the consumers of that one.

## Status

Both conventions are **drafts**, owned by this repository, and every requirement is `proposed` at severity `warning`.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0030 Interfaces declaration](interfaces-declaration.md) | IFACE-01 – IFACE-08 | `[[interfaces]]` in `.repo/outputs.toml`, formats, compatibility, the contracts directory |
| [EC-0031 Publishing interfaces](publishing-interfaces.md) | IFACE-09 – IFACE-14 | The `contracts:*` tasks, validation, the bundle and its release record |

What a consumer does with an interface is the [dependencies](../dependencies/README.md) topic. The reasoning is
recorded in
[decision 0022](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0022-interfaces-and-dependencies.md).

## Quick reference

| Field | Example |
| --- | --- |
| `id` | `public-http`, addressed by consumers as `platform-api#public-http` |
| `format` | `openapi`, `asyncapi`, `json-schema`, `protobuf`, `env-schema`, `weaver` |
| `definitions` | `["platform-api/contracts/openapi/public.json"]`, `["platform-api/contracts/events/*.schema.json"]` |
| `delivered_by` | `contracts`, the ID of a `bundle`, `site` or `library` output |
| `compatibility` | `gated`, `versioned`, `lockstep` |
| `audience` | `public`, `internal` |
| `generated` | `true` when the product's code writes the definitions |
| `docs` | `platform-api/contracts/README.md#public-http` |

| Task | Does |
| --- | --- |
| `contracts:generate` | Writes every generated definition from the code |
| `contracts:check` | Regenerates and fails when a committed definition differs |
| `contracts:breaking` | Compares each interface with the last release using its format's native tool |
| `contracts:bundle` | Writes the bundle and its `release.json` |
