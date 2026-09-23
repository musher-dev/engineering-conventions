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

The full guide for humans is `docs/authoring.md`; this is the procedure. Paths below are relative to the repository
root; `P=engineering-conventions`.

## Vocabulary

Use: convention, requirement, check, waiver, topic, area, convention profile, conventions declaration, family.
Never: `rule` for a requirement, `exception` for a waiver, `domain` for an area, `manifest` for the declaration,
`baseline` for a profile.

## Steps: a new requirement

1. **Allocate the ID.** Read `$P/checks/data/index.json` (or `$P/conventions/README.md`) and take the next unused
   number in the family, counting retired IDs. Never reuse a number. A new family is registered in
   `$P/conventions/families.yml`; prefixes under `reserved:` are not available.
2. **Frontmatter.** Append to the convention's `requirements:` list: `id`, `title` (declarative sentence, no final
   period), `status: proposed`, `severity: warning`, `since: <next release>`, `validation` (one of `conftest` +
   `package`, `jsonschema` + `schema`, `vale` + `style`, `delegated` + `tool` + `check`, or `review`), and `aliases`
   (`<repo>:<ID>`) when it ports an existing check. The schema is `$P/checks/schemas/convention-frontmatter.schema.json`.
   If the convention's `authority` is another repository, the change must already exist there.
3. **Body.** Add exactly one heading `### <ID>` in ID order under `## Requirements`, then a bold first line restating
   the title as a sentence, the rationale (the failure it prevents), `**Correct:**` and `**Incorrect:**` fenced examples,
   and the line `Checked by: <engine> · Severity: warning · Since: <version>[ · Formerly: <repo> <ID>]`. Nothing else
   goes in the heading: its anchor is the permanent diagnostic link.
4. **Check** (engine `conftest` only). In the package the frontmatter names, under `$P/checks/rego/`, add
   `findings contains f if { ... }` with `f := {"id": "<ID>", "path": <repo-relative path>, "message": ...}`. The
   message must say what to change without the URL. No severity, time or waiver logic in a check; the `main` router
   does that. Add `*_test.rego` cases beside it.
5. **Fixtures** (engine `conftest` only). Create `$P/tests/fixtures/repos/<id-lower>-<slug>/` with the smallest tree
   that triggers the finding and `expected.json`: a sorted array of `{"id", "path", "severity"}` under
   `now = 2026-09-23T00:00:00Z`. Confirm the `clean` fixture still expects `[]`.
6. **Regenerate and verify.**

   ```sh
   task generate      # index.json, Vale style, conventions/README.md
   task check         # every gate CI runs except the dev container build
   ```

   `task conventions:self` must report zero findings, warnings included.
7. **Commit type by change class.** Read the one classification table in
   `docs/decisions/0005-status-severity-and-versioning.md` (section "Change classification") and pick the type it
   gives. Do not work from memory or from another copy: that table is the only authoritative one.

## Changing or retiring

- **Retire, never delete:** `status: retired`, `replaced_by: <ID>`; keep the `### <ID>` section with a note; remove
  the ID from its Rego package and move its fixtures to the replacement.
- **Raise severity** only in a release classed `feat!`. A profile may raise severity, never lower it.

## Terms

Edit `$P/terminology/global.yml` or an overlay in `$P/terminology/areas/`. A term has `definition` or `authority`,
never both; do not restate a definition another repository owns (telemetry, specifications, positioning, platform
domain nouns). An overlay never redefines a global term. Run `task generate`.

## Decisions

A change to how the repository works (not to a convention) gets a record in `docs/decisions/` from `template.md`,
with an `## Enforcement` section.
