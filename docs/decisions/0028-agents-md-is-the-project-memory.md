---
title: AGENTS.md is the project memory, and no CLAUDE.md is committed
date: 2026-10-03
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0028 — AGENTS.md is the project memory, and no CLAUDE.md is committed

## Context

[EC-0013](../../engineering-conventions/definitions/conventions/agents/agent-context.md) was written when Claude Code
read only `CLAUDE.md`. It made `CLAUDE.md` the project memory, the contract an agent loads at launch, and gave every
other agent (Codex, Gemini, Cursor, Copilot) a root `AGENTS.md` that only pointed at it (AGENT-06, AGENT-08). Every
repository therefore kept two files for one contract, and an agent other than Claude Code had to follow a pointer to
reach any of it.

Claude Code 2.1.277 reads `AGENTS.md` itself, as project memory, with the same `@path` imports and the same
path-scoped rules under `.claude/rules/` beside it. One rule decides between the two names: when a `CLAUDE.md` or
`CLAUDE.local.md` exists in the working directory or above it, Claude Code reads the `CLAUDE.md` files and ignores
every `AGENTS.md`. A repository that keeps both therefore gives Claude Code one contract and every other agent
another.

## Decision

**`AGENTS.md` at the repository root is the project memory, and no `CLAUDE.md` is committed.**

- AGENT-15: the project memory is one `AGENTS.md`, at the root. `.claude/AGENTS.md`, which Claude Code also loads, is
  reported. An `AGENTS.md` below the root holds instructions for its directory and is allowed.
- AGENT-16: no `CLAUDE.md` is committed, at any depth or as `.claude/CLAUDE.md`.
- AGENT-17 and AGENT-18 ask of an `AGENTS.md` what AGENT-02 and AGENT-05 asked of a `CLAUDE.md`: it imports the
  README beside it, and its imports resolve.
- AGENT-04's budget counts what Claude Code loads: the root `AGENTS.md`, or a committed `CLAUDE.md` while one remains.
- AGENT-01, AGENT-02, AGENT-05, AGENT-06 and AGENT-08 are retired with those successors. AGENT-03 and AGENT-07 are
  unchanged.
- The minimum Claude Code version, 2.1.277, is stated in EC-0013. Nothing checks it.

This repository moves its own `CLAUDE.md` into `AGENTS.md` in the same change.

## Consequences

### Positive

- One file holds the contract, and every agent reads the same one.
- `AGENTS.md` is a name every agent recognises, so a repository needs no router and no explanation of Claude Code's
  import syntax for other tools.
- Per-directory instructions are an `AGENTS.md` beside the code, which other agents read too, rather than a nested
  `CLAUDE.md` only Claude Code reads.

### Negative

- Every repository with a `CLAUDE.md` gets AGENT-16 findings until it moves the file, and that is a breaking change
  (`feat!`).
- A contributor on Claude Code before 2.1.277 starts with no project memory. The release note and EC-0013 say so.
- Claude Code's `InstructionsLoaded` hook does not fire for `AGENTS.md` read through the setting that loads it, so a
  repository that relies on that hook sees one less event.

### Neutral

- `.claude/rules/`, skills, subagents, hooks and settings stay under `.claude/`; only the memory file's name changes.
- Other agents read `@README.md` as a path to open, which is what the line means to them.

## Enforcement

- AGENT-15, AGENT-16, AGENT-17 and AGENT-18 in `checks/rego/agents/agent_context.rego`, with fixtures
  `agent-15-*` to `agent-18-*`, each with a near-miss.
- The runner embeds the text of every `AGENTS.md` at any depth (`bin/conventions` `TEXTS`), so imports in a nested
  file are checked.
- `task conventions:self` holds this repository to it.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Keep `CLAUDE.md` canonical with an `AGENTS.md` router | No change | rejected: two files for one contract, and the router is redundant now that Claude Code reads `AGENTS.md` |
| Allow either name as the memory file | Let each repository choose | rejected: a reader and a tool would have to check both names in every repository, and the shadowing rule makes mixing them silently wrong |
| `CLAUDE.md` that imports `@AGENTS.md` | Claude Code's documented bridge for older versions | rejected: it keeps a second file that exists only to point at the first |
| `AGENTS.md` only | One file every agent reads | **chosen** |

## References

- [Claude Code: AGENTS.md](https://code.claude.com/docs/en/memory#agents-md)
- [AGENTS.md](https://agents.md/)
- [EC-0013 Agent context](../../engineering-conventions/definitions/conventions/agents/agent-context.md)
