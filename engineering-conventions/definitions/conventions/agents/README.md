# Agents

These conventions govern a repository's agent context: the files that give a coding agent its instructions. Every
agent reads `AGENTS.md`; Claude Code (2.1.277 or later) also loads the rules under `.claude/rules/`, and reads skills
under `.claude/skills/` and subagents under `.claude/agents/` from their frontmatter.

The governing rule, in one sentence:

> **Keep one `AGENTS.md` at the root that imports the README, commit no `CLAUDE.md`, and scope every rule to the files
> it governs.**

A repository with no agent context meets every requirement; they apply once the files exist.

## Status

Both conventions are **drafts**, owned by this repository, and every requirement is `proposed` at severity
`warning`. EC-0013 adopts `musher-dev/platform`'s memory-file checks MF-01 to MF-03.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0013 Agent context](agent-context.md) | AGENT-03, AGENT-04, AGENT-07, AGENT-15 – AGENT-18 | `AGENTS.md` as the project memory, no `CLAUDE.md`, imports, path-scoped rules, the launch budget and personal files |
| [EC-0034 Skills and subagents](skills-and-subagents.md) | AGENT-09 – AGENT-14 | Skill and subagent frontmatter, skill names, and the skills a subagent preloads |

## Quick reference

| File | Rule |
| --- | --- |
| `AGENTS.md` | One, at the root, and none in `.claude/` (AGENT-15); imports the README (AGENT-17) |
| Any nested `AGENTS.md` | Imports the README beside it, if there is one (AGENT-17) |
| `CLAUDE.md`, `.claude/CLAUDE.md`, at any depth | Never committed: it hides every `AGENTS.md` from Claude Code (AGENT-16) |
| `.claude/rules/**/*.md` | A non-empty `paths:` list in its frontmatter (AGENT-03) |
| Project memory, its imports, unscoped rules | 40 KiB in total (AGENT-04) |
| `@path` in an `AGENTS.md` | Names a file in the repository (AGENT-18) |
| `CLAUDE.local.md`, `.claude/settings.local.json` | Never committed (AGENT-07) |
| `.claude/skills/*/SKILL.md`, `.claude/agents/**/*.md` | Frontmatter that parses (AGENT-09) |
| `.claude/skills/*/SKILL.md` | Valid against the skill schema (AGENT-10); `name` is the directory's (AGENT-11) |
| `.claude/agents/**/*.md` | Valid against the subagent schema (AGENT-12); each `skills:` entry exists (AGENT-13) and is not manual-only (AGENT-14) |
