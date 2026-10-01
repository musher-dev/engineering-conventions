---
id: EC-0020
title: Environment schema
summary: >-
  An env.schema.yaml declares every variable a product or dev environment
  reads: its type, its sensitivity and what it is for, in one published
  format with optional blocks for code generation, secret delivery and the
  deployment platform. Binding names follow one grammar over a vocabulary
  the schema declares, retired names stay retired, no secret value is
  committed, a variable shared between deployables agrees everywhere, a
  binding that reaches another service or an outside capability names it,
  the runtime instances a service needs are declared once, with the
  range of versions its code works with, and a schema can name every
  binding after the program that reads it.
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
  - id: ENVS-16
    title: A binding names at most one of target and capability, and a provider only with a capability
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_schema
  - id: ENVS-17
    title: A binding's target is another repository's interface, written <repository>#<interface>
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_schema
  - id: ENVS-18
    title: A binding's capability is a registered runtime capability
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.environment.env_schema
  - id: ENVS-19
    title: A binding that reaches another service or an outside capability names it
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: review
  - id: ENVS-22
    title: A binding that reaches a runtime capability names it through requires
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.environment.env_schema
  - id: ENVS-23
    title: Every runtime instance is declared, reached by a binding, and a registered capability
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.environment.env_schema
  - id: ENVS-24
    title: A consumer prefix is MUSHER_ and the repository's component
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.environment.env_grammar
  - id: ENVS-25
    title: Under a consumer prefix, every binding name starts with it, or is reserved, a vendor's or legacy
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.environment.env_grammar
---

# Environment schema

