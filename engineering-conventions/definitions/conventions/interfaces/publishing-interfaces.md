---
id: EC-0031
title: Publishing interfaces
summary: >-
  A repository that declares interfaces defines the tasks that regenerate,
  check, compare and bundle them, runs the drift and breaking-change tasks in
  validation, and builds the bundle that delivers them, with a release record
  of every file's digest, in the workflow that publishes it.
status: draft
topic: interfaces
applies_to:
  paths:
    - .repo/outputs.toml
    - Taskfile.yml
    - .github/workflows/*.yml
    - .github/workflows/*.yaml
created: 2026-09-30
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "oasdiff: Breaking changes"
    url: https://github.com/oasdiff/oasdiff/blob/main/docs/BREAKING-CHANGES.md
  - title: "Buf: Breaking change detection"
    url: https://buf.build/docs/breaking/
  - title: "OpenTelemetry Weaver"
    url: https://github.com/open-telemetry/weaver
requirements:
  - id: IFACE-09
    title: An interface's references resolve inside the files it delivers
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: review
  - id: IFACE-10
    title: A change to an interface keeps its compatibility promise
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: review
  - id: IFACE-11
    title: A repository that declares interfaces defines the contracts tasks
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.interfaces.publishing
  - id: IFACE-12
    title: A validate workflow runs contracts:check and contracts:breaking
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.interfaces.publishing
  - id: IFACE-13
    title: The workflow that publishes a bundle of interfaces runs contracts:bundle
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.interfaces.publishing
  - id: IFACE-14
    title: A bundle of interfaces carries a release record of every file it delivers
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: review
---

# Publishing interfaces

An interface is only as good as the proof that it is current, that a change keeps its promise, and that consumers
get exactly the bytes that were checked. A generated OpenAPI document nobody regenerates drifts from the code; a
breaking change nobody compares ships in a patch release; a bundle without digests cannot prove to a consumer what it
holds. This convention asks each producer for the same four tasks and the workflow steps that run them, so every
interface is kept honest the same way in every repository.

## Scope

This convention covers the tasks and workflow steps of a repository that declares interfaces
([EC-0030](interfaces-declaration.md)), and the release record its bundle carries. It checks that the tasks exist and
that workflows run them; what each task runs is the repository's choice, and each format's own tool
(oasdiff, `buf breaking`, `weaver registry check`, a JSON Schema comparison) is where the rules of compatibility live.
This repository runs nothing for other repositories.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`), and its requirements are `proposed` at
severity `warning`
([decision 0022](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0022-interfaces-and-dependencies.md)).

## The tasks

| Task | Required when | Does |
| --- | --- | --- |
| `contracts:generate` | an interface is `generated` | Writes every generated definition from the code. |
| `contracts:check` | any interface | Regenerates, then fails when a committed definition differs, and lints each format. |
| `contracts:breaking` | any interface | Compares each interface with the one the last release delivered, by its compatibility: fails a `gated` break unless a commit since the last release is marked breaking, and fails any change to a published `versioned` file. Skips `lockstep`. |
| `contracts:bundle` | an interface is delivered by a `bundle` | Writes the bundle and its `release.json` for the version being released. |

A `gated` data interface has no format tool to compare it with. Its `contracts:breaking` compares the members a
consumer relies on, named by the producer (the keys of a registry, the members of a vocabulary), and treats a released
member that is gone, or a value that changed, as a break.

## The release record

A bundle that delivers interfaces carries `release.json` at its root, valid against
`checks/schemas/release-record.schema.json`:

```json
{
  "schema_version": 1,
  "repository": "platform-api",
  "output": "contracts",
  "version": "0.36.1",
  "tag": "v0.36.1",
  "commit": "4b1c…",
  "released_with": [
    { "output": "image", "location": "ghcr.io/your-org/platform-api:0.36.1", "digest": "sha256:…" }
  ],
  "interfaces": [
    {
      "id": "public-http",
      "format": "openapi",
      "compatibility": "gated",
      "files": [{ "path": "openapi/public.json", "sha256": "…" }]
    }
  ]
}
```

Each file's `path` is its path from the bundle's root. A consumer keeps the record unchanged in its vendored copy,
where it is the copy's lock: [EC-0032](../dependencies/dependencies-declaration.md) checks every vendored byte
against it without reaching the network. `SHA256SUMS` on the release still covers the bundle as a whole
([REL-18](../releases/release-workflows.md#rel-18)).

## Requirements

### IFACE-09

**An interface's references resolve inside the files it delivers.**

A definition that refers to a document by a URL outside the bundle, a `$ref` to another host or another repository's
branch, makes its meaning depend on something that can change or disappear after release, and makes every tool that
reads it fetch from the network. A reference by `$id` to a document the same interface delivers is fine: it resolves
from the bundle.

**Correct:**

```json
{ "$ref": "common.schema.json#/definitions/money" }
```

**Incorrect:**

```json
{ "$ref": "https://raw.githubusercontent.com/your-org/other/main/money.json" }
```

Checked by: review · Severity: warning · Since: 0.7.0

### IFACE-10

**A change to an interface keeps its compatibility promise.**

A `gated` interface's break ships only in a release marked breaking: a major release from 1.0.0, a minor release in
the 0.x series, as Semantic Versioning §4 allows. Either is cut by a commit marked `!` or carrying `BREAKING CHANGE`;
`contracts:breaking` checks the mark, not the number. A `versioned` interface's published file never changes, and a
break is a new `.vN+1.` file; a `lockstep` interface is used only by consumers released with it.
`contracts:breaking` catches the structural part. The reviewer checks what no structural comparison sees: a field
whose meaning changed while its shape stayed the same.

**Correct:**

```text
feat(api)!: remove the deprecated /v1/tokens endpoint     # a gated break, marked breaking
```

**Incorrect:**

```text
fix(api): return amounts in cents instead of dollars       # same shape, new meaning, in a patch
```

Checked by: review · Severity: warning · Since: 0.7.0

### IFACE-11

**A repository that declares interfaces defines the contracts tasks.**

The same four names in every producer let a consumer, a reviewer or a workflow regenerate, check, compare and bundle
any repository's interfaces without reading its Taskfile. The check requires `contracts:check` and
`contracts:breaking` for any interface, `contracts:generate` when one is generated, and `contracts:bundle` when one is
delivered by a bundle. A task counts when `task <name>` runs it from the root, through an include or an alias.

**Correct:**

```yaml
includes:
  contracts: taskfiles/contracts.Taskfile.yml   # defines generate, check, breaking and bundle
```

**Incorrect:**

```yaml
tasks:
  api:openapi:diff:all: …                       # a name only this repository uses
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### IFACE-12

**A validate workflow runs `contracts:check` and `contracts:breaking`.**

A drift or a break found after merge has already reached `main`, and the next release ships it. Running both tasks in
a validate workflow, the one whose checks a pull request must pass, is what makes them gates. The task must be named
on a `task` command line in a step, alone or with other tasks.

**Correct:**

```yaml
# .github/workflows/validate.yml
      - run: task contracts:check contracts:breaking
```

**Incorrect:**

```yaml
# .github/workflows/monitor-contracts.yml
      - run: task contracts:check                # runs after the fact, and gates nothing
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### IFACE-13

**The workflow that publishes a bundle of interfaces runs `contracts:bundle`.**

The bundle and its release record must be built from the tag being released, in the run that publishes them, so the
digests consumers verify are those of the files that were checked. A bundle assembled by hand, or by a different
workflow, can hold anything. The finding is reported on the bundle's publish workflow.

**Correct:**

```yaml
# .github/workflows/release.yml
      - run: task contracts:bundle
      - run: gh release upload "${TAG}" dist/platform-api-contracts-*.tar.gz dist/SHA256SUMS
```

**Incorrect:**

```yaml
# .github/workflows/release.yml
      - run: tar -czf contracts.tar.gz platform-api/contracts   # no release record
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### IFACE-14

**A bundle of interfaces carries a release record of every file it delivers.**

The release record is what lets a consumer prove, offline and at any later time, that its vendored copy is exactly
what was released: each interface, each of its files, and each file's SHA-256, with the commit and the tag they came
from. A record that leaves out a file, or lists one the bundle does not hold, fails every consumer's check. The
reviewer runs `contracts:bundle` and checks the record against the schema; consumers' DEPS-05 checks it on every
vendored copy.

**Correct:**

```text
platform-api-contracts-v0.36.1.tar.gz
├── release.json          lists openapi/public.json with its sha256
└── openapi/public.json
```

**Incorrect:**

```text
platform-api-contracts-v0.36.1.tar.gz
└── openapi/public.json   # no release.json
```

Checked by: review · Severity: warning · Since: 0.7.0

## References

- [EC-0030 Interfaces declaration](interfaces-declaration.md)
- [EC-0032 Dependencies declaration](../dependencies/dependencies-declaration.md)
- [oasdiff: Breaking changes](https://github.com/oasdiff/oasdiff/blob/main/docs/BREAKING-CHANGES.md)
- [Buf: Breaking change detection](https://buf.build/docs/breaking/)
- `checks/schemas/release-record.schema.json`
