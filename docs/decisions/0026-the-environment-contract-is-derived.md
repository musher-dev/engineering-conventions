---
title: The environment contract is derived from env.schema.yaml, declares runtime ranges, and names bindings after their reader
date: 2026-10-01
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
amends: ["0015", "0022"]
---

# 0026 — The environment contract is derived from env.schema.yaml, declares runtime ranges, and names bindings after their reader

## Context

[Decision 0022](0022-interfaces-and-dependencies.md) made a service's environment an interface (`env-schema`), put
every interface's definitions in `<product>/contracts/`, and recorded on each binding the capability or service it
reaches. Adopting it in a service showed three gaps.

**The interface has no definition a consumer can read.** `env.schema.yaml` is a bespoke format: the only schema
published for it (`env-schema.schema.json`) validates the file, not an environment. ENVS-01 puts it in the product
directory and ENVS-02 forbids a second copy, so an `env-schema` interface cannot be defined in `contracts/` the way
IFACE-08 asks, and the first service to declare one waived IFACE-08. EC-0020 also calls the schema "the source
everything else is derived from" and then checks nothing derived from it; a hand-written `.env.example` drifts first.
There is no standard for environment variables, but JSON Schema 2020-12 is what consumers already read for them:
Ajv and fastify's `env-schema` validate an environment with it, Helm validates values with `values.schema.json`, and
pydantic's `model_json_schema()` emits it. Spring Boot's generated configuration metadata, with
`deprecation.replacement`, is prior art for recording a retired name's successor. `@env-spec` was considered and not
adopted: it is young, tied to one tool, and stops at parsing.

