---
id: EC-0032
title: Dependencies declaration
summary: >-
  A repository that vendors another repository's interfaces declares each
  release it vendors, at an exact version, in .repo/dependencies.toml, and
  keeps the copy with the producer's release record so every byte can be
  checked offline; every package another Musher repository publishes is
  pinned exactly too, and no pin lives in a file of its own.
status: draft
topic: dependencies
applies_to:
  paths:
    - .repo/dependencies.toml
    - "contracts/vendor/**"
    - "*/contracts/vendor/**"
    - "**/package.json"
    - "**/config/*.ref"
created: 2026-09-30
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "Semantic Versioning 2.0.0"
    url: https://semver.org/
requirements:
  - id: DEPS-01
    title: Every vendored copy is declared as a dependency
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.dependencies.declaration
  - id: DEPS-02
    title: The dependencies declaration is valid against its schema
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.dependencies.declaration
  - id: DEPS-03
    title: A dependency is declared once, and never on the repository itself
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.dependencies.declaration
  - id: DEPS-04
    title: A dependency on another Musher repository pins an exact release
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.dependencies.declaration
  - id: DEPS-05
    title: A dependency's vendored copy carries the producer's release record for the pinned release
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.dependencies.declaration
  - id: DEPS-06
    title: A vendored copy holds exactly the released files of the interfaces it depends on
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.dependencies.declaration
  - id: DEPS-07
    title: A pin lives in the dependencies declaration or a package manifest, never in a file of its own
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.dependencies.declaration
---

# Dependencies declaration

When one repository builds against another's interfaces, two questions must have a written answer: *which release
does it build against*, and *are the files it holds exactly that release's*. Without them, a consumer's generated
client can come from a commit that was never released, a hand edit to a vendored schema looks like the producer's, and
nobody can say what a repository depends on without reading its scripts. This convention gives every dependency one
pin in one form, and makes a vendored copy prove its own bytes.

## Scope

