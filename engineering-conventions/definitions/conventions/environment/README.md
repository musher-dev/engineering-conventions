# Environment

These conventions govern the environment a product reads: the variables that decide whether it starts, what it
connects to and what it may do. A service declares them in one file beside its build manifest, and every environment
schema follows one format.

The governing rule, in one sentence:

> **Declare every variable the product reads in `<product>/env.schema.yaml`, with its type, its sensitivity and what
> it is for, and never commit a secret's value.**

## Status

Both conventions are **drafts**, owned by this repository, and every requirement is `proposed` at severity `warning`.
They adopt the environment rules of `musher-dev/platform` (the format and its naming grammar) and
`musher-dev/development-container` (the file's location and the minimal shape), unified into one format.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0019 Environment contract](env-contract.md) | ENVS-01, ENVS-02 | That a service declares its environment, and the two places a schema may live |
| [EC-0020 Environment schema](env-schema.md) | ENVS-03 – ENVS-14 | The format, the naming grammar, retired names, secrets, and shared variables |

## Who is checked

| Requirement | Profile |
| --- | --- |
| ENVS-01 | `service` only |
| ENVS-02 – ENVS-14 | Every repository (`base-repo`); a repository without an environment schema has nothing to report |

## Quick reference

| Field | Example | Values |
| --- | --- | --- |
| `service` | `platform-api` | The deployable the schema describes |
| `runtime` | `python` | `python`, `sveltekit`, `node`, `go`, `rust`, `docker-compose`, … |
| `bindings.<NAME>.type` | `integer` | `string`, `integer`, `number`, `boolean`, `enum`, `list` |
| `bindings.<NAME>.sensitivity` | `secret` | `public`, `internal`, `confidential`, `secret` |
| `naming.components` | `[API, DATABASE]` | The first words binding names may start with |

The authoritative shape is `checks/schemas/env-schema.schema.json`.
