---
id: EC-0030
title: Interfaces declaration
summary: >-
  A repository declares each surface another repository builds or runs
  against as an interface in .repo/outputs.toml, with its format, the files
  that define it, the output that delivers it and what it promises about
  change, and keeps those files, and only those, in its contracts directory.
status: draft
topic: interfaces
applies_to:
  paths:
    - .repo/outputs.toml
    - "contracts/**"
    - "*/contracts/**"
created: 2026-09-30
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "Backstage: Descriptor format of catalog entities (API)"
    url: https://backstage.io/docs/features/software-catalog/descriptor-format/#kind-api
  - title: "OpenAPI Specification"
    url: https://spec.openapis.org/oas/
  - title: "JSON Schema"
    url: https://json-schema.org/
requirements:
  - id: IFACE-01
    title: Every file in the contracts directory belongs to a declared interface
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.interfaces.declaration
  - id: IFACE-02
    title: An interface's format, compatibility and audience are registered values
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.interfaces.declaration
  - id: IFACE-03
    title: Interface IDs are unique within a repository
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.interfaces.declaration
  - id: IFACE-04
    title: Every definitions entry of an interface matches a file the repository holds
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.interfaces.declaration
  - id: IFACE-05
    title: No file belongs to two interfaces
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.interfaces.declaration
  - id: IFACE-06
    title: An interface is delivered by a bundle, site or library output the declaration lists
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.interfaces.declaration
  - id: IFACE-07
    title: Every file of a versioned interface carries its major version in its name
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.interfaces.declaration
  - id: IFACE-08
    title: An interface's definitions live in the product's contracts directory
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.interfaces.declaration
---

# Interfaces declaration

A repository that others build against offers one or more **interfaces**: surfaces such as an HTTP API, a family of
event schemas or a registry of error types. Until each is declared, a consumer cannot say which one it depends on,
a producer cannot tell which consumers a change affects, and a reader has to open workflows and bundles to learn what
is offered at all. So each interface is declared once, in `[[interfaces]]` in `.repo/outputs.toml`, beside the outputs
that deliver it.

An interface is not an output. The output is what a consumer downloads: a bundle, a site that serves schemas, a
library. The interface is what the consumer builds against. One bundle usually delivers several interfaces, and a
consumer depends on the interfaces it uses, not on the bundle.

## Scope

This convention covers `[[interfaces]]` in `.repo/outputs.toml` and the contracts directory. The formats themselves
(OpenAPI, AsyncAPI, JSON Schema, protobuf, OpenTelemetry Weaver, systemd units) are defined by their own
specifications, and this convention only names them; a data document's shape is its producer's. What a publishing
repository must run to keep its interfaces current and compatible is [EC-0031](publishing-interfaces.md); how another
repository takes an interface is [EC-0032](../dependencies/dependencies-declaration.md).

**What is an interface.** A surface is an interface when another repository builds or runs against it. A server with
one document per audience (public, agent, control plane, webhooks) has one interface per document, because each has
its own consumers and its own promise. A file only the producer reads, such as an internal state diagram or a list
its tests use, is not an interface and does not go in the contracts directory.

