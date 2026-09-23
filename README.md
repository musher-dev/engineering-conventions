# Musher Dev Container Template

Canonical dev container template for the musher-dev organization. Batteries-included configuration with AI CLIs,
multiple language runtimes, Docker-in-Docker, Task runner, and consistent VS Code settings. Comment out what you don't
need.

## What You Get

- Ubuntu 24.04 LTS base with zsh/oh-my-zsh
- Node, Python, Go, Java, Deno — pinned Features
- bun, uv, Task, mise — baked into the image by `.devcontainer/Dockerfile` (pinned `ARG`s)
- Docker-in-Docker
- Git + GitHub CLI
- Claude Code + Codex CLI + Task runner + Lefthook
- GitLens, YAML, TOML, Copilot, Go, Python, Ruff, ESLint, Docker extensions
- Format on save, rulers, trailing whitespace trimming

## Usage

1. Click **Use this template** → **Create a new repository** on GitHub
2. Clone your new repo and open in VS Code
3. **Command Palette** → **Dev Containers: Reopen in Container**
4. *(Optional)* Run `task env:setup` to choose which stacks start and fill in any values they need.

## Local Environment

Every variable the dev environment reads is declared in `.devcontainer/env.schema.yaml`. `.env.example` is generated
from it (`task env:render`; CI fails on drift), and on first build `initializeCommand` copies that rendering to
`.env` (gitignored). The same file feeds:

- **Docker Compose** — passed explicitly as `--env-file .devcontainer/.env` by every caller, used to interpolate
  `${VAR:-default}` references. It is not auto-discovered: the orchestrator lives at
  `.devcontainer/stacks/compose.yaml` and `.env` is not its sibling.
- **The dev container itself** — loaded via `runArgs --env-file`, so shells and runtimes inside the container see the
  same values.

A missing value never blocks the container — it blocks the stack that needs it, and only while that stack's profile is
enabled. Useful task commands:

| Command | Purpose |
| --- | --- |
| `task env:setup` | Fill in what is missing, interactively (menus for stack choices, masked secrets). |
| `task env:doctor` | Report what the enabled stacks still need, and which ones will be skipped. |
| `task env:sync` | Add bindings the schema has gained; never overwrites a value you set. |
| `task env:render` | Regenerate `.env.example` after editing the schema. |
| `task env:reset` | Re-copy the template over `.env` (prompts before overwriting). |
| `task stacks:restart` | Bring the stacks up to match the current `.env`. |
| `task lint:all` | Run every lint gate (Markdown, YAML, workflows, spelling). |
| `task repo:check` | Check the repo's own structure policies. |
| `task tools:install` | Install every pinned CLI from `.devcontainer/mise.toml`. |

The startup MOTD repeats anything still outstanding, and the shell profile reloads `.env` so an edited value reaches
new terminals without a rebuild.

## Customize

- Add your product → a directory named after the repo, declared in `.repo/layout.toml`. The repository root stays
  the machinery that acts on it; [LAYOUT.md](LAYOUT.md) is the rule and `repo layout check` enforces it
- Comment out unneeded features/extensions in `devcontainer.json`
- Change a tool version → `devcontainer.json` (Features), `.devcontainer/Dockerfile` (bun, uv, Task, mise), or
  `.devcontainer/mise.toml` for runtime-only CLIs (AI CLIs, lefthook, linters). The four-tier rule is in
  [CONFIGURATION.md](CONFIGURATION.md#runtimes--tools) and enforced by `repo toolchain check`.
- Change a lint rule → the matching file in `.config/` (see [`.config/README.md`](.config/README.md))
- Add project setup to `scripts/post-create.sh` (runs after `base_setup`)
- Add or enable a service → `.devcontainer/stacks/` (one folder per stack, registered in `stacks/compose.yaml`);
  toggle with `COMPOSE_PROFILES` in `.devcontainer/.env` (redis, minio, registry, azimutt, observability)
- Full reference → [CONFIGURATION.md](CONFIGURATION.md)

## Included CI

`.github/workflows/validate.yaml` runs six jobs: ShellCheck, Compose config validation, devcontainer lockfile
freshness, the lint gates, the repo structure policies (plus their tests), and a devcontainer build that also
asserts the image-baked tools report their pinned versions. Lint tool versions resolve from
`.devcontainer/mise.toml` — the same file the container uses — so CI and local cannot drift.

The same lint and structure checks run pre-commit via [`.config/lefthook.yml`](.config/lefthook.yml), and
`repo hooks check` fails the build if the two ever disagree.

Branch protection is committed as JSON under [`.github/rulesets/`](.github/rulesets/RULESETS.md); it must be imported
once per repository, since rulesets are repository state rather than content.

Keep or remove per your project's needs — but remove a CI job and its ruleset entry together, or `repo rulesets check`
will tell you why.

## Troubleshooting

### CRLF / WSL line ending issues

`.gitattributes` (`* text=auto eol=lf`) normalizes every tracked file, so scripts arrive with LF on every platform
and no fixup step is needed. The one exception is `.devcontainer/.env`, which is gitignored and therefore out of
`.gitattributes`' reach — `scripts/initialize.sh` strips `\r` from it host-side before the container starts.

### Stale containers

If settings aren't applying after changes, rebuild without cache:

**Command Palette** → **Dev Containers: Rebuild Container Without Cache**

### Volume permission errors

Named volumes may initialize with root ownership. The `ensure_writable_dir` function in `common.sh` and the
`base_setup_config_dirs` step handle this for base volumes. For custom volumes, call `ensure_writable_dir` in your
`post-create.sh`:

```bash
ensure_writable_dir /home/vscode/.my-tool
```

### Tool installation failures

Base setup uses `retry` with 3 attempts and 5-second delays for network operations. If a tool consistently fails to
install, check network connectivity and try rebuilding the container.
