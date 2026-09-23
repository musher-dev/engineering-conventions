# Authoring conventions

How to propose or change a convention, a requirement or a term, and what a change must carry to merge. Read
[decision 0004](decisions/0004-identifiers-and-diagnostic-urls.md) (IDs) and
[decision 0005](decisions/0005-status-severity-and-versioning.md) (status, severity and versioning) first; this guide
applies them.

## Vocabulary

| Word | Means | Not |
| --- | --- | --- |
| **convention** | A document with an `EC-NNNN` ID, holding related requirements | `standard`, `policy` |
| **requirement** | One normative statement with a `<FAMILY>-<NN>` ID | `rule` (`.claude/rules` already means prose) |
| **check** | An implementation that validates a requirement: a Rego package, a schema, a Vale rule, a platform check such as CI-14 | |
| **waiver** | A consumer's time-boxed, tracked deviation from a requirement | `exception` (Conftest and Python both use that word) |
| **topic** | A subdirectory of `conventions/`, such as `github-actions` | |
| **area** | A terminology overlay for a group of repositories | `domain` |
| **convention profile** | A named selection of requirements for a kind of repository | `baseline` |
| **conventions declaration** | A consumer's `.repo/conventions.yaml` | `manifest` |
| **family** | A requirement-ID prefix registered in `conventions/families.yml` | |

## Before you write

Open an issue with the matching form: **Propose a requirement**, **Change a requirement** or **Propose a term**. Say
what problem the requirement prevents and show a real example of it. If the rule is already owned by another
repository, the proposal carries `authority` pointing there
([decision 0002](decisions/0002-authority-and-migration.md)); the upstream rule is changed first.

## Adding a requirement

1. **Allocate the ID.** Take the next number in the family. Numbers are never reused, including numbers of retired
   requirements; `conventions/README.md` lists every ID ever issued. A new family needs an entry in
   `conventions/families.yml`.
2. **Add the frontmatter entry** to the convention's `requirements:` list:

   ```yaml
   - id: GHA-38
     title: A reusable workflow declares its inputs' types
     status: proposed
     severity: warning
     since: 0.2.0
     validation:
       engine: conftest
       package: conventions.checks.github_actions.workflow_files
   ```

   | Field | Notes |
   | --- | --- |
   | `title` | A declarative sentence without a final period. It is the bold first line of the body. |
   | `status` | `proposed` for anything new. |
   | `severity` | `warning` for anything new. `error` comes in a later release. |
   | `since` | The release that will first contain the requirement. |
   | `validation.engine` | `conftest` (with `package`), `jsonschema` (with `schema`), `vale` (with `style`), `delegated` (with `tool` and `check`) or `review` |
   | `aliases` | `<repo>:<ID>` of any existing check this requirement ports, such as `platform:CI-14` |

3. **Write the body section** below the frontmatter, in ID order:

   ````markdown
   ### GHA-38

   **A reusable workflow declares its inputs' types.**

   Why the requirement exists: the failure it prevents, in two or three sentences.

   **Correct:**

   ```yaml
   ...
   ```

   **Incorrect:**

   ```yaml
   ...
   ```

   Checked by: conftest · Severity: warning · Since: 0.2.0
   ````

   The heading is exactly `### <ID>` and appears once. Its anchor (`#gha-38`) is the permanent target of every
   diagnostic link, so never put anything else in that heading. Add `· Formerly: platform CI-NN` when the requirement
   has an alias.

4. **Implement the check** when the engine is `conftest`: add a `findings` rule to the package named in the
   frontmatter, emitting `{"id": "GHA-38", "path": ..., "message": ...}`. The message must say what to change without
   the link. Add Rego unit tests beside it (`*_test.rego`).
5. **Add fixtures.** Every `conftest` requirement needs at least one fixture repository that produces its finding:
   `engineering-conventions/tests/fixtures/repos/gha-38-<slug>/` holding the smallest tree that triggers it, plus an
   `expected.json` listing the exact findings (`[{"id", "path", "severity"}]`, sorted). The `clean` fixture must still
   produce no findings. A requirement with no fixture fails the invariants: a check that is never seen to fire could
   be checking nothing.
6. **Regenerate and check.**

   ```sh
   task generate
   task check
   ```

   `task generate` rewrites `checks/data/index.json`, the Vale style and `conventions/README.md`; commit them with the
   change. `task check` runs every gate CI runs except the dev container build.

## Adding or changing a term

Terms live in `engineering-conventions/terminology/global.yml` (or an area overlay under `terminology/areas/`). A term
has either a `definition` or an `authority` pointing at the repository that defines it, never both. Do not restate a
definition another repository owns. An area overlay may add terms and aliases; it may never redefine a global term.
Run `task generate` afterward: tokens and display forms feed the Rego data, and prose aliases feed the Vale style.

## Retiring a requirement

Never delete it. Set `status: retired` and `replaced_by` to the requirement that supersedes it (or explain in the body
why nothing does), and keep its `### <ID>` section with a short note. Remove the ID from its Rego package and move its
fixtures to the replacement.

## Change classes and commit types

The pull request title is a Conventional Commit, and release-please chooses the next version from it. Pick the type by
what the change does to a consumer, using the one classification table in
[decision 0005](decisions/0005-status-severity-and-versioning.md#change-classification). Examples of titles:

| Title | Why that type |
| --- | --- |
| `feat(conventions)!: make GHA-24 an error` | A requirement becomes `error` |
| `feat(conventions): require input types on reusable workflows` | A new requirement at `warning` |
| `fix(checks): accept action.yml in GHA-21 on a nested checkout` | A false positive fixed |
| `docs(conventions): add an example to GHA-14` | Prose clarified; nothing checked changes |
| `test(checks): cover GHA-09 with a renamed workflow` | This repository's tests only |

The pull request template asks for the requirement IDs touched, the change class, and whether it is breaking.

## Review checklist

- The requirement prevents a failure the issue demonstrates, and says so in its rationale.
- The message a check prints is enough to act on without the link.
- Correct and Incorrect examples are real shapes a contributor will meet.
- Nothing restates a definition owned by another repository.
- Nothing in the change is unsuitable for a public repository.
