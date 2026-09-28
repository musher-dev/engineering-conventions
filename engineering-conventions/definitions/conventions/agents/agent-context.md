---
id: EC-0013
title: Agent context
summary: >-
  The files that give a coding agent its instructions: one project memory
  file that imports the README, path-scoped rules, an always-loaded context
  kept under 40 KiB, imports that resolve, one AGENTS.md at the root, and no
  personal agent files in git.
status: draft
topic: agents
applies_to:
  paths:
    - "**/CLAUDE.md"
    - "**/AGENTS.md"
    - "**/CLAUDE.local.md"
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
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.agents.agent_context
  - id: AGENT-02
    title: A CLAUDE.md with a README beside it imports that README
    status: proposed
    severity: warning
    since: 0.6.0
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
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.agents.agent_context
  - id: AGENT-06
    title: A repository with agent context has one AGENTS.md, at its root
    status: proposed
    severity: warning
    since: 0.6.0
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
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: review
---

# Agent context

A coding agent works from the instructions a repository gives it. Claude Code reads a project memory file,
`CLAUDE.md`, at every launch, the files it imports, and the rules under `.claude/rules/` that match the files it
works on. Other agents read `AGENTS.md`. Together these files are the repository's agent context.

Each of them costs context on every session that loads it, and each is a second place a fact can be written. This
convention keeps the set small, single-sourced and shared: one project memory file that imports the README rather
than copying it, rules that load only where they apply, a ceiling on what loads every time, and one router for every
other agent.

## Scope

This convention covers the agent context a repository commits: `CLAUDE.md` at any depth, `.claude/CLAUDE.md`,
`.claude/rules/**/*.md`, `AGENTS.md`, and the personal files that must stay out of git. A repository with none of
these files meets every requirement. What the instructions say is the repository's own business, and how Claude
Code loads them is defined by its documentation, which this convention cites rather than restates.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). AGENT-02, AGENT-03 and AGENT-04 adopt
`musher-dev/platform`'s MF-01, MF-02 and MF-03, which retire there once a release carries them
([decision 0016](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)).
Its requirements are `proposed` at severity `warning`, like every requirement in the 0.x series.

## How Claude Code loads the files

The requirements depend on these behaviours of Claude Code, from its
[memory documentation](https://code.claude.com/docs/en/memory):

| Behaviour | Consequence here |
| --- | --- |
| Project memory is `./CLAUDE.md` or `./.claude/CLAUDE.md`, loaded at launch | One of the two, not both (AGENT-01) |
| `@path` imports a file into the importing file's context at launch; a relative path resolves from the importing file, and imports nest to four hops | The README is imported, not copied (AGENT-02); imports count toward the budget (AGENT-04) and must resolve (AGENT-05) |
| An `@path` inside a code span or fenced block is not an import | Write a literal `@name` in backticks |
| A rule without `paths` frontmatter, or with frontmatter that does not parse, loads at launch with the project memory | Every rule is scoped (AGENT-03) |
| A nested `CLAUDE.md` loads only when the agent reads a file in its directory | Only the project memory and its imports count toward the budget |
| `CLAUDE.local.md` and `.claude/settings.local.json` are one person's preferences | They stay out of git (AGENT-07) |

## Requirements

### AGENT-01

**Project memory is one file, `CLAUDE.md` or `.claude/CLAUDE.md`.**

Claude Code loads both locations at launch. Two files split the contract, so a reader who opens one misses the
other, and a change made to one leaves the other stale. Pick one; `.claude/CLAUDE.md` keeps the root clean, and
`CLAUDE.md` is where people look first.

**Correct:**

```text
CLAUDE.md
README.md
```

**Incorrect:**

```text
CLAUDE.md
.claude/CLAUDE.md
```

Checked by: conftest · Severity: warning · Since: 0.6.0

### AGENT-02

**A `CLAUDE.md` with a README beside it imports that README.**

The README is orientation for people and agents alike: what the directory is, how to run it, where things are. When
a `CLAUDE.md` copies that orientation instead of importing it, the two drift the first time one is edited. Importing
it writes the orientation once, and the `CLAUDE.md` adds only the contract: the rules for changing the directory. The
project memory file `.claude/CLAUDE.md` pairs with the root README and imports it as `@../README.md`. A `CLAUDE.md`
with no README beside it stands alone; do not create a README only to import it.

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

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform MF-01

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
from growing one import at a time. The check adds the project memory file, the files it imports to four hops,
resolved from the importing file, and each unscoped rule. Imports are followed through the agent-context files the
check reads (`CLAUDE.md`, `AGENTS.md` and rules), and only Markdown files have a recorded size, so an imported file of
another type counts as 0 bytes. An import from the home directory (`@~/...`) is personal and is not counted. The
message lists each file and its size.

**Correct:**

```text
CLAUDE.md (3 KiB) + README.md (12 KiB), every rule scoped
```

**Incorrect:**

```text
CLAUDE.md (6 KiB) + README.md (12 KiB) + docs/architecture.md (30 KiB)
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform MF-03

### AGENT-05

**Every import in a `CLAUDE.md` names a file in the repository.**

Claude Code skips an import it cannot find without saying so, so a moved or misspelled file silently drops what the
agent was meant to read. An `@path` outside code that names a file with an extension is checked; a handle
(`@octocat`), an npm scope (`@testing-library`) or a directory (`@docs/routes/`) is not, because prose mentions those
far more often than it imports them. An import resolves from the file that holds it, so `@.claude/CLAUDE.md` in
`.github/CLAUDE.md` names `.github/.claude/CLAUDE.md`. An import that climbs out of the repository depends on one
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

Checked by: conftest · Severity: warning · Since: 0.6.0

### AGENT-06

**A repository with agent context has one `AGENTS.md`, at its root.**

Agents other than Claude Code read `AGENTS.md`, not `CLAUDE.md`. A repository with project memory gives them a way in
with one `AGENTS.md` at the root that points at it. An `AGENTS.md` anywhere else, `.claude/AGENTS.md` included, is a
second hierarchy of instructions beside the `CLAUDE.md` files: the same directory would carry two contracts, and the
agents that read each would follow different ones. Per-directory instructions go in a nested `CLAUDE.md` or a
path-scoped rule.

**Correct:**

```text
AGENTS.md
CLAUDE.md
apps/api/CLAUDE.md
```

**Incorrect:**

```text
CLAUDE.md                  # no AGENTS.md at the root
apps/api/AGENTS.md
```

Checked by: conftest · Severity: warning · Since: 0.6.0

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

`AGENTS.md` is a router. It names the project memory, the rules directory, the commands that verify a change and
where the commit conventions live, and it says that `@path` lines are Claude Code imports, so another agent opens the
file they name. A rule copied into it is a second copy that drifts from the first. The reviewer checks that each
section of `AGENTS.md` is a pointer, and that a change to the project memory's structure updates the pointers in the
same pull request.

**Correct:**

```markdown
- [`CLAUDE.md`](CLAUDE.md): the contract for changes. It imports `@README.md`; open README.md directly.
- [`.claude/rules/`](.claude/rules/): the rules for each part, by the files they govern.
```

**Incorrect:**

```markdown
- Never push to the default branch.
- Every Rego check ships a fixture.
```

Checked by: review · Severity: warning · Since: 0.6.0

## References

- [Claude Code: How Claude remembers your project](https://code.claude.com/docs/en/memory)
- [AGENTS.md](https://agents.md/)
- [Decision 0016: Rules adopted from other repositories get new families](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)
