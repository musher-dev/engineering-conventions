---
id: EC-0005
title: Execution hygiene
summary: >-
  Workflows pin what they run, grant the least privilege they need, cannot
  hang, and pass the workflow linters.
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
    check: CI-06
    mode: blocking
references:
  - title: "GitHub Docs: Security hardening for GitHub Actions"
    url: https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions
  - title: zizmor audit rules
    url: https://docs.zizmor.sh/audits/
requirements:
  - id: GHA-24
    title: A third-party action is pinned to a full commit SHA
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.execution_hygiene
  - id: GHA-25
    title: A SHA pin carries the version it resolves to as a comment
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: review
  - id: GHA-26
    title: A workflow declares permissions at the workflow level
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.execution_hygiene
  - id: GHA-27
    title: Workflow-level permissions grant no write access; jobs widen them
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.execution_hygiene
  - id: GHA-28
    title: actions/checkout does not persist credentials
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.execution_hygiene
  - id: GHA-29
    title: Every job that runs steps sets timeout-minutes
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.execution_hygiene
  - id: GHA-30
    title: An entry point on pull_request or merge_group uses the standard concurrency group
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.execution_hygiene
  - id: GHA-31
    title: A workflow triggered only by workflow_call declares no concurrency
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.execution_hygiene
    aliases: ["platform:CI-06"]
  - id: GHA-32
    title: A workflow that emits a required check has no paths filter
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.execution_hygiene
  - id: GHA-33
    title: Workflows pass actionlint and zizmor at medium severity
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: delegated
      tool: actionlint, zizmor
      check: "actionlint; zizmor --min-severity medium --persona regular"
---

# Execution hygiene

A workflow runs third-party code with a token that can write to the repository. These requirements keep what runs
fixed, keep the token as narrow as the job allows, stop a stuck job from holding a pull request hostage, and keep
required checks reporting on every change. Each one closes a specific failure; the reason is stated with it.

## Scope

This convention covers every workflow under `.github/workflows/`, every action under `.github/actions/`, and the
required status checks in `.github/rulesets/*.json` (used to decide which workflows emit a required check). "Entry
point", "callable" and "reusable" are used as [EC-0002](workflow-files.md#scope) defines them.

## Status and authority

