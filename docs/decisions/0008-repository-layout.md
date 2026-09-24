---
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
from an allowlist that drifts. Someone working on the product would also see every piece of machinery beside it, and a
new piece of machinery would have no obvious home that is not mistaken for part of the product.

## Decision

**Two levels.** The repository root holds the machinery. One directory, named after the repository
(`engineering-conventions/`), holds the product. Naming it after the repository means every Musher repository agrees
on where its product lives. The tree, the placement test and where configuration goes are in
[How this repository is organized](../repository.md).

**The product directory is the bundle.** The release tarball is `engineering-conventions/` minus the authoring tooling
(`src/`, `tests/` and the Python project files) and the Rego unit tests, plus `checks/data/release.json` naming the
version. Consumers run the checks with Conftest and Vale alone, and conftest would load the unit tests as policy.

**The product never reaches upward.** Repository machinery may name product paths; no product file references a path
above the product directory, so a consumer can vendor it on its own.

**Everything that implements a check lives in `checks/`.** The Rego policies, the JSON Schemas, the generated data the
policies read and the generated Vale style are four implementations of one idea: the check that validates a
requirement ([decision 0001](0001-validation-engines.md)). They share one directory, named for that idea. The
directory is not called `rules/`: in this repository a normative statement is a *requirement*, and "rule" already
means something else to Rego, to linters and to `.claude/rules/`.

**Generated files are marked.** Files written by `task generate`
([decision 0007](0007-terminology-and-generated-artifacts.md)) are listed in `.gitattributes` as
`linguist-generated`. They are never edited by hand, and `task generate:check` fails when a committed copy is stale.

**Topics are created when they have content.** A topic directory under `conventions/` exists once it holds a
convention, never empty in anticipation of one.

**Diagnostic URLs include the product directory.** Requirement links are
`.../blob/<ref>/engineering-conventions/<path>#<anchor>`, where `<path>` is relative to the product directory, so the
same relative path works inside the bundle and on GitHub.

## Consequences

### Positive

- What a consumer depends on is one directory, and the bundle is that directory rather than a hand-kept list.
- Repository machinery can change without a product release.
- The layout is the one Musher repositories share (company decision 0013), so it is familiar.

### Negative

- The repeated directory name reads oddly at first (`engineering-conventions/engineering-conventions/`).
- Links from repository-level documents into the product carry an extra path segment.

## Enforcement

- `task bundle:verify` fails when the tarball's top level is anything but `engineering-conventions/`, or when it
  contains an entry outside the allowed list.
- `task generate:check` fails when a generated file is stale.
- That the product never reaches upward is `review-only`.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Flat layout | Product and machinery at the root | rejected: the bundle would need an allowlist that drifts, and consumers could not tell what they depend on |
| Separate repositories for product and tooling | Strongest separation | rejected: every rule change would span two repositories, which company decision 0012 found costly |
| Nested product directory named after the repository | Two levels | **chosen** |

## References

- Company decision 0013, on how a repository lays out its editor settings, tool configuration and product
  (`musher-dev/company`, private)
- [How this repository is organized](../repository.md)
- [Decision 0003: Public visibility and consumption](0003-public-visibility-and-consumption.md)
