---
title: The .repo/ declarations are TOML
date: 2026-09-27
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0011 — The .repo/ declarations are TOML

## Context

A consuming repository keeps its declarations under `.repo/`: the conventions declaration
([EC-0001](../../engineering-conventions/definitions/conventions/adoption/conventions-declaration.md)) and the outputs
declaration ([EC-0007](../../engineering-conventions/definitions/conventions/outputs/outputs-declaration.md),
[decision 0010](0010-outputs-declaration.md)). Both were YAML. The files beside them that pin tools are not: the
release pin itself is a line in `mise.toml` (ADOPT-09), and a Python project's settings are in `pyproject.toml`. A
reader adopting the conventions edits TOML to pin the release and YAML to declare anything else.

YAML's implicit typing is a trap in a file a policy engine reads. An unquoted `on` or `no` becomes a boolean, an
unquoted date becomes a timestamp in some loaders and a string in others, and anchors and merge keys let one value
stand for another. The checks have to defend against each of these; the GitHub Actions checks already carry a rule
for the `on:` key that YAML 1.1 reads as `true`. TOML has one type per literal, no anchors, and fails loudly on a
duplicate key.

The declarations are flat, or nearly so: a few top-level keys, a table or two, and lists of records. The repository
identity declaration planned next is flat key-value. None of them needs what YAML offers beyond TOML.

No consumer has adopted a `.repo/` declaration yet, so the format can change once, now, without a migration period.

## Decision

**Every `.repo/` declaration is TOML: `.repo/conventions.toml` and `.repo/outputs.toml`, and every declaration added
later.** The change is a single cutover. The checks read only the TOML files, and a YAML declaration is no longer
read.

- **Dates are quoted strings.** A bare TOML date, `expires = 2026-12-01`, reaches the checks as the timestamp
  `2026-12-01T00:00:00Z`, since conftest decodes it into a time value, and the schema's `YYYY-MM-DD` pattern rejects
  it. ADOPT-02 reports it with a message that asks for the quotes. Quoting keeps the value a string in every tool that
  reads the file, including the ones that cannot decode a local date at all.
- **The shapes do not change.** The JSON Schemas describe the same objects, since a TOML document is a JSON object
  once decoded; only the files' names and syntax change.
- **Editors and hooks format TOML with Taplo**, pinned like every other tool.

## Consequences

### Positive

- A repository's configuration under `.repo/` and its tool pins share one syntax.
- A value is the type it is written as. There are no implicit booleans, anchors or merge keys to guard against.
- New declarations start in TOML with nothing to migrate.

### Negative

- It is a breaking change: a repository that wrote `.repo/conventions.yaml` or `.repo/outputs.yaml` renames it to
  `.toml`, converts its syntax and quotes its dates, or its declaration is ignored.
- TOML's arrays of tables (`[[waivers]]`) are less familiar than a YAML list, and a top-level key written after a
  table header silently belongs to that table.
- A bare date is valid TOML that the checks reject, which a reader may not expect; the ADOPT-02 message names the fix.

### Neutral

- The conventions' own definitions (frontmatter, terminology, profiles, families) stay YAML. They are authored here,
  not by consumers, and this decision is about what a consuming repository writes.

## Enforcement

- `bin/conventions` and the authoring CLI pass only `.repo/*.toml` declarations to conftest, and
  `checks/rego/lib/files.rego` reads them by those paths.
- ADOPT-02 and OUT-02 validate the declarations against their schemas; ADOPT-02 names an unquoted date.
- `task schemas:validate` validates this repository's own declarations, read as TOML, and `task lint:toml` checks
  every TOML file's formatting.
- Fixture repositories under `engineering-conventions/tests/fixtures/repos/` hold only TOML declarations, and
  `adopt-02-bare-date` proves the date message.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Keep YAML | No change for anyone | rejected: keeps implicit typing in the files a policy engine reads, and a second syntax beside `mise.toml` |
| TOML only for new declarations | Identity in TOML, the rest stays YAML | rejected: two syntaxes under one directory, and the migration still comes later, with consumers by then |
| JSON | Strictly typed, read by every tool | rejected: no comments, and a waiver's reason is prose a reviewer reads |
| TOML for every declaration, in one cutover | One syntax, strict types, while no consumer has adopted | **chosen** |

## References

- [EC-0001 Conventions declaration](../../engineering-conventions/definitions/conventions/adoption/conventions-declaration.md)
- [EC-0007 Outputs declaration](../../engineering-conventions/definitions/conventions/outputs/outputs-declaration.md)
- [Decision 0010: Outputs declaration](0010-outputs-declaration.md)
- [TOML v1.0.0](https://toml.io/en/v1.0.0)
- [Taplo](https://taplo.tamasfe.dev/)
