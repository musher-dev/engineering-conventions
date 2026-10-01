---
id: EC-0034
title: Skills and subagents
summary: >-
  The skills and subagents a repository gives Claude Code: frontmatter that
  parses as YAML, skill frontmatter valid against the Agent Skills fields and
  Claude Code's, a skill named for its directory, subagent frontmatter valid
  against Claude Code's fields, and preloaded skills that exist and that the
  model may invoke.
status: draft
topic: agents
applies_to:
  paths:
    - "**/.claude/skills/*/SKILL.md"
    - "**/.claude/agents/**/*.md"
created: 2026-10-01
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "Agent Skills: Specification"
    url: https://agentskills.io/specification
  - title: "Claude Code: Extend Claude with skills"
    url: https://code.claude.com/docs/en/skills
  - title: "Claude Code: Create custom subagents"
    url: https://code.claude.com/docs/en/sub-agents
requirements:
  - id: AGENT-09
    title: A skill or subagent file starts with YAML frontmatter that parses
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.agents.skills_and_subagents
  - id: AGENT-10
    title: A skill's frontmatter is valid against the skill schema
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.agents.skills_and_subagents
  - id: AGENT-11
    title: A skill's name, when set, is its directory's name
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.agents.skills_and_subagents
  - id: AGENT-12
    title: A subagent's frontmatter is valid against the subagent schema
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.agents.skills_and_subagents
  - id: AGENT-13
    title: Every skill a subagent preloads is a skill in the repository
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.agents.skills_and_subagents
  - id: AGENT-14
    title: A subagent does not preload a skill that disables model invocation
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.agents.skills_and_subagents
---

# Skills and subagents

A skill is a directory under `.claude/skills/` whose `SKILL.md` tells an agent what the skill does and when to use
it. A subagent is a Markdown file under `.claude/agents/` that Claude Code can delegate a task to, and it can preload
skills into its context. Both are read from YAML frontmatter, and both fail quietly: a field Claude Code does not
understand is ignored, and a skill a subagent names but cannot find is skipped with a line in the debug log. Nothing
in a session shows that the instruction was lost.

This convention makes those failures visible. The frontmatter parses, holds only fields its readers define, and the
names in it resolve.

## Scope

