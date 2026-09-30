---
id: EC-0020
title: Environment schema
summary: >-
  An env.schema.yaml declares every variable a product or dev environment
  reads: its type, its sensitivity and what it is for, in one published
  format with optional blocks for code generation, secret delivery and the
  deployment platform. Binding names follow one grammar over a vocabulary
  the schema declares, retired names stay retired, no secret value is
  committed, and a variable shared between deployables agrees everywhere.
status: draft
topic: environment
applies_to:
  paths:
    - "**/env.schema.yaml"
    - "**/env.schema.yml"
created: 2026-09-28
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
implementations:
  - repo: musher-dev/development-container
    check: ENV-01
    mode: blocking
  - repo: musher-dev/development-container
    check: ENV-07
    mode: blocking
  - repo: musher-dev/platform
    check: G-01
    mode: blocking
  - repo: musher-dev/platform
    check: G-02
    mode: blocking
  - repo: musher-dev/platform
    check: G-04
    mode: blocking
  - repo: musher-dev/platform
    check: G-07
    mode: blocking
  - repo: musher-dev/platform
    check: G-11
    mode: blocking
references:
  - title: "The Twelve-Factor App: Config"
    url: https://12factor.net/config
  - title: "JSON Schema draft-07"
    url: https://json-schema.org/draft-07
requirements:
  - id: ENVS-03
    title: An environment schema is valid against the published format
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_schema
    aliases: ["development-container:ENV-01"]
  - id: ENVS-04
    title: A binding name is UPPER_SNAKE_CASE and starts with a declared component
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_grammar
    aliases: ["platform:G-01"]
  - id: ENVS-05
    title: A retired name is never declared again
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_schema
  - id: ENVS-06
    title: A secret binding commits no value but an empty one or a loopback address
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_schema
    aliases: ["development-container:ENV-07"]
  - id: ENVS-07
    title: A schema's fields agree with each other
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_schema
  - id: ENVS-08
    title: Every copy of a shared variable agrees in type and sensitivity
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_schema
  - id: ENVS-09
    title: A boolean binding's name starts with a boolean prefix
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_grammar
    aliases: ["platform:G-02", "platform:G-11"]
  - id: ENVS-10
    title: A unit suffix is abbreviated
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_grammar
    aliases: ["platform:G-04"]
  - id: ENVS-11
    title: A binding name does not repeat a word
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_grammar
    aliases: ["platform:G-07"]
  - id: ENVS-12
    title: A URL binding's name ends in _URL
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_grammar
    aliases: ["platform:G-09"]
  - id: ENVS-13
    title: A nested binding's name separates its parts with __
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_grammar
    aliases: ["platform:G-08"]
  - id: ENVS-14
    title: A binding the browser reads starts with a client prefix
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_grammar
    aliases: ["platform:G-06"]
---

# Environment schema

An `env.schema.yaml` declares every variable a product, or a dev environment, reads from its environment. It is
written by hand and is the source everything else is derived from: a generated settings module, a local environment
file, a deploy preflight, a reference page. None of those is checked here; what is checked is that the source is
well-formed, named consistently and safe to commit.

## Scope

This convention covers the content of every environment schema; where one lives is [EC-0019](env-contract.md). The
format is the one `musher-dev/platform` and `musher-dev/development-container` already use, unified: every field
either repository defines is part of it, and a schema from either validates unchanged.

Checks that need the code are out of scope: that the code reads only declared variables, that every binding has a
reader, and that generated files are current. They stay with each product's own tooling.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`), with its requirements `proposed` at
severity `warning`. It adopts development-container's ENV-01 and ENV-07 and platform's naming grammar (G-01, G-02,
G-04, G-06 to G-09 and G-11), which keep their IDs as aliases
([decision 0016](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)).
The platform's grammar IDs were rule numbers in its documentation rather than IDs its command-line tool printed;
they are aliased so a reader who knows them finds the rule. Two platform rules are not adopted: G-03 (a numeric value
with a unit carries a unit suffix) cannot tell from a schema whether a number has a unit, and G-10 (a secret's name
ends in `_KEY`, `_SECRET`, `_TOKEN` or `_PASSWORD`) would report every secret connection string.

