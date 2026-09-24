---
paths:
  - "engineering-conventions/definitions/conventions/**"
  - "engineering-conventions/definitions/profiles/**"
  - "docs/decisions/**"
---

# Conventions, profiles and decisions

A convention's frontmatter is the requirement catalog: every generated artifact,
every diagnostic and every consumer's waiver resolves against it. Treat an ID
as a public API.

## Rules

- **MUST NOT** renumber, reuse or delete a requirement ID or a convention ID.
  A retired requirement stays in its convention as a tombstone (`status:
  retired`, `replaced_by`); a legacy name goes in `aliases`.
- **MUST** give every requirement exactly one `### <ID>` heading in the body,
  with its title as a bold first line. The heading is the diagnostic URL's
  anchor.
- **MUST** register a new ID prefix in `definitions/conventions/families.yml` first.
- **MUST** choose the commit type from the change-classification table in
  docs/decisions/0005-status-severity-and-versioning.md, the only copy of it.
  Anything that can fail a build that passed is a `!` commit; a change to what
  a requirement checks is never `docs`.
- **MUST** start a new requirement `proposed` at `warning`
  (docs/decisions/0005-status-severity-and-versioning.md).
- **MUST NOT** hand-edit `definitions/conventions/README.md`; `task generate` writes it.
- **MUST** let a profile only raise a severity, never lower it.
- **MUST NOT** restate a definition owned upstream. An `authority` entry points
  at its owner; the charter lists what this repository does not own
  (docs/decisions/0000-charter.md).
- Decisions are append-only: supersede a decision with a new one, never rewrite
  an accepted one.

## Enforced vs reviewed

| Rule | How |
| --- | --- |
| Frontmatter shape, profiles, decisions | `task schemas:validate` |
| IDs unique and append-only, one heading each, families registered | `task invariants` |
| Generated files current | `task generate:check` |
| Breaking change carries `!` | Review, with the PR template's Consumer impact section |
