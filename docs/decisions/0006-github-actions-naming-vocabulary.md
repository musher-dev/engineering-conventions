---
title: GitHub Actions units are named for responsibility, result and capability, from closed token sets
date: 2026-09-23
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0006 — GitHub Actions naming vocabulary

## Context

Before platform issue [#2892](https://github.com/musher-dev/platform/issues/2892), the platform's 44 workflows mixed
suffixes (`-validation`, `-validate`, `-lint`, `-drift`, `-scheduled`), display names disagreed with filenames, and
"release" meant three different things. A job named `build-and-push` actually promoted an image. Other repositories
used `ci.yml` with a `CI / required` context, or `validate.yaml` with bare job names. Names described triggers
(`nightly`), tools (`trivy`) and execution order (`build-and-push`) rather than purpose, so they changed whenever the
implementation did, and each change broke a ruleset or a `workflow_run` trigger somewhere.

Issue #2892 settled a grammar for the platform, enforced by its checks CI-14 to CI-19. This decision records the
vocabulary this repository publishes, which is derived from those checks rather than a pure mirror of them, and why it
differs in the few places it does. The differences listed in each convention's Status section are proposals the
platform adopts at the handoff ([decision 0002](0002-authority-and-migration.md)).

## Decision

**Name workflows after the responsibility they own, jobs after the result they produce, and actions after the
capability they provide.** Keep triggers, tools and execution order out of names. The requirements are GHA-01 to
GHA-38 in [EC-0002](../../engineering-conventions/definitions/conventions/github-actions/workflow-files.md) to
[EC-0006](../../engineering-conventions/definitions/conventions/github-actions/units-and-renames.md).

**Closed token sets.**

| Set | Tokens | Where |
| --- | --- | --- |
| Responsibility | `validate`, `release`, `publish`, `deploy`, `verify`, `monitor`, `audit`, `maintain`, `repository` | first token of an entry-point workflow |
| Capability | `build`, `promote`, `check` | after `reusable-` only |
| Action | `setup`, `install`, `authenticate`, `check` | first token of an action directory |

The choices within them:

- **Responsibility first.** The first thing a reader of a check context or an Actions-tab row needs is what kind of
  outcome the workflow owns: may this merge, did this ship, is this still true. Putting the responsibility first also
  groups the directory listing by kind.
- **`maintain`, not `maintenance`.** Every other token names what the workflow does; `maintenance` names an activity.
  `maintain` keeps the set parallel and is shorter in every derived name (`Maintain Trivy Cache`). #2892 made the same
  choice; `maintenance` is listed as a banned alias so older names are caught.
- **`publish` is added.** #2892's set has no word for pushing a versioned artifact to a registry, so it was folded
  into `release` or `deploy`, the two words the drift had already overloaded. `release` now means versioning only (tags,
  changelogs, release pull requests), `publish` means pushing the artifact, and `deploy` means changing what an
  environment serves.
- **`build` is a capability only.** Building is a step of validating, publishing or deploying, never an outcome
  someone asks for by itself. As an entry-point token it invites `build-and-push.yml`, which hides the real
  responsibility.
- **`verify` is narrowed** to exercising a deployed environment. Checking a change before merge is `validate`;
  watching external state over time is `monitor`. The three words were used interchangeably before.
- **`check` is reusable-only and action-only.** A check confirms one precondition for something else. It is a useful
  word for a reusable workflow or action (`check-deploy-secrets`) and a misleading one for an entry point, where it
  would compete with `validate`.
- **`repository` is a noun.** It names workflows that act on the collaboration surface: intake, labels, CODEOWNERS
  notices. Because one token is a noun, the slot is called the *responsibility* token, not the verb, and nothing in
  the grammar requires a verb.

**The display name is the Title-Cased filename.** A workflow's `name:` is derived from its filename stem with a
shared table of display forms (`api` → `API`, `devcontainer` → `Dev Container`). One alternative was to encode the
hierarchy in the display name (`Validate / Contracts` for `validate-contracts.yml`). It was rejected: GitHub shows a
job as `<Workflow> / <Job>`, and job names use the same separator, so a slash in the workflow name makes that
ambiguous (`Validate / Contracts / Schema` could be the job `Schema` in a workflow `Validate / Contracts`, or the job
`Contracts / Schema` in a workflow `Validate`), and the mapping from name to file would need a rule of its own.

**Job names follow platform ADR 0193.** An entry-point job is named `<Subject>[ / <Check>]`, and only a job that emits
a required status check leads with its workflow's name (`Validate / Required`, `Validate Pull Request / Title`). This
is the grammar platform ADR 0193 adopted, merged in platform #2897, and these conventions follow it for two reasons.
GitHub already shows the workflow's name before every job in the checks list, so a job that repeats it reads
`Validate Code / Validate Code / API / Tests`. A ruleset, on the other hand, matches a required check by the job name
alone, so a required context must be unique across the repository, and only the workflow's name makes
`Validate / Required` and `Validate Code / Required` two contexts rather than one. The original guidance for this
repository proposed qualifying every job name with its workflow's; the platform decision superseded it, and while the
platform owns workflow naming ([decision 0002](0002-authority-and-migration.md)) these conventions follow the authority
rather than diverge from it. Any change to the grammar is proposed to the platform, or made at the handoff.

**One extension per repository, not `.yml` everywhere.** GitHub accepts both. Requiring `.yml` would rename every
workflow in repositories that use `.yaml` for no gain in clarity. GHA-06 asks for consistency and lets each repository
keep the extension it already uses.

**Digits are allowed after the first character.** GHA-01 accepts a digit anywhere after the filename's first letter
(`validate-e2e.yml`, `deploy-s3.yml`), matching CI-14. An early draft of this vocabulary banned digits; it would have
rejected real subjects such as `e2e` for no gain.

**A scope is optional after a reusable token.** `reusable-build.yml` is valid, where CI-14 requires a scope after the
capability. A repository with one image to build has nothing to narrow, and a scope invented to satisfy the grammar
says nothing.

**Synonyms are rejected where they compete; schedules everywhere.** A synonym such as `lint` is rejected in the
responsibility slot, where it competes with `validate`, and accepted as a scope, where it only narrows one
(`reusable-validate-repository-lint.yml`). A schedule or trigger word (`nightly`, `weekly`) is rejected in every
position, because anywhere in a name it ties the name to when the workflow runs.

**A workflow can be an entry point and callable at once.** A workflow with `workflow_call` and another trigger keeps an
unprefixed name, because it is an entry point, and gives its jobs bare names, because a caller prefixes them. The
alternative, splitting it into a `reusable-` workflow and a thin dispatch wrapper, doubles the files for the common
"called by a release, also runnable by hand" case without making anything clearer.

## Consequences

### Positive

- A name says what a unit is for, and survives changes of trigger, schedule and tool.
- The same name appears in the file listing, the Actions tab, the check context and the ruleset.
- The token sets are small enough to learn, and the overlaps are resolved in writing rather than by judgment.

### Negative

- Every existing repository has renames to make, and renames of required checks need an administrator
  ([EC-0006](../../engineering-conventions/definitions/conventions/github-actions/units-and-renames.md) orders them safely).
- The vocabulary adds `publish` to #2892's set; the platform adopts it at the handoff.

### Neutral

- Two kinds of automation have no token yet: notification workflows (a Slack digest, say) and actions that mutate
  external state to keep it in sync. Both are tracked as follow-up. No token is invented for them here; a repository
  that needs one before it is published records a waiver.

## Enforcement

- GHA-01 to GHA-09, GHA-10 to GHA-17, GHA-20 to GHA-23 and GHA-38 are Conftest checks, each with fixture repositories that
  must produce its finding.
- GHA-18, GHA-19 and GHA-34 to GHA-37 are `review-only`: a reviewer checks step names for imperative verbs, tool
  names for being the subject, and new units against the criteria in EC-0006.
- The token sets are generated into `checks/data/index.json` from `terminology/global.yml`, so the Rego checks and the
  documents read one list.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Trigger-first names (`pr-*`, `nightly-*`, `on-push-*`) | Group by when a workflow runs | rejected: triggers change while the responsibility does not |
| Tool-first names (`trivy.yml`, `pytest.yml`) | Group by what runs | rejected: one responsibility uses many tools, and tools are replaced |
| Adopt #2892's set unchanged | No divergence from the platform | rejected: pushing an artifact to a registry would have no token, and would keep being filed under `release` or `deploy` |
| Responsibility-first with the changes above | This decision | **chosen** |
| Every job name qualified by its workflow's (`<Workflow> / <Subject>[ / <Check>]`) | A job's name says its workflow wherever it appears | rejected: GitHub already shows the workflow's name, so it reads twice; platform ADR 0193 settled on qualifying required-check jobs only |

## References

- [platform #2892: Organize GitHub Actions workflows by responsibility](https://github.com/musher-dev/platform/issues/2892)
- [GitHub Actions conventions](../../engineering-conventions/definitions/conventions/github-actions/README.md)
- [Decision 0002: Authority and migration](0002-authority-and-migration.md)
- [Decision 0007: Terminology model and committed generated artifacts](0007-terminology-and-generated-artifacts.md)