## The format

```yaml
# platform-api/env.schema.yaml
service: platform-api
runtime: python
naming:
  components: [API, DATABASE, WORKERS]
bindings:
  API_PORT:
    type: integer
    default: 8080
    sensitivity: internal
    description: TCP port the HTTP server listens on inside the container.
  API_REQUEST_TIMEOUT_SEC:
    type: integer
    default: 30
    constraints: {min: 1, max: 300}
    sensitivity: internal
    description: Seconds a request may run before the server cancels it and answers 503.
  DATABASE_URL:
    type: string
    format: url
    required: true
    sensitivity: secret
    local_default: postgres://postgres@localhost:5432/app
    description: Connection string of the primary Postgres database, credentials included.
  ENABLE_AUDIT_LOG:
    type: boolean
    default: false
    sensitivity: internal
    description: Writes an audit event for every state-changing request when true.
retired:
  - name: API_LEGACY_TOKEN
    retired_on: "2026-05-01"
    reason: Requests authenticate with signed service tokens; see API_SIGNING_KEY.
generated:
  pydantic: {base_class: BaseSettings}
```

The authoritative shape is `checks/schemas/env-schema.schema.json` (draft-07), and ENVS-03 checks every schema
against it.

### Top level

| Field | Required | Meaning |
| --- | --- | --- |
| `service` | yes | The deployable the schema describes, e.g. `platform-api`; `devcontainer` for the dev environment's |
| `runtime` | yes | What reads the environment, as a lowercase token: `python`, `sveltekit`, `node`, `go`, `rust`, `docker-compose` |
| `bindings` | yes | Every variable, keyed by name. `{}` when there are none |
| `naming` | no | The schema's vocabulary for the naming grammar: `components`, `client_prefixes`, `vendor_prefixes` |
| `vendor_passthrough` | no | Variables a vendor library reads by its own name, passed through rather than bound; the grammar does not apply. A trailing `*` passes a prefix |
| `retired` | no | Names the product stopped reading on purpose: `name`, `retired_on` (a quoted date), `reason` (ENVS-05) |
| `shared_with` | no | Variables that hold the same value in several deployables: `name`, and `apps` of `service` and `path` (ENVS-08) |
| `settings_file` | no | Where a generated settings module is written, or `null` |
| `env_file` | no | The one file the process reads its environment from, when it reads a file |
| `generated` | no | Code generation: `pydantic` (`base_class`, `extra_imports`) for `runtime: python`, `ts` (`framework`, `client_prefix`, `output_path`) for `runtime: sveltekit` |
| `infisical` | no | Where the values are kept in Infisical (`path`, `environment`) and how they reach the process (`delivery`: `container` or `coolify-env`) |
| `coolify_env` | no | The variables the deployment platform must hold before the process can reach its secret store: `required` and `optional` |

### A binding

| Field | Required | Meaning |
| --- | --- | --- |
| `type` | yes | `string`, `integer`, `number`, `boolean`, `enum` or `list` |
| `sensitivity` | yes | `public`, `internal`, `confidential` or `secret`; see below |
| `description` | yes | What the variable is for, in at least 24 characters: what breaks when the value is wrong, not what the name says |
| `values` | for `enum` | The allowed values; also allowed on a `list` |
| `format` | no | `url`, `email`, `path` or `json`. `url` marks an address the process connects to, not an identifier shaped like a URL (ENVS-12) |
| `default` | no | The value used when the variable is unset. It ships to production |
| `required` | no | The product refuses to start without a value |
| `allow_empty` | no | An empty value is deliberate and valid; needs `default: ""` |
| `local_default` | no | A value written into a developer's local environment file, correct only there |
| `local_generate` | no | Mint per-developer secret material instead: `hex:<bytes>`, `base64:<bytes>` or `base64url:<bytes>` |
| `constraints` | no | `min_length`, `max_length`, `min`, `max`, `pattern` |
| `lifecycle` | no | `build-time`, `deploy-time`, `runtime` (the default) or `ephemeral` |
| `source` | no | `code-default`, `env-file`, `infisical`, `ci-secret`, `vendor` or `host` |
| `path` | no | The secret-store path, when not the schema's `infisical.path` |
| `consumer` | no | The part of the product that reads it: `api`, `workers`, `client` (the browser) or `server` |
| `consumers` | no | The dev-environment stacks that read it |
| `roles` | no | The host roles whose rendered environment file carries it |
| `group` | no | A heading the rendered environment file groups it under |
| `mirrored_in` | no | Files that repeat its `local_default` and must agree with it |
| `nested` | no | Groups it into a nested settings model: `group`, `sub`, `field`, `model` (ENVS-13) |
| `grammar_exempt`, `grammar_exempt_reason` | no | The grammar does not apply, and why |
| `python_field_name` | no | The generated Python field name, when the natural one would collide |