This convention covers `.claude/skills/<name>/SKILL.md` and every Markdown file below `.claude/agents/`, at the root
or in a nested directory of a monorepo. A skill's other files (`references/`, scripts) are not read. What a skill or
subagent instructs is the repository's own business. Claude Code's commands (`.claude/commands/`) and plugins are
outside it. A file larger than 256 KiB is not read (decision 0015), so the checks say nothing about it.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). The fields themselves are defined by the
[Agent Skills specification](https://agentskills.io/specification) and by Claude Code's documentation for
[skills](https://code.claude.com/docs/en/skills) and [subagents](https://code.claude.com/docs/en/sub-agents); the
schemas name each field and where it comes from, and cite rather than restate what it does. Its requirements are
`proposed` at severity `warning`, like every requirement in the 0.x series.

## The schemas

| File | Fields it accepts |
| --- | --- |
| `checks/schemas/skill-frontmatter.schema.json` | The Agent Skills fields (`name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`) and the fields Claude Code adds to them |
| `checks/schemas/subagent-frontmatter.schema.json` | The fields Claude Code reads from a subagent |

Each schema refuses a field it does not list. A field of the repository's own, such as a version or an owner, goes
under a skill's `metadata`, a map from string to string. A field a newer Claude Code release adds is added to the
schema in a release of these conventions.

## Requirements

### AGENT-09

**A skill or subagent file starts with YAML frontmatter that parses.**

Every other requirement here reads the parsed frontmatter, and so do the tools that index skills. In YAML an
unquoted value cannot hold a colon followed by a space, so an unquoted description such as
`Use when committing. Triggered by: commit, PR title` is not a string but an error, and a strict parser reads nothing
from the file. A file with no frontmatter gives Claude Code no description to choose it by, and a subagent without
one is skipped. Quote a value that holds a colon and a space, or write it as a folded block.

**Correct:**

```yaml
---
name: writing-commits
description: >-
  Draft Conventional Commit messages. Use when writing a commit. Triggered by: commit, PR title.
---
```

**Incorrect:**

```yaml
---
name: writing-commits
description: Draft Conventional Commit messages. Triggered by: commit, PR title.
---
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### AGENT-10

**A skill's frontmatter is valid against the skill schema.**

An agent decides whether to load a skill from its name and description alone, so they carry limits: a name of
lower-case letters, digits and single hyphens, at most 64 characters, and a description of at most 1024 characters.
A field the schema does not list is read by nothing: a top-level `version:` looks like metadata but no tool reads it
there. Move it under `metadata`, quoted, or remove it. One finding reports the first problem and how many more there
are.

**Correct:**

```yaml
---
name: writing-commits
description: Draft Conventional Commit messages. Use when writing a commit.
metadata:
  version: "1.2.0"
---
```

**Incorrect:**

```yaml
---
name: Writing_Commits                       # upper case and an underscore
description: Draft Conventional Commit messages. Use when writing a commit.
version: 1.2.0                              # not a skill field; goes under metadata
---
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### AGENT-11

**A skill's `name`, when set, is its directory's name.**

The Agent Skills specification requires the two to match, and every other reader of a skill finds it by its
directory. Claude Code answers to both, so a skill named apart from its directory has two names, and a subagent or a
person who uses the wrong one finds nothing. Leave `name` out, or set it to the directory's name.

**Correct:**

```text
.claude/skills/writing-commits/SKILL.md     name: writing-commits
```

**Incorrect:**

```text
.claude/skills/writing-commits/SKILL.md     name: commits
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### AGENT-12

**A subagent's frontmatter is valid against the subagent schema.**

A subagent needs a `name` and a `description`, and Claude Code skips a file whose name starts with a hyphen or holds
a colon. The other fields take fixed shapes: `skills` is a list or a comma-separated string, `maxTurns` a positive
integer, `color` one of eight colours. A misspelled field, such as `allowed-tools` copied from a skill instead of
`tools`, is ignored, and the subagent runs with every tool. One finding reports the first problem and how many more
there are.

**Correct:**

```yaml
---
name: code-reviewer
description: Reviews a diff for correctness. Use after a change is made.
tools: Read, Grep, Glob
skills:
  - writing-commits
---
```

**Incorrect:**

```yaml
---
name: code-reviewer
description: Reviews a diff for correctness. Use after a change is made.
allowed-tools: Read, Grep, Glob             # a skill's field; a subagent's is tools
color: magenta                              # not one of the eight colours
---
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### AGENT-13

**Every skill a subagent preloads is a skill in the repository.**

`skills:` loads each named skill into the subagent's context when it starts. A name that matches no skill is
skipped without a warning, so a renamed or deleted skill leaves the subagent working without the instructions it was
built around. The list may be one comma-separated string. A name resolves to a skill whose directory, or whose
frontmatter `name`, it equals. A plugin's skill, named `plugin:skill`, lives outside the repository and is not
checked.

**Correct:**

```text
.claude/agents/reviewer.md                  skills: [writing-commits]
.claude/skills/writing-commits/SKILL.md
```

**Incorrect:**

```text
.claude/agents/reviewer.md                  skills: [writing-commits]
.claude/skills/commit-messages/SKILL.md     # renamed; nothing is named writing-commits
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### AGENT-14

**A subagent does not preload a skill that disables model invocation.**

`disable-model-invocation: true` keeps a skill for people to run by name. Claude Code preloads only skills the model
may invoke, so a subagent that lists one of these does not get it, and nothing says so. Remove the entry, or remove
the setting from the skill if the subagent should have it.

**Correct:**

```yaml
# .claude/skills/deploy/SKILL.md
disable-model-invocation: true
# .claude/agents/reviewer.md
skills: [writing-commits]
```

**Incorrect:**

```yaml
# .claude/skills/deploy/SKILL.md
disable-model-invocation: true
# .claude/agents/reviewer.md
skills: [deploy]
```

Checked by: conftest · Severity: warning · Since: 0.7.1

## References

- [Agent Skills: Specification](https://agentskills.io/specification)
- [Claude Code: Extend Claude with skills](https://code.claude.com/docs/en/skills)
- [Claude Code: Create custom subagents](https://code.claude.com/docs/en/sub-agents)
- [Decision 0015: The runner reads what conftest cannot select](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0015-the-runner-reads-what-conftest-cannot-select.md)
