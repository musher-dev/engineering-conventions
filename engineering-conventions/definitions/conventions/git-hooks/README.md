# Git hooks

These conventions govern a repository's git hooks: the checks that run on a contributor's machine before a commit or
a push leaves it. Hooks are the earliest copy of the checks CI runs, never a different set, and they are only useful
while they are fast and while a failure in them is real.

The governing rule, in one sentence:

> **A hook either runs and can fail, or it tells you it did not run; it never passes by doing nothing.**

The conventions apply to a repository that runs its hooks with [lefthook](https://lefthook.dev). A repository with no
lefthook configuration is not asked to add one.

## Status

The convention is a **draft**, owned by this repository, and every requirement is `proposed` at severity `warning`.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0014 Lefthook configuration](lefthook.md) | HOOKS-01 – HOOKS-14 | The settings every configuration carries, its globs, its jobs, what may run before a commit, and how a job restages, which stage it runs in and what it calls |

The reasoning for adopting these from `musher-dev/platform` and `musher-dev/development-container` is recorded in
[decision 0016](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md).

## Quick reference

```yaml
# .config/lefthook.yml
assert_lefthook_installed: true      # HOOKS-01
min_version: "2.1.14"                # HOOKS-02: the version mise installs
glob_matcher: doublestar             # HOOKS-03

pre-commit:
  jobs:                              # HOOKS-05
    - name: markdown
      glob: "**/*.md"                # HOOKS-04, HOOKS-11
      run: markdownlint-cli2 --fix {staged_files}
      stage_fixed: true              # HOOKS-07: the job fixes
      fail_text: "Markdown lint failed. Run 'task lint:md'."   # HOOKS-06

pre-push:
  jobs:
    - name: test                     # HOOKS-08: tests run here, not in pre-commit
      run: task test
      fail_text: "Tests failed. Run 'task test'."
```

No `remotes:` or `extends:` (HOOKS-09), and no `|| true` in a `run:` (HOOKS-10).
