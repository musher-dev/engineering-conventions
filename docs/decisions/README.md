# Decisions

Architecture decision records for this repository: why it exists, how it checks conventions, how it is released and
consumed, and why the vocabulary is what it is. Each record follows [MADR](https://adr.github.io/madr/) with YAML
frontmatter validated by `engineering-conventions/checks/schemas/decision-frontmatter.schema.json`.

These records govern this repository. The conventions it publishes are in
[`engineering-conventions/conventions/`](../../engineering-conventions/conventions/); decisions about how the company
operates are in `musher-dev/company`.

| ID | Decision | Status |
| --- | --- | --- |
| [0000](0000-charter.md) | Charter: the home of shared engineering conventions, and what it does not own | accepted |
| [0001](0001-validation-engines.md) | Conventions are checked with Conftest and Rego, JSON Schema and Vale | accepted |
| [0002](0002-authority-and-migration.md) | A convention names its authority, and ownership moves in one change | accepted |
| [0003](0003-public-visibility-and-consumption.md) | The repository is public, and consumers vendor a verified, tagged bundle | accepted |
| [0004](0004-identifiers-and-diagnostic-urls.md) | Conventions and requirements have permanent IDs, and every diagnostic links to one | accepted |
| [0005](0005-status-severity-and-versioning.md) | Requirements start as warnings, and a release's version says what it can break | accepted |
| [0006](0006-github-actions-naming-vocabulary.md) | GitHub Actions units are named for responsibility, result and capability | accepted |
| [0007](0007-terminology-and-generated-artifacts.md) | Terminology is structured data, and generated artifacts are committed | accepted |
| [0008](0008-repository-layout.md) | The product lives in a nested directory, and that directory is the bundle | accepted |

## Writing a decision

Copy [`template.md`](template.md) to the next unused number, fill it in, and add a row above. Numbers are never
reused. A decision that changes an earlier one supersedes it: the new record lists the old one in `supersedes`, and
the old record's status becomes `superseded` with `superseded_by` set. The old file is kept.

A decision needs an `## Enforcement` section that names the check which holds it, or says `review-only` and what a
reviewer looks for.
