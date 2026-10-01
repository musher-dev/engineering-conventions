---
id: EC-0019
title: Environment contract
summary: >-
  The environment a service reads at runtime is part of its interface, so
  it is declared beside the product's build manifest, at
  <product>/env.schema.yaml. The only other environment schema a
  repository holds is its dev environment's, at
  .devcontainer/env.schema.yaml.
status: draft
topic: environment
applies_to:
  paths:
    - "*/env.schema.yaml"
    - "**/env.schema.yaml"
    - "**/env.schema.yml"
    - .devcontainer/**/devcontainer.json
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

This convention covers where environment schemas live, and that a service has one. What a schema says is
[EC-0020](env-schema.md). How a product generates its settings module from the schema, or checks that its code reads
only declared variables, belongs to that product's own tooling: those checks need the code, not the schema.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). It adopts LAYOUT-10 and LAYOUT-11 from
`musher-dev/development-container`, which keep their IDs as aliases
([decision 0016](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)).
Its requirements are `proposed` at severity `warning`. ENVS-01 applies to repositories whose kind is `service`; the
`service` profile selects it. ENVS-02 and ENVS-15 apply to every repository. ENVS-15 adopts ENV-06 from the same
repository.

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
platform-api/.env.example     # the variables, undeclared
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

## References

- [EC-0020 Environment schema](env-schema.md)
- [EC-0018 Repository layout](../repository/layout.md)
- [The Twelve-Factor App: Config](https://12factor.net/config)
