# Tasks

These conventions govern a repository's [Taskfiles](https://taskfile.dev): how each one is written, and which tasks
every repository answers to from its root.

The governing rule, in one sentence:

> **Write every Taskfile in Task's own style, name only things that exist, and define `setup`, `check` and `lint` at
> the root, plus the verbs your kind of repository needs.**

## Status

Both conventions are **drafts**, owned by this repository, and every requirement is `proposed` at severity `warning`.
They adopt the Taskfile rules of `musher-dev/platform` (TF-*) and one path rule of
`musher-dev/development-container` (PATH-03); each requirement lists the upstream IDs it replaces in `aliases`.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0015 Taskfile style](taskfile-style.md) | TASK-01 – TASK-09, TASK-14 – TASK-28 | Version, names, templates, descriptions, internal tasks, output prefixes, paths, includes and sources that exist, the default task, machine-specific paths, prompts before destroying data, fragments, tool wrappers, silent tasks, opt-in prefixed output and caching with `sources` |
| [EC-0016 Task interface](task-interface.md) | TASK-10 – TASK-13 | The verbs the root Taskfile defines, by kind of repository, and what `check` runs |

## Quick reference

| Verb | Every repository | `library`, `tool`, `website` | `service` |
| --- | --- | --- | --- |
| `setup`, `check`, `lint` | yes | yes | yes |
| `build`, `test` | | yes | yes |
| `dev` | | | yes |

A repository with several tools may split its Taskfiles into [layers](taskfile-style.md#layers): rules in
`.config/<concern>/`, one internal wrapper per tool in `taskfiles/tools/<tool>.Taskfile.yml` named `tool:<tool>`
(TASK-25), area fragments in `taskfiles/<area>.Taskfile.yml` whose tasks are named for the area (TASK-27), and the
verbs at the root. Once a tool has a wrapper, nothing else runs its binary (TASK-26, HOOKS-15).

Layout (key order, indentation, blank lines) follows [Task's style guide](https://taskfile.dev/docs/styleguide) and is
left to a formatter; it is not a requirement.
