---
id: EC-0019
title: Environment contract
summary: >-
  The environment a service reads at runtime is part of its interface, so
  it is declared beside the product's build manifest, at
  <product>/env.schema.yaml. The only other environment schema a
  repository holds is its dev environment's, at
  .devcontainer/env.schema.yaml. The JSON Schema contract an env-schema
  interface delivers is derived from the schema, committed and kept equal
  to it; a developer's local .env is generated from it and never committed.
status: draft
topic: environment
applies_to:
  paths:
    - "*/env.schema.yaml"
    - "**/env.schema.yaml"
    - "**/env.schema.yml"
    - .devcontainer/**/devcontainer.json
    - "*/contracts/env/*.env.schema.json"
    - "**/.env"
    - "**/.env.*"
    - "**/.gitignore"
created: 2026-09-28
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
implementations:
  - repo: musher-dev/development-container
    check: LAYOUT-10
    mode: blocking
  - repo: musher-dev/development-container
    check: LAYOUT-11
    mode: blocking
  - repo: musher-dev/development-container
    check: ENV-06
    mode: blocking
references:
  - title: "The Twelve-Factor App: Config"
    url: https://12factor.net/config
  - title: "JSON Schema 2020-12"
    url: https://json-schema.org/draft/2020-12
requirements:
  - id: ENVS-01
    title: A service declares its runtime environment at <product>/env.schema.yaml
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_contract
    aliases: ["development-container:LAYOUT-10"]
  - id: ENVS-02
    title: An environment schema lives only at <product>/env.schema.yaml or .devcontainer/env.schema.yaml
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_contract
    aliases: ["development-container:LAYOUT-11"]
  - id: ENVS-15
    title: A dev container's secrets name exactly the variables its environment schema takes from the host
    status: proposed
    severity: warning
    since: 0.6.3
    validation:
      engine: conftest
      package: conventions.checks.environment.env_contract
    aliases: ["development-container:ENV-06"]
  - id: ENVS-20
    title: A service that offers its environment as an interface commits the contract derived from its schema
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.environment.env_derived
  - id: ENVS-21
    title: A product's .env.example is the one derived from its environment schema
    status: retired
    severity: warning
    since: 0.7.1
    replaced_by: [ENVS-26, ENVS-27]
    validation:
      engine: conftest
      package: conventions.checks.environment.env_derived
  - id: ENVS-26
    title: No environment file is committed beside an environment schema or at the root
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_files
  - id: ENVS-27
    title: Git ignores the .env beside a product's environment schema
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_files
---

# Environment contract

Every variable a service reads from its environment is part of its interface, as much as its API. When nothing
declares them, a new variable reaches production only if someone remembers to set it, a renamed one keeps its old
name in every environment file, and a reviewer cannot tell which configuration a change needs. So a service declares
its environment in one file, reviewed and versioned with the code that reads it: `env.schema.yaml`.

The file sits in the product directory ([EC-0018](../repository/layout.md)), beside the build manifest, because it
describes the product rather than acting on it. Its format is [EC-0020](env-schema.md).

There are two environment schemas with one word in common, one per level of the repository:

| File | Level | Read by |
| --- | --- | --- |
| `<product>/env.schema.yaml` | Product | The shipped product, at runtime |
| `.devcontainer/env.schema.yaml` | Repository | The dev environment: its stacks and its tools |

Both use the same format, so one check reads both.

## Scope

This convention covers where environment schemas live, that a service has one, the environment contract derived from
it that a repository commits, and the local `.env` derived from it that a repository never commits. What a schema says is
[EC-0020](env-schema.md). How a product generates its settings module from the schema, or checks that its code reads
only declared variables, belongs to that product's own tooling: those checks need the code, not the schema.

## What is derived from the schema

`env.schema.yaml` is the only copy anyone writes. It holds facts no standard format has a keyword for
(`local_default`, `local_generate`, `consumer`, `nested`, `retired`), so it stays the source, and every other
document is generated from it by one published mapping, `bin/env-contract.jq`, which the release ships
([decision 0026](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0026-the-environment-contract-is-derived.md),
[decision 0029](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0029-the-local-environment-file-is-generated.md)):

