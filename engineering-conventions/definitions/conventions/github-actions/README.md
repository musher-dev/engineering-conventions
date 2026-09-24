# GitHub Actions

These conventions govern the automation under `.github/`: workflow files, their jobs and steps, local composite
actions, the hygiene every workflow keeps, and how units are chosen and renamed.

The governing rule, in one sentence:

> **Name workflows after the responsibility they own, jobs after the result they produce, and actions after the
> capability they provide; keep triggers, tools and execution order out of names.**

Behind it is a division of labor. Workflows own GitHub orchestration: triggers, the job graph, permissions and
concurrency. Taskfiles own project commands, the ones a developer also runs locally. Composite actions own reusable
GitHub-specific integration such as runner setup and authentication.

## Status

All five conventions are **drafts**, and every requirement is `proposed` at severity `warning`. Workflow naming is owned
by `musher-dev/platform` (issue [#2892](https://github.com/musher-dev/platform/issues/2892)) until the single handoff
described in [decision 0002](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0002-authority-and-migration.md).
The requirements are derived from the platform's checks CI-14 to CI-19; where they differ, each convention lists the
difference in its Status section as a proposal the platform adopts at the handoff.

Three things to know before reading a result:

- **Filenames first, then names.** A workflow's, required-check job's or action's name is derived from a filename or
  directory, so GHA-07, GHA-12 (for a required-check job) and GHA-22 wait until the file they derive from is named
  correctly. Fix the filename findings first; the next run reports the names they imply.
- **Required checks need committed rulesets.** GHA-15, GHA-16 and GHA-32 compare the workflows with
  `.github/rulesets/*.json`. A repository that does not commit its rulesets gets no findings from them, which says
  nothing about its branch protection.
- **Entry point, callable, reusable.** An entry point has any trigger other than `workflow_call`; a callable workflow
  has `workflow_call`; a reusable workflow has only `workflow_call` and the `reusable-` prefix. A workflow can be both
  an entry point and callable ([EC-0002](workflow-files.md#scope)).

## Reading order

Read them in this order. Each builds on the vocabulary of the one before.

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0002 Workflow files](workflow-files.md) | GHA-01 – GHA-09 | Filename grammar, responsibility and capability tokens, derived display names |
| [EC-0003 Jobs and steps](jobs-and-steps.md) | GHA-10 – GHA-19 | Job-name grammar, aggregates and required checks, identifiers, step names |
| [EC-0004 Composite actions](composite-actions.md) | GHA-20 – GHA-23, GHA-38 | Action tokens, directory grammar, metadata, kebab-case inputs and outputs |
| [EC-0005 Execution hygiene](execution-hygiene.md) | GHA-24 – GHA-33 | Pinning, permissions, credentials, timeouts, concurrency, path filters, linters |
| [EC-0006 Units and renames](units-and-renames.md) | GHA-34 – GHA-37 | Choosing a workflow, job, action or reusable workflow; the validation split; renaming safely |

The vocabulary and its reasoning are recorded in
[decision 0006](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0006-github-actions-naming-vocabulary.md).
A worked, conforming example is in [`examples/consumer`](../../../examples/consumer/).

## Quick reference

| Unit | Grammar | Example |
| --- | --- | --- |
| Entry point | `<responsibility>[-<scope>].yml` | `deploy-production-api.yml` |
| Reusable workflow | `reusable-<responsibility or capability>[-<scope>].yml` | `reusable-build-image.yml` |
| Entry point that is also callable | `<responsibility>[-<scope>].yml`, jobs with bare names | `verify-production.yml` |
| Workflow `name:` | filename stem in Title Case | `Deploy Production API` |
| Entry-point job name | `<Subject>[ / <Check>]`; GitHub shows the workflow name before it | `API / Tests`, shown as `Validate Code / API / Tests` |
| Required-check job name | `<Workflow> / <Check>`, unique across the repository | `Validate / Required`, `Validate Pull Request / Title` |
| Job name in a callable workflow | bare | `Lint` |
| Job ID, step ID | `snake_case` | `api_tests` |
| Action directory | `<action-token>-<object>` | `setup-tools` |
| Action `name:` | directory in Title Case | `Setup Tools` |

Responsibility tokens: `validate`, `release`, `publish`, `deploy`, `verify`, `monitor`, `audit`, `maintain`,
`repository`. Capability tokens (reusable workflows only): `build`, `promote`, `check`. Action tokens: `setup`,
`install`, `authenticate`, `check`.
