---
id: EC-0013
title: Agent context
summary: >-
  The files that give a coding agent its instructions: one AGENTS.md at the
  root as the project memory, importing the README, no CLAUDE.md beside it,
  path-scoped rules, an always-loaded context kept under 40 KiB, imports
  that resolve, and no personal agent files in git.
status: draft
topic: agents
applies_to:
  paths:
    - "**/CLAUDE.md"
    - "**/AGENTS.md"
    - "**/CLAUDE.local.md"
    - .claude/AGENTS.md
    - .claude/CLAUDE.md
    - .claude/rules/**
    - .claude/settings.local.json
created: 2026-09-28
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
implementations:
  - repo: musher-dev/platform
    check: MF-01
    mode: blocking
  - repo: musher-dev/platform
    check: MF-02
    mode: blocking
  - repo: musher-dev/platform
    check: MF-03
    mode: blocking
references:
  - title: "Claude Code: How Claude remembers your project"
    url: https://code.claude.com/docs/en/memory
  - title: "AGENTS.md"
    url: https://agents.md/
requirements:
  - id: AGENT-01
    title: Project memory is one file, CLAUDE.md or .claude/CLAUDE.md
    status: retired
    severity: warning
    since: 0.6.0
    replaced_by: [AGENT-15, AGENT-16]
    validation:
      engine: conftest
      package: conventions.checks.agents.agent_context
  - id: AGENT-02
    title: A CLAUDE.md with a README beside it imports that README
    status: retired
    severity: warning
    since: 0.6.0
    replaced_by: [AGENT-17]
    validation:
      engine: conftest
      package: conventions.checks.agents.agent_context
    aliases: ["platform:MF-01"]
  - id: AGENT-03
    title: Every rule under .claude/rules/ is scoped by a non-empty paths list
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.agents.agent_context
    aliases: ["platform:MF-02"]
  - id: AGENT-04
    title: The context loaded at every launch is at most 40 KiB
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.agents.agent_context
    aliases: ["platform:MF-03"]
  - id: AGENT-05
    title: Every import in a CLAUDE.md names a file in the repository
    status: retired
    severity: warning
    since: 0.6.0
    replaced_by: [AGENT-18]
    validation:
      engine: conftest
      package: conventions.checks.agents.agent_context
  - id: AGENT-06
    title: A repository with agent context has one AGENTS.md, at its root
    status: retired
    severity: warning
    since: 0.6.0
    replaced_by: [AGENT-15]
    validation:
      engine: conftest
      package: conventions.checks.agents.agent_context
  - id: AGENT-07
    title: Personal agent files are never committed
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.agents.agent_context
  - id: AGENT-08
    title: AGENTS.md points at the agent context and restates none of it
    status: retired
    severity: warning
    since: 0.6.0
    replaced_by: [AGENT-17]
    validation:
      engine: review
  - id: AGENT-15
    title: The project memory is one AGENTS.md, at the repository root
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.agents.agent_context
  - id: AGENT-16
    title: No CLAUDE.md is committed
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.agents.agent_context
  - id: AGENT-17
    title: An AGENTS.md with a README beside it imports that README
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.agents.agent_context
    aliases: ["platform:MF-01"]
  - id: AGENT-18
    title: Every import in an AGENTS.md names a file in the repository
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.agents.agent_context
---

# Agent context

A coding agent works from the instructions a repository gives it. Claude Code, Codex, Gemini, Cursor and Copilot all
read `AGENTS.md`; Claude Code also reads the files it imports and the rules under `.claude/rules/` that match the
files it works on. Together these files are the repository's agent context.

Each of them costs context on every session that loads it, and each is a second place a fact can be written. This
convention keeps the set small, single-sourced and shared: one `AGENTS.md` at the root that every agent reads, which
imports the README rather than copying it, rules that load only where they apply, and a ceiling on what loads every
time.

## Scope

This convention covers the agent context a repository commits: `AGENTS.md` at any depth, `.claude/AGENTS.md`,
`CLAUDE.md` at any depth, `.claude/CLAUDE.md`, `.claude/rules/**/*.md`, and the personal files that must stay out of
git. A repository with none of these files meets every requirement. What the instructions say is the repository's own
business, and how Claude Code loads them is defined by its documentation, which this convention cites rather than
restates.

`AGENTS.md` as Claude Code's project memory needs **Claude Code 2.1.277 or later**; an older version reads only
`CLAUDE.md` and starts with no project memory at all. Nothing here can check the version a contributor runs, so a
repository that adopts this convention says so where it lists its tools.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). AGENT-17, AGENT-03 and AGENT-04 adopt
`musher-dev/platform`'s MF-01, MF-02 and MF-03, which retire there once a release carries them
([decision 0016](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)).
Its requirements are `proposed` at severity `warning`, like every requirement in the 0.x series.

Until 0.8.0 the project memory was `CLAUDE.md`, and `AGENTS.md` was a router that pointed other agents at it.
AGENT-01, AGENT-02, AGENT-05, AGENT-06 and AGENT-08 were written for that layout and are retired; AGENT-15 to AGENT-18
replace them ([decision 0028](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0028-agents-md-is-the-project-memory.md)).

## How Claude Code loads the files

The requirements depend on these behaviours of Claude Code, from its
[memory documentation](https://code.claude.com/docs/en/memory):

| Behaviour | Consequence here |
| --- | --- |
| From 2.1.277, `AGENTS.md` and `.claude/AGENTS.md` are project memory, loaded at launch | One `AGENTS.md`, at the root (AGENT-15) |
| A `CLAUDE.md` or `CLAUDE.local.md` in the working directory or above it replaces every `AGENTS.md`: Claude Code then reads the `CLAUDE.md` files only | No `CLAUDE.md` is committed (AGENT-16) |
| `@path` imports a file into the importing file's context at launch, in `AGENTS.md` as in `CLAUDE.md`; a relative path resolves from the importing file, and imports nest to four hops | The README is imported, not copied (AGENT-17); imports count toward the budget (AGENT-04) and must resolve (AGENT-18) |
| An `@path` inside a code span or fenced block is not an import | Write a literal `@name` in backticks |
| Rules under `.claude/rules/` load alongside `AGENTS.md`; a rule without `paths` frontmatter, or with frontmatter that does not parse, loads at launch with the project memory | Every rule is scoped (AGENT-03) |
| A nested `AGENTS.md` loads only when the agent reads a file in its directory | Only the project memory and its imports count toward the budget |
| `CLAUDE.local.md` and `.claude/settings.local.json` are one person's preferences | They stay out of git (AGENT-07) |

Agents other than Claude Code read `AGENTS.md` as text and do not expand an `@path`: to them `@README.md` is a pointer
to a file to open, which is what it should be.

## Requirements

### AGENT-01

**Project memory is one file, `CLAUDE.md` or `.claude/CLAUDE.md`.**

Retired in 0.8.0 and replaced by [AGENT-15](#agent-15) and [AGENT-16](#agent-16). The project memory is now one
`AGENTS.md`, and a `CLAUDE.md` in either place is itself the finding.

Checked by: nothing (retired) · Severity: warning · Since: 0.6.0

### AGENT-02

**A `CLAUDE.md` with a README beside it imports that README.**

Retired in 0.8.0 and replaced by [AGENT-17](#agent-17), which asks the same of an `AGENTS.md`.

Checked by: nothing (retired) · Severity: warning · Since: 0.6.0 · Formerly: platform MF-01

### AGENT-03

**Every rule under `.claude/rules/` is scoped by a non-empty `paths` list.**

A rule without `paths` loads into every session at launch, whether or not the session touches what it governs, and a
rule whose frontmatter does not parse loads the same way. A directory of unscoped rules fills the context before any
work starts: it slows every session and can leave a subagent no room at all. `paths` takes a list of globs, or one
comma-separated string, naming the files the rule is about.

**Correct:**

```markdown
---
paths:
  - "src/api/**"