```sh
conventions env-contract platform-api/env.schema.yaml > platform-api/contracts/env/platform-api.env.schema.json
conventions env-file platform-api/env.schema.yaml        # writes platform-api/.env
```

| Document | Where | Committed | Checked by |
| --- | --- | --- | --- |
| The environment contract, JSON Schema 2020-12 | `<product>/contracts/env/<service>.env.schema.json`, when the service offers an `env-schema` interface | yes | ENVS-20 |
| A developer's local environment | `.env` beside the schema | never | ENVS-26, ENVS-27 |
| A settings module, a deploy preflight, a reference page | Wherever the product's tooling writes them | | That tooling |

`conventions check` derives the contract from the schema itself and compares it with the committed file, so a
repository needs no extra task for the check. A repository regenerates the contract with the command above in the
task that writes its generated files, and may run `conventions env-file` from its `setup` task.

### The contract

The contract is what a consumer validates an environment against with standard tools: Ajv, fastify's `env-schema`,
or any JSON Schema 2020-12 validator. Each binding is a property, and:

| `env.schema.yaml` | Contract |
| --- | --- |
| `service` | `title` |
| `type: string`, `integer`, `number`, `boolean` | `type` of the same name |
| `type: enum`, `values` | `type: string`, `enum` |
| `type: list`, `values` | `type: array`, `items: {type: string, enum}`, `x-musher-separator: ","` |
| `required: true` | The name in the top-level `required` |
| `default` | `default`; a list's default as an array |
| `format: url`, `email` | `format: uri`, `email` |
| `format: json` | `contentMediaType: application/json` |
| `format: path` | `x-musher-format: path` |
| `constraints` | `minLength`, `maxLength`, `minimum`, `maximum`, `pattern` |
| `sensitivity` | `x-musher-sensitivity`; `secret` also sets `writeOnly: true` |
| `capability`, `provider`, `target`, `requires` | `x-musher-capability`, `x-musher-provider`, `x-musher-target`, `x-musher-requires` |
| `description` | `description`, on one line |
| Top-level `requires` | Top-level `x-musher-requires` |
| `retired` | Top-level `x-musher-retired`, each `name`, `retired_on`, `reason` and `replacement` |

A property's `type` is the type of the value **after the process parses it**. An environment holds only strings, so
a validator that checks a raw environment coerces first, as Ajv's `coerceTypes` and fastify's `env-schema` do, and
splits a list on its separator. The top level allows other properties, because an environment always holds variables
the service does not read. Facts that only a developer's machine needs (`local_default`, `local_generate`) and those
that only the product's own tooling reads (`consumer`, `nested`, `generated`, `infisical`) are left out. The document
is printed with its keys sorted and two-space indentation; the check compares it as JSON, so only its content
matters.

### The local `.env`

`conventions env-file` writes `.env` beside the schema, for one developer's machine:

```sh
# The local environment platform-api reads, generated from its env.schema.yaml by
# conventions env-file. It holds this machine's values and secrets: git ignores
# it (ENVS-27), and it is never committed. Fill in the empty values. After the
# schema changes, run conventions env-file again to list what is missing.

# TCP port the HTTP server listens on inside the container.
# integer, internal
# API_PORT=8080

# Connection string of the primary Postgres database, credentials included.
# string, url, required, secret
DATABASE_URL=postgres://postgres@localhost:5432/app

# Signs session cookies.
# string, secret, generate locally: base64url:32
SESSION_KEY=<32 random bytes, base64url, minted on this machine>
```

After the header, each binding, sorted by name, is a blank line, its description on one line, a line of facts, and
its assignment:

- The facts are its type (`enum: a|b` or `list: a|b` with values), its `format`, `required`, its sensitivity, and
  `generate locally: <kind>` for a `local_generate` binding, joined by a comma and a space.
