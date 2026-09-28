---
id: EC-0014
title: Lefthook configuration
summary: >-
  A repository that runs its git hooks with lefthook fails loudly when
  lefthook is missing or older than the version it pins, matches globs the
  way they read, defines its hooks as jobs that say how to fix a failure,
  keeps tests out of pre-commit, never lets a hook pass on a failure, and
  takes its hooks from no other repository.
status: draft
topic: git-hooks
applies_to:
  paths:
    - .config/lefthook.yml
    - .config/lefthook.yaml
    - lefthook.yml
    - lefthook.yaml
    - .lefthook.yml
    - .lefthook.yaml
created: 2026-09-28
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
implementations:
  - repo: musher-dev/platform
    check: LH-01
    mode: blocking
  - repo: musher-dev/platform
    check: LH-02
    mode: blocking
  - repo: musher-dev/platform
    check: LH-03
    mode: blocking
  - repo: musher-dev/platform
    check: LH-04
    mode: blocking
  - repo: musher-dev/platform
    check: LH-05
    mode: blocking
  - repo: musher-dev/platform
    check: LH-06
    mode: blocking
  - repo: musher-dev/development-container
    check: PATH-01
    mode: blocking
references:
  - title: "Lefthook: Configuration"
    url: https://lefthook.dev/configuration/
  - title: "Lefthook: glob_matcher"
    url: https://lefthook.dev/configuration/glob_matcher/
  - title: "Lefthook: jobs"
    url: https://lefthook.dev/configuration/jobs/
requirements:
  - id: HOOKS-01
    title: A lefthook configuration sets assert_lefthook_installed
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.git_hooks.lefthook
    aliases: ["platform:LH-05"]
  - id: HOOKS-02
    title: min_version is set, and equals the lefthook version mise installs
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.git_hooks.lefthook
    aliases: ["platform:LH-05"]
  - id: HOOKS-03
    title: A lefthook configuration sets glob_matcher to doublestar
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.git_hooks.lefthook
    aliases: ["platform:LH-05"]
  - id: HOOKS-04
    title: A glob with a wildcard and no directory starts with **/
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.git_hooks.lefthook
    aliases: ["platform:LH-01"]
  - id: HOOKS-05
    title: A hook defines jobs, not commands or scripts
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.git_hooks.lefthook
  - id: HOOKS-06
    title: Every job that runs something has a fail_text
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.git_hooks.lefthook
    aliases: ["platform:LH-02"]
  - id: HOOKS-07
    title: stage_fixed is set only on a job that fixes files
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.git_hooks.lefthook
    aliases: ["platform:LH-03"]
  - id: HOOKS-08
    title: Pre-commit runs no test runner
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.git_hooks.lefthook
    aliases: ["platform:LH-06"]
  - id: HOOKS-09
    title: A lefthook configuration uses neither remotes nor extends
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.git_hooks.lefthook
    aliases: ["platform:LH-05"]
  - id: HOOKS-10
    title: A job never discards its command's exit code
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.git_hooks.lefthook
    aliases: ["platform:LH-04"]
  - id: HOOKS-11
    title: Every job glob matches a file in the repository
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.git_hooks.lefthook
    aliases: ["development-container:PATH-01"]
---

# Lefthook configuration

Git hooks are the first place a mistake can be caught, and the easiest place for a check to stop working without
anyone noticing. A hook that matches no files skips. A job that swallows its exit code passes. A clone where lefthook
was never installed runs nothing at all. None of these fail; each looks exactly like a clean commit. These
requirements close the ways a lefthook configuration goes quiet, and keep the hooks fast enough that nobody reaches
for `--no-verify`.

## Scope

This convention covers the lefthook configuration a repository commits: `.config/lefthook.yml`, or `lefthook.yml` or
`.lefthook.yml` at the root (`.yaml` too). Every requirement applies only when one of these files exists; a
repository without lefthook is not asked to adopt it. `lefthook-local.yml` is a personal override that is not
committed, and is not checked.

Lefthook's own schema, checked by `lefthook validate`, decides whether the file is well formed. These requirements
sit above it: each one is valid lefthook that fails in practice. Where the file goes is a question of tool
configuration, not of this convention.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). It adopts the lefthook checks of
`musher-dev/platform` and the lefthook half of a path check in `musher-dev/development-container`
([decision 0016](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md));
each repository retires its copy once it pins a release that carries these. Every requirement is `proposed` at
severity `warning`.

