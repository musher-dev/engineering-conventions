---
id: EC-0015
title: Taskfile style
summary: >-
  Every Taskfile declares schema version '3', names its variables in
  UPPER_SNAKE and its tasks in kebab-case, writes templates without inner
  spaces, describes every public task and calls every internal one, and
  names only includes, paths and sources that exist.
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

TASK-06 and TASK-09 are new.

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
checked. A bare relative value resolves from the directory the tasks run in: under an include with `dir:`, that
directory, for the included file and for every file it includes without a `dir:` of its own; a templated `dir:` is
not checked. A directory that only a build creates, such as ignored build output, is named for what it holds instead
(`DIST`, `SITE`, not `SITE_DIR`), and the finding says so.

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

## References

- [EC-0016 Task interface](task-interface.md)
- [Task: Style guide](https://taskfile.dev/docs/styleguide)
- [Task: Schema reference](https://taskfile.dev/docs/reference/schema)
- [Task: Guide](https://taskfile.dev/docs/guide)