- A binding with a `local_default` is assigned it. A binding with `local_generate` is assigned secret material minted
  on this machine, `hex`, `base64` or unpadded `base64url` of the bytes it names. A required binding is assigned
  nothing, to be filled in. Any other binding is commented out with its `default`, so the code's default applies until
  someone uncomments it.
- A value is written bare when it holds only letters, digits and `_@%+=:,./-`; otherwise in single quotes, or, when it
  holds a single quote, in double quotes with `\` and `"` escaped.

The file is written readable by its owner only. An existing `.env` is never replaced: the command lists the variables
the schema declares that the file lacks, and fails when there are any, so a developer adds them by hand and keeps
their own values. `--force` writes the file again and mints every secret afresh.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). It adopts LAYOUT-10 and LAYOUT-11 from
`musher-dev/development-container`, which keep their IDs as aliases
([decision 0016](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)).
Its requirements are `proposed` at severity `warning`. ENVS-01 applies to repositories whose kind is `service`; the
`service` profile selects it. ENVS-02, ENVS-15, ENVS-20, ENVS-26 and ENVS-27 apply to every repository. ENVS-15
adopts ENV-06 from the same repository.

## Requirements

### ENVS-01

**A service declares its runtime environment at `<product>/env.schema.yaml`.**

A service's environment decides whether it starts, what it connects to and what it may do. Declared beside the
manifest, the contract is reviewed with the code that reads it, and every tool that needs it (a settings generator, a
deploy preflight, a reference page) finds it in the same place in every repository. A service that reads no
variables declares an empty `bindings: {}`. The check needs the product directory from `[layout]`; without one,
REPO-14 or REPO-15 is reported instead.

**Correct:**

```text
.repo/repository.toml         # kind = "service", [layout] product = "platform-api"
platform-api/go.mod
platform-api/env.schema.yaml
```

**Incorrect:**

```text
.repo/repository.toml         # kind = "service", [layout] product = "platform-api"
platform-api/go.mod
platform-api/.env.example     # the variables, undeclared; ENVS-26 reports it too
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container LAYOUT-10

### ENVS-02

**An environment schema lives only at `<product>/env.schema.yaml` or `.devcontainer/env.schema.yaml`.**

Two locations, one per level, are all a reader or a tool should need to look in. A third copy (in a `config/`
folder, or a second product-level file) looks authoritative while feeding nothing, and the two drift. The check
reports any `env.schema.yaml` or `env.schema.yml` elsewhere, and names where it belongs, except in a vendored copy
under the contracts directory's `vendor/` ([EC-0032](../dependencies/dependencies-declaration.md)): that file is
another repository's interface, kept unchanged, and the DEPS requirements check it. It needs the product directory
from `[layout]`, and reports nothing until the repository declares it.

**Correct:**

```text
platform-api/env.schema.yaml
.devcontainer/env.schema.yaml
```

**Incorrect:**

```text
platform-api/config/env.schema.yaml
env.schema.yml
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container LAYOUT-11

### ENVS-15

**A dev container's `secrets` name exactly the variables its environment schema takes from the host.**

A binding in `.devcontainer/env.schema.yaml` with `source: host` is a value each developer supplies from their own
machine, such as an API key. On a laptop it comes from the shell; in Codespaces it arrives only if `devcontainer.json`
lists it under `secrets`, which is what makes Codespaces ask for it when the container is created. A host binding
missing from `secrets` silently arrives empty for everyone not on a machine that exports it, and a name in `secrets`
that the schema does not declare is a variable nothing documents. The check applies to each `devcontainer.json` under
`.devcontainer/` when the dev environment schema exists.

**Correct:**

```yaml
# .devcontainer/env.schema.yaml
bindings:
  OPENAI_API_KEY: {type: string, sensitivity: secret, source: host, description: "…"}
```

```jsonc
// .devcontainer/devcontainer.json
"secrets": { "OPENAI_API_KEY": { "description": "An OpenAI API key for local runs" } }
```

**Incorrect:**

```jsonc
// .devcontainer/devcontainer.json: OPENAI_API_KEY is missing
"secrets": {}
```

