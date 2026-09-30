---
id: EC-0007
title: Outputs declaration
summary: >-
  A repository that publishes something for others to consume lists each
  output in .repo/outputs.toml, with its kind, where it is built from, the
  workflow that publishes it, where consumers get it and where its use is
  documented.
status: draft
topic: outputs
applies_to:
  paths:
    - .repo/outputs.toml
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
    title: A repository with a publish workflow declares its outputs in .repo/outputs.toml
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
    status: retired
    severity: warning
    since: 0.3.0
    replaced_by: [IFACE-02, IFACE-04]
    validation:
      engine: conftest
      package: conventions.checks.outputs.declaration
  - id: OUT-12
    title: A site output's location is an https:// origin
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.outputs.declaration
---

# Outputs declaration

A repository that publishes something other repositories depend on, such as a container image, a library, a
command-line tool, a bundle or a site, says so in one file: `.repo/outputs.toml`. Each entry answers the questions a
consumer asks first. What is it? Where is it built from? What publishes it? Where do I get it? How do I use it?
Without the file, the answers are scattered across workflows, READMEs and registry pages, and nobody can tell which
repository produces what without reading all of them.

The file is a declaration, not a catalog. This convention owns its format and what each output must state. Collecting
the declarations of every repository into a searchable catalog is a separate job that reads these files; it is not
done here.

## Scope

This convention covers `.repo/outputs.toml` in every repository checked against a release of
`musher-dev/engineering-conventions`, and the publish workflows it points at. A repository that publishes nothing needs
no declaration. One with a workflow whose responsibility is `publish`
([EC-0002](../github-actions/workflow-files.md)) is taken to publish something, and must declare it (OUT-01).

The formats an output carries are out of scope: OCI defines images, OpenAPI and AsyncAPI define API contracts, and
each registry defines its packages. This convention says only which of them a repository publishes, and where. The
interfaces an output delivers, such as each OpenAPI document of an API, are declared in the same file under
`[[interfaces]]` ([EC-0030](../interfaces/interfaces-declaration.md)).

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`): the declaration is a new interface and no
other repository defines it. Its requirements are `proposed` at severity `warning`, like every requirement in the 0.x
series ([decision 0010](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0010-outputs-declaration.md)).

## The declaration file

```toml
# .repo/outputs.toml
schema_version = 2

[[outputs]]
id = "api-image"
kind = "image"
description = "The API server."
source = "api/"
publish_workflow = "publish-api.yml"
location = "ghcr.io/your-org/api"
docs = "api/README.md#run-the-image"

[[outputs]]
id = "contracts"
kind = "bundle"
description = "Each release's interfaces, with their release record."
source = "api/contracts/"
publish_workflow = "release.yml"
location = "https://github.com/your-org/your-repo/releases"
docs = "api/contracts/README.md"

[[interfaces]]
id = "public-http"
format = "openapi"
definitions = ["api/contracts/openapi/public.json"]
delivered_by = "contracts"
compatibility = "gated"
```

The file is TOML ([decision 0011](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0011-declarations-are-toml.md)):
each output is one `[[outputs]]` table, and `outputs[]` below means a key in one of them.

| Field | Required | Meaning |
| --- | --- | --- |
| `schema_version` | yes | The file format version: `2`, which adds `[[interfaces]]`. `1`, without them, is accepted in this release series. |
| `outputs[].id` | yes | The output's name within the repository, in kebab-case and unique (OUT-04). |
| `outputs[].kind` | yes | An output kind from the table below (OUT-03). |
| `outputs[].description` | no | One line on what the output is for. |
| `outputs[].source` | yes | The file or directory it is built from (OUT-05). |
| `outputs[].publish_workflow` | yes | The filename of the workflow under `.github/workflows/` that publishes it: a `publish` or `release` workflow, or for a site a `deploy` workflow (OUT-06). |
| `outputs[].location` | yes | Where a consumer gets it: an image repository, a package name, a release URL, or a site's `https://` origin (OUT-12). |
| `outputs[].docs` | yes | The document, with an optional `#anchor`, that says how to consume it (OUT-05, OUT-08). |
| `interfaces` | no | The interfaces the outputs deliver, one `[[interfaces]]` table each ([EC-0030](../interfaces/interfaces-declaration.md)). |

The authoritative shape is `checks/schemas/outputs.schema.json`, and OUT-02 checks the file against it.

### Output kinds

The kinds are terms in `definitions/terminology/global.yml`, tagged `outputs.kind`, so a new kind is a terminology
change, not a schema change. Each maps onto the Backstage descriptor format, so a catalog that speaks it can be
generated from the declaration. Backstage types are free-form: `tool`, `bundle` and `machine-image` are not among its
well-known types, and are named here so every catalog uses the same ones.

| Kind | Is | Backstage entity |
| --- | --- | --- |
| `image` | An OCI container image in a registry | `Component` of type `service` |
| `library` | A package in a language registry | `Component` of type `library` |
| `cli` | An executable released as assets, pinned with a tool manager | `Component` of type `tool` |
| `bundle` | A versioned archive of files, consumed by pinning | `Component` of type `bundle` |
| `site` | Files served at a stable HTTPS origin, fetched by URL, such as a schema host or a documentation site | `Component` of type `website` |
| `vmimage` | A bootable machine image, such as a cloud provider snapshot, that hosts are created from | `Resource` of type `machine-image` |

An interface maps to a Backstage `API`, with `spec.type` from its `format` and `spec.definition` from its
definitions, provided by the `Component` of the output that delivers it. The `contract` kind is retired
([decision 0022](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0022-interfaces-and-dependencies.md)):
an interface definition is not something a repository delivers but a surface its outputs deliver, so it is declared
as an interface. OUT-03 reports an output that still uses it.

