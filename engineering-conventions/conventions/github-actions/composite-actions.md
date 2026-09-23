---
id: EC-0004
title: Composite actions
summary: >-
  A local action is named for the reusable capability it provides, and its
  metadata describes itself and every input.
status: draft
topic: github-actions
applies_to:
  paths:
    - .github/actions/**
created: 2026-09-23
owners:
  - "@justinmerrell"
authority:
  repo: musher-dev/platform
  ref: https://github.com/musher-dev/platform/issues/2892
migration: proposed
implementations:
  - repo: musher-dev/platform
    check: CI-18
    mode: blocking
references:
  - title: "platform #2892: Organize GitHub Actions workflows by responsibility"
    url: https://github.com/musher-dev/platform/issues/2892
  - title: "GitHub Docs: Metadata syntax for GitHub Actions"
    url: https://docs.github.com/en/actions/sharing-automations/creating-actions/metadata-syntax-for-github-actions
requirements:
  - id: GHA-20
    title: An action directory is <action-token>-<object>
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.composite_actions
    aliases: ["platform:CI-18"]
  - id: GHA-21
    title: An action's metadata is action.yml, one level below .github/actions
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.composite_actions
    aliases: ["platform:CI-18"]
  - id: GHA-22
    title: An action's name is its directory in Title Case
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.composite_actions
  - id: GHA-23
    title: An action and each of its inputs have a description
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.composite_actions
  - id: GHA-38
    title: Inputs and outputs of actions and reusable workflows are kebab-case
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.composite_actions
---

# Composite actions

A local action is named for the reusable capability it provides, not for the workflow that first needed it. Its
directory name is an action token followed by the object it acts on; its `name:` is that directory in Title Case; its
metadata describes the action and every input, because the metadata is the only documentation a caller sees; and its
inputs and outputs are kebab-case, as are a reusable workflow's.

## Scope

This convention covers every action under `.github/actions/`: composite actions, and JavaScript or Docker actions kept
in the repository. It does not cover third-party actions a workflow `uses:` (see [EC-0005](execution-hygiene.md)).
GHA-38 also covers the interface of every callable workflow under `.github/workflows/`: the `inputs`, `outputs` and
`secrets` of its `on.workflow_call` trigger.

## Status and authority

This convention is a **draft**. Action naming is owned by `musher-dev/platform`, where issue
[#2892](https://github.com/musher-dev/platform/issues/2892) introduced the grammar. The requirements here are derived
from the platform's checks and published as proposed requirements until the single handoff described in
[decision 0002](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0002-authority-and-migration.md).

Every requirement here is `proposed` at severity `warning`.

| Platform check | Requirements | Mode |
| --- | --- | --- |
| `CI-18` | GHA-20, GHA-21 | blocking in `musher-dev/platform` |

### Differences from platform CI-14..19

Where this convention and the platform's checks disagree, the difference is a **proposal ahead of the platform**. The
platform keeps its current behavior until the handoff, and adopts these differences as part of it.

| Difference | Platform today | Here |
| --- | --- | --- |
| `action.yaml` | CI-18 accepts `action.yml` or `action.yaml` | GHA-21 flags `action.yaml`: one spelling |
| Nested action directories | CI-18 inspects the first level under `.github/actions/` only | GHA-21 flags an action nested deeper |
| An action's `name:` | No platform check | GHA-22 derives it from the directory, as GHA-07 does for a workflow |
| Display forms `ci`, `cli`, `dco`, `e2e`, `oci`, `uv` | CI-15 lacks them | Shipped, so `install-repo-cli` derives `Install Repo CLI` |
| Kebab-case inputs and outputs | The platform rule states them, but no check enforces them | GHA-38 checks actions' `inputs` and `outputs` and callable workflows' `workflow_call` `inputs`, `outputs` and `secrets` |

## Division of labor

Three kinds of file automate a repository, and each owns a different thing:

| Unit | Owns | Example |
| --- | --- | --- |
| Workflow | GitHub orchestration: triggers, job graph, permissions, concurrency | `validate.yml` |
| Taskfile task | Project commands: the same command a developer runs locally | `task lint` |
| Composite action | Reusable GitHub-specific integration: runner setup, authentication, caching | `setup-tools` |

An action that wraps a project command belongs in the Taskfile instead: the command then runs the same way locally and
in CI, and the workflow step calls `task <name>`. An action earns its place when the steps are specific to the GitHub
runner (toolchain installation, cache keys, token exchange) and more than one job needs them.

## Action tokens

The first token of an action directory says what kind of capability the action provides.

| Token | Provides | Not this | Example |
| --- | --- | --- | --- |
| `setup` | A prepared workspace: one or more toolchains, dependencies and caches, ready for later steps | Not `install`: setup may do several things to make a workspace usable | `setup-tools`, `setup-api` |
| `install` | Exactly one tool or CLI placed on the `PATH`, and nothing else | Not `setup`: an install touches no project dependencies | `install-repo-cli` |
| `authenticate` | A credential obtained or configured: a registry login, a minted token | Not `setup`: keeping credentials in their own action keeps them out of steps that do not need them | `authenticate-registry` |
| `check` | A precondition confirmed, failing with a clear message when it does not hold; changes nothing | Not `validate`: a check is one precondition a job relies on, not a merge decision | `check-deploy-secrets` |

The object after the token names what the action acts on (`tools`, `api`, `registry`, `deploy-secrets`), not who
calls it.

When GHA-20 reports a directory, it suggests a corrected name only where the intent is plain: a directory that already
starts with an action token, or with a common stand-in for one. `auth` maps to `authenticate`, and `validate` and
`verify` map to `check`, so `auth-registry` is suggested `authenticate-registry`. Any other name gets no automatic
suggestion, because guessing which capability an action provides is its author's call.

## Requirements

### GHA-20

**An action directory is `<action-token>-<object>`.**

The directory name is lowercase kebab-case, starts with one of `setup`, `install`, `authenticate` or `check`, and has
at least one further word naming the object. Name the capability, not the caller: an action named after the workflow
that first used it (`validate-code-prep`) stops describing itself the moment a second workflow uses it, which is the
only reason to make it an action.

**Correct:**

```text
.github/actions/setup-tools/action.yml
.github/actions/install-repo-cli/action.yml
.github/actions/authenticate-registry/action.yml
```

**Incorrect:**

```text
.github/actions/ci-setup/action.yml          # caller first, token second
.github/actions/registry-auth/action.yml     # object first; auth is not a token
.github/actions/setup/action.yml             # no object
.github/actions/deploy-helpers/action.yml    # names the caller, not a capability
```

Checked by: conftest · Severity: warning · Since: 0.1.0 · Formerly: platform CI-18

### GHA-21

**An action's metadata is `action.yml`, one level below `.github/actions`.**

`uses: ./.github/actions/<name>` resolves `action.yml` or `action.yaml` in exactly that directory. One spelling and
one depth mean a reader, a glob and a check can find every action without searching: `.github/actions/*/action.yml`.
A nested directory (`.github/actions/deploy/setup-tools/`) hides the action from that glob and invites grouping by
caller.

**Correct:**

```text
.github/actions/setup-tools/action.yml
```

**Incorrect:**

```text
.github/actions/setup-tools/action.yaml
.github/actions/deploy/check-secrets/action.yml
```

Checked by: conftest · Severity: warning · Since: 0.1.0 · Formerly: platform CI-18

### GHA-22

**An action's name is its directory in Title Case.**

The `name:` in `action.yml` is derived from the directory the same way a workflow's name is derived from its filename
([GHA-07](workflow-files.md#gha-07)): split on `-`, apply display forms, capitalize, join with spaces. This is derived
Title Case ([EC-0002](workflow-files.md#display-forms)), mechanical and without judgment. The directory, the `uses:`
path and the name in the log then agree. The check waits while GHA-20 or GHA-21 asks for the directory to move: fix
the directory first, and the next run reports the name it implies.

**Correct:**

```yaml
# .github/actions/setup-tools/action.yml
name: Setup Tools
```

```yaml
# .github/actions/authenticate-registry/action.yml
name: Authenticate Registry
```

```yaml
# .github/actions/install-repo-cli/action.yml
name: Install Repo CLI   # cli ships with the display form CLI
```

A token with no shipped display form is capitalized: `setup-grpc` derives `Setup Grpc`. A repository that wants
`gRPC` adds `grpc: gRPC` to its conventions declaration's `vocabulary.display_forms`, and the derived name becomes
`Setup gRPC`. A declaration can only add display forms; it can never redefine one the release ships.

**Incorrect:**

```yaml
# .github/actions/setup-tools/action.yml
name: Setup mise and tools
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### GHA-23

