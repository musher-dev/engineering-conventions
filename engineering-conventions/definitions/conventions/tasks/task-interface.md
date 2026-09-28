---
id: EC-0016
title: Task interface
summary: >-
  Every repository answers to the same few task names from its root:
  setup, check and lint everywhere; build and test where the repository
  builds something; dev in a service. A person, a hook or a workflow can
  run `task check` in any repository without reading its Taskfile first.
status: draft
topic: tasks
applies_to:
  paths:
    - Taskfile.yml
    - taskfiles/*.yml
created: 2026-09-28
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
implementations:
  - repo: musher-dev/platform
    check: TF-20
    mode: blocking
references:
  - title: "Task: Including other Taskfiles"
    url: https://taskfile.dev/docs/guide#including-other-taskfiles
  - title: "Task: Task aliases"
    url: https://taskfile.dev/docs/guide#task-aliases
requirements:
  - id: TASK-10
    title: The root Taskfile defines setup, check and lint
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.tasks.task_interface
    aliases: ["platform:TF-20a"]
  - id: TASK-11
    title: The root Taskfile of a library, tool, service or website also defines build and test
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.tasks.task_interface
    aliases: ["platform:TF-20b"]
  - id: TASK-12
    title: The root Taskfile of a service also defines dev
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.tasks.task_interface
    aliases: ["platform:TF-20c"]
  - id: TASK-13
    title: The check task runs every gate CI runs
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: review
---

# Task interface

A new contributor should not have to read a Taskfile to learn how to install the tools, run the tests or check a
change. When every repository answers to the same names, `task setup` and `task check` work everywhere, a git hook or
a workflow can call them without knowing the repository, and moving between repositories costs nothing.

## Scope

This convention covers the **root Taskfile**: the Taskfile Task finds at the repository root, under any name it looks
for (`Taskfile.yml` first). A verb is defined when `task <verb>` runs from the root: a task of that name, an alias of
another task, or a task that an include brings in under that name. A flattened include adds its tasks' names as they
are, and a namespaced include adds `<namespace>:<name>`. Includes are followed three levels deep. An internal task, or
a task from an internal include, does not count, because it cannot be run from the command line.

How each task is written is [EC-0015](taskfile-style.md).

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). It replaces the verb taxonomy in
`musher-dev/platform` (TF-19, TF-20), whose required list of 24 verbs describes one repository, with the few verbs
every repository shares. Every requirement is `proposed` at severity `warning`.

## The verbs

| Verb | Does | Required by |
| --- | --- | --- |
| `setup` | Installs everything the other tasks need: the pinned tools, dependencies and git hooks | TASK-10, every repository |
| `check` | Runs every gate CI runs, fastest first | TASK-10, every repository |
| `lint` | Runs the linters and format checks, without changing files | TASK-10, every repository |
| `build` | Builds what the repository publishes | TASK-11, `library`, `tool`, `service`, `website` |
| `test` | Runs the tests | TASK-11, `library`, `tool`, `service`, `website` |
| `dev` | Runs the service locally for development | TASK-12, `service` |

A repository adds any task it needs beyond these. A `<verb>:<detail>` task (`test:unit`, `lint:fix`) extends a verb
without replacing it.

### How a kind selects them

The [identity declaration](../repository/identity-declaration.md)'s `kind` selects the profile, and the profile
selects the requirements:

| Profile | TASK-10 | TASK-11 | TASK-12 |
| --- | --- | --- | --- |
| `base-repo` and every kind | yes | | |
| `library`, `tool`, `website` | yes | yes | |
| `service` | yes | yes | yes |

## Requirements

### TASK-10

**The root Taskfile defines `setup`, `check` and `lint`.**

These three are what anyone does first in a repository: get ready, check a change, and fix what the linters report.
Every repository has something to lint and something to check, even one that holds only documents, so every
repository defines them. A repository without a root Taskfile gets this finding too.

**Correct:**

```yaml
version: '3'
tasks:
  setup:
    desc: Install the pinned tools and the git hooks.
    cmds: [mise install, lefthook install]
  check:
    desc: Run every gate CI runs.
    cmds: [task: lint, task: test]
  lint:
    desc: Lint the Markdown and YAML.
    cmds: [markdownlint-cli2 '**/*.md']
```

**Incorrect:**

```yaml
version: '3'
tasks:
  install:                    # say setup
    desc: Install the tools.
  ci:                         # say check
    desc: Run the CI gates.
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform TF-20 (in part)

### TASK-11

**The root Taskfile of a library, tool, service or website also defines `build` and `test`.**

A repository that ships code has a build and tests, and a workflow that builds or tests it should not need to know
which tool it uses. The `library`, `tool`, `service` and `website` profiles select this requirement.

**Correct:**

```yaml
tasks:
  build:
    desc: Build the binary.
    cmds: [go build ./...]
  test:
    desc: Run the tests.
    cmds: [go test ./...]
```

**Incorrect:**

```yaml
tasks:
  compile:                    # say build
    desc: Build the binary.
  unit:                       # say test, or test:unit beside it
    desc: Run the tests.
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform TF-20 (in part)

### TASK-12

**The root Taskfile of a service also defines `dev`.**

A service is a process that people run to work on it. `task dev` starts it locally with whatever it needs, so nobody
has to learn a service's start command before changing it. The `service` profile selects this requirement.

**Correct:**

```yaml
tasks:
  dev:
    desc: Run the API locally, reloading on change.
    deps: [setup]
    cmds: [air]
```

**Incorrect:**

```yaml
tasks:
  start:                      # say dev, or add dev as an alias
    desc: Run the API locally.
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform TF-20 (in part)

### TASK-13

**The `check` task runs every gate CI runs.**

`task check` is the promise that a change which passes locally passes in CI. When CI runs a gate that `check` does
not, the first sign of it is a failed pull request. The reviewer checks that every command a validation workflow runs
is reached from `check`, directly or through the tasks it calls; a gate that only CI can run, such as building the dev
container, is named in `check`'s description.

**Correct:**

```yaml
check:
  desc: Run every gate CI runs except the dev container build.
  cmds:
    - task: lint
    - task: test
    - task: conventions
```

**Incorrect:**

```yaml
check:
  desc: Run the linters.
  cmds:
    - task: lint              # CI also runs the tests and conventions check
```

Checked by: review · Severity: warning · Since: 0.6.0

## References

- [EC-0015 Taskfile style](taskfile-style.md)
- [EC-0009 Identity declaration](../repository/identity-declaration.md)
- [Task: Including other Taskfiles](https://taskfile.dev/docs/guide#including-other-taskfiles)
- [Task: Task aliases](https://taskfile.dev/docs/guide#task-aliases)