A surface another repository deploys rather than builds against is an interface too. Systemd units that a
host-configuration repository installs on its hosts are declared as a `systemd-unit` interface, offered from the
contracts directory like any other, and vendored by the consumer unchanged
([EC-0032](../dependencies/dependencies-declaration.md#the-vendored-copy)).

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`), and its requirements are `proposed` at
severity `warning`
([decision 0022](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0022-interfaces-and-dependencies.md)),
with the `data` and `systemd-unit` formats added by
[decision 0027](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0027-data-units-and-fetched-dependencies.md).
It replaces the `contract` output kind and OUT-07 ([EC-0007](../outputs/outputs-declaration.md)). IFACE-08 applies to
repositories whose kind is `service`, `website`, `library` or `tool`: a `specification` repository's product is its
interfaces, laid out as its own published paths require.

## The declaration

Interfaces are declared in the outputs declaration, which says `schema_version = 2`:

```toml
# .repo/outputs.toml
schema_version = 2

[[outputs]]
id = "contracts"
kind = "bundle"
source = "platform-api/contracts/"
publish_workflow = "release.yml"
location = "https://github.com/your-org/platform-api/releases"
docs = "platform-api/contracts/README.md"

[[interfaces]]
id = "public-http"
format = "openapi"
description = "The public HTTP API that customers' tools call."
definitions = ["platform-api/contracts/openapi/public.json"]
delivered_by = "contracts"
compatibility = "gated"
audience = "public"
generated = true

[[interfaces]]
id = "control-plane-http"
format = "openapi"
definitions = ["platform-api/contracts/openapi/control-plane.json"]
delivered_by = "contracts"
compatibility = "lockstep"
audience = "internal"
generated = true

[[interfaces]]
id = "events"
format = "json-schema"
definitions = ["platform-api/contracts/events/*.schema.json"]
delivered_by = "contracts"
compatibility = "versioned"
audience = "internal"
generated = true
```

| Field | Required | Meaning |
| --- | --- | --- |
| `id` | yes | The interface's name within the repository, in kebab-case and unique (IFACE-03). Another repository addresses it as `<repository>#<id>`, such as `platform-api#public-http`. |
| `format` | yes | An interface format from the table below (IFACE-02). |
| `description` | no | One line on what it is for and who builds against it. |
| `definitions` | yes | The files that define it: a file, a directory ending in `/`, or a glob in which `*` stays within one path segment and `**` crosses them (IFACE-04, IFACE-05, IFACE-08). |
| `delivered_by` | yes | The ID of the `bundle`, `site` or `library` output that delivers its files (IFACE-06). |
| `compatibility` | yes | What the producer promises about a change, from the table below (IFACE-02, IFACE-07). |
| `audience` | no | `public` or `internal`, as in the identity declaration (IFACE-02). |
| `generated` | no | `true` when the product's code writes its definitions, so a drift check applies ([EC-0031](publishing-interfaces.md)). |
| `docs` | no | The document, with an optional `#anchor`, that says how to build against it. |

An interface's version is the version of the release that delivers it. A `versioned` interface also carries the
major version of each file in the file's name.

The authoritative shape is `checks/schemas/outputs.schema.json`, and OUT-02 checks the file against it.
`schema_version = 1` is still accepted in this release series, without `[[interfaces]]`; an output of the retired
`contract` kind is reported by OUT-03.

### Formats

The formats are terms tagged `interfaces.format` in `definitions/terminology/global.yml`, so a new format is a
terminology change.

| Format | Is |
| --- | --- |
| `openapi` | An OpenAPI document: an HTTP API's paths, operations and schemas |
| `asyncapi` | An AsyncAPI document: message-driven channels and their messages |
| `json-schema` | One or more JSON Schema documents, such as event payloads or a document format |
| `protobuf` | Protocol Buffers messages and gRPC services, in `.proto` files |
| `env-schema` | An `env.schema.yaml` ([EC-0020](../environment/env-schema.md)), when another repository deploys or configures the product |
| `weaver` | An OpenTelemetry Weaver registry: the telemetry signals a producer emits |
| `data` | One or more JSON or YAML documents that are the published fact themselves: a registry, a vocabulary, a rate card |
| `systemd-unit` | systemd unit files (service, timer, socket and the other unit types) that another repository installs on the hosts it configures |

### Compatibility

| Compatibility | Promise | Fits |
| --- | --- | --- |
| `gated` | A change that breaks a consumer ships only in a release marked breaking. `contracts:breaking` compares each change with the last release and fails on a break no commit marked breaking signals. | A public or partner API |
| `versioned` | A published `.vN.` file never changes. A break is a new file with the next number, and the old one stays for the consumers that read it. | Event schemas, webhooks: anything read long after it was written |
| `lockstep` | No promise across releases. Only consumers released in the same composition as the producer may depend on it. | An internal API that ships with its only clients |

A release marked breaking is a major release from 1.0.0, and a minor release in the 0.x series, as Semantic Versioning
§4 allows. Either is cut by a commit marked `!` or carrying `BREAKING CHANGE`; `contracts:breaking` checks the mark,
not the number.

### The contracts directory

The contracts directory is `<product>/contracts/`, or `contracts/` at the root when the repository declares
`product = ""` ([EC-0018](../repository/layout.md)). It holds exactly the interfaces the repository offers, and under
`vendor/`, the copies it takes from other repositories ([EC-0032](../dependencies/dependencies-declaration.md)). One
place to look is what lets a reader, a reviewer or a tool find every interface without reading the code.

```text
platform-api/contracts/
├── README.md                  how to build against each interface
├── openapi/public.json        public-http
├── openapi/control-plane.json control-plane-http
├── events/*.v1.schema.json    events
└── vendor/                    copies of other repositories' interfaces
```

## Requirements

### IFACE-01

**Every file in the contracts directory belongs to a declared interface.**

The contracts directory is where consumers and tools look for what a repository offers. A file there that no
interface covers is either an interface nobody declared, so no consumer can depend on it and no check guards it, or a
private file that looks public. The finding is reported on each such file. Documents (`*.md`), dotfiles and the
`vendor/` directory are not checked.

**Correct:**

```toml
[[interfaces]]
id = "public-http"
definitions = ["platform-api/contracts/openapi/public.json"]
```

**Incorrect:**

```text
platform-api/contracts/openapi/public.json
platform-api/contracts/state-machines/order.mmd   # read only by the producer: move it out of contracts/
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### IFACE-02

**An interface's format, compatibility and audience are registered values.**

The format decides which tool reads an interface and which breaking-change check applies; the compatibility decides
what a consumer may rely on. A free-form value (`oas3`, `swagger`, `stable`) splits one meaning into several and
leaves every tool guessing.

**Correct:**

```toml
format = "openapi"
compatibility = "gated"
audience = "public"
```

**Incorrect:**

```toml
format = "swagger"
compatibility = "stable"
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### IFACE-03

**Interface IDs are unique within a repository.**

A consumer names an interface as `<repository>#<id>` in its dependencies and in its environment bindings. Two
interfaces with one ID make every such reference ambiguous.

**Correct:**

```toml
[[interfaces]]
id = "public-http"

[[interfaces]]
id = "agent-http"
```

**Incorrect:**

```toml
[[interfaces]]
id = "http"

[[interfaces]]
id = "http"
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### IFACE-04

**Every definitions entry of an interface matches a file the repository holds.**

A definitions entry that matches nothing, usually after a file was moved or renamed, declares an interface with no
files: the bundle ships without it and every check of it passes vacuously.

**Correct:**

```toml
definitions = ["platform-api/contracts/events/*.schema.json"]   # matches the event schemas
```

**Incorrect:**

```toml
definitions = ["platform-api/contracts/event/*.json"]            # the directory is events/
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### IFACE-05

**No file belongs to two interfaces.**

Each interface has its own consumers and its own compatibility. A file in two interfaces gets two promises, and a
breaking-change check judges it twice, perhaps differently. The finding is reported on each shared file.

**Correct:**

```toml
[[interfaces]]
id = "public-http"
definitions = ["platform-api/contracts/openapi/public.json"]

[[interfaces]]
id = "agent-http"
definitions = ["platform-api/contracts/openapi/agent.json"]
```

**Incorrect:**

```toml
[[interfaces]]
id = "public-http"
definitions = ["platform-api/contracts/openapi/"]

[[interfaces]]
id = "agent-http"
definitions = ["platform-api/contracts/openapi/agent.json"]   # also covered by public-http
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### IFACE-06

**An interface is delivered by a bundle, site or library output the declaration lists.**

A consumer gets an interface by fetching the output that delivers it. The output must exist in the declaration, and
must be one that carries files: a bundle (released assets), a site (files served by URL) or a library (a package that
ships them). An image runs the implementation; it does not deliver the definition.

**Correct:**

```toml
[[outputs]]
id = "contracts"
kind = "bundle"

[[interfaces]]
id = "public-http"
delivered_by = "contracts"
```

**Incorrect:**

```toml
[[outputs]]
id = "image"
kind = "image"

[[interfaces]]
id = "public-http"
delivered_by = "image"      # an image does not deliver files to build against
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### IFACE-07

**Every file of a versioned interface carries its major version in its name.**

A `versioned` interface promises that a published file never changes and that a break is a new file. The major
version in the name, as `.vN.`, is what makes that visible: a consumer reads `order.created.v1.schema.json` and knows
it keeps reading the same shape. The finding is reported on each file without it.

**Correct:**

```text
platform-api/contracts/events/order.created.v1.schema.json
platform-api/contracts/events/order.created.v2.schema.json
```

**Incorrect:**

```text
platform-api/contracts/events/order.created.schema.json
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### IFACE-08

**An interface's definitions live in the product's contracts directory.**

One directory for every interface a repository offers is what lets a consumer, a reviewer or a tool find them without
reading the code, and what lets IFACE-01 prove nothing in it is undeclared. A definition elsewhere is an interface the
repository offers from a place nobody looks. The check needs the product directory from `[layout]`; without one,
REPO-14 is reported instead.

**Correct:**

```toml
definitions = ["platform-api/contracts/proto/"]
```

**Incorrect:**

```toml
definitions = ["platform-api/proto/"]
```

Checked by: conftest · Severity: warning · Since: 0.7.0

## References

- [EC-0031 Publishing interfaces](publishing-interfaces.md)
- [EC-0032 Dependencies declaration](../dependencies/dependencies-declaration.md)
- [EC-0007 Outputs declaration](../outputs/outputs-declaration.md)
- [Decision 0022: Interfaces and dependencies](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0022-interfaces-and-dependencies.md)
- `checks/schemas/outputs.schema.json`
