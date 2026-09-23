# Configuration Guide

**Philosophy: One need, one place.** Every configuration concern maps to exactly one canonical location. If you're
unsure where something goes, use the decision tree below.

This guide covers the **repository level**. Whether a file belongs to the repository or to the product directory is
decided first, by [LAYOUT.md](LAYOUT.md#the-placement-test).

## Decision Tree

```text
Where does my configuration go?

Is it read by the product's native toolchain, or found by walking up from
the product (Cargo.toml, rustfmt.toml, tsconfig.json, ruff.toml)?
  → <product>/ — see LAYOUT.md. Everything below is the repository level.

Is the tool's config auto-loaded only from the repo root, with no way to
point at another path (Task)?
  → repo root. No alternative — these are orchestration entry points.

Does it configure a linter, formatter, or the git hooks?
  → .config/<concern>/<tool>.<ext> (lefthook.yml stays at .config/ top level)

Does it provision the container itself?
  → .devcontainer/ (see the branches below)

Runtime, or a tool with a Feature whose installer avoids api.github.com?
  → devcontainer.json → features block (pin the version)

Tool whose Feature is rate-limit-fragile, or that must exist before
Features run (bun, uv, task, mise)?
  → .devcontainer/Dockerfile → an ARG pin

CLI with no Feature (npm-distributed, e.g. codex, lefthook)?
  → .devcontainer/mise.toml

Self-updating CLI (e.g. Claude Code)?
  → scripts/lib/base-setup.sh (native installer)

Infrastructure service (DB, cache, queue, storage)?
  → stacks/<name>/compose.yaml (new folder, add to stacks/compose.yaml includes)

VS Code editor behavior or extension?
  → devcontainer.json → customizations.vscode block

Credential or per-developer toggle?
  → declare it in .devcontainer/env.schema.yaml (.env.example is generated)

Service-internal configuration (tuning, pipelines)?
  → stacks/<name>/ (colocated with that stack's compose.yaml)

One-time setup step?
  → scripts/post-create.sh

Runs on every container start?
  → scripts/startup.sh
```

## Where Configuration Lives

Four homes at the repository level, and a rule for choosing between them. Ask these in order and stop at
the first "yes".

| # | Question | Home | Examples |
| --- | --- | --- | --- |
| 1 | Can the tool *only* load from the repo root, with no flag to point elsewhere? | Repo root | `Taskfile.yml`, `.gitattributes`, `.gitignore` |
| 2 | Does it configure a linter, formatter, or the git hooks? | `.config/<concern>/` | `markdown/markdownlint.jsonc`, `yaml/yamllint.yaml` (`lefthook.yml` top-level) |
| 3 | Does it provision the container or its services? | `.devcontainer/` | `Dockerfile`, `devcontainer.json`, `mise.toml`, `stacks/` |
| 4 | Does it enforce repo structure? | `.repo/` | The `repo` CLI and its policies |

Why `.config/` is dotted: it is repo infrastructure, and it sits alongside the
other infrastructure directories this repo already has — `.devcontainer/`,
`.github/`, `.repo/`. Undotted at the root are the product directory and the
entry points people open first; dotted is the machinery that operates on the
repository (see [LAYOUT.md](LAYOUT.md#the-rule)).

Three rules make the `.config/` home hold:

- **Bucket by concern.** `.config/<concern>/<tool>.<ext>` — a one-file bucket
  is fine and collects siblings over time. The single exception is
  `lefthook.yml`, which sits at the top level because lefthook's config search
  does not descend past `.config/lefthook.*`.
- **Pass the config path explicitly.** Every caller names its config with the
  tool's own flag (`--config`, `-c`, `-config-file`). The single exception is
  lefthook, which searches `.config/` natively. Relying on default discovery is
  what scatters dotfiles across the root to begin with.
- **Every config must have a caller.** A file nothing reads is dead weight.
  `repo config check` fails on orphans.

See [`.config/README.md`](.config/README.md) for the per-file index, and
[`.repo/README.md`](.repo/README.md) for what is mechanically enforced.

## Quick Reference

| Category | Need | Canonical Location |
| --- | --- | --- |
| **Runtimes & Tools** | Anything with a usable Feature (Node, Python, Go, Java, Deno, gh, ShellCheck, psql) | `devcontainer.json` → `features` (pinned) |
| | Image-baked tools (bun, uv, Task, mise) | `.devcontainer/Dockerfile` → `ARG` (pinned) |
| | CLIs with no Feature (Codex, Lefthook) | `.devcontainer/mise.toml` |
| | Self-updating CLIs (Claude Code) | `scripts/lib/base-setup.sh` |
| **Tooling** | Git hooks | `.config/lefthook.yml` |
| | Markdown lint rules | `.config/markdown/markdownlint.jsonc` |
| | YAML lint rules | `.config/yaml/yamllint.yaml` |
| | GitHub Actions lint rules | `.config/actions/actionlint.yaml` |
| | Spelling dictionary / ignores | `.config/spelling/codespell.cfg` |
| | Task automation for the template | `Taskfile.yml` + `taskfiles/<name>.Taskfile.yml` |
| | Repo structure policies | `.repo/governance/policies/` |
| **Editor** | VS Code settings (formatters, rulers, whitespace) | `devcontainer.json` → `customizations.vscode.settings` |
| | VS Code extensions | `devcontainer.json` → `customizations.vscode.extensions` |
| | Debug launch configs | `.vscode/launch.json` (in consuming project) |
| **Shell & User** | Default shell, prompt, oh-my-zsh config | `devcontainer.json` → `common-utils` feature |
| | Git config | Host `.gitconfig` (auto-forwarded by devcontainers) |
| **Environment** | Runtime behavior vars (`PYTHONUNBUFFERED`, etc.) | `devcontainer.json` → `containerEnv` |
| | PATH extensions | `devcontainer.json` → `remoteEnv` |
| | Service credentials (dev-only) | `.devcontainer/env.schema.yaml` → rendered to `.env.example`, copied to `.env` |
| | Service profiles/toggles | `COMPOSE_PROFILES` (set it with `task env:setup`) |
| | Secrets (API keys, tokens) | Host env forwarded via `remoteEnv` — never committed |
| **Services** | Stack orchestrator (`include:` list) | `.devcontainer/stacks/compose.yaml` |
| | Infrastructure services | `.devcontainer/stacks/<name>/compose.yaml` |
| | Service enable/disable | `.devcontainer/.env` → `COMPOSE_PROFILES` |
| | Service tuning/config | `.devcontainer/stacks/<name>/` (colocated) |
| **Networking** | Port allocation (container-side) | `.devcontainer/stacks/<name>/compose.yaml` → `ports:` |
| | Port forwarding (to host IDE) | `devcontainer.json` → `forwardPorts` + `portsAttributes` |
| | Service discovery | Automatic via Docker Compose `musher-dev` network |
| **Observability** | Telemetry pipeline config | `.devcontainer/stacks/observability/config/otel-collector-config.yaml` |
| | Grafana dashboards | `.devcontainer/stacks/observability/config/grafana/provisioning/dashboards/json/` |
| | Grafana datasources | `.devcontainer/stacks/observability/config/grafana/provisioning/datasources/` |
| **Data** | DB schema init (base) | `.devcontainer/stacks/postgres/init/00-init.sql` |
| | DB schema init (project) | `.devcontainer/stacks/postgres/init/01-project.sql` |
| | DB migrations | Project tooling (Atlas, Flyway — not in template) |
| | Data persistence | Compose files → named volumes |
| **Lifecycle** | One-time container setup | `scripts/post-create.sh` → `lib/base-setup.sh` |
| | Every-start tasks | `scripts/startup.sh` |
| | Task automation (consuming project) | `Taskfile.yml` in the consuming repo |
| **AI Tools** | Claude Code (native installer) | `lib/base-setup.sh` |
| | Codex CLI (pinned) | `.devcontainer/mise.toml` |
| | AI CLI config persistence | `devcontainer.json` → `mounts` (named volumes) |
| **Security** | Container capabilities | `devcontainer.json` → `capAdd` / `securityOpt` |
| | Docker build context exclusions | `.devcontainer/.dockerignore` |
| | Network binding | Compose files → all ports bound to `127.0.0.1` |

---

## Runtimes & Tools

Tools land in one of four places. Ask these in order and stop at the first "yes".

| # | Question | Home |
| --- | --- | --- |
| 1 | Is there a Feature, **and** does its installer avoid `api.github.com`? | `devcontainer.json` → `features` |
| 2 | Is the Feature rate-limit-fragile, or must the tool exist before Features run? | `.devcontainer/Dockerfile` → an `ARG` pin |
| 3 | No Feature, and only needed at runtime? | `.devcontainer/mise.toml` |
| 4 | Does the tool update itself? | `scripts/lib/base-setup.sh` |

**Prefer a Feature.** Tier 2 exists because of one specific, verified failure — not as a general escape hatch.

### 1. Tools with a Feature → `devcontainer.json`

Runtimes and any CLI that ships a devcontainer Feature are pinned in the `features` block, so they're baked into the image:

```jsonc
"features": {
  "ghcr.io/devcontainers/features/node:1": { "version": "24.18.0" },
  "ghcr.io/devcontainers/features/python:1": { "version": "3.13.14" },
  "ghcr.io/devcontainers-extra/features/deno:1": { "version": "2.9.2" }
}
```

Comment out any tool you don't need (and its matching VS Code extension). Pin an exact version where the Feature
supports it; a couple track a major line instead (`java: 17`, `postgresql-client: 16`).

Before adding a third-party Feature, read its `install.sh`. If it delegates to
`ghcr.io/devcontainers-extra/features/gh-release` (directly or via nanolayer), it belongs in tier 2 — see below.

### 2. Image-baked tools → `.devcontainer/Dockerfile`

`bun`, `uv`, `task` and `mise` are installed by the Dockerfile as pinned `ARG`s rather than by Features:

```dockerfile
ARG BUN_VERSION=1.3.14
ARG UV_VERSION=0.11.28
ARG TASK_VERSION=3.52.0
ARG MISE_VERSION=v2026.8.6
```

The first three have Features, and those Features are the problem. All of them resolve release assets through
nanolayer's `gh-release` helper, which lists a release's assets by calling `api.github.com` **with no credentials** —
`nanolayer/installers/gh_release/resolvers/asset_resolver.py`:

```python
response = urllib.request.urlopen(
    f"https://api.github.com/repos/{repo}/releases/tags/{tag}"
)  # nosec
```

There is no `Authorization` header and no `GITHUB_TOKEN` read anywhere in that module. Codespaces build hosts and
GitHub-hosted Actions runners share egress IP pools, so the 60 req/hr anonymous limit is routinely exhausted and the
call 403s. One failed Feature fails the entire image build, after which Codespaces drops you into a bare recovery
container — so the symptom a developer reports is `task: command not found`, not a rate limit.

**Pinning the version does not help.** The pin only supplies the tag; `_get_release_assets()` still calls the API to
*list* the assets. The build log reads `Using Bun version: bun-v1.3.14` and then 403s, which makes the failure look
like a bad version pin when the pin was fine.

`mise` is baked for a different reason — it was previously an unpinned `curl | sh` in post-create, the only unpinned
tool in a template that pins everything else.

**Features that were checked and cleared**, and stay Features: `devcontainers-extra/deno` and `lukewiwa/shellcheck`
build a `releases/download/...` URL directly; `robbert229/postgresql-client` is apt. The rule is about the
installer's behaviour, not the publisher — so read a third-party Feature's `install.sh` before adding it.

`repo toolchain check` enforces all of this: `TC-01` fails if one of those Features comes back, `TC-02` fails on a
floating pin, and `TC-03` fails if `TASK_VERSION` drifts from CI's `arduino/setup-task` version.

Version assertions in the Dockerfile are presence-only (`test -x`). The pinned download URLs already guarantee the
version — a wrong one 404s — and executing a binary in the layer that installed it is a known BuildKit hazard. The
runtime assertion lives in `scripts/verify-toolchain.sh`, which CI runs against the built container.

Two constraints on what can go here:

- **Features layer *after* this stage**, so the Dockerfile cannot use anything a Feature provides. This is why
  `mise install` stays in post-create — four of the six entries in `mise.toml` use the `npm:` and `pipx:` backends,
  and Node and Python come from Features.
- **Runtime identity is not the Dockerfile's job.** There is no `USER` instruction; `updateRemoteUserUID` expects
  root at build time and `remoteUser` owns identity afterwards. Anything touching the named-volume mount points
  (`~/.claude`, `~/.config/gh`, `~/.codex`) belongs in post-create.

The build context is `.devcontainer/`, emptied by `.dockerignore` — the Dockerfile has no `COPY` instruction, and
`.devcontainer/.env` must never reach the Docker daemon.

### 3. CLIs with no Feature → `.devcontainer/mise.toml`

npm-distributed CLIs like Codex and Lefthook have no Feature, so [mise](https://mise.jdx.dev) pins and installs them.
Add a line under `[tools]`:

```toml
[tools]
"npm:@openai/codex" = "0.143.0"
"npm:lefthook"      = "2.1.10"
```

`mise install` runs in post-create; re-run it (or `task tools:install`) after editing.

### 4. Self-updating CLIs → `scripts/lib/base-setup.sh`

CLIs that manage their own updates (Claude Code) install via their native installer. Add a function and call it from `base_setup()`:

```bash
base_install_mytool() {
  has_cmd mytool && return 0
  log "Installing mytool..."
  retry 3 5 bash -c 'curl -fsSL https://mytool.dev/install.sh | bash'
}
```

---

## Comments

This template is read before it is run, so its comments are part of the interface. Four rules, the first two
enforced by `repo comments check`.

**Comment the non-obvious.** The code states *what*; a comment earns its line by stating *why*. The test: could
someone who has never seen this code write the comment just by reading the line below it? If so, delete it.

**Write each rationale once, then reference it.** A decision explained at every call site is a decision that will
disagree with itself within a release. The full account lives here in `CONFIGURATION.md`; code carries a one-line
summary and a pointer. `repo comments check` (`CMT-03`) fails the build if a pointer stops resolving, so
references are safe to rely on.

**Keep file headers short.** A header says what the file is and the one constraint a reader must not violate.
Depth goes here. Blocks over 20 lines fail `CMT-01` — the natural size in this repo is 4–8.

**Library functions are the exception.** Every function in `.devcontainer/scripts/lib/` carries a full header, per
the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html): *"Any function in a library
must have a function header comment regardless of length or complexity."* Tags go in Google's order — `Globals`,
`Arguments`, `Outputs`, `Returns` — and annotate access mode (`— read`, `— modified (export)`).

```bash
# Polls compose services until all report healthy or timeout elapses.
#
# Globals:
#   COMPOSE_FILE — read, path to stacks/compose.yaml
# Arguments:
#   $1 — timeout in seconds (default: 60)
# Outputs:
#   Writes progress/warnings to stderr via log()
# Returns:
#   0 when healthy or on timeout (non-fatal), 1 if services failed
```

---

## Editor

### VS Code Settings

All editor settings live in `devcontainer.json` → `customizations.vscode.settings`. Do not create a
`.vscode/settings.json` in the template — that's for consuming projects.

### VS Code Extensions

All extensions live in `devcontainer.json` → `customizations.vscode.extensions`. Comment out extensions for runtimes you
don't use.

### Why there is no `.editorconfig`

Editor intent is expressed once, in `devcontainer.json` →
`customizations.vscode.settings` (LF endings, final newline, trimmed trailing
whitespace, rulers at 80/120). Adding `.editorconfig` would create a second
place to state the same thing, and the two would drift.

The tradeoff is deliberate and worth knowing: those settings only reach VS Code
*inside the container*. Another editor, or a host-side edit, is not covered. Two
things backstop that gap — `.gitattributes` enforces line endings for every
file Git checks out regardless of editor, and the lint gates (`task lint:all`,
and the same checks in CI) fail on violations no matter what wrote the file.

If a consuming project has contributors who work outside the container, adding
`.editorconfig` there is the right call. It does not belong in the template.

---

## Shell & User

### Git Config

Git config is auto-forwarded from your host machine by the devcontainer CLI. No configuration needed in the template.

---

## Environment Variables

There are four distinct scopes for environment variables. Use the right one:

| Scope | Location | When to Use |
| --- | --- | --- |
| **Container-wide** | `devcontainer.json` → `containerEnv` | Runtime behavior (`PYTHONUNBUFFERED`, `UV_LINK_MODE`) |
| **Remote/IDE** | `devcontainer.json` → `remoteEnv` | PATH extensions, forwarded host secrets |
| **Compose services** | `.devcontainer/.env` | Service credentials, `COMPOSE_PROFILES` |
| **Service-specific** | `stacks/<name>/compose.yaml` → `environment:` | Internal service config (uses `${VAR:-default}` interpolation) |

### Secrets

Never commit secrets. Forward them from your host environment:

```jsonc
"remoteEnv": {
  "MY_API_KEY": "${localEnv:MY_API_KEY}"
}
```

### The schema is the source of truth

Every variable the dev environment reads is declared in
[`.devcontainer/env.schema.yaml`](.devcontainer/env.schema.yaml). `.env.example` is **generated** from it
(`task env:render`), and `repo env check` fails the build when the two disagree. Edit the schema, never the rendering.

The product's own runtime contract is a *different* schema, at `<product>/env.schema.yaml` — see
[LAYOUT.md](LAYOUT.md#the-env-contract) for why they sit at different levels.

```yaml
bindings:
  MINIO_ROOT_PASSWORD:
    type: string
    local_default: minioadmin     # → `MINIO_ROOT_PASSWORD=minioadmin`
    sensitivity: internal         # public | internal | secret
    consumers: [minio]            # only required when the minio stack runs
    description: Root password of the project MinIO stack. Dev-only.
```

| Field | Effect |
| --- | --- |
| `local_default` | Rendered live: `VAR=value`. A `secret` may only carry an empty or loopback value (`ENV-07`). |
| `required: true` | Rendered empty: `VAR=`. `repo env doctor` asks for it. |
| neither | Rendered commented: `# VAR=<default>` — an offer, not a value. |
| `consumers: [<stack>]` | Requiredness follows the enabled `COMPOSE_PROFILES`. Checked against the stack's compose file (`ENV-03`). |
| `source: host` | Filled from the host environment by `initialize.sh`, and mirrored into `secrets` so Codespaces prompts (`ENV-06`). |
| `local_generate: hex:32` | Minted per developer by `repo env sync`, never committed. |
| `mirrored_in: [...]` | Configs that repeat the value literally (Tempo, Loki) must agree (`ENV-05`). |

### Filling it in

The container always starts. What does not start is the stack whose value is missing:

| Command | Purpose |
| --- | --- |
| `task env:setup` | Interactive fill — asks only for what is missing or invalid, masks secrets, offers menus |
| `task env:doctor` | What the *enabled* stacks still need, and which ones will be skipped |
| `task env:sync` | Adds bindings the schema has gained, mints local secrets; never overwrites a value |
| `task env:render` | Regenerates `.env.example` after a schema change |
| `task env:reset` | Re-copies the template over `.env` (destroys local values) |

`startup.sh` skips a stack whose required values are missing and says so; the MOTD repeats it on every shell. Because
`runArgs --env-file` reads `.env` once at `docker run` time, the shell profile re-loads the file (`lib/env-load.sh`)
so an edited value reaches new terminals without a rebuild.

---

## Services

### Enabling/Disabling Services

All services are included in `.devcontainer/stacks/compose.yaml`. Optional services are gated by Compose profiles:

| Service | Profile | Always On? |
| --- | --- | --- |
| PostgreSQL | — | Yes |
| Redis | `redis` | No |
| MinIO | `minio` | No |
| OCI Registry | `registry` | No |
| Azimutt | `azimutt` | No |
| Observability stack | `observability` | No |

Enable services by setting `COMPOSE_PROFILES` in `.devcontainer/.env`:

```env
COMPOSE_PROFILES=redis,minio,observability
```

### Adding a New Service

1. Create `stacks/myservice/compose.yaml`
2. Add `- myservice/compose.yaml` to the `include:` list in `stacks/compose.yaml`
   (paths are relative to that file)
3. Optionally add `profiles: [myservice]` if it should be opt-in
4. Add port forwarding in `devcontainer.json` → `forwardPorts` and `portsAttributes`
5. Use `${VAR:-default}` for any credentials, and add them to `.env.example`

### Service Configuration

Each stack owns its config: put a stack's config files inside its own folder,
next to that stack's `compose.yaml`, and bind-mount them with a path relative to
the stack folder (e.g. `./init`, `./config/...`):

```text
stacks/
  compose.yaml          The orchestrator: `include:` one line per stack
  postgres/
    compose.yaml
    init/               SQL init scripts (mounted at ./init)
  observability/
    compose.yaml
    config/             OTel, Grafana, Tempo, Loki configs (mounted at ./config)
```

Relative paths inside a stack's `compose.yaml` resolve against *that file's* folder, not the orchestrator's, so a
stack stays self-contained.

### Why every caller passes `--env-file`

Compose discovers `.env` in the project directory, which defaults to the folder holding the first `-f` file. The
orchestrator lives in `stacks/` and `.env` lives in `.devcontainer/`, so that discovery does not reach it. Every
caller — `scripts/startup.sh`, the MOTD, and CI — therefore names it explicitly:

```bash
docker compose --env-file .devcontainer/.env -f .devcontainer/stacks/compose.yaml up -d
```

Omitting it does not error. Every `${VAR:-default}` quietly takes its default and `COMPOSE_PROFILES` reads as empty,
so all opt-in stacks silently vanish. The orchestrator also sets `name: musher-dev` explicitly, because Compose
would otherwise derive the project name from the `stacks/` folder.

---

## Networking

### Port Allocation

All ports are bound to `127.0.0.1` (localhost only) for security. The template uses the `154xx` range:

| Port | Service | Protocol |
| --- | --- | --- |
| 15432 | PostgreSQL | TCP |
| 15433 | Redis | TCP |
| 15434 | MinIO API | HTTP |
| 15435 | MinIO Console | HTTP |
| 15436 | OCI Registry | HTTP |
| 15440 | MinIO API (Observability) | HTTP |
| 15441 | MinIO Console (Observability) | HTTP |
| 15442 | Tempo | HTTP |
| 15443 | Loki | HTTP |
| 15444 | VictoriaMetrics | HTTP |
| 15445 | OTel Collector HTTP | HTTP |
| 15446 | OTel Collector gRPC | gRPC |
| 15447 | Grafana | HTTP |
| 15448 | Pyroscope | HTTP |
| 15460 | Azimutt | HTTP |

### Service Discovery

Services communicate via the `musher-dev` Docker network. Use the service name as the hostname (e.g., `postgres`,
`redis`, `minio-observability`) with the container-internal port.

---

## Observability

The observability stack is profile-gated (`COMPOSE_PROFILES=observability`). It includes:

- **Grafana** — Dashboards and visualization (port 15447)
- **Tempo** — Distributed tracing backend
- **Loki** — Log aggregation
- **VictoriaMetrics** — Metrics storage
- **OTel Collector** — Telemetry pipeline (receives OTLP on ports 15445/15446)
- **Pyroscope** — Continuous profiling
- **MinIO (Observability)** — Object storage for Tempo and Loki

### Configuration Files

| File | Purpose |
| --- | --- |
| `stacks/observability/config/otel-collector-config.yaml` | OTel Collector pipeline configuration |
| `stacks/observability/config/tempo-config.yaml` | Tempo storage and ingestion config |
| `stacks/observability/config/loki-config.yaml` | Loki storage and ingestion config |
| `stacks/observability/config/grafana/provisioning/datasources/` | Auto-provisioned Grafana datasources |
| `stacks/observability/config/grafana/provisioning/dashboards/json/` | Auto-provisioned Grafana dashboards |

> **Note:** `tempo-config.yaml` and `loki-config.yaml` contain hardcoded MinIO credentials because they are native YAML
configs that don't support environment variable interpolation. If you change `MINIO_OBS_ROOT_USER` or
`MINIO_OBS_ROOT_PASSWORD` in `.env`, you must also update these files to match.

---

## Data

### Database Initialization

SQL files in `.devcontainer/stacks/postgres/init/` are mounted into PostgreSQL's `docker-entrypoint-initdb.d/` and run
in alphabetical order on first container creation:

- `00-init.sql` — Base schema (extensions, shared types)
- `01-project.sql.example` — Project-specific schema (copy to `01-project.sql`)

### Persistence

All services use named Docker volumes (e.g., `musher-postgres-data`). Data persists across container restarts but is
lost on full rebuild. For migrations, use project-level tooling (Atlas, Flyway, etc.).

### Adding Volumes

Follow the naming convention `musher-${devcontainerId}-<purpose>`:

```jsonc
"source=musher-${devcontainerId}-my-tool,target=/home/vscode/.my-tool,type=volume"
```

---

## Lifecycle

| Hook | Runs | Use For |
| --- | --- | --- |
| `initializeCommand` | Host-side, before every `docker run` | Bootstrap that must exist before the container starts (e.g., creating `.devcontainer/.env` so `--env-file` works) |
| `postCreateCommand` | Once, on container creation | Tool installation, permissions, lefthook hooks |
| `postStartCommand` | Every container start | `docker compose up`, health checks |

### Skipping Base Steps

Call individual functions instead of `base_setup`:

```bash
main() {
  log "Starting post-create setup..."
  base_setup_config_dirs
  base_setup_cache_dirs
  base_fix_nvm_permissions
  base_setup_path
  base_install_mise
  # Skip the mise CLIs: base_install_tools
  base_install_claude
  base_verify_tools
  log "Post-create setup completed"
}
```

### Script Layers

```text
post-create.sh              ← Entry point (repo-specific customization)
  └── lib/base-setup.sh     ← Reusable orchestrator (mise CLIs, Claude, nvm, config/cache dirs)
        └── lib/common.sh   ← Shared utilities (log, retry, has_cmd, ensure_writable_dir)
```

---

## AI Tools

### Installed CLIs

- **Claude Code** — native self-updating installer (`base-setup.sh`), config persisted in the `~/.claude` volume
- **Codex CLI** — pinned in `.devcontainer/mise.toml`, config persisted in the `~/.codex` volume

### Configuration Persistence

AI CLI configs are stored in named volumes mounted via `devcontainer.json` → `mounts`. This preserves authentication and
settings across container rebuilds.

---

## Directory Map

```text
<product>/                    The product (absent in the template; see LAYOUT.md)
LAYOUT.md                     Which level a file belongs to: repository or product
.config/                      Tool configuration (see "Where configuration lives")
  README.md                   Index: every file, its tool, and how it is reached
  lefthook.yml                Git hooks (top-level: lefthook's search stops at .config/lefthook.*)
  lefthook-local.yml          Personal hook overrides (gitignored, auto-merged)
  markdown/markdownlint.jsonc Markdown rules      (--config)
  yaml/yamllint.yaml          YAML rules          (--config)
  actions/actionlint.yaml     Workflow rules      (-config-file)
  spelling/codespell.cfg      Spelling            (--config)
.repo/                        Repo governance toolchain (the `repo` CLI)
  README.md                   What each policy enforces, and why
  pyproject.toml              uv project; declares the `repo` console-script
  layout.toml                 The product declaration (`product = ""` here)
  tests/                      pytest suite for the policies
  governance/
    cli.py                    `repo check` and the per-policy subcommands
    reporting.py              The Violation record (code, reason, fix)
    repo.py                   Repo-root discovery, YAML/JSONC/TOML readers, tracked files
    globs.py                  Glob matching shared by the path policies
    envschema.py              The shared env.schema.yaml shape
    policies/__init__.py      The policy registry -- the only wiring a policy needs
    policies/config/          .config/ layout, index, and no shadowing root config
    policies/layout/          Root vs the declared product directory, and parity with it
    policies/paths/           Configured globs, directories and path vars still resolve
    policies/env/             Every env.schema.yaml has the shared shape
    policies/ports/           Port table ↔ forwardPorts ↔ compose parity
    policies/toolchain/       Image-baked pins; banned rate-limit-fragile Features
    policies/hooks/           lefthook ↔ CI job parity
    policies/rulesets/        Branch rulesets ↔ CI job-name parity
    policies/comments/        Comment-block size and live docs pointers
.github/
  dependabot.yml              Weekly updates: devcontainers, actions, docker
  rulesets/                   Branch protection as committed JSON (+ RULESETS.md)
  workflows/                  CI
taskfiles/                    Task modules included by the root Taskfile.yml
Taskfile.yml                  Task entry point (cannot move — root-only discovery)
.gitattributes                Line-ending policy (`* text=auto eol=lf`)
.devcontainer/
  Dockerfile                  The image: bun, uv, task, mise as pinned ARGs
  .dockerignore               Empties the build context (`*`); keeps .env off the daemon
  devcontainer.json           Features, extensions, settings, mounts, ports
  mise.toml                   Runtime-only CLIs with no Feature
  env.schema.yaml             Dev-environment contract -- the source of truth
  .env.example                GENERATED from the schema by `task env:render`
  .env                        Local overrides (gitignored)
  stacks/                     The services, and the orchestrator that includes them
    compose.yaml              Stack orchestrator (`include:` + `name: musher-dev`)
    postgres/
      compose.yaml             PostgreSQL with pgvector (always on)
      init/
        00-init.sql            Base DB schema
        01-project.sql.example Project schema template
    redis/
      compose.yaml             Redis (profile: redis)
    minio/
      compose.yaml             MinIO S3 storage (profile: minio)
    registry/
      compose.yaml             OCI Registry (profile: registry)
    azimutt/
      compose.yaml             DB explorer UI (profile: azimutt)
    observability/
      compose.yaml             Full observability stack (profile: observability)
      config/
        otel-collector-config.yaml
        tempo-config.yaml
        loki-config.yaml
        grafana/provisioning/
          datasources/         Auto-provisioned datasources
          dashboards/json/     Auto-provisioned dashboards
  scripts/
    initialize.sh             Host-side bootstrap (runs before docker run)
    post-create.sh            One-time setup entry point
    startup.sh                Every-start service launcher
    verify-toolchain.sh       Asserts baked tools match the Dockerfile ARGs (CI)
    lib/
      base-setup.sh           Reusable tool installer (mise CLIs + Claude)
      common.sh               Shared utilities
      env-load.sh             Exports .env into a shell without sourcing it
      motd.sh                 Startup MOTD renderer
```