**An action and each of its inputs have a description.**

A caller reads `action.yml` to learn what an action does and what to pass it; nothing else is shown to them. A
`description:` on the action and on every input is that documentation. Say what the input controls and what its
default means, not its type.

**Correct:**

```yaml
name: Setup Tools
description: Install the toolchain pinned in .devcontainer/mise.toml and put it on PATH.
inputs:
  cache:
    description: Restore and save the tool cache. Set to "false" in release jobs so no cache can alter what ships.
    default: "true"
```

**Incorrect:**

```yaml
name: Setup Tools
inputs:
  cache:
    default: "true"
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### GHA-38

**Inputs and outputs of actions and reusable workflows are kebab-case.**

A caller writes an input's name under `with:` and reads an output as `steps.<id>.outputs.<name>` or
`needs.<id>.outputs.<name>`, so these names are the interface of the unit. GitHub's own actions name them in
kebab-case (`actions/checkout` takes `fetch-depth` and `persist-credentials`), and a caller who mixes a local action
with third-party ones then writes one style throughout. The check covers the `inputs` and `outputs` of every
`action.yml`, and the `inputs`, `outputs` and `secrets` under `on.workflow_call` in every callable workflow, reusable
or not. A name is lowercase words joined by `-` (`^[a-z][a-z0-9]*(-[a-z0-9]+)*$`); renaming one means updating every
caller's `with:` and every expression that reads it.

A key a third-party action defines is its own API and is passed as that action spells it, even from inside a
kebab-case action: `setup-tools` takes `install-args` and passes it to `jdx/mise-action` as `install_args`.

**Correct:**

```yaml
# .github/actions/setup-tools/action.yml
inputs:
  install-args:
    description: Tools to install instead of the whole toolchain.
outputs:
  cache-hit:
    description: Whether the tool cache was restored.
    value: ${{ steps.install_tools.outputs.cache-hit }}
```

```yaml
# .github/workflows/reusable-build-image.yml
on:
  workflow_call:
    inputs:
      service-slug:
        type: string
        required: true
    secrets:
      registry-token:
        required: true
```

**Incorrect:**

```yaml
inputs:
  install_args:     # snake_case
  cacheHit:         # camelCase
```

Checked by: conftest · Severity: warning · Since: 0.1.0

## References

- [platform #2892: Organize GitHub Actions workflows by responsibility](https://github.com/musher-dev/platform/issues/2892)
- [EC-0002 Workflow files](workflow-files.md)
- [EC-0006 Units and renames](units-and-renames.md)
- [GitHub Docs: Metadata syntax for GitHub Actions](https://docs.github.com/en/actions/sharing-automations/creating-actions/metadata-syntax-for-github-actions)