## Requirements

### OUT-01

**A repository with a publish workflow declares its outputs in .repo/outputs.toml.**

A publish workflow pushes a versioned output somewhere others fetch it from. If nothing declares that output, a reader
has to open the workflow to learn what the repository produces, and a catalog has nothing to read. The finding is
reported on each publish workflow, entry point or reusable, while the declaration is missing.

**Correct:**

```text
.github/workflows/publish-api.yml
.repo/outputs.toml
```

**Incorrect:**

```text
.github/workflows/publish-api.yml
# no .repo/outputs.toml
```

Checked by: conftest · Severity: warning · Since: 0.3.0

### OUT-02

**The outputs declaration is valid against its schema.**

Every other requirement in this convention reads the declaration's fields. A misspelled or misplaced key is not an
option the checks can ignore; it is an output they cannot see. One finding reports the first problem and how many
more there are.

**Correct:**

```toml
schema_version = 1

[[outputs]]
id = "api-image"
kind = "image"
source = "api/"
publish_workflow = "publish-api.yml"
location = "ghcr.io/your-org/api"
docs = "api/README.md"
```

**Incorrect:**

```toml
schema_version = 1

[[outputs]]
name = "api-image"            # the field is id
kind = "image"
source = "api/"
location = "ghcr.io/your-org/api"
```

Checked by: conftest · Severity: warning · Since: 0.3.0

### OUT-03

**An output's kind is a registered output kind.**

The kind is what a consumer and a catalog sort by. A free-form value (`docker`, `container`, `oci-image`) splits one
kind into several, which is the drift the terminology exists to stop.

**Correct:**

```toml
kind = "image"
```

**Incorrect:**

```toml
kind = "docker"
```

```toml
kind = "contract"      # retired: declare it in [[interfaces]] (EC-0030)
```

Checked by: conftest · Severity: warning · Since: 0.3.0

### OUT-04

**Output IDs are unique within a repository.**

An output's ID is how it is referred to, in the repository and in any catalog built from the declaration. Two outputs
with one ID make every such reference ambiguous.

**Correct:**

```toml
[[outputs]]
id = "api-image"

[[outputs]]
id = "api-contract"
```

**Incorrect:**

```toml
[[outputs]]
id = "api"

[[outputs]]
id = "api"
```

Checked by: conftest · Severity: warning · Since: 0.3.0

### OUT-05

**Every path an output names exists.**

`source`, `definition` and `docs` are where a reader goes next. A path that no longer exists, usually after a move or
a rename, sends them nowhere. A directory exists when the repository holds a file under it. The `#anchor` of `docs` is
not checked.

**Correct:**

```toml
source = "api/"
docs = "api/README.md#run-the-image"  # api/README.md exists
```

**Incorrect:**

```toml
source = "server/"                    # moved to api/
docs = "docs/api.md"                  # never written
```

Checked by: conftest · Severity: warning · Since: 0.3.0

### OUT-06

**An output names a publish workflow that exists.**

The workflow is how a reader learns when and how a version is published. It must exist under `.github/workflows/`,
and its responsibility must be `publish` or `release`: a workflow that builds without publishing, or one that deploys,
is not the one that makes the output available. A `release` workflow qualifies because it may publish the artifacts of
the release it cuts, in the same run, when the version is known only there
([decision 0014](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0014-release-workflows-may-publish.md)).
A `site` is the one exception: its host is the environment it is served from, so the `deploy` workflow that pushes its
files there is what makes it available, and a `deploy` workflow qualifies for a site and for nothing else
([decision 0018](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0018-a-site-is-an-output.md)).

**Correct:**

```toml
publish_workflow = "publish-api.yml"
```

```toml
publish_workflow = "release.yml"      # cuts the release, then publishes its image
```

```toml
kind = "site"
publish_workflow = "deploy-docs.yml"  # pushes the site's files to the host that serves them
```

**Incorrect:**

```toml
publish_workflow = "validate.yml"     # validates; does not publish
```

```toml
kind = "image"
publish_workflow = "deploy.yml"       # deploys; changes what runs, publishes nothing
```

Checked by: conftest · Severity: warning · Since: 0.3.0

### OUT-07

**A contract output names its format and its definition file.**

Retired in 0.7.0 and replaced by [IFACE-02](../interfaces/interfaces-declaration.md#iface-02) and
[IFACE-04](../interfaces/interfaces-declaration.md#iface-04). The `contract` output kind it applied to was retired
with it: an interface definition is a surface an output delivers, not an output, and is declared under
`[[interfaces]]`, where every interface names its format and the files that define it.

Checked by: nothing (retired) · Severity: warning · Since: 0.3.0

### OUT-12

**A site output's location is an https:// origin.**

A site is consumed by URL: a person opens it, and a tool such as a JSON Schema validator or an editor fetches from it.
Its location is the origin those URLs start with, so it must be one a client can request. A host name without a
scheme is not a URL, and an `http://` origin serves bytes that anyone on the path can change, which defeats a consumer
that pins a versioned path on the site.

**Correct:**

```toml
kind = "site"
location = "https://docs.example.com"
```

**Incorrect:**

```toml
kind = "site"
location = "docs.example.com"         # no scheme: not a URL a client can fetch
```

Checked by: conftest · Severity: warning · Since: 0.6.2

## References

- [EC-0008 Publishing and consuming outputs](publishing-and-consuming.md)
- [Decision 0010: Repositories declare the outputs they publish](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0010-outputs-declaration.md)
- [Backstage: Descriptor format of catalog entities](https://backstage.io/docs/features/software-catalog/descriptor-format/)
- `checks/schemas/outputs.schema.json`