### Sensitivity

The platform used four levels and the dev container three; the format keeps all four, so the dev container's are a
subset and nothing is relabeled.

| Level | Who may see the value |
| --- | --- |
| `public` | Anyone, including a browser that downloads it |
| `internal` | People in the organization |
| `confidential` | People who operate the product; not a credential, but not for everyone |
| `secret` | Only the process. A credential or key; never committed (ENVS-06) |

### The naming grammar

A binding's name says what it configures before its value does. The grammar is:

```text
[<client prefix>]<COMPONENT>_<WHAT>[_<UNIT>]      API_REQUEST_TIMEOUT_SEC, VITE_API_BASE_URL
[<client prefix>]ENABLE_|IS_|HAS_|SHOULD_<WHAT>    ENABLE_AUDIT_LOG, VITE_ENABLE_BILLING
<GROUP>__<SUB>__<FIELD>                            WORKERS__EXPORT__BATCH_SIZE
```

The components are the schema's own: `naming.components` lists them, generalizing the platform's single list, and
ENVS-04 checks the first word against them only when the list is declared. `naming.client_prefixes` defaults to
`VITE_` and `PUBLIC_`, plus `generated.ts.client_prefix`. A name that something outside the repository fixes, such as
`OTEL_EXPORTER_OTLP_ENDPOINT`, is either a `vendor_passthrough` entry, a binding under a `naming.vendor_prefixes`
prefix, or a binding with `grammar_exempt: true` and its reason. ENVS-04 and ENVS-09 to ENVS-14 skip all three.

## Requirements

### ENVS-03

**An environment schema is valid against the published format.**

Every tool that reads a schema (a generator, a preflight, a reference page) assumes its shape. A misspelled field is
silently ignored by all of them, a sensitivity outside the list means nobody knows how to treat the value, and a
missing description leaves the next reader guessing. One finding reports the first problem and how many more there
are.

**Correct:**

```yaml
API_PORT:
  type: integer
  sensitivity: internal
  description: TCP port the HTTP server listens on inside the container.
```

**Incorrect:**

```yaml
API_PORT:
  type: int                   # not a type
  sensitivity: private        # not a level
  summary: The API port.      # not a field; description is missing
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container ENV-01

### ENVS-04

**A binding name is UPPER_SNAKE_CASE and starts with a declared component.**

A name is found by search, typed in shells and read in logs. One case and one separator make it findable, and a
first word from a closed vocabulary groups related variables and says what they configure. The vocabulary is the
schema's own `naming.components`; a schema without one is checked only for the case. A boolean name and a client
prefix may come before the component.

**Correct:**

```yaml
naming:
  components: [API, DATABASE]
bindings:
  API_PORT: {...}
  DATABASE_URL: {...}
```

**Incorrect:**

```yaml
bindings:
  Port: {...}                 # not UPPER_SNAKE_CASE
  SERVER_PORT: {...}          # SERVER is not a declared component
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform G-01

### ENVS-05

**A retired name is never declared again.**

Deleting a variable stops it being read; it does not stop it coming back, re-added with a reader by someone who never
knew it was removed on purpose. A `retired` entry records the removal with its reason, and the check refuses the name
as a binding, a `vendor_passthrough` entry or a `coolify_env` key, quoting the reason. Reviving a name is deleting its
entry in the same change. The platform's tool also refuses the name in the product's source; that half needs the
code and stays there.

