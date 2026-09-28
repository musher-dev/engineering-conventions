---
id: EC-0022
title: Runners and step outcomes
summary: >-
  A job runs on a pinned runner image that it fits, every failure reaches the
  run's result, and a job relies only on what exists: a build cache in a
  registry, the permissions its caller grants, a diff base it can fetch, and
  directories the repository holds.
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
    check: CI-13
    mode: blocking
  - repo: musher-dev/platform
    check: CI-21
    mode: blocking
  - repo: musher-dev/platform
    check: CI-22
    mode: blocking
  - repo: musher-dev/platform
    check: DL-09
    mode: blocking
  - repo: musher-dev/platform
    check: DL-10
    mode: blocking
  - repo: musher-dev/development-container
    check: PATH-02
    mode: blocking
references:
  - title: "GitHub Changelog: Ubuntu 26.04 is generally available, and ubuntu-latest migration"
    url: https://github.blog/changelog/2026-09-17-ubuntu-26-generally-available-and-latest-migration/
  - title: "GitHub Changelog: 1 vCPU Linux runner now generally available in GitHub Actions"
    url: https://github.blog/changelog/2026-01-22-1-vcpu-linux-runner-now-generally-available-in-github-actions/
  - title: "GitHub Docs: Reusing workflow configurations"
    url: https://docs.github.com/en/actions/sharing-automations/reusing-workflows
  - title: zizmor audit rules
    url: https://docs.zizmor.sh/audits/
requirements:
  - id: GHA-39
    title: A job runs on a pinned runner image, never a -latest label
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.runners_and_step_outcomes
    aliases: ["platform:CI-21"]
  - id: GHA-40
    title: A job on ubuntu-slim sets timeout-minutes of at most 15 and runs no Docker
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.runners_and_step_outcomes
    aliases: ["platform:CI-21"]
  - id: GHA-41
    title: No step or job swallows a failure
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.runners_and_step_outcomes
    aliases: ["platform:CI-13b"]
  - id: GHA-42
    title: A Docker build does not use the GitHub Actions cache backend
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.runners_and_step_outcomes
    aliases: ["platform:CI-22b"]
  - id: GHA-43
    title: A job that calls a local reusable workflow grants every permission the callee declares
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.runners_and_step_outcomes
    aliases: ["platform:DL-09"]
  - id: GHA-44
    title: dorny/paths-filter in a push-triggered workflow sets base
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.runners_and_step_outcomes
    aliases: ["platform:DL-10"]
  - id: GHA-45
    title: Every literal working-directory names a directory in the repository
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.runners_and_step_outcomes
    aliases: ["development-container:PATH-02a"]
---

# Runners and step outcomes

A job's result is only worth reading if the job ran on the machine it was proven on and every failure inside it
reached that result. These requirements pin the runner image, keep a job within the limits of the runner it picks,
refuse the shell idioms that turn a failure green, and catch four settings that fail only at run time: a build cache
that evicts every other cache, a caller that grants less than its callee needs, a path filter with no diff base, and a
working directory that does not exist.

## Scope

