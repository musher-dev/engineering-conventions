---
title: Deployment environments have one name, and reach a process only as MUSHER_ENVIRONMENT
date: 2026-10-13
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0034 — Deployment environments have one name, and reach a process only as MUSHER_ENVIRONMENT

## Context

A survey of the organization's environment schemas found the deployment environment, the tier a process runs in,
reaching programs under four variables: `OTEL_DEPLOYMENT_ENVIRONMENT`, `DEPLOYMENT_ENVIRONMENT`,
`COLLECTOR_DEPLOYMENT_ENVIRONMENT` and `OTEL_ENVIRONMENT`. None of them is one OpenTelemetry reads: its SDKs take
resource attributes from `OTEL_RESOURCE_ATTRIBUTES`, so the telemetry's `deployment.environment.name` was whatever
each service's bootstrap copied by hand. The values were spelled two ways, `production` in one place and `prod` in
another, and tiers appeared inside names (`PROD_READONLY_URL`, a secret-store setting suffixed `_PROD`), so the code
chose between variables by environment instead of the environment choosing the value.

The same survey found an invented `OTEL_ENABLED` where OpenTelemetry's switch is `OTEL_SDK_DISABLED`, a log level
spelled four ways, and booleans written as `X_ENABLED`. Each is a name or a value that one program chose and the next
one could not guess.

The tier is a word the whole organization uses, in deployment records, GitHub environments, dashboards and resource
names. It needs one owner and one spelling before any check can hold a schema to it.

## Decision

**The deployment environments are four names owned here, and a process learns which one it runs in from
`MUSHER_ENVIRONMENT` alone.**

- **The names.** `production`, `staging`, `development` and `test` are terms tagged `deployment.environment` in
  `definitions/terminology/global.yml`. They are chosen to equal the well-known values OpenTelemetry lists for
  `deployment.environment.name`
  ([deployment attributes](https://opentelemetry.io/docs/specs/semconv/registry/attributes/deployment/)), so the
  telemetry needs no translation. This repository owns the names; `musher-dev/observability-schema-registry` keeps
  the attribute and takes its values from here, so the dependency points one way.
- **The slug.** Each name has a slug (`prod`, `staging`, `dev`, `test`), its short form, written only where a system
  caps the length of a name: a DNS label, a worker or cloud resource name. Everywhere a name is written, in
  `MUSHER_ENVIRONMENT`, a GitHub `environment:`, a deployment record or the telemetry, it is the name.
- **A developer's own environment** is `development`, with `MUSHER_DEVELOPER_SLUG` set to name the resources that
  belong to it alone. It is not a fifth environment.
- **One variable.** `MUSHER_ENVIRONMENT`, an organization-wide reserved name (`env.org-scoped`), is the only
  variable that carries the tier, set by whatever deploys or starts the process. Telemetry derives
  `deployment.environment.name` from it, through `OTEL_RESOURCE_ATTRIBUTES` set at the seam or the SDK bootstrap;
  documenting that mapping is the registry's.
- **The rest of the grammar is published** as `env_grammar` in `checks/data/index.json`, from
  `definitions/environment/grammar.yml`: the unit suffixes, the boolean and client prefixes, the tier's variable and
  the names that must not carry it, and the prefixes a vendor reserves with every name it defines. Shared stems such
  as `_LOG_LEVEL` are terms tagged `env.shared-stem` with their values. Other repositories read these from the release
  they pin instead of keeping copies.

[EC-0020](../../engineering-conventions/definitions/conventions/environment/env-schema.md) gains ENVS-28 to ENVS-31,
and ENVS-10 gains `_HR` for `_HOURS` and `_DAY` for `_DAYS`.

## Consequences

### Positive

- A deploy sets one variable and every program, its logs and its telemetry agree on where it runs.
- Telemetry carries OpenTelemetry's own values, so dashboards built on the specification work unchanged.
- A name under `OTEL_` or `GITHUB_` is one the vendor reads, so a setting is never silently ignored.
- Other repositories stop keeping their own lists of units, prefixes and tiers.

### Negative

- Every schema with another tier variable, a slug as a value or a tier in a name has findings to clear, and each
  rename is recorded as a retired name.
- A short environment such as a preview has no name of its own; it is `development` or `test` until a term is added.
- The vendored OpenTelemetry and GitHub Actions lists age, and a name a vendor adds is reported until they are
  refreshed.

### Neutral

- A framework's own mode, such as `NODE_ENV`, stays the framework's; the deploy sets it from `MUSHER_ENVIRONMENT`
  where it must follow the tier.

## Enforcement

- ENVS-28 reports a binding that carries the tier under another name, and a `MUSHER_ENVIRONMENT` that admits a slug or
  an unregistered value.
- ENVS-29 reports a name under a reserved vendor prefix that the vendor does not define.
- ENVS-30 reports a deployment environment's name or slug as a word of a variable's name.
- ENVS-31 reports a value outside a shared stem's registered values.
- `task generate:check` fails when `env_grammar` or the vocabulary is stale, and `conventions generate` refuses a
  suggested replacement the vendor's list does not define.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| The slug as the name | `prod`, `dev` everywhere, since they are shorter | rejected: they differ from OpenTelemetry's values, so telemetry would need a translation, and `dev` reads as a person's laptop |
| Per-system names with translation tables | Each system keeps its spelling, and a table maps between them | rejected: every new system adds a table, and every table is a place to be wrong |
| Several variables, one per reader | `OTEL_DEPLOYMENT_ENVIRONMENT` for the exporter, another for the application | rejected: two variables for one fact drift, which is how the survey found four |
| Four names owned here, one variable, the slug only where length is capped | This decision | **chosen** |

## References

- [EC-0020 Environment schema](../../engineering-conventions/definitions/conventions/environment/env-schema.md)
- [OpenTelemetry: Deployment attributes](https://opentelemetry.io/docs/specs/semconv/registry/attributes/deployment/)
- [OpenTelemetry: Environment Variable Specification](https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/)
- [Decision 0000: Charter](0000-charter.md)
