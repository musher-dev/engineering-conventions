---
id: EC-0007
title: Outputs declaration
summary: >-
  A repository that publishes something for others to consume lists each
  output in .repo/outputs.yaml, with its kind, where it is built from, the
  workflow that publishes it, where consumers get it and where its use is
  documented.
status: draft
topic: outputs
applies_to:
  paths:
    - .repo/outputs.yaml
    - .github/workflows/*.yml
    - .github/workflows/*.yaml
created: 2026-09-24
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "Backstage: Descriptor format of catalog entities"
    url: https://backstage.io/docs/features/software-catalog/descriptor-format/
  - title: "OCI image-spec: Pre-defined annotation keys"
    url: https://github.com/opencontainers/image-spec/blob/main/annotations.md
requirements:
  - id: OUT-01
    title: A repository with a publish workflow declares its outputs in .repo/outputs.yaml
    status: proposed
    severity: warning
    since: 0.3.0
    validation:
      engine: conftest
      package: conventions.checks.outputs.declaration
  - id: OUT-02
    title: The outputs declaration is valid against its schema
    status: proposed
    severity: warning
    since: 0.3.0
    validation:
      engine: conftest
      package: conventions.checks.outputs.declaration
  - id: OUT-03
    title: An output's kind is a registered output kind
    status: proposed
    severity: warning
    since: 0.3.0
    validation:
      engine: conftest
      package: conventions.checks.outputs.declaration
  - id: OUT-04
    title: Output IDs are unique within a repository
    status: proposed
    severity: warning
    since: 0.3.0
    validation:
      engine: conftest
      package: conventions.checks.outputs.declaration
  - id: OUT-05
    title: Every path an output names exists
    status: proposed
    severity: warning
    since: 0.3.0
    validation:
      engine: conftest
      package: conventions.checks.outputs.declaration
  - id: OUT-06
    title: An output names a publish workflow that exists
    status: proposed
    severity: warning
    since: 0.3.0
    validation:
      engine: conftest
      package: conventions.checks.outputs.declaration
  - id: OUT-07
    title: A contract output names its format and its definition file
    status: proposed
    severity: warning
    since: 0.3.0
    validation:
      engine: conftest
      package: conventions.checks.outputs.declaration
---

# Outputs declaration

A repository that publishes something other repositories depend on, such as a container image, a library, a
command-line tool, a contract or a bundle, says so in one file: `.repo/outputs.yaml`. Each entry answers the questions a
consumer asks first. What is it? Where is it built from? What publishes it? Where do I get it? How do I use it?
Without the file, the answers are scattered across workflows, READMEs and registry pages, and nobody can tell which
repository produces what without reading all of them.

The file is a declaration, not a catalog. This convention owns its format and what each output must state. Collecting
the declarations of every repository into a searchable catalog is a separate job that reads these files; it is not
done here.

## Scope

This convention covers `.repo/outputs.yaml` in every repository checked against a release of
`musher-dev/engineering-conventions`, and the publish workflows it points at. A repository that publishes nothing needs
no declaration. One with a workflow whose responsibility is `publish`
([EC-0002](../github-actions/workflow-files.md)) is taken to publish something, and must declare it (OUT-01).

The formats an output carries are out of scope: OCI defines images, OpenAPI and AsyncAPI define API contracts, and
each registry defines its packages. This convention says only which of them a repository publishes, and where.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`): the declaration is a new interface and no
other repository defines it. Its requirements are `proposed` at severity `warning`, like every requirement in the 0.x
series ([decision 0010](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0010-outputs-declaration.md)).

## The declaration file

```yaml
# .repo/outputs.yaml
schema_version: 1
outputs:
  - id: api-image
    kind: image
    description: The API server.
    source: api/
    publish_workflow: publish-api.yml
    location: ghcr.io/your-org/api
    docs: api/README.md#run-the-image
  - id: api-contract
    kind: contract
    format: openapi
    definition: api/openapi.yaml
    source: api/
    publish_workflow: publish-api.yml
    location: https://github.com/your-org/your-repo/releases
    docs: api/README.md#the-contract
```

| Field | Required | Meaning |
| --- | --- | --- |
| `schema_version` | yes | The file format version. Always `1`. |
| `outputs[].id` | yes | The output's name within the repository, in kebab-case and unique (OUT-04). |
| `outputs[].kind` | yes | An output kind from the table below (OUT-03). |
| `outputs[].description` | no | One line on what the output is for. |
| `outputs[].source` | yes | The file or directory it is built from (OUT-05). |
| `outputs[].publish_workflow` | yes | The filename of the workflow under `.github/workflows/` that publishes it (OUT-06). |
| `outputs[].location` | yes | Where a consumer gets it: an image repository, a package name, a release URL. |
| `outputs[].docs` | yes | The document, with an optional `#anchor`, that says how to consume it (OUT-05, OUT-08). |
| `outputs[].format` | contract | The interface format, such as `openapi`, `asyncapi`, `protobuf` or `json-schema` (OUT-07). |
| `outputs[].definition` | contract | The machine-readable definition file consumers build against (OUT-05, OUT-07). |

The authoritative shape is `checks/schemas/outputs.schema.json`, and OUT-02 checks the file against it.

### Output kinds

The kinds are terms in `definitions/terminology/global.yml`, tagged `outputs.kind`, so a new kind is a terminology
change, not a schema change. Each maps onto the Backstage descriptor format, so a catalog that speaks it can be
generated from the declaration. Backstage types are free-form: `tool` and `bundle` are not among its well-known types,
and are named here so every catalog uses the same ones.

| Kind | Is | Backstage entity |
| --- | --- | --- |
| `image` | An OCI container image in a registry | `Component` of type `service` |
| `library` | A package in a language registry | `Component` of type `library` |
| `cli` | An executable released as assets, pinned with a tool manager | `Component` of type `tool` |
| `contract` | An interface definition other repositories build against | `API`, with `spec.type` from `format` and `spec.definition` from `definition` |
| `bundle` | A versioned archive of files, consumed by pinning | `Component` of type `bundle` |

## Requirements

### OUT-01

**A repository with a publish workflow declares its outputs in .repo/outputs.yaml.**

A publish workflow pushes a versioned output somewhere others fetch it from. If nothing declares that output, a reader
has to open the workflow to learn what the repository produces, and a catalog has nothing to read. The finding is
reported on each publish workflow, entry point or reusable, while the declaration is missing.

**Correct:**

```text
.github/workflows/publish-api.yml
.repo/outputs.yaml
```

**Incorrect:**

```text
.github/workflows/publish-api.yml
# no .repo/outputs.yaml
```

Checked by: conftest · Severity: warning · Since: 0.3.0

### OUT-02

**The outputs declaration is valid against its schema.**

Every other requirement in this convention reads the declaration's fields. A misspelled or misplaced key is not an
option the checks can ignore; it is an output they cannot see. One finding reports the first problem and how many
more there are.

**Correct:**

```yaml
schema_version: 1
outputs:
  - id: api-image
    kind: image
    source: api/
    publish_workflow: publish-api.yml
    location: ghcr.io/your-org/api
    docs: api/README.md
```

**Incorrect:**

```yaml
schema_version: 1
outputs:
  - name: api-image        # the field is id
    kind: image
    source: api/
    location: ghcr.io/your-org/api
```

Checked by: conftest · Severity: warning · Since: 0.3.0

### OUT-03

**An output's kind is a registered output kind.**

The kind is what a consumer and a catalog sort by. A free-form value (`docker`, `container`, `oci-image`) splits one
kind into several, which is the drift the terminology exists to stop.

**Correct:**

```yaml
kind: image
```

**Incorrect:**

```yaml
kind: docker
```

Checked by: conftest · Severity: warning · Since: 0.3.0

### OUT-04

**Output IDs are unique within a repository.**

An output's ID is how it is referred to, in the repository and in any catalog built from the declaration. Two outputs
with one ID make every such reference ambiguous.

**Correct:**

```yaml
outputs:
  - id: api-image
  - id: api-contract
```

**Incorrect:**

```yaml
outputs:
  - id: api
  - id: api
```

Checked by: conftest · Severity: warning · Since: 0.3.0

### OUT-05

**Every path an output names exists.**

`source`, `definition` and `docs` are where a reader goes next. A path that no longer exists, usually after a move or
a rename, sends them nowhere. A directory exists when the repository holds a file under it. The `#anchor` of `docs` is
not checked.

**Correct:**

```yaml
source: api/
docs: api/README.md#run-the-image   # api/README.md exists
```

**Incorrect:**

```yaml
source: server/                     # moved to api/
docs: docs/api.md                   # never written
```

Checked by: conftest · Severity: warning · Since: 0.3.0

### OUT-06

**An output names a publish workflow that exists.**

The workflow is how a reader learns when and how a version is published. It must exist under `.github/workflows/`,
and its responsibility must be `publish`: a workflow that builds without publishing, or one that deploys, is not the
one that makes the output available.

**Correct:**

```yaml
publish_workflow: publish-api.yml
```

**Incorrect:**

```yaml
publish_workflow: validate.yml      # validates; does not publish
```

Checked by: conftest · Severity: warning · Since: 0.3.0

### OUT-07

**A contract output names its format and its definition file.**

A contract exists to be built against, so its consumers need the machine-readable definition and the format that
reads it. Both are what a catalog needs to present it as an API.

**Correct:**

```yaml
kind: contract
format: openapi
definition: api/openapi.yaml
```

**Incorrect:**

```yaml
kind: contract                      # which file, in which format?
```

Checked by: conftest · Severity: warning · Since: 0.3.0

## References

- [EC-0008 Publishing and consuming outputs](publishing-and-consuming.md)
- [Decision 0010: Repositories declare the outputs they publish](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0010-outputs-declaration.md)
- [Backstage: Descriptor format of catalog entities](https://backstage.io/docs/features/software-catalog/descriptor-format/)
- `checks/schemas/outputs.schema.json`
