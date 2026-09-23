# AGENTS.md

A router for coding agents that do not read `CLAUDE.md` (Codex, Gemini,
Copilot). It restates no rules; it points at the files that hold them.

- **[`CLAUDE.md`](CLAUDE.md)**: the contract for changes in this repository.
  It opens by importing `@README.md`, which is Claude Code syntax for "inline
  that file"; other tools should open [`README.md`](README.md) directly.
- **[`.claude/rules/`](.claude/rules/)**: the policy for each part, as
  MUST / MUST NOT. Read the one whose `paths:` covers the files you change:
  `conventions.md`, `terminology.md`, `rego.md`, `github-workflows.md`,
  `toolchain-pins.md`.
- **[`docs/authoring.md`](docs/authoring.md)**: how to add or change a
  requirement, a term or a check.
- **[`docs/decisions/`](docs/decisions/)**: why the repository is shaped the
  way it is.
- **[`LAYOUT.md`](LAYOUT.md)** and **[`CONFIGURATION.md`](CONFIGURATION.md)**:
  where a file belongs.
- **[`.github/conventional-commits.yaml`](.github/conventional-commits.yaml)**:
  the only list of commit types and scopes.

Verification: `task check`. `task --list` enumerates everything.

Agents open pull requests. Humans merge them.
