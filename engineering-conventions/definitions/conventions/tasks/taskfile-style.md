---
id: EC-0015
title: Taskfile style
summary: >-
  Every Taskfile declares schema version '3', names its variables in
  UPPER_SNAKE and its tasks in kebab-case, writes templates without inner
  spaces, describes every public task and calls every internal one,
  names only includes, paths and sources that exist, keeps its default
  task to listing, nests names at most three namespaces deep, names no
  machine-specific path, and prompts before destroying data.
status: draft
topic: tasks
applies_to:
  paths:
    - Taskfile.yml
    - "*/Taskfile.yml"
    - "*/*/Taskfile.yml"
    - "**/taskfiles/*.yml"
created: 2026-09-28
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
implementations:
  - repo: musher-dev/platform
    check: TF-01
    mode: blocking
  - repo: musher-dev/platform
    check: TF-06
    mode: blocking
  - repo: musher-dev/platform
    check: TF-07
    mode: blocking
  - repo: musher-dev/platform
    check: TF-08
    mode: blocking
  - repo: musher-dev/platform
    check: TF-09
    mode: blocking
  - repo: musher-dev/platform
    check: TF-12
    mode: blocking
  - repo: musher-dev/platform
    check: TF-15
    mode: blocking
  - repo: musher-dev/platform
    check: TF-21
    mode: blocking
  - repo: musher-dev/development-container
    check: PATH-03
    mode: blocking
references:
  - title: "Task: Style guide"
    url: https://taskfile.dev/docs/styleguide
  - title: "Task: Schema reference"
    url: https://taskfile.dev/docs/reference/schema
  - title: "Task: Guide"
    url: https://taskfile.dev/docs/guide
requirements:
  - id: TASK-01
    title: A Taskfile declares version '3' as a string
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.tasks.taskfile_style
    aliases: ["platform:TF-01"]
  - id: TASK-02
    title: A Taskfile names its variables in UPPER_SNAKE
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.tasks.taskfile_style
    aliases: ["platform:TF-06"]
  - id: TASK-03
    title: A task name is kebab-case words joined by colons, with a leading underscore only on an internal task
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.tasks.taskfile_style
    aliases: ["platform:TF-08", "platform:TF-12"]
  - id: TASK-04
    title: A template has no whitespace inside its delimiters
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.tasks.taskfile_style
    aliases: ["platform:TF-07"]
  - id: TASK-05
    title: Every public task has a desc
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.tasks.taskfile_style
    aliases: ["platform:TF-09"]
  - id: TASK-06
    title: Every internal task is called by another task
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.tasks.taskfile_style
  - id: TASK-07
    title: A task sets prefix only where the output mode is prefixed
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.tasks.taskfile_style
    aliases: ["platform:TF-15"]
  - id: TASK-08
    title: A variable named for a directory, file or configuration names a path that exists
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.tasks.taskfile_style
    aliases: ["development-container:PATH-03"]
  - id: TASK-09
    title: Every include names a Taskfile that exists, unless it is optional
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.tasks.taskfile_style
  - id: TASK-14
    title: Every literal sources entry names something the repository holds
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.tasks.taskfile_style
    aliases: ["platform:TF-21"]
  - id: TASK-15
    title: The root Taskfile's default task only lists the tasks
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.tasks.taskfile_style
  - id: TASK-16
    title: A task name nests at most three namespaces
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.tasks.taskfile_style
  - id: TASK-17
    title: A Taskfile names no path that exists on only one machine
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.tasks.taskfile_style
  - id: TASK-18
    title: A task that destroys what nothing can restore declares a prompt
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.tasks.taskfile_style
---

# Taskfile style

