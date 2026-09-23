---
id: "0001"
title: Conventions are checked with Conftest and Rego, JSON Schema and Vale
date: 2026-09-23
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0001 — Validation engines

## Context

A convention that nothing checks is advice. The conventions here have to be checked in repositories written in Python,
TypeScript, Go and plain YAML, by people and agents who should not have to install one language's toolchain to lint
another's workflows. Three kinds of thing need checking, and they are different problems:

- **Structure across files**: a workflow's `name:` agrees with its filename; every context a ruleset requires is a job
  some workflow emits; a waiver matches a finding. These are relational queries over several parsed documents.
- **The shape of one file**: the conventions declaration, a convention's frontmatter, a profile. These are schemas.
- **Prose**: a document uses the agreed term, not its banned alias.

The platform's governance CLI answers the first two in Python, and its `.repo/CLAUDE.md` records a deliberate choice
not to add OPA or Conftest: for a Python monorepo whose engineers already know Pydantic, a second policy language was
unjustified scope. That reasoning is sound for that repository, and this decision does not reopen it. It is scoped to
one Python codebase checking itself. This repository has a different audience: every repository in the organization,
most of which have no Python toolchain and should not need one to consume a naming rule.

## Decision

We will check conventions with three engines, each for the problem it was built for:

| Engine | Checks | Why this engine |
| --- | --- | --- |
| **Conftest with Rego** (OPA) | Structure and relations across files: workflows, actions, rulesets, the declaration | A single static binary; parses YAML and JSON; policy is data-driven, so severity, profiles and waivers are data, not code |
| **JSON Schema** (draft-07) | The shape of one file: declaration, frontmatter, profiles, terminology | Language-neutral, and validators exist in every ecosystem; draft-07 is what `opa check -s` and Rego's `json.match_schema` support |
| **Vale** | Prose: preferred terms and banned aliases in Markdown | A single binary with a package format consumers can sync; the terminology generates its rules |

Checks are pure. A Rego check emits findings (`{id, path, message}`) and nothing else; one router package applies the
profile, severity and waivers from the generated `index.json`. Changing a requirement's severity is a frontmatter edit,
never a Rego change.

A small Python package (`conventions-tools`) generates the committed artifacts and runs the meta-checks. It is
authoring tooling for this repository only. Consumers need `conftest`, optionally `vale`, and the bundle; they never
need Python.

## Consequences

### Positive

- A consumer installs two pinned binaries and downloads one tarball. No language runtime is required.
- Findings carry the requirement ID from the check itself, so the ID in a diagnostic is always the ID in the document.
- OPA's own test runner and Regal's linter give the policies unit tests and style checks.

### Negative

- Rego is a language most contributors have not written. Every check is small, pure and tested, and fixture
  repositories show expected findings, but the learning cost is real.
- Two implementations of the GitHub Actions naming rules exist while the platform keeps its Python checks (CI-14 to
  CI-19). [Decision 0002](0002-authority-and-migration.md) keeps them from diverging.

### Neutral

- Conftest parses YAML 1.1, so an unquoted `on:` key arrives as `"true"`. The Rego library normalizes it once.
- Some requirements cannot be checked by any engine (a step name is an imperative verb phrase). They are marked
  `engine: review`, not approximated.

## Enforcement

- `task checks:test` runs `opa test` with a coverage threshold and fails when no tests are found, then runs every
  fixture repository through the runner and compares its findings to `expected.json`.
- `conventions invariants` fails when a requirement declared with `engine: conftest` is not emitted by its package or
  has no fixture expecting it, and when a check emits an ID no convention declares.
- `task checks:lint` runs Regal; `task schemas:check` validates every schema and every file that has one.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| A Python package consumers install | Reuse the platform's approach | rejected: every consumer would need a Python toolchain and a package index to read a naming rule |
| CUE | Schemas and constraints in one language | rejected: strong for shapes, weaker for relational queries across many files; smaller ecosystem for GitHub Actions |
| A custom Go binary | One tool that does everything | rejected: a policy language would be reinvented inside it, and every rule change would be a code release |
| Conftest/Rego + JSON Schema + Vale | Each engine for its problem | **chosen** |

## References

- [Conftest](https://www.conftest.dev/)
- [Open Policy Agent: Policy language](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [Regal](https://github.com/open-policy-agent/regal)
- [Vale](https://vale.sh/)
- `musher-dev/platform` `.repo/CLAUDE.md`, section "Why no OPA/Conftest"
- [Decision 0007: Terminology model and committed generated artifacts](0007-terminology-and-generated-artifacts.md)
