---
id: EC-0003
title: Jobs and steps
summary: >-
  Jobs are named for the result they report, only required-check jobs lead
  with their workflow's name, identifiers are snake_case, and required
  checks are stable aggregates.
status: draft
topic: github-actions
applies_to:
  paths:
    - .github/workflows/*.yml
    - .github/workflows/*.yaml
    - .github/actions/*/action.yml
    - .github/actions/*/action.yaml
    - .github/rulesets/*.json
created: 2026-09-23
owners:
  - "@justinmerrell"
authority:
  repo: musher-dev/platform
  ref: https://github.com/musher-dev/platform/issues/2892
migration: proposed
implementations:
  - repo: musher-dev/platform
    check: CI-16
    mode: blocking
  - repo: musher-dev/platform
    check: CI-17
    mode: blocking
  - repo: musher-dev/platform
    check: CI-19
    mode: blocking
references:
  - title: "platform #2892: Organize GitHub Actions workflows by responsibility"
    url: https://github.com/musher-dev/platform/issues/2892
  - title: "GitHub Docs: Troubleshooting required status checks"
    url: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks
requirements:
  - id: GHA-10
    title: Job IDs and step IDs are snake_case
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.jobs_and_steps
    aliases: ["platform:CI-16"]
  - id: GHA-11
    title: Every job declares a name, unique within its workflow
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.jobs_and_steps
    aliases: ["platform:CI-17"]
  - id: GHA-12
    title: An entry-point job is named <Subject>[ / <Check>]; only a required-check job leads with its workflow's name
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.jobs_and_steps
    aliases: ["platform:CI-17"]
  - id: GHA-13
    title: A job in a callable workflow has a bare name
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.jobs_and_steps
    aliases: ["platform:CI-17"]
  - id: GHA-14
    title: An aggregate job runs even when a dependency fails, and needs every other job
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.jobs_and_steps
  - id: GHA-15
    title: Every required status check is a context exactly one job emits
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.jobs_and_steps
    aliases: ["platform:CI-19"]
  - id: GHA-16
    title: A multi-job workflow is required only through its aggregate
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.jobs_and_steps
  - id: GHA-17
    title: Every run step has a name
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.jobs_and_steps
  - id: GHA-18
    title: A step name is an imperative verb phrase
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: review
  - id: GHA-19
    title: A tool is named only when the tool is the subject
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: review
---

# Jobs and steps

A job is named for the result it reports, so its check says which part of which workflow failed: GitHub already
shows the workflow's name before the job's. A step is named for what it was doing, so the log says where. Identifiers are
snake_case, and the checks a branch ruleset requires are stable aggregates rather than whichever jobs exist this week.

## Scope

This convention covers the `jobs:` of every workflow under `.github/workflows/`, the `steps:` of those jobs and of
composite actions under `.github/actions/`, and the required status checks declared in `.github/rulesets/*.json`.

Terms used below, as [EC-0002](workflow-files.md#scope) defines them:

- **Entry point**: a workflow with any trigger other than `workflow_call`. Each of its jobs reports its own check
  context.
- **Callable workflow**: a workflow with a `workflow_call` trigger. When called, GitHub reports each of its jobs as
  `<caller job name> / <called job name>`.
- **Reusable workflow**: a workflow with *only* a `workflow_call` trigger, carrying the `reusable-` prefix. It is
  callable and never an entry point.
- A workflow with `workflow_call` and another trigger is **both** an entry point and callable. Its jobs have bare
  names (GHA-13), and it emits those bare names as contexts when an event starts it directly.
- **Required-check job**: a job whose name a committed ruleset lists as a required status check.
- **Aggregate job**: the one job in a workflow whose result stands for all of the others. It is recognized by its
  name, `<Workflow> / Required` compared case-insensitively, or by its job ID, `required`.

**Required checks need committed rulesets.** GHA-15, GHA-16 and [GHA-32](execution-hygiene.md#gha-32) compare the
workflows with the required status checks in `.github/rulesets/*.json`. A repository that does not commit its rulesets
there gives them nothing to compare, so they report nothing. A clean result from them then says nothing about the
repository's branch protection; commit the rulesets (exported from the repository settings) to have them checked.

## Status and authority

This convention is a **draft**. Job naming is owned by `musher-dev/platform`, where issue
[#2892](https://github.com/musher-dev/platform/issues/2892) introduced the grammar. The requirements here are derived
from the platform's checks and published as proposed requirements until the single handoff described in
[decision 0002](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0002-authority-and-migration.md).

Every requirement here is `proposed` at severity `warning`.

| Platform check | Requirements | Mode |
| --- | --- | --- |
| `CI-16` | GHA-10 | blocking in `musher-dev/platform` |
| `CI-17` | GHA-11, GHA-12, GHA-13 | blocking in `musher-dev/platform` |
| `CI-19` | GHA-15 | blocking in `musher-dev/platform` |

### Differences from platform CI-14..19

Where this convention and the platform's checks disagree, the difference is a **proposal ahead of the platform**. The
platform keeps its current behavior until the handoff, and adopts these differences as part of it.

| Difference | Platform today | Here |
| --- | --- | --- |
| A required-check job's workflow prefix | The platform rule names a required-check job `<Workflow> / <Check>`, but CI-17 only permits the prefix there and does not require it | GHA-12 requires it: a job that emits a required context leads with its workflow's name. The prefix may be the workflow's `name:` or the name GHA-07 derives from its filename, so a wrong workflow name is one finding, not one per job |
| An empty subject | No platform check | GHA-12 flags a job name with an empty segment, such as `/ Lint` or `API / / Tests` |
| Which rulesets are read | CI-19 reads `.github/rulesets/main-branch.json` only | GHA-15 reads every `.github/rulesets/*.json` |
| Called workflows | CI-19 resolves entry-point job names only | GHA-15 resolves a called workflow's jobs as `<caller> / <callee>`, recursively through nested calls |
| Contexts it cannot verify | CI-19 judges every required context | GHA-15 skips contexts under a call to another repository's workflow, and checks another app reports |
| Dual-trigger workflows | CI-17 and CI-19 treat any workflow with `workflow_call` as callable only, emitting nothing | A workflow with `workflow_call` and another trigger is an entry point too, and emits its jobs' bare names |

## Two questions, two names

When something goes red, a reader asks two questions in order:

| Question | Answered by | Example |
| --- | --- | --- |
| Which part failed? | The **job name**, shown after its workflow's name in the checks list | `Validate Code / API / Tests` |
| What was it doing? | The **step name**, in the job's log | `Run the integration tests` |

The job name is an interface: rulesets require it, people search for it, and it outlives any one implementation. It
names the result the job produces. The step name is a log line: it names the action the step takes, and it can change
whenever the implementation does.

## Job-name grammar

An entry-point job is named:

```text
<Subject>[ / <Check>]
```

GitHub shows every job in the checks list after its workflow's name, so the job `API / Tests` in the workflow
`Validate Code` reads `Validate Code / API / Tests`. A job that starts with its own workflow's name reads that name
twice.

| Segment | Content | Case |
| --- | --- | --- |
| Subject | The thing being judged or produced: an app, a package, a surface, an environment | Chosen, not derived: capitalize its words and keep display forms (`API`, `E2E`) |
| Check | Which result about the subject, when a subject has more than one | Sentence case: only the first word and proper nouns capitalized |

The separator is a space, a slash and a space. The Check segment is optional; use it when the Subject alone does not
say which result this is. Neither segment may be empty.

**Required-check jobs lead with their workflow's name.** A ruleset matches a check by the job name alone, without the
workflow name GitHub shows before it, so a required context has to be unique across the repository. A job that emits
one is named `<Workflow> / <Check>`, where Workflow is the workflow's `name:` exactly, as
[EC-0002](workflow-files.md) derives it from the filename. That is what makes `Validate / Required` and
`Validate Code / Required` two different contexts. Every other job leaves the workflow's name to GitHub.

Two kinds of capitalization meet in a job name, and they are different rules. The Workflow segment of a required-check
job is **derived Title Case** ([EC-0002](workflow-files.md#display-forms)): mechanical, every token capitalized,
checked by GHA-07. The Subject is written by a person, who capitalizes its words and keeps display forms, but it is not
derived from any filename, so its casing is a review matter: `OpenAPI / Codegen drift` is right although no rule could
produce `OpenAPI`.

| Workflow file | Job name | Checks list shows | Reads as |
| --- | --- | --- | --- |
| `validate.yml` | `Workflows` | `Validate / Workflows` | the workflows in this repository are valid |
| `validate.yml` | `Repository / Lint` | `Validate / Repository / Lint` | the repository passes lint |
| `validate-code.yml` | `API / Tests` | `Validate Code / API / Tests` | the API's tests pass |
| `validate-code.yml` | `OpenAPI / Codegen drift` | `Validate Code / OpenAPI / Codegen drift` | the OpenAPI client code is not stale |
| `deploy-staging.yml` | `Console` | `Deploy Staging / Console` | the console was deployed to staging |
| `validate-pull-request.yml` | `Validate Pull Request / Title` (required) | `Validate Pull Request / Validate Pull Request / Title` | the pull request title is valid |
| any entry point | `<Workflow> / Required` (required) | `<Workflow> / <Workflow> / Required` | every other job in this workflow reported acceptably |

A required-check job reads its workflow's name twice in the checks list. That is the price of a context the ruleset
can match unambiguously, and it is paid by one or two jobs per workflow rather than all of them.

A callable workflow's jobs have bare names (`Tests`, `Build image`) because the caller's job name becomes the prefix:
a job `Migrations` in `validate-code.yml` that calls `reusable-validate-migrations.yml`, whose job is `Lint`, is shown as
`Validate Code / Migrations / Lint`, and a ruleset would match it as `Migrations / Lint`.

## Status and required checks

A branch ruleset names the check contexts a pull request must pass. Those names are the most expensive names in a
repository to change: a ruleset that requires a context no job emits leaves every pull request waiting on
"Expected" until an administrator edits the ruleset. Three requirements keep that surface small and stable:

1. Every required context is a job name that exists (GHA-15).
2. A workflow with more than one job is required through its aggregate only (GHA-16). Jobs can then be added,
   removed, split or renamed inside the workflow without touching the ruleset.
3. The aggregate classifies every result it depends on (GHA-14).

**Aggregate semantics.** The aggregate runs with `if: always()` or `if: ${{ !cancelled() }}`, so it reports even when
a job it needs failed or was skipped. (The two differ only when the run itself is cancelled: `always()` still runs the
aggregate, `!cancelled()` does not. Either way a cancelled run never reports success.) It then classifies each result:

| Result | Aggregate treats it as |
| --- | --- |
| `success` | passed |
| `failure`, `cancelled` | failed |
| `skipped` | failed, **unless** the workflow's own scope policy says this job was expected to skip for this event |

A skip is not a success. A job skipped because a path filter matched nothing is fine; a job skipped because the job it
needs failed is not, and the two look the same to a naive `!contains(needs.*.result, 'failure')` test. The simplest
correct aggregate treats anything but `success` as failure; a workflow that skips jobs by design passes its scope
decision to the aggregate and allows exactly those skips.

## Requirements

### GHA-10

**Job IDs and step IDs are snake_case.**

Job IDs appear in `needs:` and in `needs.<job_id>.outputs`; step IDs appear in `steps.<step_id>.outputs`. Both are
expression identifiers, where a hyphen reads as subtraction to anyone scanning the expression, and a mix of
kebab-case, camelCase and snake_case makes every reference a guess. snake_case (`^[a-z][a-z0-9_]*$`) is valid everywhere
an identifier appears. The rule applies to workflow jobs, workflow steps and composite-action steps.

**Correct:**

```yaml
jobs:
  api_tests:
    steps:
      - id: detect_changes
```

**Incorrect:**

```yaml
jobs:
  api-tests:
    steps:
      - id: detectChanges
```

Checked by: conftest · Severity: warning · Since: 0.1.0 · Formerly: platform CI-16

### GHA-11

**Every job declares a name, unique within its workflow.**

A job without `name:` reports its check context as its bare ID (`api_tests`), which says nothing a reader can use.
Two jobs in one workflow that render the same name are worse: a failure cannot say which one it was, and a ruleset
cannot require one without the other. Matrix legs count separately, each rendering the matrix values its name
references. A matrix job with a static name is fine, because GitHub appends the leg's matrix values to it
(`Tests (ubuntu-latest, 3.12)`). Naming every job is the precondition for the grammar in GHA-12 and GHA-13.

**Correct:**

```yaml
jobs:
  api_tests:
    name: API / Tests
  docs_quality:
    name: ${{ matrix.site.name }} / Quality
    strategy:
      matrix:
        site: [{name: Docs}, {name: Engineering Docs}]
```

**Incorrect:**

```yaml
jobs:
  api_tests:
    runs-on: ubuntu-latest       # no name
  docs_quality:
    name: ${{ matrix.site.name }} / Quality
    strategy:
      matrix:
        site: [{name: Docs}, {name: Engineering Docs}]
  docs_quality_extra:
    name: Docs / Quality         # renders the same as a matrix leg above
```

Checked by: conftest · Severity: warning · Since: 0.1.0 · Formerly: platform CI-17

### GHA-12

**An entry-point job is named `<Subject>[ / <Check>]`; only a required-check job leads with its workflow's name.**

GitHub shows each job in the checks list after its workflow's name, so a job named `Validate Code / API / Tests` inside
`Validate Code` reads `Validate Code / Validate Code / API / Tests`. The check reports an entry-point job that leads
with its workflow's name, unless the job emits a required context.

A job that emits a required context is the exception, and must lead with its workflow's name. A ruleset matches the job
name alone, so a required context has to be unique across the repository: `Validate / Required` and `Validate Code /
Required` are two contexts, where two jobs named `Required` would be one. The prefix is the workflow's `name:`; the
check also accepts the name [GHA-07](workflow-files.md#gha-07) derives from the filename, so a workflow whose `name:`
is wrong gets one GHA-07 finding rather than one GHA-12 finding per job. While the filename itself must change, this
half of the check waits.

A repository that commits no rulesets has no required contexts, and may still name its aggregate
`<Workflow> / Required`, the job a ruleset will require. Every job name also needs a Subject: an empty segment such as
`/ Lint` is reported.

The Subject and Check segments are written, not derived, so their casing is a review matter: capitalize the Subject's
words and keep display forms, and write the Check in sentence case. Telling a proper noun from an ordinary word needs
judgment that a check cannot make. A job in a callable workflow is not judged here; it is bare ([GHA-13](#gha-13)).

**Correct:**

```yaml
name: Validate Code
jobs:
  api_tests:
    name: API / Tests
  openapi_codegen:
    name: OpenAPI / Codegen drift
  required:
    name: Validate Code / Required   # the context the ruleset requires
```

**Incorrect:**

```yaml
name: Validate Code
jobs:
  api_tests:
    name: Validate Code / API / Tests   # shown as Validate Code / Validate Code / API / Tests
  openapi_codegen:
    name: / Codegen drift               # no subject
  required:
    name: Required                      # required by the ruleset, so it must be unique across the repository
```

Checked by: conftest · Severity: warning · Since: 0.1.0 · Formerly: platform CI-17

### GHA-13

**A job in a callable workflow has a bare name.**

GitHub prefixes a called job's context with the caller's job name. A called job named with its own
`<Workflow> / ...` prefix therefore reports as `Validate Code / Migrations / Reusable Validate Migrations / Lint`,
which repeats itself. A job in any callable workflow, which is any workflow with a `workflow_call` trigger, is named
with a bare Check or Subject and contains no ` / `. That includes a workflow that is also an entry point
(`workflow_call` plus `workflow_dispatch`): when it is dispatched directly it reports the bare names, and when it is
called they are prefixed by the caller.

**Correct:**

```yaml
# reusable-validate-migrations.yml
on:
  workflow_call:
jobs:
  lint:
    name: Lint
```

**Incorrect:**

```yaml
# reusable-validate-migrations.yml
on:
  workflow_call:
jobs:
  lint:
    name: Reusable Validate Migrations / Lint
```

Checked by: conftest · Severity: warning · Since: 0.1.0 · Formerly: platform CI-17

### GHA-14

**An aggregate job runs even when a dependency fails, and needs every other job.**

The aggregate is named `<Workflow> / Required`. It sets `if: always()` or `if: ${{ !cancelled() }}`, so it reports
even after a job it needs has failed, and its `needs:` lists every other job in the workflow, so a job cannot be added
without being judged. The check recognizes the aggregate by its name, compared case-insensitively, or by the job ID
`required`, and verifies those two structural properties. Whether the aggregate classifies each result correctly (see
[Aggregate semantics](#status-and-required-checks)) is a review matter.

**Correct:**

```yaml
jobs:
  lint:
    name: Repository / Lint
    # ...
  checks:
    name: Checks
    # ...
  required:
    name: Validate / Required
    if: always()                  # or: ${{ !cancelled() }}
    needs: [lint, checks]
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Fail unless every job succeeded
        env:
          NEEDS: ${{ toJSON(needs) }}
        run: |
          echo "$NEEDS" | jq -e 'to_entries | all(.value.result == "success")' > /dev/null
```

**Incorrect:**

```yaml
  required:
    name: Validate / Required
    needs: [lint]                 # checks is not judged
    if: ${{ !contains(needs.*.result, 'failure') }}   # skipped after a failure, so the check never reports
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### GHA-15

**Every required status check is a context exactly one job emits.**

A ruleset that requires a context no job emits parks every pull request on "Expected" indefinitely, and only an
administrator can recover by editing the ruleset. A context that two jobs emit is as bad: the ruleset cannot tell
them apart, and GitHub may block the merge on either. This check reads each `required_status_checks` rule in every
`.github/rulesets/*.json` and resolves each `context` against the contexts the workflows emit:

- Every entry point emits its jobs' names, including a workflow that is also callable.
- A job that calls a reusable workflow in this repository emits `<caller job name> / <callee job name>` for each job
  of the callee, and a callee that calls another workflow resolves the same way, recursively.
- A job whose `uses:` points at a workflow in another repository cannot be resolved from this one, so contexts under
  that caller are not verified.
- Only checks that GitHub Actions reports are resolved: an entry with no `integration_id`, or with `integration_id`
  15368 (the GitHub Actions app). A check another app reports, such as a coverage service, is not a job in these
  workflows and is left alone.

A required context that no job emits, or that more than one job emits, is a finding. The check only has something to
compare when the repository commits its rulesets under `.github/rulesets/`; see [Scope](#scope).

**Correct:**

```json
{"type": "required_status_checks",
 "parameters": {"required_status_checks": [{"context": "Validate / Required"}]}}
```

with a job `name: Validate / Required` in `.github/workflows/validate.yml`.

**Incorrect:**

```json
{"type": "required_status_checks",
 "parameters": {"required_status_checks": [{"context": "CI / required"}]}}
```

after `ci.yml` was renamed to `validate.yml`, or with two workflows that both have a job named `Validate / Required`.

Checked by: conftest · Severity: warning · Since: 0.1.0 · Formerly: platform CI-19

### GHA-16

**A multi-job workflow is required only through its aggregate.**

If a ruleset requires individual jobs, every change to the workflow's job graph is also a ruleset change, which needs
an administrator and has to land at the same moment. Requiring only `<Workflow> / Required` moves that coupling inside
the workflow, where a pull request can change it. A matrix-expanded job name (anything built from
`${{ matrix.* }}`) is never a required context: adding a matrix entry would silently change the set of required
checks. A ruleset that requires one gets a GHA-16 finding: the job exists, and requiring it directly is the mistake.

A workflow with exactly one job is its own aggregate and may be required directly. The check reports once per
workflow, listing every job of it that a ruleset requires directly, and only has something to compare when the
repository commits its rulesets under `.github/rulesets/`.

**Correct:**

```json
"required_status_checks": [
  {"context": "Validate / Required"},
  {"context": "Validate Pull Request / Title"}
]
```

**Incorrect:**

```json
"required_status_checks": [
  {"context": "Repository / Lint"},
  {"context": "Checks"},
  {"context": "Console / Quality"}
]
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### GHA-17

**Every run step has a name.**

An unnamed `run:` step appears in the log as the first line of its script (`Run set -euo pipefail`), which says
nothing about what the step was doing. A `uses:` step without a name is labelled with the action reference, which is
usually enough; a name is still welcome there.

**Correct:**

```yaml
- name: Build the bundle
  run: task bundle:build
```

**Incorrect:**

```yaml
- run: task bundle:build
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### GHA-18

**A step name is an imperative verb phrase.**

A step name answers "what was it doing?", so it starts with a verb in the imperative and names its object:
`Install dependencies`, `Check generated files are current`, `Upload the bundle`. Noun phrases (`Dependencies`) and
gerunds (`Installing dependencies`) read inconsistently in a log that is scanned line by line. This is a review
matter: recognizing an imperative verb reliably needs a dictionary this repository does not ship yet.

**Correct:**

```yaml
- name: Verify the release checksums
```

**Incorrect:**

```yaml
- name: Checksums
- name: Verifying checksums
```

Checked by: review · Severity: warning · Since: 0.1.0

### GHA-19

**A tool is named only when the tool is the subject.**

Name the result, not the tool that produces it: `Check Python formatting`, not `Run ruff`. The tool changes; what the
step establishes does not. When the step acts *on* a tool, the tool is the subject and belongs in the name:
`Install conftest`, `Restore the Trivy database cache`. The same applies to job names: `Workflows`, not
`actionlint`. This is a review matter.

**Correct:**

```yaml
- name: Install uv
- name: Check workflow syntax
```

**Incorrect:**

```yaml
- name: Run actionlint
- name: pytest
```

Checked by: review · Severity: warning · Since: 0.1.0

## References

- [platform #2892: Organize GitHub Actions workflows by responsibility](https://github.com/musher-dev/platform/issues/2892)
- [EC-0002 Workflow files](workflow-files.md)
- [EC-0006 Units and renames](units-and-renames.md)
- [GitHub Docs: Troubleshooting required status checks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks)
- [GitHub Docs: Using jobs in a workflow](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/using-jobs-in-a-workflow)