This convention covers `.repo/dependencies.toml`, the vendored copies under the contracts directory, and the exact
pinning of packages another Musher repository publishes. What a producer must ship for a copy to be checkable is
[EC-0031](../interfaces/publishing-interfaces.md). Tools pinned in mise are held to one exact version by
[TOOL-03](../toolchain/tool-pins.md#tool-03), and runtime edges are fields of an environment binding
([EC-0020](../environment/env-schema.md)). Which dependencies form a cycle across repositories is not visible from one
repository: the graph built from every repository's declarations answers it
([decision 0022](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0022-interfaces-and-dependencies.md)).

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`), and its requirements are `proposed` at
severity `warning`. DEPS-04 is the checked form of OUT-11 for the pins it can read.

## The declaration

```toml
# .repo/dependencies.toml
schema_version = 1

[[dependencies]]
repository = "platform-api"
output = "contracts"
interfaces = ["public-http", "events"]
version = "0.36.1"
description = "The console's API client is generated from the public API."
```

| Field | Required | Meaning |
| --- | --- | --- |
| `schema_version` | yes | The file format version. Always `1`. |
| `dependencies[].repository` | yes | The producer's name on GitHub, without the organization. |
| `dependencies[].output` | yes | The ID of the producer's output that delivers the interfaces, usually a `bundle`. |
| `dependencies[].interfaces` | no | The IDs of the producer's interfaces this repository vendors. Every interface the output delivers when omitted. |
| `dependencies[].version` | yes | The exact release, without a leading `v`. The only copy of the pin (DEPS-04). |
| `dependencies[].description` | no | One line on what the repository uses it for. |

Only vendored dependencies are declared. A package or a tool keeps its pin in the manifest its package manager reads,
and a runtime edge is named on the binding that reaches it; listing them here again would give one fact two copies.
The authoritative shape is `checks/schemas/dependencies.schema.json`, and DEPS-02 checks the file against it.

### The vendored copy

Each declared dependency is vendored at `<product>/contracts/vendor/<repository>/<output>/` (or
`contracts/vendor/…` when `product = ""`), holding the producer's `release.json` unchanged and the files of the
interfaces it depends on, at their paths in the bundle:

```text
web/contracts/vendor/platform-api/contracts/
├── release.json
├── openapi/public.json
└── events/order.created.v1.schema.json
```

The copy is committed, so a review shows what changed between two releases, and it is never edited: code generated
from it lives elsewhere in the product. The release record lists each file's SHA-256, and the conventions runner
hashes every vendored file, so DEPS-05 and DEPS-06 prove the copy without reaching the network.

## Requirements

### DEPS-01

**Every vendored copy is declared as a dependency.**

An undeclared copy is a dependency nothing pins: nobody can tell which release it came from, the scheduled update
never touches it, and the dependency graph never shows it. The finding is reported on the copy's directory.

**Correct:**

```toml
[[dependencies]]
repository = "platform-api"
output = "contracts"
version = "0.36.1"            # web/contracts/vendor/platform-api/contracts/
```

**Incorrect:**

```text
web/contracts/vendor/platform-api/contracts/release.json
# .repo/dependencies.toml does not declare platform-api's "contracts"
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### DEPS-02

**The dependencies declaration is valid against its schema.**

Every other requirement here reads the declaration's fields. A misspelled key is not an option the checks can
ignore; it is a dependency they cannot see. One finding reports the first problem and how many more there are.

**Correct:**

```toml
[[dependencies]]
repository = "platform-api"
output = "contracts"
version = "0.36.1"
```

**Incorrect:**

```toml
[[dependencies]]
repo = "platform-api"          # the field is repository
output = "contracts"
path = "config/vendor/"        # the location is fixed, not declared
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### DEPS-03

**A dependency is declared once, and never on the repository itself.**

Two entries for one output give it two versions, and only one copy can be vendored. A repository that depends on a
release of itself builds against an old copy of what it already holds in source.

**Correct:**

```toml
[[dependencies]]
repository = "platform-api"
output = "contracts"
version = "0.36.1"
```

**Incorrect:**

```toml
[[dependencies]]
repository = "platform-api"
output = "contracts"
version = "0.36.1"

[[dependencies]]
repository = "platform-api"
output = "contracts"
version = "0.35.0"
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### DEPS-04

**A dependency on another Musher repository pins an exact release.**

An exact version makes a build reproducible and an upgrade a reviewed change a bot can raise. A commit SHA names
something that was never released, a branch moves under the consumer, and a range upgrades it without a change in its
own repository. The check reads the declaration's `version`, and every `@musher-dev/` package in a `package.json`'s
`dependencies`, `devDependencies` and `optionalDependencies`; a package from the same workspace (`workspace:`,
`file:`, `link:`) is not a release and is not checked.

**Correct:**

```toml
version = "0.36.1"
```

```json
"dependencies": { "@musher-dev/ui": "1.0.2" }
```

**Incorrect:**

```toml
version = "4b1c0e9"            # a commit, not a release
```

```json
"dependencies": { "@musher-dev/ui": "^1.0.2" }
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### DEPS-05

**A dependency's vendored copy carries the producer's release record for the pinned release.**

The release record is what ties the copy to a release: its repository, output and version must be the ones declared,
and it must be valid against `checks/schemas/release-record.schema.json`. A copy without one, or with the record of
another release, is a pin the files do not honour, usually a half-finished update.

**Correct:**

```json
{ "schema_version": 1, "repository": "platform-api", "output": "contracts", "version": "0.36.1", "…": "…" }
```

**Incorrect:**

```json
{ "schema_version": 1, "repository": "platform-api", "output": "contracts", "version": "0.35.0", "…": "…" }
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### DEPS-06

**A vendored copy holds exactly the released files of the interfaces it depends on.**

Every file of each interface the dependency names must be present with the SHA-256 the release record lists, the
record must deliver every interface the dependency names, and the copy holds nothing else. A changed digest is a hand
edit or a file from another release; a missing file is a partial update; an extra file is something no release
vouches for. Each problem is reported on the file.

**Correct:**

```text
web/contracts/vendor/platform-api/contracts/openapi/public.json   # sha256 as release.json lists it
```

**Incorrect:**

```text
web/contracts/vendor/platform-api/contracts/openapi/public.json   # edited after it was vendored
web/contracts/vendor/platform-api/contracts/notes.txt             # listed by no interface
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### DEPS-07

**A pin lives in the dependencies declaration or a package manifest, never in a file of its own.**

A `config/<repository>.ref` or a hand-kept `*.lock.json` is a second place a pin can live, in a form no tool
recognises and no check reads, and in practice it often holds a commit SHA. Moving the pin into the declaration puts
every vendored dependency in one file, in one form, where the scheduled update and the graph both read it.

**Correct:**

```toml
# .repo/dependencies.toml
[[dependencies]]
repository = "platform-api"
output = "contracts"
version = "0.36.1"
```

**Incorrect:**

```text
config/platform-api.ref          # 0.36.1
config/specifications.lock.json
```

Checked by: conftest · Severity: warning · Since: 0.7.0

## References

- [EC-0033 Keeping dependencies current](keeping-dependencies-current.md)
- [EC-0031 Publishing interfaces](../interfaces/publishing-interfaces.md)
- [EC-0008 Publishing and consuming outputs](../outputs/publishing-and-consuming.md)
- `checks/schemas/dependencies.schema.json`, `checks/schemas/release-record.schema.json`
