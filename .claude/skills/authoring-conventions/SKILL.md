---
name: authoring-conventions
description: >-
  Add, change or retire a convention, requirement or term in this repository, with its ID, frontmatter,
  `### <ID>` section, Rego check, fixture repositories, regenerated artifacts and the right Conventional Commit type.
  Use when writing or editing anything under engineering-conventions/conventions/, terminology/, profiles/ or
  checks/rego/. Triggered by: new requirement, add requirement, GHA-, ADOPT-, EC-, convention, requirement ID,
  retire requirement, tombstone, waiver, terminology, display form, banned alias, profile, fixture, expected.json,
  task generate, change class, feat!.
---

# Authoring conventions

**Read `docs/authoring.md` first and follow it.** It is the procedure: vocabulary, the frontmatter fields, the body
section, the check, the fixtures, retiring, terms and change classes. This skill adds only what an agent tends to get
wrong. Paths are relative to the repository root.

## Checklist

- [ ] **ID.** Take the next unused number in the family from
  `engineering-conventions/checks/data/index.json`, counting retired IDs. Never reuse or renumber one.
- [ ] **Frontmatter.** New requirements are `status: proposed`, `severity: warning`. The schema is
  `engineering-conventions/checks/schemas/convention-frontmatter.schema.json`; `task schemas:validate` checks it.
- [ ] **Body.** Add exactly one `### <ID>` heading, with nothing else in it. Its anchor is the permanent diagnostic
  link.
- [ ] **Check** (`conftest` only). Emit `{"id", "path", "message"}` and nothing more. No severity, time or waiver logic:
  the `main` router owns those. Put a `*_test.rego` beside it.
- [ ] **Fixture** (`conftest` only). Add a case under `engineering-conventions/tests/fixtures/repos/` whose
  `expected.json` names the requirement. `clean` must still expect `[]`.
- [ ] **Generated files.** Run `task generate` and commit what it rewrites. Never hand-edit a file `.gitattributes`
  marks `linguist-generated`.
- [ ] **Verify.** Run `task check`. `task conventions:self` must report zero findings, warnings included.
- [ ] **Commit type.** Take it from the change-classification table in
  `docs/decisions/0005-status-severity-and-versioning.md`, the only copy. Never work from memory. Anything a consumer
  must be able to pin is never `docs`.
- [ ] **Upstream.** If the convention's `authority` is another repository, the change must already exist there. Never
  restate a definition another repository owns.