| Upstream check | Requirements | Mode |
| --- | --- | --- |
| platform `LH-01` | HOOKS-04 | blocking in `musher-dev/platform` |
| platform `LH-02` | HOOKS-06 | blocking in `musher-dev/platform` |
| platform `LH-03` | HOOKS-07 | blocking in `musher-dev/platform` |
| platform `LH-04` | HOOKS-10 | blocking in `musher-dev/platform` |
| platform `LH-05` | HOOKS-01, HOOKS-02, HOOKS-03, HOOKS-09 | blocking in `musher-dev/platform` |
| platform `LH-06` | HOOKS-08 | blocking in `musher-dev/platform` |
| development-container `PATH-01` (lefthook globs) | HOOKS-11 | blocking in `musher-dev/development-container` |

### Differences from the upstream checks

| Upstream | Here | Why |
| --- | --- | --- |
| LH-05 compares `min_version` with a CI workflow's `LEFTHOOK_VERSION` | HOOKS-02 compares it with the lefthook pin in mise | mise is where every tool version is pinned; CI installs from the same file |
| LH-05 requires `output:` | Not required | Output is a matter of taste; nothing fails without it |
| LH-06 allows a pre-push test only as a `:changed` verb | HOOKS-08 covers pre-commit only | What pre-push may run depends on the size of the suite, which differs by repository |
| LH-07 requires a hook-level `files:` and `parallel: true` on pre-push | Not adopted | It guarded against lefthook before 2.1.5 finding no files on a branch's first push. Since then lefthook diffs against the remote's default branch, and HOOKS-02 pins the version; `parallel` is speed, not correctness |
| LH-08 bans TODO comments | Not adopted | YAML parsers discard comments, so no engine here can see them |

## Requirements

### HOOKS-01

**A lefthook configuration sets `assert_lefthook_installed`.**

The hook scripts lefthook installs call the `lefthook` executable. When it cannot be found, on a machine or in a
container where it was never installed or has gone from `PATH`, the scripts skip and every commit goes through
unchecked with no message. With `assert_lefthook_installed: true`, the hook fails instead, so the gap is noticed on the
first commit.

**Correct:**

```yaml
assert_lefthook_installed: true
```

**Incorrect:**

```yaml
# assert_lefthook_installed not set: without the executable, the hooks skip silently
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform LH-05

### HOOKS-02

**`min_version` is set, and equals the lefthook version mise installs.**

An older lefthook reads a newer file with whatever subset of it that version understands: a key it does not know is
ignored, and jobs silently stop running. `min_version` makes lefthook refuse to run a file written for a newer
version. It equals the lefthook pin in the repository's mise configuration (`aqua:evilmartians/lefthook`,
`npm:lefthook` or `lefthook`, in any mise configuration file), so the floor is the version everyone actually runs and
a version bump changes both lines together. When mise pins no lefthook, only that `min_version` is set is checked.

**Correct:**

```yaml
# .config/lefthook.yml
min_version: "2.1.14"
```

```toml
# .config/mise/config.toml
[tools]
"aqua:evilmartians/lefthook" = "2.1.14"
```

**Incorrect:**

```yaml
min_version: "2.1.4"          # mise installs 2.1.14
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform LH-05

### HOOKS-03

**A lefthook configuration sets `glob_matcher` to `doublestar`.**

Lefthook's default glob engine reads `**/` as *one or more* directories, so `**/*.md` misses `README.md` at the root.
With `glob_matcher: doublestar`, globs mean what they mean in a shell, in `.gitignore`, and in every other tool the
repository configures: `**/` is zero or more directories and `*` stays within one. A reader can then tell what a job
matches from its glob alone.

**Correct:**

```yaml
glob_matcher: doublestar
```

**Incorrect:**

```yaml
# glob_matcher not set: **/*.md misses root files
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform LH-05

### HOOKS-04

**A glob with a wildcard and no directory starts with `**/`.**

Under doublestar, `*` does not cross a `/`, so `*.md` matches only Markdown files at the repository root. A job
written as `glob: "*.md"` to lint every Markdown file checks almost none of them and never fails. Each alternative of a
brace group is judged on its own: `*.{ts,md}` is two such globs. A glob that names a directory (`docs/*.md`) or a file
(`README.md`) says where it looks, and is not affected.

**Correct:**

```yaml
glob: "**/*.md"
glob: "docs/*.md"
```

**Incorrect:**

```yaml
glob: "*.md"                  # root files only
glob: "*.{ts,js}"             # both alternatives are root files only
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform LH-01

### HOOKS-05

**A hook defines `jobs`, not `commands` or `scripts`.**

`jobs:` is lefthook's current form: an ordered list that holds both commands (`run:`) and scripts (`script:`), and
groups them with `group:`. The older `commands:` and `scripts:` maps cannot be ordered or grouped, and a hook that
mixes the forms is read in an order the file does not show. One form means every hook reads the same way, and every
other requirement here reads one shape.

**Correct:**

```yaml
pre-commit:
  jobs:
    - name: lint
      run: task lint
      fail_text: "Lint failed. Run 'task lint'."
```