An `env.schema.yaml` declares every variable a product, or a dev environment, reads from its environment. It is
written by hand and is the source everything else is derived from: the environment contract an `env-schema` interface
delivers, a local environment file, a generated settings module, a deploy preflight, a reference page. What is checked
here is that the source is well-formed, named consistently and safe to commit. The contract and `.env.example` are
derived by a mapping the release ships, and [EC-0019](env-contract.md#what-is-derived-from-the-schema) checks them
(ENVS-20, ENVS-21).

## Scope

This convention covers the content of every environment schema; where one lives is [EC-0019](env-contract.md). The
format is the one `musher-dev/platform` and `musher-dev/development-container` already use, unified: every field
either repository defines is part of it, and a schema from either validates unchanged.

A vendored copy under `contracts/vendor/` is another repository's schema; ENVS-03 to ENVS-19 do not read it.

Checks that need the code are out of scope: that the code reads only declared variables, that every binding has a
reader, and that a generated settings module is current. They stay with each product's own tooling.

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
| `naming` | no | The schema's vocabulary for the naming grammar: `components`, `client_prefixes`, `vendor_prefixes`, and `consumer_prefix` and `legacy` (ENVS-24, ENVS-25) |
| `requires` | no | Every runtime instance the service needs, keyed by an instance ID: `capability`, `version` (a range), optionally `provider`, and `description` (ENVS-22, ENVS-23) |
| `vendor_passthrough` | no | Variables a vendor library reads by its own name, passed through rather than bound; the grammar does not apply. A trailing `*` passes a prefix |
| `retired` | no | Names the product stopped reading on purpose: `name`, `retired_on` (a quoted date), `reason`, and `replacement` when it was renamed (ENVS-05) |
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
| `target` | no | The other Musher service the value reaches, as `<repository>#<interface>`, e.g. `platform-api#public-http` (ENVS-16, ENVS-17) |
| `capability` | no | What the value reaches when it is not a Musher service: a registered runtime capability, e.g. `postgresql` (ENVS-16, ENVS-18) |
| `provider` | no | The vendor whose API the code speaks for that capability, e.g. `stripe`; only with `capability` (ENVS-16) |
| `requires` | no | The runtime instance the value reaches, by its ID under the top-level `requires`; never with `target`, `capability` or `provider` (ENVS-16, ENVS-22, ENVS-23) |

### What a binding reaches

A service's runtime dependencies are already in its schema: the variables that hold where to connect. Naming what
each one reaches turns the schema into the service's runtime edges, which the dependency graph reads, and which a
reviewer and a deploy check can use without guessing from names
([decision 0022](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0022-interfaces-and-dependencies.md)).

```yaml
bindings:
  PLATFORM_API_BASE_URL:
    type: string
    format: url
    sensitivity: internal
    target: platform-api#public-http
    description: The public API the console calls to load a workspace.
  DATABASE_URL:
    type: string
    format: url
    sensitivity: secret
    capability: postgresql
    description: The PostgreSQL database that holds every account, workspace and job.
  STRIPE_API_KEY:
    type: string
    sensitivity: secret
    capability: payments
    provider: stripe
    description: The key the billing worker charges and refunds customers with.
```

A binding names **either** a `target`, another Musher service's interface, **or** a `capability`, something outside
Musher that the code needs. It names what the code needs, never the cluster, bucket or account that provides it:
that is a fact of each environment, held in its configuration. Several bindings may reach one thing (a database's
URL and its admin URL), and each names it.

The capabilities are terms tagged `runtime.capability` in `definitions/terminology/global.yml`, so a new one is a
terminology change. A capability that names an engine, such as `postgresql` or `valkey`, means that engine: its
protocol and semantics are what the code depends on, and a compatible server from another project is a different
engine. `cdn` covers content delivery only; an edge platform's key-value store or functions are `edge-compute`.

| Capability | Is |
| --- | --- |
| `postgresql` | A PostgreSQL database, including a queue or notification channel kept in it |
| `object-storage` | An object store, through an S3-compatible API or a provider's own |
| `otlp` | An OpenTelemetry collector the process exports to |
| `email-delivery` | A service the process sends email through |
| `payments` | A payment provider |
| `llm` | A hosted language model |
| `oauth-identity` | An OAuth or OpenID Connect provider users sign in with |
| `code-hosting` | A source code host the process calls as an application |
| `dns` | A DNS provider whose records the process reads or changes |
| `cdn` | A content delivery network whose caching and delivery the process configures or purges |
| `vpn-mesh` | An overlay network the process joins or manages |
| `block-storage` | A block storage system whose volumes the process provisions |
| `cloud-compute` | A cloud provider whose machines the process creates or destroys |
| `web-search` | A search engine API the process queries |
| `container-registry` | A container image registry the process, or the machines it manages, pull from or push to |
| `edge-compute` | An edge platform's key-value store or functions the process writes to or deploys |
| `access-proxy` | An identity-aware proxy in front of services the process calls, presenting a service credential |
| `valkey` | A Valkey key-value server the process reads from and writes to over its Redis-compatible protocol: a cache, counters, short-lived state |

### Runtime requirements

Some capabilities are engines the code depends on by version: a query that needs PostgreSQL 18, a command Valkey added
in 9. That fact belongs to the service, which knows what its code uses, while the exact version in an environment
belongs to whoever provisions it, who moves minor and patch versions as routine maintenance. So a schema declares each
runtime instance the service needs once, at the top level, with the **range** of versions its code works with, and
each binding that reaches the instance names it:

```yaml
requires:
  primary-db:
    capability: postgresql
    version: ">=18"
    description: Every account, workspace and job.
  cache:
    capability: valkey
    version: ">=9, <10"
    provider: digitalocean
    description: Rate-limit counters and short-lived sessions.
bindings:
  DATABASE_URL: {type: string, format: url, sensitivity: secret, requires: primary-db, description: "…"}
  DATABASE_ADMIN_URL: {type: string, format: url, sensitivity: secret, requires: primary-db, description: "…"}
  CACHE_URL: {type: string, format: url, sensitivity: secret, requires: cache, description: "…"}
```

A range is one or more comparators separated by commas, all of which must hold. An operator is `>=`, `>`, `<=`, `<`
or `==`, and a version is integers separated by dots, a missing component counting as 0, so `<10` excludes `10.0` and
`==1.2` matches `1.2.0`. There is no `^`, `~` or wildcard: write both bounds out. ENVS-03 checks the grammar.

A range is not a pin. The exact version a vendored release is pinned to belongs in `.repo/dependencies.toml`
([EC-0032](../dependencies/dependencies-declaration.md)); a runtime the code runs against never goes there. The
derived contract carries `requires` ([EC-0019](env-contract.md#the-contract)), so a deploy preflight can compare it
with what infrastructure reports, and a dev container's compose stack is compared with it when it labels its services
([DEVC-16](../dev-containers/dev-container-stacks.md#devc-16)).

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
prefix, or a binding with `grammar_exempt: true` and its reason. ENVS-04 and ENVS-09 to ENVS-14 skip all three, and
the reserved organization-wide names below.

The test for a vendor's name is narrow: **a name is a vendor's only if a library the repository does not own reads
it**, by that name, without the repository's code in between. `OTEL_SERVICE_NAME`, read by the OpenTelemetry SDK, is
one. `STRIPE_API_KEY`, read by the repository's own code and handed to the Stripe client, is not: the repository chose
the name, so the grammar applies to it.

### Naming a binding after its reader

A name with no reader in it collides. A shared secret store that injects `CACHE_URL` into every service cannot point
two services at two caches, and `DATABASE_URL` means something different in every repository that reads it. The names
that age well are named after the program that reads them, as `SPRING_*`, `OTEL_*` and `POSTGRES_*` are. So a schema
may declare a consumer prefix, and every binding is then named after the service that reads it:

```text
[<client prefix>]<consumer prefix>_<COMPONENT>_<WHAT>[_<UNIT>]      MUSHER_API_CACHE_URL, VITE_MUSHER_WEB_API_BASE_URL
```

```yaml
service: platform-api
naming:
  consumer_prefix: MUSHER_API         # MUSHER_ and component = "api" from .repo/repository.toml (ENVS-24)
  components: [CACHE, DATABASE, HTTP]
  legacy: [DATABASE_URL]              # unprefixed when the schema adopted the prefix; only shrinks
bindings:
  MUSHER_API_CACHE_URL: {...}
  MUSHER_API_HTTP_PORT: {...}
  DATABASE_URL: {...}
  MUSHER_ENVIRONMENT: {...}           # reserved, organization-wide
```

The prefix is `MUSHER_` and the repository's component in upper snake case. With one declared, the grammar (ENVS-04
and ENVS-09 to ENVS-14) applies to the part after it, and ENVS-25 asks every binding to carry it, except:

- a **reserved organization-wide name**, a term tagged `env.org-scoped` in the terminology, such as
  `MUSHER_ENVIRONMENT`, which every Musher program may read. Reserving them keeps `MUSHER_<WORD>` unambiguous;
- a **vendor's name**, under the test above: a `naming.vendor_prefixes` prefix, a `vendor_passthrough` entry, or a
  binding with `grammar_exempt: true`;
- a **legacy name** in `naming.legacy`: a binding that was unprefixed when the schema adopted the prefix.

Infrastructure maps a supplier's name to the consumer's at the seam: a secret-store reference, a platform's variable
reference or a Kubernetes `valueFrom` sets `MUSHER_API_CACHE_URL` from the cache's own output. The code never reads the
supplier's name, and never maps one name to another.

Moving to the prefix is a rename, and a rename is recorded. A binding that gains the prefix leaves `naming.legacy`,
and its old name moves to `retired` with the new name as its `replacement`, so ENVS-05 refuses the old name from then
on. A product that must accept both for a release reads both in its settings module, not in the schema.
`naming.legacy` only shrinks; a reviewer rejects a name added to it.

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

### ENVS-16

**A binding names at most one of `target` and `capability`, and a `provider` only with a `capability`.**

A value reaches one thing. A binding with both says two contradictory things about what it connects to, and a
provider without a capability names a vendor without saying what the code uses it for. A binding that names a runtime
instance with `requires` names nothing else: the instance already says its capability and provider, and an instance
is not another service.

**Correct:**

```yaml
STRIPE_API_KEY: {type: string, sensitivity: secret, capability: payments, provider: stripe, description: "…"}
```

**Incorrect:**

```yaml
STRIPE_API_KEY: {type: string, sensitivity: secret, provider: stripe, description: "…"}
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### ENVS-17

**A binding's `target` is another repository's interface, written `<repository>#<interface>`.**

The target is how a runtime edge is joined to the interface the other service declares
([EC-0030](../interfaces/interfaces-declaration.md)): the repository's name, then the interface's ID. A free-form
value (`api`, `the platform`) joins nothing, and a target in the repository itself is not an edge between services.

**Correct:**

```yaml
PLATFORM_API_BASE_URL: {type: string, format: url, sensitivity: internal, target: "platform-api#public-http", description: "…"}
```

**Incorrect:**

```yaml
PLATFORM_API_BASE_URL: {type: string, format: url, sensitivity: internal, target: api, description: "…"}
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### ENVS-18

**A binding's `capability` is a registered runtime capability.**

A capability is what an environment must provide before the service can run, and what the graph groups services by.
A free-form value (`postgres`, `db`, `s3`) splits one capability into several, so a registered term is the only
spelling.

**Correct:**

```yaml
DATABASE_URL: {type: string, format: url, sensitivity: secret, capability: postgresql, description: "…"}
```

**Incorrect:**

```yaml
DATABASE_URL: {type: string, format: url, sensitivity: secret, capability: postgres, description: "…"}
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### ENVS-19

**A binding that reaches another service or an outside capability names it.**

The runtime graph is only as complete as the bindings that name what they reach. A reviewer checks that each binding
holding an address, a connection string or a credential for something outside the process names its `target` or
`capability`. A value that addresses the service itself, such as its own public origin, names neither.

**Correct:**

```yaml
DATABASE_URL: {type: string, format: url, sensitivity: secret, capability: postgresql, description: "…"}
```

**Incorrect:**

```yaml
DATABASE_URL: {type: string, format: url, sensitivity: secret, description: "…"}
```

Checked by: review · Severity: warning · Since: 0.7.0

### ENVS-22

**A binding that reaches a runtime capability names it through `requires`.**

An inline `capability` says what a binding reaches but not which versions the code works with, and the three bindings
that reach one database each say it again. Declared once under `requires`, the instance carries its range, and every
binding that reaches it points at it. An inline `capability` stays valid against the format while schemas move over;
this requirement reports each one.

**Correct:**

```yaml
requires:
  primary-db: {capability: postgresql, version: ">=18", description: "Every account, workspace and job."}
bindings:
  DATABASE_URL: {type: string, format: url, sensitivity: secret, requires: primary-db, description: "…"}
```

**Incorrect:**

```yaml
bindings:
  DATABASE_URL: {type: string, format: url, sensitivity: secret, capability: postgresql, description: "…"}
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### ENVS-23

**Every runtime instance is declared, reached by a binding, and a registered capability.**

`requires` is only useful when it agrees with the bindings: a binding that names an undeclared instance has no
version to check, an instance no binding reaches is a requirement nothing uses, and an instance whose capability is not
a registered term ([ENVS-18](#envs-18)) cannot be grouped or compared with what an environment provides. The check
reports each.

**Correct:**

```yaml
requires:
  cache: {capability: valkey, version: ">=9, <10", description: "Rate-limit counters and short-lived sessions."}
bindings:
  CACHE_URL: {type: string, format: url, sensitivity: secret, requires: cache, description: "…"}
```

**Incorrect:**

```yaml
requires:
  cache: {capability: redis, version: ">=9", description: "…"}       # not a registered capability
  search: {capability: web-search, version: ">=1", description: "…"} # no binding reaches it
bindings:
  CACHE_URL: {type: string, format: url, sensitivity: secret, requires: kv, description: "…"}   # kv is undeclared
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### ENVS-24

**A consumer prefix is `MUSHER_` and the repository's component.**

The prefix names the program that reads the variables, so it has one spelling everywhere that program is deployed:
`MUSHER_`, then the `component` of `.repo/repository.toml` in upper snake case, its hyphens as underscores. Any other
prefix names a reader nobody can find, or another repository's. The check needs the identity declaration's
`component`, and reports nothing without one.

**Correct:**

```yaml
# .repo/repository.toml: name = "platform-api", component = "api"
naming:
  consumer_prefix: MUSHER_API
```

**Incorrect:**

```yaml
naming:
  consumer_prefix: MUSHER_PLATFORM_API     # the component is api
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### ENVS-25

**Under a consumer prefix, every binding name starts with it, or is reserved, a vendor's or legacy.**

A prefix that only some names carry says nothing about the rest. Once a schema declares `naming.consumer_prefix`, each
binding is `<consumer prefix>_…`, after its client prefix if it has one, unless it is a reserved organization-wide
name, a vendor's name, or listed in `naming.legacy` ([Naming a binding after its reader](#naming-a-binding-after-its-reader)).
A `naming.legacy` entry that is no longer a binding is reported too: the name has moved to `retired`, so it leaves the
list.

**Correct:**

```yaml
naming:
  consumer_prefix: MUSHER_API
  vendor_prefixes: [OTEL_]
  legacy: [DATABASE_URL]
bindings:
  MUSHER_API_CACHE_URL: {...}
  OTEL_SERVICE_NAME: {...}
  DATABASE_URL: {...}
```

**Incorrect:**

```yaml
naming:
  consumer_prefix: MUSHER_API
bindings:
  CACHE_URL: {...}              # no prefix, and not legacy
```

Checked by: conftest · Severity: warning · Since: 0.7.1

## References

- [EC-0019 Environment contract](env-contract.md)
- [The Twelve-Factor App: Config](https://12factor.net/config)
- `checks/schemas/env-schema.schema.json`