**Correct:**

```yaml
retired:
  - name: API_LEGACY_TOKEN
    retired_on: "2026-05-01"
    reason: Requests authenticate with signed service tokens; see API_SIGNING_KEY.
```

**Incorrect:**

```yaml
bindings:
  API_LEGACY_TOKEN: {...}     # retired above
```

Checked by: conftest · Severity: warning · Since: 0.6.0

### ENVS-06

**A secret binding commits no value but an empty one or a loopback address.**

The schema is committed, so a `default` or `local_default` on a secret is a credential in version control, shared
with everyone who can read the repository. An empty string (explicitly unset) and a URL whose host is the local
machine (`localhost`, `127.0.0.1`, `[::1]`, `host.docker.internal`) cannot authenticate anywhere else. Secret material
each developer needs goes in `local_generate`, which mints it locally.

**Correct:**

```yaml
DATABASE_URL:
  sensitivity: secret
  local_default: postgres://postgres@localhost:5432/app
API_SIGNING_KEY:
  sensitivity: secret
  local_generate: base64:32
```

**Incorrect:**

```yaml
DATABASE_URL:
  sensitivity: secret
  local_default: postgres://app:hunter2@db.example.com:5432/app
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container ENV-07

### ENVS-07

**A schema's fields agree with each other.**

Some combinations are each valid alone and contradictory together, and a JSON Schema cannot say so clearly. Each
contradiction leaves a tool to pick one reading, and different tools pick differently. The check reports:

| Combination | Why |
| --- | --- |
| `type: enum` without `values` | Nothing can be validated |
| `required: true` with a `default` | A default makes it never missing |
| `allow_empty: true` without `default: ""` | The empty value it allows must be the default |
| `grammar_exempt: true` without `grammar_exempt_reason` | An exemption says why |
| `local_default` with `local_generate` | A binding has one local source |
| `local_generate` on a binding that is not `secret` | Minted entropy is secret material |
| `local_generate` shorter than `constraints.min_length` | The minted value would fail validation at start |
| A `local_default` that does not satisfy the binding's `type` | The local file would not start the product |
| `generated.pydantic` without `runtime: python`, or `generated.ts` without `runtime: sveltekit` | The generator does not match what reads the file |
| A `t3-core-dynamic` client binding without a `default`, or `required` | It is empty at build time |
| A `shared_with` name that is not a binding, or whose `apps` omit this service | The entry describes a variable the schema does not have |
| A `coolify_env` name in both `required` and `optional` | It is one or the other |

**Correct:**

```yaml
DATABASE_POOL_URL:
  type: string
  allow_empty: true
  default: ""
  sensitivity: secret
```

**Incorrect:**

```yaml
DATABASE_POOL_URL:
  type: string
  allow_empty: true           # no default: ""
  required: true
  default: postgres://localhost/app
  sensitivity: secret
```

Checked by: conftest · Severity: warning · Since: 0.6.0

### ENVS-08

**Every copy of a shared variable agrees in type and sensitivity.**

A variable in `shared_with` holds one value in several deployables: a signing key the API writes with and a worker
verifies with. If one schema says `secret` and another `internal`, one of them logs it; if the types differ, one of
them rejects the value the other accepts. Among the schemas in one repository, each copy must agree, and a service
the entry names must declare the entry too. Schemas in other repositories are not visible to the check.

**Correct:**

```yaml
# api/env.schema.yaml and workers/env.schema.yaml
API_SIGNING_KEY: {type: string, sensitivity: secret, ...}
```

**Incorrect:**

```yaml
# workers/env.schema.yaml
API_SIGNING_KEY: {type: string, sensitivity: internal, ...}
```

Checked by: conftest · Severity: warning · Since: 0.6.0

### ENVS-09

**A boolean binding's name starts with a boolean prefix.**

The boolean prefixes are `ENABLE_`, `IS_`, `HAS_` and `SHOULD_`. A flag read as a question is set right the first
time: `ENABLE_AUDIT_LOG=true` cannot be misread, `AUDIT_LOG=true` can be a path. A browser flag keeps its client
prefix first (`VITE_ENABLE_BILLING`), and a nested flag puts the prefix on its field (`WORKERS__EXPORT__IS_ENABLED`).

**Correct:**

```yaml
ENABLE_AUDIT_LOG: {type: boolean, ...}
VITE_ENABLE_BILLING: {type: boolean, ...}
```

**Incorrect:**

```yaml
AUDIT_LOG: {type: boolean, ...}
VITE_BILLING: {type: boolean, ...}
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform G-02, G-11