This convention covers every workflow under `.github/workflows/` and every composite action under `.github/actions/`.
"Entry point", "callable" and "reusable" are used as [EC-0002](workflow-files.md#scope) defines them.

Only what is written literally in the file is checked. An expression such as `${{ inputs.runner }}` or
`${{ matrix.experimental }}` is decided when the workflow runs, and is left alone; a `runs-on` of
`${{ matrix.<key> }}` is resolved to the matrix's literal values.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`), and every requirement is `proposed` at
severity `warning`. The requirements are adopted from checks in `musher-dev/platform` and
`musher-dev/development-container`
([decision 0016](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)),
which keep their own copies until they pin a release that carries these and retire them.

| Upstream check | Requirements | Difference |
| --- | --- | --- |
| platform `CI-21` | GHA-39, GHA-40 | The platform allows only `ubuntu-24.04` and `ubuntu-slim`. Here any label but a `-latest` one passes, so a repository may pin macOS, Windows, a larger runner or a self-hosted group. |
| platform `CI-13` (part b) | GHA-41 | The platform keeps its reviewed exceptions in a list in its checker. Here a reviewed exception is a waiver in `.repo/conventions.toml`, and `continue-on-error` set by an expression is not reported. |
| platform `CI-22` (part b) | GHA-42 | Parts (a) and (c), a single cache writer and a pruning job, name the platform's own workflows and stay there. |
| platform `DL-09` | GHA-43 | A caller that declares no permissions at all is left to GHA-26, where the platform reads it as granting none; a callee's `read-all` or `write-all` is compared too. |
| platform `DL-10` | GHA-44 | The platform checks one workflow, and also requires a deep checkout; here every push-triggered workflow is checked, for `base` only. |
| development-container `PATH-02` | GHA-45 | The workflow half. The Dependabot half belongs to the repository-layout conventions. |

## Requirements

### GHA-39

**A job runs on a pinned runner image, never a `-latest` label.**

`ubuntu-latest`, `macos-latest` and `windows-latest` are labels GitHub moves to a new image on its own schedule. When
it moves one, every job on it gets a new operating system, new preinstalled tools and new defaults on the same day,
with no change in the repository to review or revert. `ubuntu-latest` moves from Ubuntu 24.04 to 26.04 between
2026-10-19 and 2026-11-19. Name the image the job was proven on, and moving to the next one becomes a pull request that
CI checks.

Any other label passes: a versioned image (`ubuntu-24.04`, `ubuntu-slim`, `macos-15`, `windows-2025`), a larger runner,
a self-hosted runner or a runner group. A job that calls a reusable workflow chooses no runner and is not checked.

**Correct:**

```yaml
jobs:
  lint:
    name: Lint
    runs-on: ubuntu-24.04
  tests:
    name: Tests
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-24.04, macos-15]
```

**Incorrect:**

```yaml
jobs:
  lint:
    name: Lint
    runs-on: ubuntu-latest
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CI-21

### GHA-40

**A job on `ubuntu-slim` sets `timeout-minutes` of at most 15 and runs no Docker.**

`ubuntu-slim` is a single-vCPU runner that runs the job in a container. It suits short orchestration jobs (detecting
changes, an aggregate, a comment on a pull request) and costs less than the standard runner, but it has two hard
limits. GitHub stops a job on it after 15 minutes, whatever `timeout-minutes` says, so a larger timeout promises time
the job does not have. And it has no Docker daemon, so a job container, a service container, a `docker/*` action, a
`docker://` step or a `docker` command fails on it. A job that needs either runs on `ubuntu-24.04`.

**Correct:**

```yaml
jobs:
  required:
    name: Validate / Required
    runs-on: ubuntu-slim
    timeout-minutes: 5
```

**Incorrect:**

```yaml
jobs:
  image:
    name: Image
    runs-on: ubuntu-slim
    timeout-minutes: 30            # stopped at 15 anyway
    services:
      db:
        image: postgres            # no Docker on ubuntu-slim
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CI-21

### GHA-41

**No step or job swallows a failure.**

A check either blocks or it does not exist. `task test || true` is a test step that cannot fail: it reports success
whether the tests passed, failed or never ran, and the pull request merges on a green run that proved nothing. The
same goes for `|| :`, `set +e` and `continue-on-error: true` on a step or a job. The check reads `run:` blocks in
workflows and composite actions, one command line at a time, ignoring comment lines.

When a command's failure really is expected, test for it: capture the exit code and decide, so the step still fails
on the outcomes that matter. When nothing a result depends on is lost (deleting a file that may not exist, printing
diagnostics on a path that already fails), say so in a [waiver](../adoption/conventions-declaration.md) with the
reason.

**Correct:**

```yaml
- name: Check for drift
  run: |
    if ! diff -u expected actual; then
      echo "::error::generated files are stale; run task generate"
      exit 1
    fi
- name: Remove the stale lock if present
  run: rm -f .lock
```

**Incorrect:**

```yaml
- name: Run the tests
  run: task test || true
- name: Mutation tests
  run: task mutants
  continue-on-error: true
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CI-13

### GHA-42

**A Docker build does not use the GitHub Actions cache backend.**

The `type=gha` cache backend stores Docker layers in the repository's Actions cache, which holds 10 GB and evicts the
least recently used entry when full. Layer caches are large, so a few builds push every dependency cache out and every
other job slows down. Keep the layer cache in a registry (`type=registry`, for example a `-buildcache` tag beside the
image) instead. The check reads `cache-from` and `cache-to` on any step, bake's `set` overrides and `--cache-from` or
`--cache-to` in a `run:` block. Who may write a cache, and whether a pull request can poison it, is zizmor's
[`cache-poisoning`](https://docs.zizmor.sh/audits/#cache-poisoning) audit under GHA-33.

**Correct:**

```yaml
- uses: docker/build-push-action@<sha>  # pinned as GHA-24 asks
  with:
    cache-from: type=registry,ref=ghcr.io/example/api:buildcache
```

**Incorrect:**

```yaml
- uses: docker/build-push-action@<sha>  # pinned as GHA-24 asks
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CI-22

### GHA-43

**A job that calls a local reusable workflow grants every permission the callee declares.**

A called workflow's token can hold at most what the calling job grants. When the callee asks for more in a job's
`permissions:`, GitHub refuses to start the run; when it asks for more at its workflow level, GitHub quietly cuts the
grant down and the called job fails at its first API call. Both surface only when the workflow runs, and GitHub
reports one such error per attempt. The check compares each calling job's permissions (its own, else the workflow's)
with the highest level the callee asks for on each scope, anywhere in the file: `write` covers `read`, `read` covers
`none`, and `read-all` and `write-all` cover every scope. Only callees in the same repository (`uses:
./.github/workflows/...`) are checked; another repository's workflow is not in the files the check reads.

**Correct:**

```yaml
# deploy.yml
jobs:
  deploy:
    name: Deploy
    uses: ./.github/workflows/reusable-deploy.yml
    permissions:
      contents: read
      deployments: write
      id-token: write
```

**Incorrect:**

```yaml
# deploy.yml; reusable-deploy.yml's job asks for deployments: write
permissions:
  contents: read
jobs:
  deploy:
    name: Deploy
    uses: ./.github/workflows/reusable-deploy.yml
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform DL-09

### GHA-44

**`dorny/paths-filter` in a push-triggered workflow sets `base`.**

On a `push` event the action diffs against `github.event.before`, the commit the branch pointed at before the push,
and fetches it itself. A shallow, credential-free checkout (the kind GHA-28 asks for) cannot, and the job fails before
it decides anything, so nothing downstream runs. Setting `base` explicitly (for example to the default branch) gives
the action a ref it can name and makes the comparison a choice that a reviewer can see. Check out enough history
(`fetch-depth`) for the base to be in the clone as well; the check requires `base`, and the depth is a review matter.

**Correct:**

```yaml
on:
  push:
    branches: [main]
jobs:
  detect:
    steps:
      - uses: dorny/paths-filter@<sha>  # pinned as GHA-24 asks
        with:
          base: ${{ github.event.repository.default_branch }}
          filters: .github/filters.yml
```

**Incorrect:**

```yaml
on:
  push:
    branches: [main]
jobs:
  detect:
    steps:
      - uses: dorny/paths-filter@<sha>  # pinned as GHA-24 asks
        with:
          filters: .github/filters.yml
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform DL-10

### GHA-45

**Every literal `working-directory` names a directory in the repository.**

A `working-directory` on a step, in a job's `defaults.run` or in the workflow's `defaults.run` that names a missing
directory fails the step with a message about the shell, not the path. It usually means a directory was renamed and
the workflow was not. The check compares each literal, relative value with the directories that hold the repository's
files. An expression, a variable (`$RUNNER_TEMP`), an absolute path and a path outside the workspace are not checked,
and neither is a workflow that checks the repository out into a subdirectory (`actions/checkout` with `path:`).

**Correct:**

```yaml
defaults:
  run:
    working-directory: apps/api     # the repository has apps/api/
```

**Incorrect:**

```yaml
defaults:
  run:
    working-directory: services/api # renamed to apps/api
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container PATH-02

## References

- [GitHub Changelog: Ubuntu 26.04 is generally available, and ubuntu-latest migration](https://github.blog/changelog/2026-09-17-ubuntu-26-generally-available-and-latest-migration/)
- [GitHub Changelog: 1 vCPU Linux runner now generally available in GitHub Actions](https://github.blog/changelog/2026-01-22-1-vcpu-linux-runner-now-generally-available-in-github-actions/)
- [GitHub Docs: Reusing workflow configurations](https://docs.github.com/en/actions/sharing-automations/reusing-workflows)
- [zizmor audit rules](https://docs.zizmor.sh/audits/)
- [EC-0005 Execution hygiene](execution-hygiene.md)
