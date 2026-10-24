---
title: Each tool runs from one internal wrapper task, and a cached task lists every input it has
date: 2026-10-24
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0038 — Each tool runs from one internal wrapper task, and a cached task lists every input it has

## Context

[EC-0011](../../engineering-conventions/definitions/conventions/configuration/tool-configuration.md) puts each tool's
rules in `.config/<concern>/`, and [EC-0015](../../engineering-conventions/definitions/conventions/tasks/taskfile-style.md)
lets a repository split its Taskfile into `taskfiles/<area>.Taskfile.yml` fragments. Neither says where a tool's
command line lives. In practice it is written more than once: in an area task, again in a lefthook job over the
staged files, and sometimes a third time in a workflow. The copies drift. A severity flag such as yamllint's
`--strict` or Regal's `--fail-level` is set in one and not another, so a hook passes what CI fails. Task names drift
from the files that hold them too: this repository's `secrets:scan` lives in `lint.Taskfile.yml`, and nothing says
it should not.

Nothing is cached either, so every gate reruns on unchanged files. Task can skip a task whose `sources` have not
changed, but its fingerprint is narrow. Tested with Task 3.53.1: it covers the contents of the files `sources`
matches, keyed by base name, and nothing else. A changed command line, variable, `CLI_ARGS` value or environment
variable does not change it; neither does a file moved to another directory under the same name; and a `sources`
list that matches nothing leaves the task up to date after its first run, whatever changes. The same tests found
that a glob ending in `/**` matches every file below its directory, as `/**/*` does, so that form needs no rule.

## Decision

We will describe a repository's task layout as four layers, each with one job: rules in `.config/<concern>/`; how one
tool runs in `taskfiles/tools/<tool>.Taskfile.yml`, one wrapper per tool; which tools make up an area in
`taskfiles/<area>.Taskfile.yml`; and the verbs and environment tasks in the root `Taskfile.yml`. The layers are
optional, and the requirements that hold them apply once a repository has a wrapper:

- TASK-25: a wrapper is included with `flatten: true` and `internal: true`, and its tasks are named `tool:<tool>` or
  `tool:<tool>:<detail>`.
- TASK-26: a tool that has a wrapper runs only in its wrapper.
- TASK-27: a flattened area fragment's public tasks are named under its area.
- HOOKS-15: a lefthook job runs a task, not a tool that has a wrapper.
- TASK-20 no longer reads as forbidding `internal: true` on a wrapper's include; an area fragment is still never
  internal.

We will state in EC-0015 what a cached task lists as `sources`: the files the tool reads, its configuration file,
`.config/mise/mise.lock` and the Taskfiles that define it. A wrapper splits a cached whole-repository run
(`tool:<tool>:all`, `method: checksum`) from an uncached run over the files a hook passes (`tool:<tool>:files`),
sharing one command through a YAML anchor, and `tool:<tool>` chooses between them on `FILES`. A hook passes its files
after `--` (`task lint:yaml -- {staged_files}`), which keeps quoted names intact. A cached task is not silent, so
Task's "is up to date" line shows. A task that reads the network or the git history, or publishes, is left
uncached. TASK-28 asks every `sources` glob to match something the repository holds.

## Consequences

### Positive

- A tool's configuration path, flags and default files are written once, and the hook, the area task and CI run it
  the same way.
- A task's name says which file holds it.
- A gate whose inputs have not changed can be skipped locally, and the list of inputs says why it was.

### Negative

- A repository that adopts the layers has more Taskfiles, and a reader follows one more call to find a command line.
- A cached task whose `sources` miss an input skips when it should not. `task --force` is the remedy, and a local
  up-to-date result is never evidence that a gate passed.

### Neutral

- A repository with a few tools may keep each command in its area fragment; TASK-25, TASK-26 and HOOKS-15 do not
  apply to it.

## Enforcement

TASK-25 to TASK-28 in `conventions.checks.tasks.taskfile_fragments` and `conventions.checks.tasks.taskfile_style`,
and HOOKS-15 in `conventions.checks.git_hooks.lefthook`, each with a fixture and a near-miss. Whether a cached task's
`sources` list every input it reads is review-only: a reviewer compares the list with the files and flags the
command reads.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| A | Keep command lines in the area fragments, and only ask hooks to call tasks | rejected: an area task and a fixer for the same tool still write two command lines |
| B | One internal wrapper per tool, called by area tasks and hooks | **chosen** |
| C | A shell script per tool under `.github/scripts/` | rejected: Task already passes variables and fingerprints sources; a script would duplicate both |
| D | A templated `method: '{{if .FILES}}none{{else}}checksum{{end}}'` on one task | rejected: Task runs it, but its schema allows only `none`, `checksum` or `timestamp`, so a schema check refuses the Taskfile |
| E | Require every glob ending in `/**` to be written `/**/*` | rejected: tested with Task 3.53.1, both forms match the same files |

## References

- [EC-0015 Taskfile style: Layers](../../engineering-conventions/definitions/conventions/tasks/taskfile-style.md#layers)
- [EC-0014 Lefthook configuration](../../engineering-conventions/definitions/conventions/git-hooks/lefthook.md#hooks-15)
- [Task: Prevent unnecessary work](https://taskfile.dev/docs/guide#prevent-unnecessary-work)