---

# API rules
```

**Incorrect:**

```markdown
# API rules
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform MF-02

### AGENT-04

**The context loaded at every launch is at most 40 KiB.**

The project memory, everything it imports, and any rule without `paths` load in every session and every subagent,
before the agent reads a line of the task. The ceiling, 40,960 bytes or about ten thousand tokens, keeps that set
from growing one import at a time. The check counts what Claude Code would load: the root `AGENTS.md` and
`.claude/AGENTS.md`, or, when a root `CLAUDE.md` or `.claude/CLAUDE.md` is committed, those instead (AGENT-16 reports
them); the files they import to four hops, resolved from the importing file; and each unscoped rule. Imports are
followed through the agent-context files the check reads (`AGENTS.md`, `CLAUDE.md` and rules), and only Markdown files
have a recorded size, so an imported file of another type counts as 0 bytes. An import from the home directory
(`@~/...`) is personal and is not counted. The message lists each file and its size.

**Correct:**

```text
AGENTS.md (3 KiB) + README.md (12 KiB), every rule scoped
```

**Incorrect:**

```text
AGENTS.md (6 KiB) + README.md (12 KiB) + docs/architecture.md (30 KiB)
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform MF-03

### AGENT-05

**Every import in a `CLAUDE.md` names a file in the repository.**

Retired in 0.8.0 and replaced by [AGENT-18](#agent-18), which checks the imports in an `AGENTS.md`.

Checked by: nothing (retired) · Severity: warning · Since: 0.6.0

### AGENT-06

**A repository with agent context has one `AGENTS.md`, at its root.**

Retired in 0.8.0 and replaced by [AGENT-15](#agent-15). The root `AGENTS.md` is now the project memory rather than a
router beside it, and a nested `AGENTS.md` is per-directory instructions, the place a nested `CLAUDE.md` used to be.

Checked by: nothing (retired) · Severity: warning · Since: 0.6.0

### AGENT-07

**Personal agent files are never committed.**

`.claude/settings.local.json` holds one person's permissions and settings, and `CLAUDE.local.md` one person's
instructions. Committed, they apply to everyone who clones the repository: a permission one person granted
themselves becomes a permission for every contributor's agent. Add both to `.gitignore`; the project's shared
settings go in `.claude/settings.json` and its shared instructions in the project memory.

**Correct:**

```gitignore
.claude/settings.local.json
CLAUDE.local.md
```

**Incorrect:**

```text
.claude/settings.local.json   # tracked
```

Checked by: conftest · Severity: warning · Since: 0.6.0

### AGENT-08

**`AGENTS.md` points at the agent context and restates none of it.**

Retired in 0.8.0 and replaced by [AGENT-17](#agent-17). `AGENTS.md` is no longer a router to a `CLAUDE.md`: it is the
contract, and it imports the README instead of restating it.

Checked by: nothing (retired) · Severity: warning · Since: 0.6.0

### AGENT-15

**The project memory is one `AGENTS.md`, at the repository root.**

Every coding agent reads `AGENTS.md`, so one file at the root gives each of them the same contract. A repository with
any agent context, an `AGENTS.md` below the root, a `CLAUDE.md` or a rule under `.claude/rules/`, keeps that file at
the root. `.claude/AGENTS.md` is reported too: Claude Code loads it beside the root file, so the contract would be
split across two files and a change made to one would leave the other stale. An `AGENTS.md` below the root is fine:
it holds the instructions for its directory, and an agent reads it when it works there.

**Correct:**

```text
AGENTS.md
README.md
apps/api/AGENTS.md
```

**Incorrect:**

```text
.claude/AGENTS.md          # not at the root
apps/api/AGENTS.md         # and nothing at the root
```

Checked by: conftest · Severity: warning · Since: 0.8.0

### AGENT-16

**No `CLAUDE.md` is committed.**

When Claude Code finds a `CLAUDE.md` in the working directory or above it, it reads the `CLAUDE.md` files and ignores
every `AGENTS.md`. One committed `CLAUDE.md`, at any depth or as `.claude/CLAUDE.md`, therefore splits the agents: Claude
Code follows one contract and every other agent another. Move what it says into the `AGENTS.md` beside it, and keep
anything that only Claude Code understands, such as a rule or a skill, under `.claude/`.

**Correct:**

```text
AGENTS.md
.claude/rules/api.md
```

**Incorrect:**

```text
AGENTS.md
CLAUDE.md                  # Claude Code now ignores AGENTS.md
```

Checked by: conftest · Severity: warning · Since: 0.8.0

### AGENT-17

**An `AGENTS.md` with a README beside it imports that README.**

The README is orientation for people and agents alike: what the directory is, how to run it, where things are. When
an `AGENTS.md` copies that orientation instead of importing it, the two drift the first time one is edited. Importing
it writes the orientation once, and the `AGENTS.md` adds only the contract: the rules for changing the directory.
Claude Code expands the import; another agent reads `@README.md` as the file to open. An `AGENTS.md` with no README
beside it stands alone; do not create a README only to import it.

**Correct:**

```markdown
# API

