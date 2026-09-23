---
id: EC-0006
title: Units and renames
summary: >-
  Choose the right unit of automation before naming it, and treat every name
  another file or ruleset refers to as an interface.
status: draft
topic: github-actions
applies_to:
  paths:
    - .github/workflows/*.yml
    - .github/workflows/*.yaml
    - .github/actions/**
    - .github/rulesets/*.json
created: 2026-09-23
owners:
  - "@justinmerrell"
authority:
  repo: musher-dev/platform
  ref: https://github.com/musher-dev/platform/issues/2892
migration: proposed
references:
  - title: "GitHub Docs: Reusing workflows"
    url: https://docs.github.com/en/actions/sharing-automations/reusing-workflows
  - title: "GitHub Docs: Creating a composite action"
    url: https://docs.github.com/en/actions/sharing-automations/creating-actions/creating-a-composite-action
requirements:
  - id: GHA-34
    title: A new workflow, job, action or reusable workflow is chosen by the unit criteria
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: review
  - id: GHA-35
    title: Validation is split into validate workflows by what they judge
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: review
  - id: GHA-36
    title: A rename updates every reference to the renamed identity in the same change
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: review
  - id: GHA-37
    title: A name states the responsibility, result or capability, not the trigger or tool
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: review
---

# Units and renames

Most naming problems start one step earlier, as a unit problem: a job that should have been a step, a workflow that
should have been a job, an action that exists because two workflows were copied. This convention says how to choose
the unit before naming it, how validation is divided into workflows, and how to change a name that other files and
rulesets depend on without breaking them.

The governing rule, for every unit: **name workflows after the responsibility they own, jobs after the result they
produce, and actions after the capability they provide.**

## Scope

This convention covers decisions about the automation in `.github/`: when to add a workflow, a job, a composite
action or a reusable workflow; how `validate` workflows are split; and how renames are carried out. All four
requirements are review matters. They describe judgment that a policy engine cannot make from the files alone.

## Status and authority

This convention is a **draft** owned by `musher-dev/platform` through issue
[#2892](https://github.com/musher-dev/platform/issues/2892), published here as proposed requirements until the single
handoff described in [decision 0002](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0002-authority-and-migration.md).
No platform check implements these
requirements; they are applied in review.

## Requirements

### GHA-34

**A new workflow, job, action or reusable workflow is chosen by the unit criteria.**

Each unit exists for one reason. Pick the unit whose reason applies, then name it for that reason.

| If the new automation... | Make it a | Because |
| --- | --- | --- |
| has a different lifecycle: a different trigger, schedule or event set from everything that exists | **workflow** | Triggers are per workflow; a job cannot have its own |
| crosses a trust or permission boundary: needs secrets, write access or an environment the others must not have | **workflow** (or at least a separate job with its own `permissions:`) | Isolation is cheapest at the workflow boundary, where triggers and default permissions are set |
| is an independent operation someone would re-run, cancel or read on its own | **workflow** | A workflow is the unit of re-run and of history in the Actions tab |
| contributes to the same validation result as existing jobs | **job** in that workflow | A job is an independently reported unit of work; the aggregate combines them |
| repeats steps that already appear in another job | **composite action** | An action is a reusable capability; copying steps is how drift starts |
| repeats a whole job graph (jobs, needs, matrix) used by several workflows | **reusable workflow** (`reusable-*`) | Only a workflow can package more than one job |
| is a project command a developer also runs locally | **Taskfile task**, called from a step | Workflows own GitHub orchestration; Taskfiles own project commands |

A new workflow means a distinct responsibility. A new job means an independently reported unit of work. A new action
means a reusable capability. If none of those is true, the change is a step in something that exists.

**Correct:**

```text
Adding shellcheck to the lint job: a step (same result, same lifecycle).
Adding a weekly mutation-testing run: a workflow, audit-api-mutants.yml (new schedule, never gates a merge).
Three jobs install the same toolchain: a composite action, setup-tools.
```

**Incorrect:**

```text
A workflow per linter (validate-shellcheck.yml, validate-yamllint.yml): same lifecycle, same result.
A composite action used by one job: nothing is reused yet.
A job per step: every step becomes a check context, and the aggregate grows with no new information.
```

Checked by: review · Severity: warning · Since: 0.1.0

### GHA-35

**Validation is split into validate workflows by what they judge.**

Every `validate-*` workflow decides whether a change may merge, so the split between them is by *what is judged*, not
by tool, speed or history:

| Workflow | Judges | Typical subjects |
| --- | --- | --- |
| `validate-code.yml` | The product: code that builds, tests or ships | apps, packages, migrations, generated clients, images |
| `validate-repository.yml` | The repository's own files outside the product | documentation, configuration, policies, spelling, rulesets |
| `validate-workflows.yml` | The automation itself | workflow syntax and security, naming conventions |
| `validate-pull-request.yml` | The pull request, not its files | title, description, labels |

A small repository needs one `validate.yml` and expresses the same split in its Subject segments (`Repository / Lint`,
`Workflows`, shown as `Validate / Repository / Lint` and `Validate / Workflows`). Split into separate workflows when the
parts need different triggers or permissions (`validate-pull-request.yml` needs `pull_request` edit events that the
others do not), or when one workflow's job graph has grown too large to read. A check lives in exactly one validate
workflow; the same build running in two is a sign the split is by history rather than by subject.

**Correct:**

```text
validate.yml               jobs: Repository / Lint, Checks, Validate / Required
validate-pull-request.yml  jobs: Validate Pull Request / Title
```

**Incorrect:**

```text
ci.yml     jobs: lint, test, shellcheck-docs
gates.yml  jobs: shellcheck, docs-build        # docs built twice, shellcheck split across both
```

Checked by: review · Severity: warning · Since: 0.1.0

### GHA-36

**A rename updates every reference to the renamed identity in the same change.**

Every name in `.github/` that another file, a ruleset or a person refers to is an interface. Required-check names are
the most important of them: renaming a required job without changing the ruleset leaves every pull request waiting on
a context that never arrives. Before renaming, find every consumer of the name:

| Renamed | Breaks | Update |
| --- | --- | --- |
| Workflow filename | Callers' `uses: ./.github/workflows/<file>`, status badges, scripts and docs that link the file, `gh workflow run <file>` | Every caller and link in the same change |
| Workflow `name:` | `on.workflow_run.workflows` in other workflows (fails silently), the prefix GitHub shows before every job, and the name each required-check job leads with | `workflow_run` triggers and the required-check job names; then the rulesets, as for job names |
| Job ID | `needs:` lists, `needs.<id>.outputs` expressions, the aggregate's `needs:` | Every reference in the same workflow |
| Job `name:` | Required contexts in rulesets and branch protection, saved searches, dashboards | The ruleset, with the ordering below |
| Action directory | `uses: ./.github/actions/<dir>` in every workflow and action | Every `uses:` in the same change |
| Step ID | `steps.<id>.outputs` and `steps.<id>.outcome` expressions | Every reference in the same job |

**Preserve the existing protection until the replacement check is emitted.** A ruleset change is applied by an
administrator, separately from the pull request. The safe order is:

1. Merge the rename, keeping the old required context satisfied (for example, by keeping the old aggregate job name
   alongside the new one, or by having an administrator add the new context before removing the old).
2. Confirm on the default branch that the new context is reported.
3. Update the ruleset to require the new context and drop the old one.
4. Remove the temporary old name.

Never leave a window where the ruleset requires nothing, or requires a context nothing emits.

**Two passes.** Migrating an existing repository to these conventions is two separate changes:

1. **Names first, behavior unchanged.** Rename files, `name:`s, job names, IDs and action directories. The job graph,
   triggers and steps stay as they were, so the diff can be checked mechanically: every run still does what it did.
2. **Boundaries second.** Move jobs between workflows, merge duplicated aggregates, extract actions. These change
   behavior and are reviewed as such, with the new names already in place.

Mixing the two hides a behavior change inside a rename that a reviewer skims.

**Correct:**

```text
PR 1: ci.yml -> validate-code.yml; name: Validate Code; aggregate renamed to "Validate Code / Required";
      ruleset updated by an admin after it reports on main.
PR 2: move shellcheck from validate-code.yml to validate-repository.yml.
```

**Incorrect:**

```text
One PR renames ci.yml, moves six jobs, and changes the required context; the ruleset still requires "CI / required".
```

Checked by: review · Severity: warning · Since: 0.1.0

### GHA-37

**A name states the responsibility, result or capability, not the trigger or tool.**

Triggers, tools and execution order are implementation. They change while the purpose stays the same, and a name tied
to them has to change too, breaking every reference in GHA-36's table. The same test applies at every level:

| Unit | Name it after | Not after | Correct | Incorrect |
| --- | --- | --- | --- | --- |
| Workflow | The responsibility it owns | Its trigger or schedule | `audit-api-mutants.yml` | `nightly.yml` |
| Job | The result it produces | The tool it runs, or its order | `Workflows` | `actionlint`, `Step 2` |
| Action | The capability it provides | The caller that first needed it | `setup-tools` | `validate-prep` |
| Step | What it does | (tool only when it is the subject) | `Check workflow syntax` | `Run actionlint` |

**Correct:**

```text
maintain-trivy-cache.yml         # the responsibility: keeping a cache current
API / Tests                      # the result
```

**Incorrect:**

```text
scheduled-trivy.yml              # a schedule and a tool
API / pytest                     # a tool
build-and-push                   # an execution order, and push is really a promotion
```

Checked by: review · Severity: warning · Since: 0.1.0

## References

- [platform #2892: Organize GitHub Actions workflows by responsibility](https://github.com/musher-dev/platform/issues/2892)
- [EC-0002 Workflow files](workflow-files.md)
- [EC-0003 Jobs and steps](jobs-and-steps.md)
- [EC-0004 Composite actions](composite-actions.md)
- [GitHub Docs: Reusing workflows](https://docs.github.com/en/actions/sharing-automations/reusing-workflows)
- [GitHub Docs: Creating a composite action](https://docs.github.com/en/actions/sharing-automations/creating-actions/creating-a-composite-action)
