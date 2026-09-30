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
| **topic** | The part of a repository a group of conventions governs, named for its file surface or tool, such as `github-actions`; a subdirectory of `definitions/conventions/` | `domain` (the platform's bounded contexts) |
| **convention profile** | A named selection of requirements for a kind of repository | `baseline` |
| **conventions declaration** | A consumer's `.repo/conventions.toml` | `manifest` |
| **output** | Something a repository publishes for others to consume: an image, library, command-line tool, bundle or site | `artifact` (GitHub Actions already means a workflow's upload) |
| **outputs declaration** | A publishing repository's `.repo/outputs.toml` | |
| **interface** | A surface another repository builds or runs against, declared in `[[interfaces]]` and addressed as `<repository>#<id>` | `contract` (the retired output kind), `API` (one format of many) |
| **dependencies declaration** | A consuming repository's `.repo/dependencies.toml`: each vendored release and its pin | `lock file` |
| **identity declaration** | Every repository's `.repo/repository.toml`: its name, system, component, kind, owner, lifecycle, audience and tier | `manifest`, `catalog-info` |
| **system** | A registered grouping of repositories, the first token of each of their names, such as `platform` | `team`, `domain` |
| **component** | What one repository holds within its system, the rest of its name, such as `api` in `platform-api` | |
| **family** | A requirement-ID prefix registered in `definitions/conventions/families.yml` | |

## Before you write

Open an issue with the matching form: **Propose a requirement**, **Change a requirement** or **Propose a term**. Say
what problem the requirement prevents and show a real example of it. If the rule is already owned by another
repository, the proposal carries `authority` pointing there
([decision 0002](decisions/0002-authority-and-migration.md)); the upstream rule is changed first.

## Adding a requirement

1. **Allocate the ID.** Take the next number in the family. Numbers are never reused, including numbers of retired
   requirements; `definitions/conventions/README.md` lists every ID ever issued. A new family needs an entry in
   `definitions/conventions/families.yml`.
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
5. **Add fixtures.** Every `conftest` requirement needs at least one fixture repository that produces its finding,
   under `engineering-conventions/tests/fixtures/repos/gha-38-<slug>/`. A case is an overlay on the `clean` case,
   which conforms fully, so it holds only:
   - the files that differ from `clean/`, the smallest change that triggers the finding;
   - `removed.txt`, when the case needs a `clean/` file gone: one path per line;
   - `expected.json`, listing the exact findings (`[{"id", "path", "severity"}]`, sorted).

   `clean/` itself must still produce no findings. A requirement with no fixture fails the invariants: a check that
   is never seen to fire could be checking nothing.

   A requirement first released after 0.6.2 also needs a **near-miss**: a case named `gha-38-passes-<slug>/` that
   comes as close to the requirement as a conforming repository can, and expects none of its findings. It proves the
   check stays quiet where it should, which is where false positives come from: which files it selects, how a parser
   reads them, a pattern, a threshold or a date boundary. The invariants fail on a new requirement without one.
6. **Update the findings snapshot.** `engineering-conventions/tests/fixtures/findings.snapshot.json` records every
   case's findings with their messages, duplicates included. `expected.json` says which requirements fire where; the
   snapshot says what each finding tells the reader, so a new case, a reworded message or a finding reported twice
   shows up as a diff in review. After a change that adds a case or changes a message:

   ```sh
   uv run --project engineering-conventions conventions fixtures --update-snapshot
   ```

   Read the diff before committing it: a message change is a `fix` ([decision
   0005](decisions/0005-status-severity-and-versioning.md#change-classification)), and a line you did not expect to
   change is a regression.
7. **Regenerate and check.**

   ```sh
   task generate
   task check
   ```

   `task generate` rewrites `checks/data/index.json`, the Vale style and `definitions/conventions/README.md`; commit
   them with the change. `task check` runs every gate CI runs except the dev container build.

## Adding or changing a term

Terms live in `engineering-conventions/definitions/terminology/global.yml`. A term has either a `definition` or an `authority`
pointing at the repository that defines it, never both. Do not restate a definition another repository owns. Run
`task generate` afterward: tokens and display forms feed the Rego data, and prose aliases feed the Vale style.

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

`Validate Pull Request / Title` also runs `task classify`, which diffs `checks/data/index.json` against the pull
request's base and fails when the title's type is weaker than what that diff shows. It is a lower bound: a diagnostic
message or a check's logic is not in the index, so the table still decides.

## Review checklist

- The requirement prevents a failure the issue demonstrates, and says so in its rationale.
- The message a check prints is enough to act on without the link.
- Correct and Incorrect examples are real shapes a contributor will meet.
- Nothing restates a definition owned by another repository.
- Nothing in the change is unsuitable for a public repository.
