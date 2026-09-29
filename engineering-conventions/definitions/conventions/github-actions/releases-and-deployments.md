---
id: EC-0023
title: Releases and deployments
summary: >-
  A force push names the commit it replaces, release-please runs with a token
  whose events start workflows, the last jobs of a release, publish or deploy
  workflow cannot be skipped into a green run, and nothing that acts on
  production runs on a push to a branch.
status: draft
topic: github-actions
applies_to:
  paths:
    - .github/workflows/*.yml
    - .github/workflows/*.yaml
    - .github/actions/*/action.yml
    - .github/actions/*/action.yaml
created: 2026-09-28
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
implementations:
  - repo: musher-dev/platform
    check: CI-09
    mode: blocking
  - repo: musher-dev/platform
    check: CI-10
    mode: blocking
  - repo: musher-dev/platform
    check: DL-18
    mode: blocking
  - repo: musher-dev/platform
    check: DL-21
    mode: blocking
references:
  - title: "Git: git-push --force-with-lease"
    url: https://git-scm.com/docs/git-push#Documentation/git-push.txt---force-with-leaseltrefnamegtltexpectgt
  - title: "GitHub Docs: Triggering a workflow from a workflow"
    url: https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/triggering-a-workflow#triggering-a-workflow-from-a-workflow
  - title: "GitHub Docs: Status check functions"
    url: https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/evaluate-expressions-in-workflows-and-actions#status-check-functions
  - title: "release-please-action"
    url: https://github.com/googleapis/release-please-action
requirements:
  - id: GHA-46
    title: A force push leases on the commit it expects to replace
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.releases_and_deployments
    aliases: ["platform:CI-09"]
  - id: GHA-47
    title: release-please runs with a token other than the default GITHUB_TOKEN
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.releases_and_deployments
    aliases: ["platform:CI-10a"]
  - id: GHA-48
    title: The last jobs of a release, publish or deploy workflow run unless the run is cancelled
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.releases_and_deployments
    aliases: ["platform:DL-18"]
  - id: GHA-49
    title: A workflow that acts on production does not run on a push to a branch
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.releases_and_deployments
    aliases: ["platform:DL-21"]
---

# Releases and deployments

Release and deploy workflows fail differently from validation workflows. A validation failure is a red check on a
pull request; a release or deploy failure is often a green run that did not do what it reports. A push that
overwrote someone's commit, a release pull request whose checks never start, a deploy job that was skipped, a probe
that tested the previous release: each of these reads as success. These requirements close those four gaps.

## Scope

This convention covers every workflow under `.github/workflows/` and every composite action under `.github/actions/`.
GHA-48 applies to the workflows whose responsibility token ([EC-0002](workflow-files.md#gha-02)) is `release`,
`publish` or `deploy`, including reusable ones such as `reusable-deploy-api.yml`. GHA-49 applies to the workflows that
act on production: one whose filename has a `production` token, or with a job whose `environment` is `production`.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`), and every requirement is `proposed` at
severity `warning`. The requirements are adopted from checks in `musher-dev/platform`
([decision 0016](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)),
which keeps its own copies until it pins a release that carries these and retires them.

| Upstream check | Requirement | Difference |
| --- | --- | --- |
| platform `CI-09` | GHA-46 | The platform reports a bare `--force-with-lease` only when it pushes to a URL. Here every force push must name the commit it expects, and `--force`, `-f` and a `+` refspec are reported too. |
| platform `CI-10` (part a) | GHA-47 | The platform checks `release.yml` for `secrets.GITHUB_TOKEN`. Here every workflow and action is checked, and a missing `token` and `github.token` are reported too. |
| platform `DL-18` | GHA-48 | The platform checks jobs with the IDs `deploy` and `smoke_test` and accepts `always()`. Here the last jobs of every release, publish and deploy workflow are checked, and only `!cancelled()` passes. |
| platform `DL-21` | GHA-49 | The platform finds a production workflow by the production hosts it names. Here the filename or the `environment` says so, since hosts are not declared anywhere the check reads. |

## Requirements

### GHA-46

**A force push leases on the commit it expects to replace.**

`git push --force` replaces whatever the remote branch holds, including a commit someone pushed a second ago.
`--force-with-lease` is meant to prevent that, but its bare form compares the remote with the local remote-tracking
ref, and in CI that ref is either missing (a shallow checkout, a push to a URL rather than a named remote) or was
fetched by the same job moments before, so the lease protects nothing. With a missing ref git refuses every push as
`stale info`, which reads exactly like a lost race. The explicit form, `--force-with-lease=<branch>:<expected-sha>`,
is the only one git documents as working without a tracking ref: the push succeeds only if the branch is still at the
commit the job read.

The check reads each `git push` in a `run:` block and reports `--force`, `-f` (alone or combined, such as `-fu`),
`--force-with-lease` without `=<ref>:<expected>`, and a `+<refspec>`. A `git push` the step only shows its reader
is text, not a command: the body of a heredoc and a line that only runs `echo` or `printf` are not read.

**Correct:**

```yaml
- name: Move the release branch
  env:
    EXPECTED: ${{ steps.read.outputs.sha }}
  run: git push --force-with-lease="release:${EXPECTED}" origin HEAD:release
```

**Incorrect:**

```yaml
- run: git push --force origin HEAD:release
- run: git push --force-with-lease origin HEAD:release   # leases on a ref CI does not have
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CI-09

### GHA-47

**release-please runs with a token other than the default `GITHUB_TOKEN`.**

GitHub starts no workflow for an event raised with the default `GITHUB_TOKEN`. A release pull request opened with it
never runs its checks, so its required contexts never report and it can only merge by bypassing branch protection;
a tag or release created with it never starts the workflow that publishes the release. Mint a GitHub App installation
token (for example with `actions/create-github-app-token`, scoped to `contents` and `pull-requests`) and pass it as
`token`. The check reports a `googleapis/release-please-action` step with no `token`, or one that passes
`secrets.GITHUB_TOKEN` or `github.token`.

**Correct:**

```yaml
- name: Mint the release token
  id: app_token
  uses: actions/create-github-app-token@<sha>  # pinned as GHA-24 asks
  with:
    app-id: ${{ secrets.RELEASE_APP_ID }}
    private-key: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
- name: Open or update the release pull request
  uses: googleapis/release-please-action@<sha>  # pinned as GHA-24 asks
  with:
    token: ${{ steps.app_token.outputs.token }}
```

**Incorrect:**

```yaml
- uses: googleapis/release-please-action@<sha>  # pinned as GHA-24 asks
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CI-10

### GHA-48

**The last jobs of a release, publish or deploy workflow run unless the run is cancelled.**

A job with the default condition runs only if every job it needs succeeded, and a skip spreads: when any job upstream
is skipped (an optional check switched off by a variable, say), every job downstream of it is skipped too, even
through jobs that override the condition themselves. A skipped job is not a failure, so the run goes green, and a
deploy that deployed nothing or a publish that published nothing reports success. The last jobs of the workflow, the
ones no other job needs, therefore state their condition: `!cancelled()`, so they are evaluated whatever happened
upstream, combined with the results they actually depend on.

Only `!cancelled()` passes, not `always()`. `always()` also runs the job after someone cancels the run, and for a job
that deploys or publishes, a cancel has to stop it. This is stricter than the aggregate in
[GHA-14](jobs-and-steps.md#gha-14), which accepts either: an aggregate only reports, so running it after a cancel
does no harm. An aggregate in a release, publish or deploy workflow uses `!cancelled()`, which satisfies both.

A job that needs nothing is not checked: nothing upstream can skip it.

**Correct:**

```yaml
jobs:
  build:
    name: Build
  deploy:
    name: Deploy
    needs: [build, migrate]
    if: ${{ !cancelled() && needs.build.result == 'success' && needs.migrate.result != 'failure' }}
```

**Incorrect:**

```yaml
jobs:
  deploy:
    name: Deploy
    needs: [build, migrate]      # skipped, and green, whenever migrate is skipped
  smoke_test:
    name: Smoke Test
    needs: deploy
    if: always()                 # still runs after the run is cancelled
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform DL-18

### GHA-49

**A workflow that acts on production does not run on a push to a branch.**

A merge to the default branch does not release anything: production moves when a release is cut. A workflow that
deploys to, probes or reports on production and runs on `push` therefore acts on the previous release every time.
A deploy on push ships whatever was merged, bypassing the release; a probe on push reports on a build that does not
contain the merge that started it, so its green runs prove nothing about that merge and its red ones are blamed on
it. Run it from the release instead: a tag, `release: published`, a `workflow_call` from the deploy, a schedule or
`workflow_dispatch`.

Two `push` forms pass. A push limited to `tags` (with no `branches` or `branches-ignore`) is the release itself. A
push whose `paths` name only the workflow's own file re-runs it when it changes and claims nothing about the rest of
the tree. A deploy to staging on push is out of scope: it has no `production` token and no `production` environment.

**Correct:**

```yaml
# deploy-production-api.yml
on:
  push:
    tags: ["api-v*"]
  workflow_dispatch:
```

**Incorrect:**

```yaml
# verify-production.yml
on:
  push:
    branches: [main]   # probes the last release, not this merge
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform DL-21

## References

- [Git: git-push --force-with-lease](https://git-scm.com/docs/git-push#Documentation/git-push.txt---force-with-leaseltrefnamegtltexpectgt)
- [GitHub Docs: Triggering a workflow from a workflow](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/triggering-a-workflow#triggering-a-workflow-from-a-workflow)
- [GitHub Docs: Status check functions](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/evaluate-expressions-in-workflows-and-actions#status-check-functions)
- [release-please-action](https://github.com/googleapis/release-please-action)
- [EC-0003 Jobs and steps](jobs-and-steps.md)
