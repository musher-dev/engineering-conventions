---
id: EC-0018
title: Repository layout
summary: >-
  A repository keeps what its product is built from in one directory named
  after the repository, declared as [layout] product in
  .repo/repository.toml, and keeps the root for what acts on the product.
  Dependabot and the Taskfile name the product directory the declaration
  names.
status: draft
topic: repository
applies_to:
  paths:
    - .repo/repository.toml
    - .github/dependabot.yml
    - .github/dependabot.yaml
    - Taskfile.yml
    - Taskfile.yaml
created: 2026-09-28
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
implementations:
  - repo: musher-dev/development-container
    check: LAYOUT-01
    mode: blocking
  - repo: musher-dev/development-container
    check: LAYOUT-02
    mode: blocking
  - repo: musher-dev/development-container
    check: LAYOUT-03
    mode: blocking
  - repo: musher-dev/development-container
    check: LAYOUT-04
    mode: blocking
  - repo: musher-dev/development-container
    check: LAYOUT-05
    mode: blocking
  - repo: musher-dev/development-container
    check: LAYOUT-06
    mode: blocking
  - repo: musher-dev/development-container
    check: LAYOUT-08
    mode: blocking
  - repo: musher-dev/development-container
    check: LAYOUT-09
    mode: blocking
  - repo: musher-dev/development-container
    check: PATH-02
    mode: blocking
references:
  - title: "Dependabot options reference: directories"
    url: https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference#directories-or-directory--
  - title: "Task: Special variables"
    url: https://taskfile.dev/reference/templating/#special-variables
requirements:
  - id: REPO-14
    title: The identity declaration says where the product lives
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.repository.layout
    aliases: ["development-container:LAYOUT-01"]
  - id: REPO-15
    title: The declared product directory exists
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.repository.layout
    aliases: ["development-container:LAYOUT-02"]
  - id: REPO-16
    title: The product directory is named after the repository
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.repository.layout
    aliases: ["development-container:LAYOUT-03"]
  - id: REPO-17
    title: The product directory holds its build manifest
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.repository.layout
    aliases: ["development-container:LAYOUT-04"]
  - id: REPO-18
    title: The repository root holds no manifest, lockfile, toolchain file or source tree
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.repository.layout
    aliases: ["development-container:LAYOUT-05"]
  - id: REPO-19
    title: Every root exception gives a reason and names an entry at the root
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.repository.layout
    aliases: ["development-container:LAYOUT-06"]
  - id: REPO-20
    title: Dependabot updates the product's dependencies in the product directory, not the root
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.repository.layout
    aliases: ["development-container:LAYOUT-08"]
  - id: REPO-21
    title: The Taskfile's PRODUCT_DIR is the declared product directory
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.repository.layout
    aliases: ["development-container:LAYOUT-09"]
  - id: REPO-22
    title: Every directory a Dependabot update names exists
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.repository.layout
    aliases: ["development-container:PATH-02b"]
---

# Repository layout

A repository has two levels. The root holds what *acts on* the product: the dev container, CI, tool configuration,
the Taskfile, the declarations under `.repo/`, and the documents people open first. One directory, named after the
repository, holds what the product *is built from*: its manifest, its lockfile, its sources, its tests, and the
configuration its tools find by walking up from it.

```text
platform-api/                   repository level: acts on the product
├── .devcontainer/  .github/    homes whose location the tool mandates
├── .config/  .repo/            tool configuration; the declarations
├── Taskfile.yml                reaches the product through PRODUCT_DIR
├── README.md  docs/
└── platform-api/               product level: what the product is built from
    ├── go.mod | package.json | pyproject.toml | Cargo.toml …
    └── sources, tests, schemas, the tools' own configuration
```

The product directory is the ecosystem's native build root. With the working directory set to it, `go test ./...`,
`npm test` or `uv run pytest` behave exactly as they would in a repository with nothing else in it, because every
file those tools discover by walking up is inside it. Someone working on the product sees only the product, and a new
piece of repository machinery has an obvious home that nobody mistakes for implementation.

The name repeats (`platform-api/platform-api/`) on purpose: the two levels have different jobs, and naming the inner
one after the repository means every repository agrees on where its product lives without looking it up.

## Scope

This convention covers where a repository keeps its product, and the three places that must name it literally:
`.repo/repository.toml`, Dependabot's configuration and the root Taskfile. Where tool configuration goes within the
repository level, and what the product directory holds beyond its manifest, are not decided here.