This convention is a **draft** owned by `musher-dev/platform` through issue
[#2892](https://github.com/musher-dev/platform/issues/2892), published here as proposed requirements until the single
handoff described in [decision 0002](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0002-authority-and-migration.md).

Every requirement here is `proposed` at severity `warning`.

| Platform check | Requirements | Mode |
| --- | --- | --- |
| `CI-06` | GHA-31 | blocking in `musher-dev/platform` |

## Requirements

### GHA-24

**A third-party action is pinned to a full commit SHA.**

A tag such as `@v4` is a mutable pointer: whoever controls the action's repository can move it, and every workflow
that trusts the tag runs the new code on its next run, with its token. A 40-character commit SHA cannot be moved. This
applies to every `uses:` that is not a local path (`./...`), in workflow steps, in composite-action steps and in
job-level calls to another repository's reusable workflow. A `docker://` image is pinned by its `@sha256:` digest.
Dependabot updates SHA pins and their version comments together.

**Correct:**

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
- uses: ./.github/actions/setup-tools
```

**Incorrect:**

```yaml
- uses: actions/checkout@v7
- uses: actions/checkout@main
- uses: actions/checkout@3d3c42e    # abbreviated SHAs are resolved like branch names
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### GHA-25

**A SHA pin carries the version it resolves to as a comment.**

A bare SHA tells a reviewer nothing: they cannot see whether an update is a patch or a major version, or whether the
pin is years old. A trailing `# vX.Y.Z` comment says what the SHA is, and Dependabot rewrites the comment when it
bumps the pin. Keep the comment exact: a comment that names a different version than the SHA is worse than none. This
is a review matter, because YAML parsers discard comments before a policy engine sees the document.

**Correct:**

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
```

**Incorrect:**

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
```

Checked by: review · Severity: warning · Since: 0.1.0

### GHA-26

**A workflow declares permissions at the workflow level.**

Without a `permissions:` block, the `GITHUB_TOKEN` gets the repository's or organization's default, which may be
read-write on every scope and can change without any edit to the workflow. Declaring permissions at the top of the
file fixes the ceiling in the file itself, where a reviewer sees it.

**Correct:**

```yaml
name: Validate
on:
  pull_request:
permissions:
  contents: read
```

**Incorrect:**

```yaml
name: Validate
on:
  pull_request:
jobs:
  # no permissions anywhere: the token gets the repository default
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### GHA-27

**Workflow-level permissions grant no write access; jobs widen them.**

The workflow level applies to every job, including jobs added later by someone who never read the block. Keep it at
the floor: `{}` (no permissions) or read scopes such as `contents: read` (enough to check out the repository). The
check rejects any `write` scope and `write-all` there. It also rejects `read-all`: it grants read access to every
scope, present and future, including ones such as `security-events` and `actions` that expose more than a job
usually needs, and a new scope GitHub adds is granted without anyone deciding to. A job that needs more declares its
own `permissions:`, which replaces the workflow-level set for that job only, so the widening sits next to the steps
that need it and is reviewed with them.

**Correct:**

```yaml
permissions: {}
jobs:
  title:
    name: Validate Pull Request / Title
    permissions:
      pull-requests: read
```

**Incorrect:**

```yaml
permissions:
  contents: write
  pull-requests: write
jobs:
  title:
    name: Validate Pull Request / Title
```

```yaml
permissions: read-all   # every read scope, including ones added later
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### GHA-28

**`actions/checkout` does not persist credentials.**

By default, `actions/checkout` writes the job's token into `.git/config` so later `git` commands can push. Every later
step, including third-party actions and anything that uploads the workspace as an artifact, can then read that token.
Set `persist-credentials: false`. A job that genuinely pushes passes a token to that one command instead.

**Correct:**

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
  with:
    persist-credentials: false
```

**Incorrect:**

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1  # v7.0.1
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### GHA-29

**Every job that runs steps sets `timeout-minutes`.**

The default timeout is 360 minutes. A hung job (a test waiting on a network call, an interactive prompt) holds its
runner, spends Actions minutes and leaves the aggregate, and so the pull request, pending for six hours. A timeout set
near the job's real duration turns a hang into a prompt failure. A job that only calls a reusable workflow
(`jobs.<id>.uses`) is exempt: GitHub does not accept `timeout-minutes` there, and the called workflow's jobs carry
their own.

**Correct:**

```yaml
jobs:
  checks:
    name: Checks
    runs-on: ubuntu-latest
    timeout-minutes: 10
```

**Incorrect:**

```yaml
jobs:
  checks:
    name: Checks
    runs-on: ubuntu-latest
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### GHA-30

**An entry point on `pull_request` or `merge_group` uses the standard concurrency group.**

This applies to every entry point triggered by `pull_request` or `merge_group`, except a `pull_request` trigger whose
`types` include none of `opened`, `synchronize` and `reopened` (for example `types: [closed]`): such a workflow does not
run on new commits, so there is no earlier run to supersede.

The standard group is `${{ github.workflow }}-${{ github.ref }}`: one run per workflow per ref. A new push to a pull
request then supersedes the run for the previous push instead of queuing behind it. Using one expression everywhere
means nobody has to reason about which workflows share a group. Set `cancel-in-progress` for pull requests only, so a
run on the default branch always completes:

**Correct:**

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

**Incorrect:**

```yaml
# no concurrency: every push to a pull request queues another full run
```

```yaml
concurrency:
  group: validate   # one group for every ref: a push to one pull request cancels another's run
```

The check requires the standard group as a prefix: the `group` starts with `${{ github.workflow }}-${{ github.ref }}`,
and a suffix that narrows it further is allowed. The `cancel-in-progress` choice is a review matter. A workflow that
runs only on `push` (a deploy, a release) is out of scope: it may group by commit on purpose so that no run is ever
cancelled. A workflow that also runs on `pull_request` or `merge_group` is checked like any other validation entry
point.

Checked by: conftest · Severity: warning · Since: 0.1.0

### GHA-31

**A workflow triggered only by `workflow_call` declares no concurrency.**

Inside a called workflow, `github.workflow` resolves to the *caller's* name. A concurrency group there therefore
lands in the caller's group, alongside every other reusable workflow the caller invokes, and they cancel one another.
Concurrency belongs to the entry point, which decides what supersedes what.

**Correct:**

```yaml
# reusable-validate-spelling.yml
on:
  workflow_call:
permissions:
  contents: read
jobs:
  # ...
```

**Incorrect:**

```yaml
# reusable-validate-spelling.yml
on:
  workflow_call:
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
```

Checked by: conftest · Severity: warning · Since: 0.1.0 · Formerly: platform CI-06

### GHA-32

**A workflow that emits a required check has no `paths` filter.**

When a workflow-level `paths` or `paths-ignore` filter excludes a change, the workflow does not run at all, so its
jobs never report. GitHub shows a required context that never reported as "Expected", and the pull request cannot
merge. Decide scope inside the workflow instead: a first job detects what changed, later jobs skip when their area did
not change, and the aggregate treats those planned skips as passing
([EC-0003](jobs-and-steps.md#status-and-required-checks)). A workflow emits a required check when one of its job names
is a `context` in `.github/rulesets/*.json`, so the check only has something to judge when the repository commits its
rulesets there. Without them it reports nothing, which is not evidence that no required workflow is filtered.

**Correct:**

```yaml
on:
  pull_request:
  merge_group:
jobs:
  detect:
    name: Detect changes
    # ...outputs which areas changed
  api_tests:
    name: API / Tests
    needs: detect
    if: needs.detect.outputs.api == 'true'
```

**Incorrect:**

```yaml
on:
  pull_request:
    paths: ["apps/api/**"]   # a docs-only pull request never reports Validate Code / Required
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### GHA-33

**Workflows pass actionlint and zizmor at medium severity.**

[actionlint](https://github.com/rhysd/actionlint) catches workflow errors the YAML schema cannot: bad expressions,
unknown contexts, shell errors in `run:` blocks through shellcheck. [zizmor](https://docs.zizmor.sh/) catches
security defects: template injection, dangerous triggers, credential persistence, over-broad permissions. Both are
maintained tools with far larger rule sets than this repository should reimplement, so this requirement delegates to
them rather than duplicating them in Rego. Run both in the repository's own validation:

```sh
actionlint
zizmor --min-severity medium --persona regular .github/
```

The conventions runner does not run these tools itself; a finding appears in the repository's own `validate`
workflow, not in `conventions check` output.

Checked by: actionlint, zizmor (delegated) · Severity: warning · Since: 0.1.0

## References

- [GitHub Docs: Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions)
- [GitHub Docs: Controlling permissions for GITHUB_TOKEN](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/controlling-permissions-for-github_token)
- [zizmor audit rules](https://docs.zizmor.sh/audits/)
- [actionlint](https://github.com/rhysd/actionlint)
- [EC-0003 Jobs and steps](jobs-and-steps.md)
