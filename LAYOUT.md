# Repository Layout

**Two levels.** The repository root holds what *acts on* the product: the dev environment, tool configuration, CI,
release automation, contributor documentation and the decisions. One directory, `engineering-conventions/`, holds
the product itself: what a consumer pins.

This file decides **which level** a file belongs to. [CONFIGURATION.md](CONFIGURATION.md) decides where it goes
*within* the repository level. The reasoning is [decision 0008](docs/decisions/0008-repository-layout.md).

## The Rule

```text
engineering-conventions/               repository level: acts ON the product
├── .devcontainer/ .github/            integration homes whose location the tool mandates
├── .config/                           tool configuration (linters, hooks), by explicit path
├── .claude/  CLAUDE.md  AGENTS.md     agent contract and path-scoped rules
├── .repo/conventions.yaml             this repository's own conventions declaration
├── Taskfile.yml  taskfiles/           orchestration; reaches the product via PRODUCT_DIR
├── docs/                              contributor docs and decisions (docs/decisions/)
├── README.md  LAYOUT.md  CONFIGURATION.md  CONTRIBUTING.md  SECURITY.md  CHANGELOG.md  version.txt
└── engineering-conventions/           product level: what a consumer pins
    ├── README.md
    ├── conventions/                   EC-NNNN documents by topic; families.yml; README.md (generated)
    ├── terminology/                   global.yml and areas/ overlays
    ├── profiles/                      convention profiles (base-repo.yml, …)
    ├── checks/                        everything that implements a check
    │   ├── rego/                      the conftest checks, *_test.rego beside each
    │   ├── schemas/                   JSON Schemas (draft-07) for every content file
    │   ├── data/index.json            generated: requirements, profiles, vocabulary
    │   └── vale/MusherConventions/    generated: the Vale style
    ├── examples/                      a worked, conforming consumer
    ├── src/  tests/                   the authoring CLI and its tests (not shipped)
    └── pyproject.toml  uv.lock  .python-version
```

The product directory is a native uv project root: with the working directory set to it, `uv run pytest` or `ruff
check .` behave as they would in a single-purpose repository, because every file those tools discover by walking
upward is inside it.

The name repeats (`engineering-conventions/engineering-conventions/`) on purpose. The two levels have different jobs,
and naming the inner one after the repository means every Musher repository agrees on where its product lives.

## Generated Files

Three product files are written by `task generate` and committed, so that a consumer never needs the authoring CLI.
They are never edited by hand; `task generate:check` fails when one is stale.

| File | Generated from |
| --- | --- |
| `checks/data/index.json` | Convention frontmatter, `families.yml`, `profiles/`, `terminology/` |
| `checks/vale/MusherConventions/**` | `terminology/` (prose-scope aliases) |
| `conventions/README.md` | Convention frontmatter |

`.gitattributes` marks them `linguist-generated`, so diffs collapse them.

## The Bundle

A release is the product directory as a consumer runs it: the checks, the data they read and the documents their
diagnostics link to. `task bundle:build` writes it to `dist/`:

| Artifact | Contents |
| --- | --- |
| `engineering-conventions-<version>.tar.gz` | `engineering-conventions/` **except** `src/`, `tests/`, `pyproject.toml`, `uv.lock`, `.python-version` and the Rego unit tests (`checks/rego/**/*_test.rego`), plus an injected `checks/data/release.json` carrying the version |
| `MusherConventions.zip` | The Vale style as a Vale package (`MusherConventions/` at the zip root) |
| `manifest.json` | Version, commit, and the sha256 of every artifact and every bundled file |
| `SHA256SUMS` | Input for `sha256sum -c` |

The authoring side is excluded because a consumer runs the checks with conftest and Vale alone; the Rego unit tests
are excluded because conftest would load them as policy. `task bundle:verify` fails if the tarball holds anything but
`README.md`, `checks/`, `conventions/`, `examples/`, `profiles/` and `terminology/` under a single
`engineering-conventions/` root. The build is reproducible: the same commit produces the
same bytes.

## The Placement Test

Ask in order and stop at the first "yes":

| # | Question | Level |
| --- | --- | --- |
| 1 | Does a consumer need it to run the checks, or read it through a diagnostic link? | Product |
| 2 | Does the authoring CLI's native tooling read it, or find it by walking up from the product? | Product |
| 3 | Does it act on the repository: dev environment, CI, release, review policy, contributor docs? | Repository |

Worked examples:

| File | Level | Why |
| --- | --- | --- |
| `conventions/github-actions/workflow-files.md` | Product | Diagnostics link to its headings |
| `checks/rego/**`, `checks/data/index.json` | Product | conftest loads them in a consumer's run |
| `pyproject.toml`, `tests/` | Product | uv, ruff and pytest find them from the product directory; the bundle excludes them |
| `docs/decisions/*.md` | Repository | They record why this repository is shaped as it is; consumers do not run them |
| `.config/rego/regal.yaml` | Repository | Lints the Rego checks here, passed by explicit path; consumers never lint them |
| `.repo/conventions.yaml` | Repository | This repository's declaration as a consumer of itself, not part of what it ships |
| `Taskfile.yml` | Repository | Orchestrates; reaches the product with `PRODUCT_DIR` |

When the answer is genuinely both, it goes up a level and points down: repository machinery may name product paths,
but the product never reaches upward. A product file never references a path above `engineering-conventions/`, so a
consumer can vendor the directory on its own.

## What is Not Here Yet

The template this repository came from enforced its layout with numbered `LAYOUT-NN` checks. Those are not carried
over as local rules: they will migrate into this repository as a published `LAYOUT` family with their IDs unchanged
(the prefix is already reserved in `conventions/families.yml`), and then apply here like any other requirement.
