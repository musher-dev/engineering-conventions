# Agents

These conventions govern a repository's agent context: the files that give a coding agent its instructions. Claude
Code reads `CLAUDE.md` and the rules under `.claude/rules/`; other agents read `AGENTS.md`. Skills under
`.claude/skills/` and subagents under `.claude/agents/` are read from their frontmatter.

The governing rule, in one sentence:

> **Keep one project memory file that imports the README, scope every rule to the files it governs, and give other
> agents one `AGENTS.md` that points at both.**

A repository with no agent context meets every requirement; they apply once the files exist.

## Status

Both conventions are **drafts**, owned by this repository, and every requirement is `proposed` at severity
`warning`. EC-0013 adopts `musher-dev/platform`'s memory-file checks MF-01 to MF-03.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0013 Agent context](agent-context.md) | AGENT-01 – AGENT-08 | Project memory, imports, path-scoped rules, the launch budget, `AGENTS.md` and personal files |
| [EC-0034 Skills and subagents](skills-and-subagents.md) | AGENT-09 – AGENT-14 | Skill and subagent frontmatter, skill names, and the skills a subagent preloads |

## Quick reference

| File | Rule |
| --- | --- |
| `CLAUDE.md` or `.claude/CLAUDE.md` | One of the two (AGENT-01); imports the README (AGENT-02) |
| Any nested `CLAUDE.md` | Imports the README beside it, if there is one (AGENT-02) |
| `.claude/rules/**/*.md` | A non-empty `paths:` list in its frontmatter (AGENT-03) |
| Project memory, its imports, unscoped rules | 40 KiB in total (AGENT-04) |
| `@path` in a `CLAUDE.md` | Names a file in the repository (AGENT-05) |
| `AGENTS.md` | One, at the root (AGENT-06), made of pointers (AGENT-08) |
| `CLAUDE.local.md`, `.claude/settings.local.json` | Never committed (AGENT-07) |
| `.claude/skills/*/SKILL.md`, `.claude/agents/**/*.md` | Frontmatter that parses (AGENT-09) |
| `.claude/skills/*/SKILL.md` | Valid against the skill schema (AGENT-10); `name` is the directory's (AGENT-11) |
| `.claude/agents/**/*.md` | Valid against the subagent schema (AGENT-12); each `skills:` entry exists (AGENT-13) and is not manual-only (AGENT-14) |