**Multi-product repositories are out of scope.** A repository with several peer products under one workspace root (a
root `package.json` with `apps/` and `packages/`) is a different shape: its root *is* a build root. Until a variant is
designed for it, such a repository declares `product = ""` and waives REPO-18 in `.repo/conventions.toml`, with the
issue that tracks its split or the variant as the waiver's reason
([EC-0001](../adoption/conventions-declaration.md)).

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). It adopts the layout rules
`musher-dev/development-container` checks today (LAYOUT-01 to LAYOUT-06, LAYOUT-08 and LAYOUT-09, and the Dependabot
half of PATH-02), which keep their IDs as aliases
([decision 0016](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)).
Its requirements are `proposed` at severity `warning`. The dev container's mounts and editor links (LAYOUT-07) stay
with the scaffold.

## Declaring the product

The product directory is declared once, in the `[layout]` table of the identity declaration
([EC-0009](identity-declaration.md)):

```toml
# .repo/repository.toml
name = "platform-api"
# … the identity fields …

[layout]
product = "platform-api"

[layout.root_exceptions]
"package.json" = "Repository tooling only (commitlint); the product has its own under platform-api/."
```

| Field | Meaning |
| --- | --- |
| `product` | The product directory: one path segment, the repository's name. `""` means the repository has no product directory, such as a documentation or infrastructure repository. |
| `root_exceptions` | Root entries REPO-18 would report, each mapped to the reason it stays at the root. |

`product = ""` is a statement, not an absence: the requirements that need a product directory skip, and the root
still holds no product content (REPO-18). A missing `[layout]` table is not read as "no product" (REPO-14), or
deleting the table would switch every other requirement here off.

Nothing else can read the declaration: Dependabot and the Taskfile need a literal path. So each states the path
itself, and REPO-20 and REPO-21 check that each literal agrees with the declaration.

## Requirements

### REPO-14

**The identity declaration says where the product lives.**

Every other requirement here keys off one declaration. A repository that states none leaves each tool to guess where
the product is, and a reader to look. Only a repository that has an identity declaration is asked; one without it
already gets REPO-01.

**Correct:**

```toml
[layout]
product = "platform-api"
```

**Incorrect:**

```toml
# no [layout] table
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container LAYOUT-01

### REPO-15

**The declared product directory exists.**

The declaration is what every other path is checked against, so it has to be true. A product directory that was
renamed or never created leaves every literal that names it pointing at nothing.

**Correct:**

```text
.repo/repository.toml         # product = "platform-api"
platform-api/go.mod
```

**Incorrect:**

```text
.repo/repository.toml         # product = "platform-api"
api/go.mod                    # the product is somewhere else
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container LAYOUT-02

### REPO-16

**The product directory is named after the repository.**

Naming the product directory after the repository is what lets a reader, a search and a tool find the product in
any repository without reading its declaration. It is compared with the declared `name`; REPO-07 compares that name
with the repository's actual one.

**Correct:**

```toml
name = "platform-api"

[layout]
product = "platform-api"
```

**Incorrect:**

```toml
name = "platform-api"

[layout]
product = "server"
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container LAYOUT-03

### REPO-17

**The product directory holds its build manifest.**

The product directory is the ecosystem's build root. Without a manifest there, the build still starts from somewhere
else, and the directory is only a folder of sources. The recognised manifests are `Cargo.toml`, `package.json`,
`pyproject.toml`, `go.mod`, `deno.json`, `deno.jsonc`, `pom.xml`, `build.gradle`, `build.gradle.kts`,
`settings.gradle` and `settings.gradle.kts`, at the top of the product directory.

**Correct:**

```text
platform-api/pyproject.toml
platform-api/src/platform_api/__init__.py
```

**Incorrect:**

```text
pyproject.toml                # the manifest is at the root
platform-api/src/platform_api/__init__.py
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container LAYOUT-04

### REPO-18

**The repository root holds no manifest, lockfile, toolchain file or source tree.**

Manifests, lockfiles, toolchain files and source trees are what the product is built from. At the root they merge the
product back into the machinery that acts on it, and a tool that walks up from the product finds them from the wrong
level. This applies whether or not the repository has a product directory. The entries reported are, by ecosystem:

| Ecosystem | Root entries |
| --- | --- |
| Rust | `Cargo.toml`, `Cargo.lock`, `rust-toolchain`, `rust-toolchain.toml`, `.cargo`, `rustfmt.toml`, `.rustfmt.toml`, `clippy.toml`, `.clippy.toml`, `deny.toml`, `.deny.toml` |
| Node | `package.json`, `package-lock.json`, `npm-shrinkwrap.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`, `yarn.lock`, `bun.lock`, `bun.lockb`, `tsconfig.json`, `.nvmrc`, `.node-version` |
| Python | `pyproject.toml`, `uv.lock`, `poetry.lock`, `setup.py`, `setup.cfg`, `.python-version`, `ruff.toml`, `.ruff.toml`, `pytest.ini`, `tox.ini` |
| Go | `go.mod`, `go.sum`, `go.work`, `go.work.sum` |
| Deno | `deno.json`, `deno.jsonc`, `deno.lock` |
| Java | `pom.xml`, `build.gradle`, `build.gradle.kts`, `settings.gradle`, `settings.gradle.kts`, `gradlew`, `mvnw` |
| Source trees | `src`, `crates`, `cmd`, `internal`, `pkg`, `lib`, `tests`, `apps`, `packages` |

An entry kept on purpose goes under `[layout.root_exceptions]` with its reason (REPO-19).

**Correct:**

```text
Taskfile.yml
platform-api/package.json
platform-api/src/
```

**Incorrect:**

```text
package.json
src/
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container LAYOUT-05

### REPO-19

**Every root exception gives a reason and names an entry at the root.**

An exception is a standing hole in REPO-18. It must say why it exists, so a reviewer can judge it, and it must go
when the entry it excused does, so the list cannot quietly widen.

**Correct:**

```toml
[layout.root_exceptions]
"package.json" = "Repository tooling only (commitlint); the product has its own under platform-api/."
```

**Incorrect:**

```toml
[layout.root_exceptions]
"package.json" = ""                        # no reason
"yarn.lock" = "Kept for the old build."    # no yarn.lock at the root
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container LAYOUT-06

### REPO-20

**Dependabot updates the product's dependencies in the product directory, not the root.**

The root holds no manifest, so a `cargo`, `npm`, `bun`, `pip`, `uv`, `gomod`, `maven` or `gradle` update that scans
`/` finds nothing and opens no pull requests, which looks exactly like having nothing to update. Another directory
is fine: repository tooling may keep a manifest of its own. An ecosystem whose manifest is a root exception may scan
the root.

**Correct:**

```yaml
updates:
  - package-ecosystem: "gomod"
    directory: "/platform-api"
```

**Incorrect:**

```yaml
updates:
  - package-ecosystem: "gomod"
    directory: "/"
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container LAYOUT-08

### REPO-21

**The Taskfile's `PRODUCT_DIR` is the declared product directory.**

Tasks reach the product's toolchain through `dir: '{{.PRODUCT_DIR}}'`. A task run from the wrong directory does not
fail: it builds with the root's defaults, or finds no project. So the root Taskfile carries the product path in one
variable, `PRODUCT_DIR: '{{.ROOT_DIR}}/<product>'`, and a repository with no product directory does not set it. The
name is shared across repositories; "workspace" already means something to Cargo and pnpm.

**Correct:**

```yaml
vars:
  PRODUCT_DIR: '{{.ROOT_DIR}}/platform-api'
```

**Incorrect:**

```yaml
vars:
  PRODUCT_DIR: '{{.ROOT_DIR}}/api'   # not the declared product
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container LAYOUT-09

### REPO-22

**Every directory a Dependabot update names exists.**

Dependabot does not fail on a directory that is not there: the update scans nothing and opens no pull requests, and a
move or a rename leaves it that way silently. Each `directory` and each `directories` entry must name a directory that
holds a file; `/` always exists, and a glob must match at least one directory. This holds whatever the layout, so a
repository without a `[layout]` table is checked too.

**Correct:**

```yaml
updates:
  - package-ecosystem: "github-actions"
    directories: ["/", "/.github/actions/*"]
```

**Incorrect:**

```yaml
updates:
  - package-ecosystem: "github-actions"
    directories: ["/", "/.github/actions/setup"]   # renamed to setup-tools
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container PATH-02 (its Dependabot half)

## References

- [EC-0009 Identity declaration](identity-declaration.md)
- [Decision 0016: Rules adopted from other repositories get new families, and keep their old IDs as aliases](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)
- [Dependabot options reference: directories](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference#directories-or-directory--)
- [Task: Special variables](https://taskfile.dev/reference/templating/#special-variables)
- `checks/schemas/repository.schema.json`