**A capability has no version.** A service that needs PostgreSQL 18 features, or a Valkey 9 command, says so only
in prose, so nothing compares it with what infrastructure provisions or what the dev container's stack runs. The
dependencies declaration is the wrong home: it holds exact pins of vendored releases (DEPS-04), which a bot moves and
the consumer decides on. For a runtime the code runs against, the provider decides the minor and patch version, so an
exact pin is either false or a block on routine maintenance. Several bindings also reach one instance (a database's
URL, its worker URL, its admin URL), so a version per binding would repeat one fact. Prior art splits the two the same
way: the workload declares an abstract type and a compatibility range, and the platform provisions an exact version
(Score's `resources.<id>.type`, servicebinding.io's `type` and `provider`, Helm's `kubeVersion: ">= 1.19.0-0"`, npm
`engines`, `requires-python`, Terraform's `required_version`).

**A name does not say who reads it.** The grammar `[<client prefix>]<COMPONENT>_<WHAT>` has no place for the program
that reads the variable. A shared secret store that injects `CACHE_URL` into every service cannot point two services
at two caches, and `DATABASE_URL` means something different in each repository that reads it. The conventions that
age well are named after their reader: `SPRING_*` read by Spring, `OTEL_*` read by the OpenTelemetry SDKs, `POSTGRES_*`
read by the postgres image. Names chosen by the supplier (an add-on's `REDIS_URL`, Kubernetes service links'
`<SVC>_SERVICE_HOST`) need a mapping layer to rename them anyway, and Kubernetes service links are usually disabled
for their collisions.

## Decision

**`env.schema.yaml` stays the only authored copy, and everything else is derived from it by one published mapping.**
It holds facts JSON Schema has no keyword for (`local_default`, `local_generate`, `consumer`, `nested`, `retired`), so
it is not replaced. The release ships `bin/env-contract.jq`, the one implementation of the mapping, and
`conventions env-contract [--example] SCHEMA` prints what it derives:

- **The environment contract**, JSON Schema 2020-12: each binding a property, `required`, `default`, `format`,
  `values` and `constraints` mapped to the standard keywords, and `x-musher-sensitivity`, `x-musher-capability`,
  `x-musher-provider`, `x-musher-target`, `x-musher-requires` and the top-level `x-musher-requires` and
  `x-musher-retired` carrying the rest. A property's type is the value's type after parsing, as validators that
  coerce an environment expect. A service that offers an `env-schema` interface commits it at
  `<product>/contracts/env/<service>.env.schema.json` and names that file in the interface's `definitions`
  (ENVS-20). The contract is the interface's definition, so IFACE-08 holds with no exemption.
- **`.env.example`**, at `<product>/.env.example` when the product keeps one (ENVS-21), in a fixed format EC-0019
  describes.
- **A settings module** stays the product's own tooling: it needs the code, and generators differ by language.

The checks only compare. The runner derives both documents from each environment schema with jq, the engine
consumers already run, and adds them to the inventory as `derived`, beside the texts and digests decision 0015 and
decision 0022 added; conftest reads the committed contract as JSON and `.env.example` as text. This amends
[decision 0015](0015-the-runner-reads-what-conftest-cannot-select.md) once more, selected by a fixed pattern.

**A runtime requirement is a range the workload declares; the platform provisions an exact version.** A schema's
top-level `requires` names each runtime instance the service needs, keyed by an instance ID: its `capability`, a
`version` range, an optional `provider` and a `description`. A binding names the instance it reaches with
`requires: <id>` in place of an inline `capability` and `provider`. The range grammar is deliberately small:
comparators `>=`, `>`, `<=`, `<` and `==` on dot-separated integers, separated by commas and all required, with a
missing component read as 0, so `>=9, <10` excludes 10.0. There is no `^`, `~` or wildcard to interpret. Exact pins
stay where they are right: `.repo/dependencies.toml` holds exact versions of vendored releases only, and a runtime
range never goes there. The derived contract carries `requires`, so a deploy preflight can compare it with what
infrastructure reports, and a dev container's compose stack opts in to being compared with labels
`dev.musher.capability` and `dev.musher.capability-version` (DEVC-16). This amends decision 0022's table: a runtime
capability's version is owned by the environment schema's `requires`, written by a person.

**A binding is named after the program that reads it.** A schema opts in with `naming.consumer_prefix`, which is
`MUSHER_` and the repository's component in upper snake case (`MUSHER_API` for `platform-api`), and then every
binding is named `[<client prefix>]<consumer prefix>_<COMPONENT>_<WHAT>[_<UNIT>]`. The grammar applies to the part
after the prefix. Three kinds of name are exempt: a reserved organization-wide name (`env.org-scoped` terms such as
`MUSHER_ENVIRONMENT`), a vendor name, exempt only if a library the repository does not own reads it, and a name in
`naming.legacy`, the unprefixed names frozen when the schema opted in. Infrastructure maps a supplier's name to the
consumer's at the seam, with a secret-store reference or its platform's equivalent, never in code. A renamed binding
moves to `retired` with its `replacement`, and `naming.legacy` only shrinks.

## Consequences

### Positive

- A consumer validates an environment against the interface with standard tools, and the interface lives in
  `contracts/` like every other.
- `.env.example` and the contract cannot drift from the schema without a finding, and no repository needs a task for
  the check.
- A required runtime version is a fact a check, a reviewer and a preflight can read, written once per instance.
- A variable's name says who reads it, so a shared store cannot inject one service's value into another by accident.

### Negative

- The runner runs conftest and jq once more for each environment schema.
- The contract's types are the parsed types, so a validator that does not coerce rejects a correct environment; the
  convention says so.
- Prefixed names are longer, and an ecosystem default such as `DATABASE_URL` no longer works without the mapping at
  the seam.

### Neutral

- Every new requirement is `proposed` at `warning`, and every new field is optional: a schema that opts into nothing
  is checked as before, apart from ENVS-22's transition finding on an inline `capability`.

## Enforcement

- ENVS-20 and ENVS-21 (EC-0019) compare the committed contract and `.env.example` with what the runner derived; their
  fixture repositories run through both runners (`tests/test_launcher.py`).
- ENVS-22 and ENVS-23 (EC-0020) check that a binding reaches a runtime through `requires`, and that every instance is
  declared, referenced and a registered capability. ENVS-16 keeps `requires` exclusive of `target`, `capability` and
  `provider`. `env-schema.schema.json` validates the range grammar (ENVS-03).
- DEVC-16 (EC-0028) compares a labelled stack's version with every range that names its capability.
- ENVS-24 and ENVS-25 (EC-0020) check the consumer prefix and every name under it.
- That `naming.legacy` only shrinks, and that a vendor exemption is read by a library the repository does not own,
  are `review-only`.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Exempt `env-schema` from IFACE-08 | Let the interface be defined by `<product>/env.schema.yaml` | rejected: the definition stays a format no standard tool reads |
| Write the contract by hand | Commit a JSON Schema beside the YAML | rejected: two authored copies of one fact drift |
| JSON Schema as the only source | Replace the YAML | rejected: local values, retired names and nested models have no keyword |
| Check drift with a delegated task | `conventions env-contract --check` in each repository's CI | rejected: the runner already reads every input, so a conftest check needs no task |
| Runtime versions in `dependencies.toml` | One file for every version | rejected: an exact pin is false for a provisioned runtime, and the file is a bot's |
| A version on each binding | No new block | rejected: several bindings reach one instance and would repeat it |
| npm or PEP 440 range syntax | A familiar grammar | rejected: `^`, `~` and `~=` mean different things in each, and need an interpreter |
| A global `MUSHER_` prefix without the service | Shorter names | rejected: two services still collide in one store |
| Derived contract, ranges on instances, reader-named bindings | This decision | **chosen** |

## References

- [Decision 0015: The runner reads what conftest cannot select](0015-the-runner-reads-what-conftest-cannot-select.md)
- [Decision 0022: Interfaces and dependencies](0022-interfaces-and-dependencies.md)
- [JSON Schema 2020-12](https://json-schema.org/draft/2020-12)
- [fastify env-schema](https://github.com/fastify/env-schema)
- [Helm: schema files](https://helm.sh/docs/topics/charts/#schema-files)
- [Spring Boot: configuration metadata](https://docs.spring.io/spring-boot/specification/configuration-metadata/format.html)
- [Score specification](https://docs.score.dev/docs/score-specification/score-spec-reference/)
- [servicebinding.io](https://servicebinding.io/spec/core/1.0.0/)
- [Terraform: version constraints](https://developer.hashicorp.com/terraform/language/expressions/version-constraints)
