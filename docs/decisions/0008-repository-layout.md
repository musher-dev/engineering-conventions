---
id: "0008"
title: The product lives in a nested engineering-conventions directory, and that directory is the bundle
date: 2026-09-23
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0008 — Repository layout

## Context

This repository contains two different things. One is the **product**: conventions, terminology, profiles, checks and
the generated data a consumer pins. The other is the **repository machinery** that builds, checks and releases the
product: the dev container, tool configuration, Taskfiles, workflows, decisions and contributor documentation.

Mixed at one level, it is unclear which files a consumer depends on, and a release bundle would have to be assembled
from an allowlist that drifts. Company decision 0013 and the `musher-dev/development-container` template, which this
repository was created from, separate the two with a nested product directory named after the repository.

## Decision

**Two levels.**

```text
engineering-conventions/                # repository: acts on the product
├── .config/ .devcontainer/ .github/    # tooling, container, automation
├── docs/                               # contributor docs and these decisions
├── Taskfile.yml  taskfiles/
└── engineering-conventions/            # product: what a consumer pins
    ├── conventions/                    # EC-NNNN documents, families.yml, generated README.md
    ├── terminology/                    # global.yml and area overlays
    ├── profiles/                       # convention profiles
    ├── checks/                         # rego/, schemas/, data/ (generated), vale/ (generated)
    ├── examples/                       # a worked, conforming consumer
    ├── src/  tests/  pyproject.toml    # authoring tooling (not shipped)
    └── README.md
```

**The product directory is the bundle.** The release tarball contains `engineering-conventions/` with `README.md`,
`conventions/`, `terminology/`, `profiles/`, `checks/` and `examples/`, plus `checks/data/release.json` naming the
version. The authoring tooling (`src/`, `tests/`, `pyproject.toml`, `uv.lock`, `.python-version`) and the Rego unit
tests are excluded, because consumers run the checks with Conftest and Vale alone.

**Everything that implements a check lives in `checks/`.** The Rego policies, the JSON Schemas, the generated data the
policies read and the generated Vale style are four implementations of one idea: the check that validates a
requirement ([decision 0001](0001-validation-engines.md)). They share one directory, named for that idea. The
directory is not called `rules/`: in this repository a normative statement is a *requirement*, and "rule" already
means something else to Rego, to linters and to `.claude/rules/`.

**Generated files are marked.** `checks/data/index.json`, `checks/vale/MusherConventions/*.yml` and
`conventions/README.md` are generated ([decision 0007](0007-terminology-and-generated-artifacts.md)). They are
never edited by hand: `task generate` rewrites them, and `task generate:check` fails when a committed copy is stale.

**Topics are created when they have content.** A topic directory under `conventions/` exists once it holds a
convention. Planned topics are listed in the generated index, not created empty.

**Diagnostic URLs include the product directory.** Requirement links are
`.../blob/<ref>/engineering-conventions/<path>#<anchor>`, where `<path>` is relative to the product directory, so the
same relative path works inside the bundle and on GitHub.

## Consequences

### Positive

- What a consumer depends on is one directory, and the bundle is that directory rather than a hand-kept list.
- The layout matches the template and the company repository, so it is familiar.
- Repository machinery can change without a product release.

### Negative

- The repeated directory name reads oddly at first (`engineering-conventions/engineering-conventions/`).
- Links from repository-level documents into the product carry an extra path segment.

### Neutral

- `LAYOUT.md` at the repository root describes the layout in more detail for contributors.

## Enforcement

- `task bundle:verify` fails when the tarball's top level is anything but `engineering-conventions/`, or when it
  contains an entry outside the allowed list.
- `task generate:check` fails when a generated file is stale.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Flat layout | Product and machinery at the root | rejected: the bundle would need an allowlist that drifts, and consumers could not tell what they depend on |
| Separate repositories for product and tooling | Strongest separation | rejected: every rule change would span two repositories, which company decision 0012 found costly |
| Nested product directory | The template's two-level layout | **chosen** |

## References

- Company decision 0013, on how a repository lays out its editor settings, tool configuration and product
  (`musher-dev/company`, private)
- [`LAYOUT.md`](../../LAYOUT.md)
- [Decision 0003: Public visibility and consumption](0003-public-visibility-and-consumption.md)
