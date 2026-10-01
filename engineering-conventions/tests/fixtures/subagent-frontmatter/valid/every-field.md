---
name: code-reviewer
description: "Reviews code for quality. Triggered by: review, audit."
tools: Read, Glob, Grep
disallowedTools: [Bash]
model: sonnet
permissionMode: acceptEdits
maxTurns: 10
skills:
  - writing-commits
mcpServers:
  - github
  - docs:
      type: http
      url: https://example.com/mcp
hooks: {}
memory: project
background: false
omitClaudeMd: true
effort: high
isolation: worktree
color: blue
initialPrompt: Review the current diff.
experimental:
  cacheTtl: 1h
---

You are a code reviewer.
