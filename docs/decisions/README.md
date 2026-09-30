# Decisions

Architecture decision records for this repository: why it exists, how it checks conventions, how it is released and
consumed, and why the vocabulary is what it is. Each record follows [MADR](https://adr.github.io/madr/) and the
decision-record convention this repository publishes,
[EC-0021](../../engineering-conventions/definitions/conventions/decisions/decision-records.md), with YAML
frontmatter validated by [`decision.schema.json`](../../engineering-conventions/checks/schemas/decision.schema.json).

These records govern this repository. The conventions it publishes are in
[`engineering-conventions/definitions/conventions/`](../../engineering-conventions/definitions/conventions/);
decisions about how the company operates are in `musher-dev/company`.

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
| [0008](0008-repository-layout.md) | The product lives in a nested directory, and that directory is the bundle | superseded by 0009 |
| [0009](0009-definitions-and-checks.md) | The product separates what is defined from what checks it | accepted |
| [0010](0010-outputs-declaration.md) | A repository declares the outputs it publishes in .repo/outputs.yaml | accepted |
| [0011](0011-declarations-are-toml.md) | The .repo/ declarations are TOML | accepted |
| [0012](0012-repository-names.md) | A repository is named `<system>-<component>`, from a registered system | accepted |
| [0013](0013-identity-declaration.md) | A repository declares its identity in .repo/repository.toml, and its kind selects its profile | accepted |
| [0014](0014-release-workflows-may-publish.md) | A release workflow may publish what it releases | accepted |
| [0015](0015-the-runner-reads-what-conftest-cannot-select.md) | The runner reads what conftest cannot select | accepted |
| [0016](0016-adopted-rules-get-new-families.md) | Rules adopted from other repositories get new families, and keep their old IDs as aliases | accepted |
| [0017](0017-releases-from-drafts.md) | Repositories release with release-please from a draft, and tag vX.Y.Z or \<component\>/vX.Y.Z | accepted |
| [0018](0018-a-site-is-an-output.md) | A site is an output, and a deploy workflow may publish it | accepted |
| [0019](0019-staged-adoption.md) | A repository may adopt the conventions one family at a time, for a limited time | accepted |
| [0020](0020-dev-container-files-get-their-own-family.md) | Dev container files get their own family, and the scaffold is consumed by pinning an image | accepted |
| [0021](0021-notify-and-sync-join-the-token-sets.md) | A notification workflow is notify, a syncing action is sync, and action synonyms are terminology | accepted |

## Writing a decision

Copy [`template.md`](template.md) to the next unused number, fill it in, and add a row above. Numbers are never
reused. A decision that changes an earlier one supersedes it: the new record lists the old one in `supersedes`, and
the old record's status becomes `superseded` with `superseded_by` set. The old file is kept. A decision that changes
only part of an earlier one lists it in `amends`, and the earlier record gains `amended_by`.

A decision needs an `## Enforcement` section that names the check which holds it, or says `review-only` and what a
reviewer looks for.