[Task](https://taskfile.dev) runs a repository's commands the same way on a laptop, in a hook and in CI. A Taskfile
is read by people more often than it is changed, and it fails quietly: a source that matches nothing, a path variable
that points at a moved directory, or an include that no longer exists does not always stop a task. It just makes the
task do less than it says. These requirements keep every Taskfile readable in one style and catch those silent
failures before they ship.

Task publishes its own [style guide](https://taskfile.dev/docs/styleguide). This convention cites it rather than
restating it, and checks the parts that tools can check: version, variable and task names, and template spacing
(TASK-01 to TASK-04). The rest of the guide is about layout, which a formatter owns (see [Not required](#not-required)).

## Scope

This convention covers every Taskfile in a repository that is checked against a release of
`musher-dev/engineering-conventions`: a `Taskfile.yml` (or any name Task looks for) at the root or up to two
directories below it, and the YAML files in a `taskfiles/` directory. Which tasks a repository must define is
[EC-0016](task-interface.md).

A relative path in a Taskfile is resolved the way Task resolves it. A Taskfile that no other Taskfile includes runs
from its own directory. An included Taskfile runs from the directory of the Taskfile Task was started from, which is
also `{{.ROOT_DIR}}`, and `{{.TASKFILE_DIR}}` is its own directory. The checks skip a path when the include or the
task that uses it sets `dir:`, and they skip any value that holds another template, a glob or a variable. Such a path
can only be known when the task runs.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirements are adopted from
`musher-dev/platform`'s Taskfile rules (TF-*) and `musher-dev/development-container`'s path rules (PATH-03), which
retire their copies once they pin a release that carries them
([decision 0016](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)).
Every requirement is `proposed` at severity `warning`.

### What was adopted, and what was not

| Upstream | Here | Why |
| --- | --- | --- |
| TF-01, TF-06, TF-07, TF-08, TF-09 | TASK-01, TASK-02, TASK-04, TASK-03, TASK-05 | Adopted as written. |
| TF-12 (`_name` needs `internal: true`) | Part of TASK-03 | One statement about what a name says. |
| TF-15 (`prefix:` needs `silent: true`) | TASK-07 | Generalized: `prefix:` only changes output in the `prefixed` mode, whatever else the task sets. |
| TF-21 (literal `sources:` exist) | TASK-14 | Adopted, resolved from the directory the task runs in. |
| PATH-03 (`{{.ROOT_DIR}}` variables exist) | TASK-08 | Generalized to any literal path in a variable named for a path. |
| TF-02, TF-13, TF-14, TF-16, TF-17, TF-18 | Not adopted | They describe one repository's output style, not a rule every repository needs. |
| TF-03, TF-04, TF-05, TF-10, TF-11 | Not adopted | Layout, which a formatter owns. |
| TF-19, TF-20 | [EC-0016](task-interface.md) | A small shared set of verbs replaces one repository's allow-list. |
| TF-22, TF-23 | Not adopted | Specific to the platform's tools and layout. |

TASK-06 and TASK-09 are new. TASK-15 to TASK-18 put into checks what the platform's Taskfile authoring guide
asked of every Taskfile in prose: a `default` task that only lists, shallow namespaces, no machine-specific paths,
and a prompt before destroying data. Task's schema does not check any of them.

## Not required

Key order, two-space indentation and blank lines between sections and tasks are in Task's style guide, and a
Taskfile should follow them. They are not requirements here, because a formatter settles them without a person
deciding anything, and a check that fails on whitespace teaches nothing. The same goes for the guide's advice to move
long scripts into files: good advice, but not something a check can judge.

## Requirements

### TASK-01

**A Taskfile declares `version: '3'` as a string.**

The version tells Task which schema to read the file with, and `3` is the only one it supports. Writing it unquoted
makes it a number, which Task accepts today but the schema describes as a string; quoting it keeps every Taskfile the
same.

**Correct:**

```yaml
version: '3'
```

**Incorrect:**

```yaml
version: 3
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform TF-01

### TASK-02

**A Taskfile names its variables in UPPER_SNAKE.**

Variables are read inside templates next to Task's own (`.ROOT_DIR`, `.TASK`, `.CLI_ARGS`), which are all upper case,
and next to environment variables, which are too. A lowercase or camelCase name looks like something else and is easy
to mistype. The requirement covers global `vars` and `env`, and each task's. An environment variable a tool reads in
lowercase, such as `http_proxy`, needs a waiver.

**Correct:**

```yaml
vars:
  BINARY_NAME: server
```

**Incorrect:**

```yaml
vars:
  binaryName: server
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform TF-06

### TASK-03

**A task name is kebab-case words joined by colons, with a leading underscore only on an internal task.**

A task's name is what people type and what hooks and workflows call, so every repository spells it one way: lowercase
words joined by hyphens, and `:` between a namespace and a name (`docker:build`), as Task's style guide asks. A
wildcard segment (`migrate:*`) is allowed. Aliases follow the same form. A leading `_` tells a reader that a task is a
helper, but Task does not hide it for the name alone: without `internal: true` it is listed and can be run on its own.

**Correct:**

```yaml
tasks:
  docker:build:
    desc: Build the image.
  _login:
    internal: true
```

**Incorrect:**

```yaml
tasks:
  docker_build:
    desc: Build the image.
  _login:                     # listed and runnable; add internal: true
    cmds: [docker login]
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform TF-08, TF-12

### TASK-04

**A template has no whitespace inside its delimiters.**

Task's style guide writes `{{.NAME}}`, not `{{ .NAME }}`. Both work, so a file that mixes them is harder to search:
a reader looking for `{{.NAME}}` misses the spaced form. A trim marker (`{{-` and `-}}`) is not whitespace in this
sense and is allowed.

**Correct:**

```yaml
cmds:
  - go build -o {{.BINARY_NAME}}
```

**Incorrect:**

```yaml
cmds:
  - go build -o {{ .BINARY_NAME }}
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform TF-07

### TASK-05

**Every public task has a `desc`.**

`task --list` prints only tasks with a description, so a public task without one cannot be found by the people it is
for. A task that is not meant to be run directly is internal instead (TASK-03).

**Correct:**

```yaml
tasks:
  test:
    desc: Run the unit tests.
    cmds: [go test ./...]
```

**Incorrect:**

```yaml
tasks:
  test:
    cmds: [go test ./...]
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform TF-09

### TASK-06

**Every internal task is called by another task.**

An internal task cannot be run from the command line; it exists only to be called. One that nothing calls is dead
code that still looks alive, and a reader has to trace every Taskfile to find that out. A call is a `task:` entry in
`cmds` or `deps` (or a `defer`) in any Taskfile of the repository, by its name or through a namespace.

**Correct:**

```yaml
tasks:
  build:
    desc: Build the binary.
    deps: [_generate]
  _generate:
    internal: true
    cmds: [go generate ./...]
```

**Incorrect:**

```yaml
tasks:
  _generate:                  # nothing calls it
    internal: true
    cmds: [go generate ./...]
```

Checked by: conftest · Severity: warning · Since: 0.6.0

### TASK-07

**A task sets `prefix` only where the output mode is `prefixed`.**

`prefix:` sets the label Task prints before each line of a task's output, and only the `prefixed` output mode prints
it. Anywhere else it does nothing, and a reader who trusts it expects labeled output that never appears. The mode is
set by `output: prefixed` in the Taskfile, or in a Taskfile that includes it.

**Correct:**

```yaml
output: prefixed
tasks:
  deps:
    desc: Install the dependencies.
    prefix: deps
```

**Incorrect:**

```yaml
tasks:                        # no output: prefixed anywhere
  deps:
    desc: Install the dependencies.
    prefix: deps
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform TF-15

### TASK-08

**A variable named for a directory, file or configuration names a path that exists.**

A variable whose name ends in `_DIR`, `_FILE` or `_CONFIG` is how a Taskfile passes a directory or a configuration
file to its tools, and its literal value must name something the repository holds. When the file
moves, nothing fails at once: a linter falls back to its defaults, or a command scans an empty directory and passes.
A `_FILE` variable may name a file a task writes, such as an ignored local `.env`, so only its directory has to
exist. The value is resolved after `{{.ROOT_DIR}}/` or `{{.TASKFILE_DIR}}/`; a value with any other template is not
checked. A bare relative value resolves from the directory the tasks run in, as Task sets it: an include written as
a map runs in its `dir:`, or without one in the including file's directory; an include written as a bare string runs
where the including file's tasks run. A value under a templated `dir:` is not checked. A directory that only a build
creates, such as ignored build output, is named for what it holds instead (`DIST`, `SITE`, not `SITE_DIR`), and the
finding says so.

**Correct:**

```yaml
vars:
  LINT_CONFIG: .config/golangci.yml
  PRODUCT_DIR: '{{.ROOT_DIR}}/server'
```

**Incorrect:**

```yaml
vars:
  LINT_CONFIG: .golangci.yml         # moved to .config/ and not updated
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container PATH-03

### TASK-09

**Every include names a Taskfile that exists, unless it is optional.**

Task loads every include before it runs anything, so an include whose file is gone breaks every task in the
repository, not only the ones it held. The path is resolved from the including Taskfile's directory, and a directory
counts when it holds a Taskfile. An include marked `optional: true` is allowed to be missing. A remote or templated
include is not checked.

**Correct:**

```yaml
includes:
  docs: ./docs                # docs/Taskfile.yml exists
```

**Incorrect:**

```yaml
includes:
  docs: ./documentation       # renamed to docs/
```

Checked by: conftest · Severity: warning · Since: 0.6.0

### TASK-14

**Every literal `sources` entry names something the repository holds.**

Task fingerprints a task's `sources` to decide whether it can skip it. An entry that matches nothing is not an error:
it adds nothing to the fingerprint, so the task stops noticing changes to the file it was meant to watch, and nothing
says so. A glob is not checked, because it may match nothing until the first build, and neither is an entry in a
task with its own `dir:`.

**Correct:**

```yaml
tasks:
  install:
    desc: Install the dependencies.
    sources: [package.json, bun.lock]
```

**Incorrect:**

```yaml
tasks:
  install:
    desc: Install the dependencies.
    sources: [package.json, bun.lock]   # the lockfile is one directory up
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform TF-21

### TASK-15

**The root Taskfile's `default` task only lists the tasks.**

`task` with no arguments runs the root Taskfile's `default` task, and it is the first thing a newcomer types to find
out what a repository offers. A `default` that builds, migrates or deploys does that work by surprise. Every command
of a `default` task (or of the task that takes `default` as an alias) is a `task` call with flags only, among them
`--list`, `--list-all`, `-l` or `-a`; or `task help` or `task list`, or a `task:` call to either, where that task
itself only lists or prints; or a line that only prints text with `echo` or `printf`. A `default` task has no
`deps`. A Taskfile with no `default` task is not affected: Task then lists the tasks itself.

**Correct:**

```yaml
tasks:
  default:
    desc: List the tasks.
    cmds:
      - task --list
```

**Incorrect:**

```yaml
tasks:
  default:
    desc: Build everything.
    cmds:
      - task: build             # name the work, and let default list it
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### TASK-16

**A task name nests at most three namespaces.**

A name is typed, read in `task --list`, and matched by hooks and workflows. Each `:` adds a level a reader has to
hold, and past three the levels stop meaning anything: `check:biome:fix:unsafe:all` says no more than
`check:biome:fix:unsafe-all`. A name has at most four segments, three namespaces and the name, counted in the
Taskfile that declares it; the namespace an include adds is the including Taskfile's choice and is not counted.
Aliases are counted the same way. Join the extra words with hyphens.

**Correct:**

```yaml
tasks:
  test:contract:openapi:public:
    desc: Check the public API against its contract.
```

**Incorrect:**

```yaml
tasks:
  test:contract:openapi:public:v2:
    desc: Check version 2 of the public API.
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### TASK-17

**A Taskfile names no path that exists on only one machine.**

A path into someone's home directory or into the place one environment keeps its checkout works for whoever wrote
it, and fails in every other clone, container and CI runner, often far from the line that caused it. Task gives
every Taskfile `{{.ROOT_DIR}}` and `{{.TASKFILE_DIR}}` for exactly this. The check reads each command line, each
task's `dir`, `sources`, `generates` and `dotenv`, every variable, and each include's `taskfile` and `dir`, and looks
for a path that starts `/home/<user>`, `/Users/<user>`, `/root/`, `/workspace` or `/workspaces`, or a Windows
drive (`C:\`). It does not read a line that runs a container tool (`docker`, `podman`, `nerdctl`, `kubectl`,
`devcontainer`), where a path may be the container's own, nor a path after `:`, such as a mount target or a URL,
nor a line that only prints text or a comment. Shared system paths such as `/tmp`, `/dev/null`, `/usr/bin/env` and
`/opt` are not one machine's.

**Correct:**

```yaml
vars:
  CACHE_DIR: '{{.ROOT_DIR}}/.cache'
tasks:
  build:
    desc: Build the binary.
    cmds:
      - go build -o {{.ROOT_DIR}}/dist/app ./...
      - docker run -v "{{.ROOT_DIR}}:/workspace" -w /workspace builder make
```

**Incorrect:**

```yaml
vars:
  CACHE_DIR: /home/ana/project/.cache
tasks:
  build:
    desc: Build the binary.
    cmds:
      - cd /workspaces/project && go build ./...
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### TASK-18

**A task that destroys what nothing can restore declares a `prompt`.**

`prompt:` makes Task ask before it runs a task, so a mistyped or autocompleted name cannot wipe data on its own;
Task still runs it without asking under `--yes`, which is how a workflow calls it. The requirement covers what no
checkout, build or rerun brings back:

| Command | Loses |
| --- | --- |
| `docker volume rm` or `prune`, `docker system prune --volumes` (and `podman`) | Container volumes |
| `compose … down -v` or `--volumes`, also behind a template such as `{{.COMPOSE}} down -v` | A stack's volumes |
| `tofu` or `terraform` `destroy -auto-approve`, and `apply -auto-approve` without a saved plan | Infrastructure |
| `git clean -f…` | Untracked files |
| `git reset --hard` | Uncommitted changes |

A task whose last name segment is `destroy`, `drop` or `wipe`, or that is named `db:reset` (or `database:reset`),
promises to destroy data and needs a prompt as well. An internal task may leave the prompt to a task that calls it.

Deleting files is not covered. `rm -rf` in a Taskfile almost always removes what a build writes (`dist`, `build`,
`node_modules`) or a scratch directory the task made, which the next build or `git checkout` restores, and a check
cannot tell build output from data. A `clean` task needs no prompt. Neither does a database the task drops and
recreates as scratch, such as a migration tool's dev database or a test database; a database people keep data in is
dropped by a task named for it (`db:reset`, `db:drop`), and that name is what the check reads.

**Correct:**

```yaml
tasks:
  db:reset:
    desc: Drop the local database and migrate it from scratch.
    prompt: This deletes every row in the local database. Continue?
    cmds:
      - docker compose down -v
      - task: db:migrate
  clean:
    desc: Remove the build output.
    cmds:
      - rm -rf dist
```

**Incorrect:**

```yaml
tasks:
  stack:reset:
    desc: Stop the stack and wipe its volumes.
    cmds:
      - docker compose down -v   # no prompt
```

Checked by: conftest · Severity: warning · Since: 0.7.1

## References

- [EC-0016 Task interface](task-interface.md)
- [Task: Style guide](https://taskfile.dev/docs/styleguide)
- [Task: Schema reference](https://taskfile.dev/docs/reference/schema)
- [Task: Guide](https://taskfile.dev/docs/guide)