### ENVS-10

**A unit suffix is abbreviated.**

One spelling per unit keeps related variables sorted together and searchable: `_SEC`, `_MIN`, `_HR`, `_MS`, `_PCT`,
`_BYTES`, `_KB`, `_MB`, `_GB`, `_COUNT`. The check reports the long forms `_SECONDS`, `_MINUTES`, `_MILLISECONDS` and
`_PERCENT`.

**Correct:**

```yaml
API_REQUEST_TIMEOUT_SEC: {...}
```

**Incorrect:**

```yaml
API_REQUEST_TIMEOUT_SECONDS: {...}
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform G-04

### ENVS-11

**A binding name does not repeat a word.**

A repeated word (`API_API_URL`, `DATABASE_DATABASE_NAME`) is almost always a component prefix added to a name that
already had it. It reads as a different variable from the one the code expects, and the next person adds a third.

**Correct:**

```yaml
API_URL: {...}
```

**Incorrect:**

```yaml
API_API_URL: {...}
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform G-07

### ENVS-12

**A URL binding's name ends in `_URL`.**

A binding with `format: url` is a URL, and a name that says so tells the reader to write a scheme and host, not a
bare hostname. `_BASE_URL` ends in `_URL` too, for a URL others are appended to.

`format: url` marks an address the process connects to. An identifier that is only shaped like a URL, such as an
OIDC issuer, a JWT audience or a namespace URI, is compared as a string and never fetched, so its binding leaves
`format` unset and may pin the shape with `constraints.pattern`, such as `^https://`. `grammar_exempt` is not the way
out: it is for a name fixed outside the product, and it turns off every grammar requirement, not just this one.

**Correct:**

```yaml
API_BASE_URL: {type: string, format: url, ...}
API_JWT_ISSUER: {type: string, constraints: {pattern: '^https://'}, ...}   # an identifier, not an address
```

**Incorrect:**

```yaml
API_ENDPOINT: {type: string, format: url, ...}
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform G-09

### ENVS-13

**A nested binding's name separates its parts with `__`.**

A binding with a `nested` block is read into a nested settings model, and settings libraries split a name on `__` to
find the group, sub-model and field. A name with single underscores cannot be split, so the value lands nowhere.

**Correct:**

```yaml
WORKERS__EXPORT__BATCH_SIZE:
  nested: {group: workers, sub: export, field: batch_size}
```

**Incorrect:**

```yaml
WORKERS_EXPORT_BATCH_SIZE:
  nested: {group: workers, sub: export, field: batch_size}
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform G-08

### ENVS-14

**A binding the browser reads starts with a client prefix.**

Front-end build tools expose to the browser only the variables with their prefix (`VITE_`, or `PUBLIC_` for values
read from the server at start), and the prefix is also what tells a reviewer that the value ships to every visitor.
A binding with `consumer: client` and no prefix is undefined in the browser. The prefixes are
`naming.client_prefixes`, by default `VITE_` and `PUBLIC_`, plus `generated.ts.client_prefix`.

**Correct:**

```yaml
VITE_API_BASE_URL: {consumer: client, sensitivity: public, ...}
```

**Incorrect:**

```yaml
API_BASE_URL: {consumer: client, sensitivity: public, ...}
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform G-06

## References

- [EC-0019 Environment contract](env-contract.md)
- [The Twelve-Factor App: Config](https://12factor.net/config)
- `checks/schemas/env-schema.schema.json`