Checked by: conftest · Severity: warning · Since: 0.6.3 · Formerly: development-container ENV-06

### ENVS-20

**A service that offers its environment as an interface commits the contract derived from its schema.**

An `env-schema` interface ([EC-0030](../interfaces/interfaces-declaration.md)) tells another repository it may build
or run against the service's environment: a deploy that sets it, a preflight that checks it. That consumer needs a
document a standard validator reads, in the contracts directory where every other interface is defined. So a service
whose `.repo/outputs.toml` offers an `env-schema` interface commits the contract derived from
`<product>/env.schema.yaml` at `<product>/contracts/env/<service>.env.schema.json`, names that file in the
interface's `definitions`, and keeps it equal to what the schema derives. The schema itself stays where
[ENVS-01](#envs-01) puts it, the only copy anyone edits. The check reports a missing contract at the schema, an
interface that does not name it at `.repo/outputs.toml`, and a contract that differs from the derived one at the
contract. A contract the repository commits without the interface is held to the schema too.

**Correct:**

```toml
# .repo/outputs.toml
[[interfaces]]
id = "runtime-config"
format = "env-schema"
definitions = ["platform-api/contracts/env/platform-api.env.schema.json"]
delivered_by = "contracts"
compatibility = "gated"
```

**Incorrect:**

```toml
[[interfaces]]
id = "runtime-config"
format = "env-schema"
definitions = ["platform-api/env.schema.yaml"]   # the source, not the contract; IFACE-08 reports it too
delivered_by = "contracts"
compatibility = "gated"
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### ENVS-21

**A product's `.env.example` is the one derived from its environment schema.**

Retired in 0.8.0 and replaced by [ENVS-26](#envs-26) and [ENVS-27](#envs-27). A committed example duplicated the
schema in a second format; a developer now generates a ready-to-run `.env` from the schema with
`conventions env-file`, and nothing derived for one machine is committed.

Checked by: nothing (retired) · Severity: warning · Since: 0.7.1

### ENVS-26

**No environment file is committed beside an environment schema or at the root.**

`env.schema.yaml` already says every variable, its type, its default and its local value, so a committed `.env.example`
is a second copy that falls behind the first, and a committed `.env` puts one machine's values, often its secrets,
in every clone. The check reports `.env` and every `.env.<suffix>` (`.env.example`, `.env.local`, `.env.sample`) in the
repository's root and in each directory that holds an environment schema: the product directory and `.devcontainer/`.
An environment file elsewhere, such as a fixture or an example application, is not this repository's environment and
is not reported.

**Correct:**

```text
platform-api/env.schema.yaml
.gitignore                     # /platform-api/.env
```

**Incorrect:**

```text
platform-api/env.schema.yaml
platform-api/.env.example
```

Checked by: conftest · Severity: warning · Since: 0.8.0

### ENVS-27

**Git ignores the `.env` beside a product's environment schema.**

`conventions env-file` writes a developer's values and freshly minted secrets to `.env` beside the schema. If git does
not ignore that path, the next `git add .` commits them. The check reads the `.gitignore` at the root and in each
directory above the schema, and takes the last pattern that matches, as git does: `.env`, `/platform-api/.env`,
`**/.env`, `.env*` and `*.env` all ignore it, and a later `!.env` un-ignores it. The finding sits on the schema. The
dev environment's schema, `.devcontainer/env.schema.yaml`, describes what a developer's host passes in rather than a
file the product reads, so it is not checked.

**Correct:**

```gitignore
# A developer's local environment (conventions env-file)
/platform-api/.env
```

**Incorrect:**

```gitignore
.env*
!.env
```

Checked by: conftest · Severity: warning · Since: 0.8.0

## References

- [EC-0020 Environment schema](env-schema.md)
- [EC-0018 Repository layout](../repository/layout.md)
- [EC-0030 Interfaces declaration](../interfaces/interfaces-declaration.md)
- [The Twelve-Factor App: Config](https://12factor.net/config)
