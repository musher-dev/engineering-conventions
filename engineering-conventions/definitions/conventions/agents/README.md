# Agents

These conventions govern a repository's agent context: the files that give a coding agent its instructions. Claude
Code reads `CLAUDE.md` and the rules under `.claude/rules/`; other agents read `AGENTS.md`.

The governing rule, in one sentence:

> **Keep one project memory file that imports the README, scope every rule to the files it governs, and give other
> agents one `AGENTS.md` that points at both.**

A repository with no agent context meets every requirement; they apply once the files exist.

## Status

The convention is a **draft**, owned by this repository, and every requirement is `proposed` at severity `warning`.
It adopts `musher-dev/platform`'s memory-file checks MF-01 to MF-03.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0013 Agent context](agent-context.md) | AGENT-01 – AGENT-08 | Project memory, imports, path-scoped rules, the launch budget, `AGENTS.md` and personal files |

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