@README.md

## Rules for changes
```

**Incorrect:**

```markdown
# API

Run `task dev` to start the server on port 8080.
```

Checked by: conftest · Severity: warning · Since: 0.8.0 · Formerly: platform MF-01

### AGENT-18

**Every import in an `AGENTS.md` names a file in the repository.**

Claude Code skips an import it cannot find without saying so, so a moved or misspelled file silently drops what the
agent was meant to read. An `@path` outside code that names a file with an extension is checked; a handle
(`@octocat`), an npm scope (`@testing-library`) or a directory (`@docs/routes/`) is not, because prose mentions those
far more often than it imports them. An import resolves from the file that holds it, so `@docs/api.md` in
`apps/api/AGENTS.md` names `apps/api/docs/api.md`. An import that climbs out of the repository depends on one
person's checkout and is reported too; an import from the home directory (`@~/...`) is personal by design and is
skipped.

**Correct:**

```markdown
@README.md
See @docs/testing.md before changing a test. Ask @octocat about releases.
```

**Incorrect:**

```markdown
@docs/tesing.md
Ask @octocat about releases.
```

Checked by: conftest · Severity: warning · Since: 0.8.0

## References

- [Claude Code: How Claude remembers your project](https://code.claude.com/docs/en/memory)
- [Claude Code: AGENTS.md](https://code.claude.com/docs/en/memory#agents-md)
- [AGENTS.md](https://agents.md/)
- [Decision 0016: Rules adopted from other repositories get new families](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)
- [Decision 0028: AGENTS.md is the project memory](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0028-agents-md-is-the-project-memory.md)
