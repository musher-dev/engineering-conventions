---
id: EC-0002
title: Workflow files
summary: >-
  A workflow file is named for the responsibility it owns, and its display
  name is derived from that filename, so every workflow has one identity.
status: draft
topic: github-actions
applies_to:
  paths:
    - .github/workflows/*.yml
    - .github/workflows/*.yaml
created: 2026-09-23
owners:
  - "@justinmerrell"
authority:
  repo: musher-dev/platform
  ref: https://github.com/musher-dev/platform/issues/2892
migration: proposed
implementations:
  - repo: musher-dev/platform
    check: CI-14
    mode: blocking
  - repo: musher-dev/platform
    check: CI-15
    mode: blocking
references:
  - title: "platform #2892: Organize GitHub Actions workflows by responsibility"
    url: https://github.com/musher-dev/platform/issues/2892
  - title: "GitHub Docs: Workflow syntax for GitHub Actions"
    url: https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions
requirements:
  - id: GHA-01
    title: A workflow filename follows [reusable-]<responsibility>[-<scope>].<ext>
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.workflow_files
    aliases: ["platform:CI-14"]
  - id: GHA-02
    title: An entry-point workflow starts with a responsibility token
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.workflow_files
    aliases: ["platform:CI-14"]
  - id: GHA-03
    title: The reusable- prefix marks exactly the workflows triggered only by workflow_call
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.workflow_files
    aliases: ["platform:CI-14"]
  - id: GHA-04
    title: A reusable workflow names a responsibility or capability token
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.workflow_files
    aliases: ["platform:CI-14"]
  - id: GHA-05
    title: A workflow filename carries no trigger, schedule, tool or synonym token
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.workflow_files
  - id: GHA-06
    title: A repository uses one workflow file extension
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.workflow_files
  - id: GHA-07
    title: A workflow's name is its filename stem in Title Case
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.workflow_files
    aliases: ["platform:CI-15"]
  - id: GHA-08
    title: Workflow names are unique within a repository
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.workflow_files
  - id: GHA-09
    title: A workflow_run trigger names a workflow that exists
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.workflow_files
---

# Workflow files

A workflow is named for the responsibility it owns. Its filename carries a responsibility token and, where the
repository has more than one workflow for that responsibility, a scope that narrows it. The workflow's `name:` is
derived from the filename, so the file, the Actions tab and every required-check context agree on one identity. The
filename says what the workflow is for; it does not say when it runs, which tool it calls, or what order its steps
happen in.

## Scope

This convention covers every file directly under `.github/workflows/` with a `.yml` or `.yaml` extension. Three words
describe a workflow by its triggers, and every GitHub Actions convention uses them in exactly this sense:

| Word | A workflow that | Consequence |
| --- | --- | --- |
| **Entry point** | has any trigger other than `workflow_call` (`pull_request`, `push`, `schedule`, `workflow_dispatch`, …) | GitHub starts it from an event, and its jobs report check contexts of their own |
| **Callable** | has a `workflow_call` trigger | Another workflow can call it; its jobs then report under the caller's job name |
| **Reusable** | has *only* a `workflow_call` trigger, and carries the `reusable-` prefix | Callable and never an entry point |

A workflow with `workflow_call` and another trigger (usually `workflow_dispatch`) is both an entry point and callable.
It needs no prefix, because it is an entry point, and its jobs have bare names ([GHA-13](jobs-and-steps.md#gha-13)),
because a caller prefixes them. See GHA-03.

It does not cover job and step names ([EC-0003](jobs-and-steps.md)), composite actions
([EC-0004](composite-actions.md)), or pinning and permissions ([EC-0005](execution-hygiene.md)).

## Status and authority

This convention is a **draft**. Workflow naming is owned by `musher-dev/platform`, where issue
[#2892](https://github.com/musher-dev/platform/issues/2892) introduced the grammar and its blocking checks. The
requirements here are derived from those checks and published as proposed requirements; this document becomes the
authority only through the single handoff described in
[decision 0002](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0002-authority-and-migration.md).
Until then there is one live authority, and it is the platform.

Every requirement here is `proposed` at severity `warning`. A finding is advice, not a failure.

| Platform check | Requirements | Mode |
| --- | --- | --- |
| `CI-14` | GHA-01, GHA-02, GHA-03, GHA-04 | blocking in `musher-dev/platform` |
| `CI-15` | GHA-07 | blocking in `musher-dev/platform` |

### Differences from platform CI-14..19

Where this convention and the platform's checks disagree, the difference is a **proposal ahead of the platform**. The
platform keeps its current behavior until the handoff, and adopts these differences as part of it.

| Difference | Platform today | Here |
| --- | --- | --- |
| `publish` token | CI-14 rejects `publish-*.yml` | `publish` is a responsibility token ([decision 0006](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0006-github-actions-naming-vocabulary.md)) |
| `.yaml` extension | CI-14 accepts `.yml` only | Either extension; GHA-06 asks for one per repository |
| Scope after a reusable token | CI-14 requires one: `reusable-build.yml` fails | Optional: `reusable-build.yml` passes GHA-01 |
| Display forms `ci`, `cli`, `dco`, `e2e`, `oci`, `uv` | CI-15 lacks them, so `validate-e2e.yml` must be named `Validate E2e` | Shipped, so `validate-e2e.yml` is named `Validate E2E` |
| A name whose filename must change | CI-15 judges the name against the current filename | GHA-07 waits until GHA-01 and GHA-05 accept the filename |

## Vocabulary

### Responsibility tokens

The first token of an entry-point workflow's filename is one of these. Each owns one kind of outcome, and the
"Not this" column is where the overlaps are resolved.

| Token | Owns | Not this |
| --- | --- | --- |
| `validate` | Deciding whether a change may merge. Runs against a change (pull request, merge queue, push to the default branch) and mutates nothing outside the run. | Not `verify`, which exercises a deployed environment. Not `audit`, which never gates a merge. Not `check`, which is a capability a responsibility uses, never a responsibility of its own. |
| `release` | Versioning: release pull requests, version bumps, changelogs, tags and GitHub Releases. Builds and ships nothing. | Not `publish`, which pushes the artifact a release names. Not `deploy`. |
| `publish` | Pushing a versioned artifact to a registry or distribution channel: a package, an image, release assets. | Not `release`, which decides the version. Not `deploy`: publishing an artifact changes nothing that is running. |
| `deploy` | Changing what a running environment serves. | Not `publish`. Not `verify`, which confirms the result afterward. |
| `verify` | Exercising a *deployed* environment to confirm it behaves: smoke tests and probes after a deploy. | Not `validate`, which judges a change before it merges. Not `monitor`, which watches for drift over time rather than confirming one deploy. |
| `monitor` | A scheduled, report-only comparison of something this repository depends on but does not own (external links, an upstream schema, a pinned version) against what the repository expects. | Not `audit`, which examines this repository's own contents. Not `maintain`: a monitor changes nothing. |
| `audit` | A scheduled or on-demand, report-only examination of this repository's own contents that is too slow or too noisy to gate a merge: mutation testing, full SAST sweeps, hotspot analysis. | Not `validate`: an audit never blocks a merge. Not `monitor`, which looks outward. |
| `maintain` | Changing state that is not the product: caches, vendored copies, generated mirrors. | Not `monitor`, which only reports. Not `release` or `deploy`, which change the product or what serves it. |
| `repository` | Automating the collaboration surface: issue intake, labels, project boards, CODEOWNERS notices. | Not `validate`: checking the repository's *files* is validation (`validate-repository.yml`). `repository-*` workflows act on the people-facing surface around the files. |

`repository` is a noun. The slot is therefore called the *responsibility* token, not the verb, and nothing in the
grammar depends on the token being a verb.

Four words are deliberately absent:

| Not a token | Why | Use |
| --- | --- | --- |
| `check` | A precondition another responsibility runs; it never owns an outcome by itself | `check` as a capability token (reusable workflows) or action token |
| `build` | Producing an artifact is a step inside `validate`, `publish` or `deploy`, not a reason to run | `build` as a capability token (reusable workflows) |
| `maintenance` | A noun for an activity; every other token names what the workflow does | `maintain` |
| `test`, `lint` | They name a tool category, and a merge decision usually needs more than one | `validate` |

**Not yet covered.** Two kinds of automation have no token yet: a workflow that only sends a notification (a Slack
digest of open pull requests, say), and an action that changes external state to keep it in sync with the repository.
Both are tracked as follow-up work. Until a token is published, a repository that needs one records a waiver for the
finding it gets rather than bending an existing token to fit.

### Capability tokens

A reusable workflow may instead be named for a capability it provides to a responsibility. These tokens are valid
**only** after `reusable-`; an entry point never starts with one.

| Token | Provides | Example |
| --- | --- | --- |
| `build` | Producing an artifact (an image, a bundle) without publishing or deploying it | `reusable-build-image.yml` |
| `promote` | Moving an already-built artifact from one channel or environment to the next | `reusable-promote-image.yml` |
| `check` | Confirming a precondition and failing clearly when it does not hold | `reusable-check-deploy-readiness.yml` |

### Scope order

The scope narrows the responsibility from broad to narrow, the way a path does: environment or tier before service,
service before component. `deploy-production-api.yml`, not `deploy-api-production.yml`. Files for one responsibility
and tier then sort together in a directory listing, and the derived display name reads left to right from the general
to the specific.

### Display forms

A workflow's `name:` is its filename stem split on `-`, each token capitalized, joined with single spaces. Tokens
whose conventional spelling is not a simple capital take their display form instead:

| Token | Display form |
| --- | --- |
| `api` | API |
| `ci` | CI (the token itself is banned as a responsibility by GHA-05; the form keeps suggested names readable) |
| `cli` | CLI |
| `codeowners` | CODEOWNERS |
| `dco` | DCO |
| `devcontainer` | Dev Container |
| `e2e` | E2E |
| `hq` | HQ |
| `oci` | OCI |
| `pr` | PR |
| `sast` | SAST |
| `uv` | uv |

`deploy-production-api` becomes `Deploy Production API`; `validate-devcontainer` becomes `Validate Dev Container`;
`reusable-build-image` becomes `Reusable Build Image`.

This is **derived Title Case**: mechanical, every token capitalized, no judgment and no list of minor words. It applies
to every name derived from a filename or a directory: a workflow's `name:` (GHA-07) and an action's `name:`
([GHA-22](composite-actions.md#gha-22)). It is not how a person writes the Subject of a job name, which is chosen
rather than derived; [EC-0003](jobs-and-steps.md#job-name-grammar) covers that.

**Extending the list.** A repository adds a display form for its own tokens in its
[conventions declaration](../adoption/conventions-declaration.md) under `vocabulary.display_forms`. A declaration can
only add forms: it can never redefine one this list ships, so a name derived in one repository reads the same in
every other. A form that more than one repository needs is proposed here with the *Propose a term* issue form, and
ships in a minor release.

## Requirements

### GHA-01

**A workflow filename follows `[reusable-]<responsibility>[-<scope>].<ext>`.**

The filename is lowercase ASCII letters and digits, with words separated by single hyphens. It starts with a letter;
digits may appear anywhere after that (`validate-e2e.yml`, `deploy-s3.yml`). The first word is a responsibility token,
or `reusable-` followed by a responsibility or capability token. Any further words are the scope, which is optional in
both forms: `reusable-build.yml` is as valid as `validate.yml`. The extension is `.yml` or `.yaml` (see GHA-06).
Underscores, uppercase letters, dots inside the stem and repeated hyphens are not part of the grammar: a filename is
read as a list of words, and the display name (GHA-07) is built from exactly those words.

**Correct:**

```text
.github/workflows/validate.yml
.github/workflows/validate-code.yml
.github/workflows/deploy-production-api.yml
.github/workflows/reusable-build-image.yml
```

**Incorrect:**

```text
.github/workflows/CI.yml              # uppercase, and ci is not a responsibility token
.github/workflows/deploy_staging.yml  # underscore separator
.github/workflows/build-and-push.yml  # starts with a capability token and chains steps
```

Checked by: conftest · Severity: warning · Since: 0.1.0 · Formerly: platform CI-14

### GHA-02

**An entry-point workflow starts with a responsibility token.**

An entry point is a workflow with any trigger other than `workflow_call`, including one that also has `workflow_call`
(see [Scope](#scope)). Its first filename token is one of `validate`, `release`, `publish`, `deploy`, `verify`,
`monitor`, `audit`, `maintain` or `repository`, so a reader who sees the file in a listing, a check context or a failure
notification knows what kind of outcome it owns before opening it.

**Correct:**

```text
validate-pull-request.yml
monitor-external-links.yml
repository-project-intake.yml
```

**Incorrect:**

```text
build.yml          # a capability, not a responsibility; name the outcome the build serves
security.yml       # a topic, not a responsibility; validate-* or audit-* depending on whether it gates
nightly.yml        # a schedule
```

Checked by: conftest · Severity: warning · Since: 0.1.0 · Formerly: platform CI-14

### GHA-03

**The `reusable-` prefix marks exactly the workflows triggered only by `workflow_call`.**

The prefix is a promise that the workflow is never an entry point: it never starts a run by itself, so it emits no
check context of its own and cannot be a required check. The promise has to hold in both directions. A prefixed
workflow with any other trigger breaks it, and an unprefixed `workflow_call`-only workflow hides the fact that it is
never an entry point until someone opens it.

A workflow that needs both `workflow_call` and another trigger, such as `workflow_dispatch`, is both an entry point
and callable. It is allowed as one file without the prefix, because it is an entry point, and its jobs have bare names
([GHA-13](jobs-and-steps.md#gha-13)), because it is callable. The platform's `deploy-production-*` and
`verify-production` workflows are built this way: a release calls them, and an operator can also dispatch them by
hand.

**Correct:**

```yaml
# .github/workflows/reusable-validate-spelling.yml
on:
  workflow_call:
```

```yaml
# .github/workflows/deploy-production-api.yml
on:
  workflow_call:       # a release calls it...
  workflow_dispatch:   # ...and an operator can start it: an entry point, so no prefix
```

**Incorrect:**

```yaml
# .github/workflows/reusable-validate-spelling.yml
on:
  workflow_call:
  workflow_dispatch:   # an entry point wearing the reusable- prefix
```

```yaml
# .github/workflows/validate-spelling.yml
on:
  workflow_call:       # callable only, but nothing in the filename says so
```

Checked by: conftest · Severity: warning · Since: 0.1.0 · Formerly: platform CI-14

### GHA-04

**A reusable workflow names a responsibility or capability token.**

After `reusable-`, the next token is a responsibility token or one of the capability tokens `build`, `promote` and
`check`. A reusable workflow often provides one step of a responsibility rather than a whole one: building the image a
deploy then promotes. Capability tokens name that step without pretending it is an outcome of its own.

**Correct:**

```text
reusable-validate-migrations.yml
reusable-build-image.yml
reusable-promote-image.yml
reusable-check-deploy-readiness.yml
```

**Incorrect:**

```text
reusable-docker.yml        # a tool
reusable-helpers.yml       # names nothing
reusable-push-image.yml    # push is not a token; publish (responsibility) or promote (capability)
```

Checked by: conftest · Severity: warning · Since: 0.1.0 · Formerly: platform CI-14

### GHA-05

**A workflow filename carries no trigger, schedule, tool or synonym token.**

Triggers, schedules and tools change while the responsibility stays the same. A workflow named `nightly.yml` must be
renamed when it moves to a weekly schedule, and every reference to it breaks, though it still does the same job. A
synonym for a responsibility token (`ci` for `validate`) splits one idea across two words and defeats a search for
either.

The two kinds of rejected token are rejected in different places:

- A **synonym** is rejected only in the **responsibility slot**: the first token, or the first token after
  `reusable-`. There it competes with the token it duplicates. In a scope or capability position it narrows a
  responsibility like any other word, so `reusable-validate-repository-lint.yml` passes: the responsibility is
  `validate`, and `lint` says which part of the repository's validation it provides.
- A **schedule or trigger** token is rejected **anywhere** in the filename, because in any position it ties the name to
  when the workflow runs.

| Kind | Rejected token | Use instead |
| --- | --- | --- |
| Synonym | `ci`, `checks`, `quality`, `lint`, `test`, `tests`, `gates` | `validate` |
| Synonym | `pr` | `validate` (as a responsibility; `PR` stays valid in a scope and in prose) |
| Synonym | `cd`, `rollout`, `ship` | `deploy` |
| Synonym | `maintenance`, `cleanup` | `maintain` |
| Synonym | `drift` | `monitor` |
| Synonym | `forensics` | `audit` |
| Schedule | `scheduled`, `nightly`, `cron`, `weekly`, `daily` | the responsibility the schedule serves: usually `audit`, `monitor` or `maintain` |

The generated list is `vocabulary.banned_identifier_tokens` in `checks/data/index.json`. A tool name has no list: in
the responsibility slot it fails GHA-02, and elsewhere it is a review matter
([GHA-37](units-and-renames.md#gha-37)).

**Correct:**

```text
validate-pull-request.yml
audit-api-mutants.yml
maintain-trivy-cache.yml
reusable-validate-repository-lint.yml   # lint narrows validate; it is not the responsibility
```

**Incorrect:**

```text
pr-lint.yml                     # pr in the responsibility slot
audit-api-mutants-nightly.yml   # a schedule, rejected in any position
maintenance-trivy-cache.yml     # a synonym for maintain in the responsibility slot
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### GHA-06

**A repository uses one workflow file extension.**

GitHub accepts both `.yml` and `.yaml`. A repository that mixes them makes every glob, script and reference guess which
one a given workflow uses. This requirement asks for one extension per repository and does not choose it: keep the
extension most of the existing workflows already use, so adopting the convention does not rename every file.
[Decision 0006](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0006-github-actions-naming-vocabulary.md)
records why.

**Correct:**

```text
.github/workflows/validate.yml
.github/workflows/release.yml
```

**Incorrect:**

```text
.github/workflows/validate.yml
.github/workflows/release.yaml
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### GHA-07

**A workflow's name is its filename stem in Title Case.**

The `name:` is derived, not chosen: split the stem on `-`, replace each token with its display form if it has one,
otherwise capitalize its first letter, and join the tokens with single spaces. A workflow then has one identity. The
Actions tab, the check-context prefix and the filename all say the same thing, and a reader who knows one can find the
others.

Every token is capitalized, short words included: `repository-add-to-project` becomes `Repository Add To Project`,
not `Repository Add to Project`. Editorial title case would need a list of minor words and would stop the name from
mapping back to the filename; the mechanical rule keeps the derivation reversible.

A reusable workflow follows the same rule. Its name appears in the Actions tab when a run is inspected, and the
prefix `Reusable` tells the reader what they are looking at.

**Filenames first, then names.** GHA-07 is not judged while GHA-01 or GHA-05 asks for a new filename: the name would
be derived from a stem that is about to change. Rename the file first; the next run reports the name it implies. The
same order holds for required-check job names ([GHA-12](jobs-and-steps.md#gha-12)) and action names
([GHA-22](composite-actions.md#gha-22)).

**Correct:**

```yaml
# .github/workflows/validate-code.yml
name: Validate Code
```

```yaml
# .github/workflows/deploy-production-api.yml
name: Deploy Production API
```

**Incorrect:**

```yaml
# .github/workflows/validate-code.yml
name: CI
```

```yaml
# .github/workflows/validate-code.yml
name: Validate / Code   # the slash belongs to job names; see EC-0003
```

Checked by: conftest · Severity: warning · Since: 0.1.0 · Formerly: platform CI-15

### GHA-08

**Workflow names are unique within a repository.**

A workflow's name is the prefix of every check context it emits and the value a `workflow_run` trigger matches on.
Two workflows with one name produce check contexts that cannot be told apart and a `workflow_run` trigger that fires
for either. GHA-07 makes this follow from unique filenames; the check exists for repositories that have not adopted
GHA-07 yet.

**Correct:**

```yaml
# validate-code.yml
name: Validate Code
# validate-repository.yml
name: Validate Repository
```

**Incorrect:**

```yaml
# validate-code.yml
name: Validate
# validate-repository.yml
name: Validate
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### GHA-09

**A `workflow_run` trigger names a workflow that exists.**

`on.workflow_run.workflows` matches workflow *names*, not filenames. When the upstream workflow is renamed, the
trigger does not fail; it silently never fires again. This check resolves every entry against the `name:` of the
workflows in the repository.

**Correct:**

```yaml
# verify-production.yml
on:
  workflow_run:
    workflows: [Deploy Production]   # deploy-production.yml has name: Deploy Production
    types: [completed]
```

**Incorrect:**

```yaml
on:
  workflow_run:
    workflows: [Release Deploy]      # the workflow was renamed; this never fires
    types: [completed]
```

Checked by: conftest · Severity: warning · Since: 0.1.0

## Rationale

A repository's workflows are read far more often from the outside than from the inside: as a row in the Actions tab,
a context on a pull request, a failure notification, a name in a ruleset. Naming them for the responsibility they own
makes each of those surfaces answer "what is this for?" without opening the file. Naming them for their trigger or
tool answers a question the reader did not ask, and changes whenever the implementation does.

The token set is small on purpose. Each token owns one kind of outcome, and the overlaps that caused the drift this
convention replaces are resolved in the table above rather than left to judgment.
[Decision 0006](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0006-github-actions-naming-vocabulary.md)
records the choices: why `maintain` rather than `maintenance`, why `publish` is separate from `release`, and why
`build` and `check` are capabilities rather than responsibilities.

## References

- [platform #2892: Organize GitHub Actions workflows by responsibility](https://github.com/musher-dev/platform/issues/2892)
- [Decision 0006: GitHub Actions naming vocabulary](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0006-github-actions-naming-vocabulary.md)
- [EC-0003 Jobs and steps](jobs-and-steps.md)
- [EC-0006 Units and renames](units-and-renames.md)
- [GitHub Docs: Workflow syntax for GitHub Actions](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions)