**Incorrect:**

```yaml
pre-commit:
  commands:
    lint:
      run: task lint
```

Checked by: conftest · Severity: warning · Since: 0.6.0

### HOOKS-06

**Every job that runs something has a `fail_text`.**

When a hook fails, the contributor is in the middle of a commit and wants one thing: what to run to fix it. Without a
`fail_text`, they get a job name and a scroll of tool output. One sentence naming the task or command that reproduces
or fixes the failure saves every contributor the same search. A group of jobs needs none; each job it runs does.

**Correct:**

```yaml
- name: yaml
  glob: "**/*.{yml,yaml}"
  run: yamllint --strict {staged_files}
  fail_text: "YAML lint failed. Run 'task lint:yaml' for the report."
```

**Incorrect:**

```yaml
- name: yaml
  glob: "**/*.{yml,yaml}"
  run: yamllint --strict {staged_files}
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform LH-02

### HOOKS-07

**`stage_fixed` is set only on a job that fixes files.**

`stage_fixed: true` restages the files a job changed. On a job that only checks (`--check`, a `:check` task,
`--dry-run`, `--exit-code`) it restages nothing, but it tells a reader the job fixes what it finds, so they commit
expecting a fix that never happened. Run the fixing form of the tool, or drop the flag.

**Correct:**

```yaml
- name: format
  run: prettier --write {staged_files}
  stage_fixed: true
```

**Incorrect:**

```yaml
- name: format
  run: prettier --check {staged_files}
  stage_fixed: true
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform LH-03

### HOOKS-08

**Pre-commit runs no test runner.**

Pre-commit runs on every commit, so it has to finish in seconds. A test suite needs the whole dependency graph and
takes minutes; once a commit takes minutes, contributors skip the hooks, and every other check goes with them. Tests
belong in pre-push or CI. The check looks for `pytest`, `jest`, `vitest`, `go test`, `cargo test`, `cargo nextest`,
`bun test`, and a `task` call whose name is or ends in `test`.

**Correct:**

```yaml
pre-push:
  jobs:
    - name: test
      run: task test
      fail_text: "Tests failed. Run 'task test'."
```

**Incorrect:**

```yaml
pre-commit:
  jobs:
    - name: test
      run: uv run pytest
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform LH-06

### HOOKS-09

**A lefthook configuration uses neither `remotes` nor `extends`.**

`remotes:` downloads configuration from another repository at a tag, which can be moved, and lefthook carries on
without it when the download fails, so hooks disappear with no error. `extends:` merges other files over this one, so
the jobs that run are no longer the jobs this file shows. Shared expectations for hooks are published as this
convention instead, and each repository writes its jobs in its own file, where a reviewer sees them.

**Correct:**

```yaml
pre-commit:
  jobs:
    - name: secrets
      run: gitleaks git --pre-commit --staged
      fail_text: "A staged change looks like a secret. Remove it."
```

**Incorrect:**

```yaml
remotes:
  - git_url: https://example.com/shared-hooks
    ref: v1
    configs: [hooks.yml]
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform LH-05

### HOOKS-10

**A job never discards its command's exit code.**

`|| true`, `|| :`, `|| exit 0`, `|| echo ...` and `set +e` turn a failing command into a passing job. The hook then
reports success on exactly the change it exists to stop. A tool that is sometimes absent is guarded with
`command -v` before it runs; a finding that is acceptable is configured away in the tool's own configuration.
Comments in `run:` are ignored, so a note explaining the rule does not trip it.

**Correct:**

```yaml
run: shellcheck {staged_files}
run: lint || { echo "see docs/lint.md" >&2; exit 1; }
```

**Incorrect:**

```yaml
run: shellcheck {staged_files} || true
run: atlas migrate lint || echo "atlas not installed, skipping"
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform LH-04

### HOOKS-11

**Every job glob matches a file in the repository.**

A job whose glob matches nothing is skipped on every commit, and a skip looks like a pass. It happens after a
directory is renamed or a file type is dropped, and nothing reports it. Each glob, on a job or on a group, is matched
with doublestar semantics against the files the repository holds; files set apart as fixtures in the conventions
declaration do not count.

**Correct:**

```yaml
glob: "src/**/*.py"           # the repository has src/app/main.py
```

**Incorrect:**

```yaml
glob: "app/**/*.py"           # app/ was renamed to src/
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container PATH-01

## References

- [Decision 0016: Rules adopted from other repositories get new families](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)
- [Lefthook: Configuration](https://lefthook.dev/configuration/)
- [Lefthook: glob_matcher](https://lefthook.dev/configuration/glob_matcher/)
- [Lefthook: jobs](https://lefthook.dev/configuration/jobs/)
