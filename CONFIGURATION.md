# Configuration Guide

**Philosophy: One need, one place.** Every configuration concern maps to exactly one canonical location. If you're
unsure where something goes, use the decision tree below.

This guide covers the **repository level**. Whether a file belongs to the repository or to the product directory is
decided first, by [LAYOUT.md](LAYOUT.md#the-placement-test).

## Decision Tree

```text
Where does my configuration go?

Does a consumer need it, or does the product's own tooling (uv, ruff,
basedpyright, pytest) find it by walking up from engineering-conventions/?
  → engineering-conventions/ — see LAYOUT.md. Everything below is the repository level.

Is the tool's config auto-loaded only from the repo root, with no way to
point at another path (Task, git)?
  → repo root. No alternative — these are orchestration entry points.

Does it configure a linter, formatter, the rule tooling, or the git hooks?
  → .config/<concern>/<tool>.<ext> (lefthook.yml stays at .config/ top level)

Is it a CLI version?
  → .devcontainer/mise.toml (mise itself: the Dockerfile's ARG MISE_VERSION)

Does it provision the container itself (Features, mounts, editor)?
  → .devcontainer/devcontainer.json

One-time container setup step?
  → .devcontainer/scripts/post-create.sh

Which conventions this repository holds itself to, and any waiver?
  → .repo/conventions.yaml
```

## Where Configuration Lives

Four homes at the repository level. Ask these in order and stop at the first "yes".

| # | Question | Home | Examples |
| --- | --- | --- | --- |
| 1 | Can the tool *only* load from the repo root, with no flag to point elsewhere? | Repo root | `Taskfile.yml`, `.gitattributes`, `.gitignore` |
| 2 | Does it configure a linter, formatter, rule tool, or the git hooks? | `.config/<concern>/` | `markdown/vale.ini`, `rego/regal.yaml` (`lefthook.yml` top-level) |
| 3 | Does it provision the container or pin a tool? | `.devcontainer/` | `Dockerfile`, `devcontainer.json`, `mise.toml` |
| 4 | Is it GitHub's own configuration? | `.github/` | workflows, rulesets, Dependabot, release-please |

Why `.config/` is dotted: it is repository machinery, alongside `.devcontainer/` and `.github/`. Undotted at the root
are the product directory and the entry points people open first.

Three rules make the `.config/` home hold:

- **Bucket by concern.** `.config/<concern>/<tool>.<ext>`: a one-file bucket is fine and collects siblings over time.
  The single exception is `lefthook.yml`, which sits at the top level because lefthook's config search does not
  descend past `.config/lefthook.*`.
- **Pass the config path explicitly.** Every caller names its config with the tool's own flag (`--config`, `-c`,
  `-config-file`). The single exception is lefthook, which searches `.config/` natively. Relying on default
  discovery is what scatters dotfiles across the root to begin with.
- **Every config must have a caller**, and every ignore a reason.

See [`.config/README.md`](.config/README.md) for the per-file index.

## Quick Reference

| Category | Need | Canonical Location |
| --- | --- | --- |
| **Tools** | mise itself | `.devcontainer/Dockerfile` → `ARG MISE_VERSION` |
| | Every other CLI (task, lefthook, conftest, opa, regal, vale, linters, uv) | `.devcontainer/mise.toml` |
| | gh, git, zsh | `devcontainer.json` → `features` |
| | Claude Code (self-updating) | `.devcontainer/scripts/lib/base-setup.sh` |
| **Tooling** | Git hooks | `.config/lefthook.yml` |
| | Markdown lint / prose rules | `.config/markdown/markdownlint.jsonc`, `.config/markdown/vale.ini` |
| | YAML lint | `.config/yaml/yamllint.yaml` |
| | Workflow lint / security | `.config/actions/actionlint.yaml`, `.config/actions/zizmor.yml` |
| | Rego lint | `.config/rego/regal.yaml` |
| | Spelling | `.config/spelling/typos.toml` |
| | Secret scan | `.config/security/gitleaks.toml` |
| | Task automation | `Taskfile.yml` + `taskfiles/<name>.Taskfile.yml` |
| **Product** | The CLI's ruff, basedpyright and pytest config | `engineering-conventions/pyproject.toml` |
| **GitHub** | Commit types and scopes | `.github/conventional-commits.yaml` |
| | Branch and tag protection | `.github/rulesets/*.json` (applied by hand; see `RULESETS.md`) |
| | Releases | `.github/release-please/`, `version.txt` |
| **Editor** | VS Code settings and extensions | `devcontainer.json` → `customizations.vscode` |
| **Environment** | Runtime behaviour vars, cache locations | `devcontainer.json` → `containerEnv` |
| | PATH extensions | `devcontainer.json` → `remoteEnv` |
| **AI tools** | Config persistence across rebuilds | `devcontainer.json` → `mounts` (named volumes) |
| | Agent permissions and hooks | `.claude/settings.json`, `.claude/hooks/` |

---

## Runtimes & Tools

Two tiers, and the second holds almost everything.

| Tier | Home | Holds |
| --- | --- | --- |
| 1. Image-baked | `.devcontainer/Dockerfile` → `ARG MISE_VERSION` | mise, and only mise |
| 2. Pinned by mise | `.devcontainer/mise.toml` | Every CLI the gates run, and their runtimes (node, uv, Python via uv) |

**Why one anchor.** The dev container (post-create), a local `task` run and CI all install from `mise.toml`; CI does so
through `.github/actions/setup-tools`, the repository's one `jdx/mise-action` reference. So a version exists in exactly
one place, and a local run and CI cannot disagree about which linter version passed.

**Why mise is baked.** mise cannot pin itself from its own config, and it must exist before post-create runs `mise
install`. Its ARG is kept in lockstep with the mise version setup-tools installs; that pair, and the other lockstep
pins mise cannot express, are listed in [`.claude/rules/toolchain-pins.md`](.claude/rules/toolchain-pins.md).

**Why not Features.** A Feature per tool would be a second pin list that CI never reads, and several Features resolve
release assets through unauthenticated `api.github.com` calls that the shared egress of Codespaces and CI rate-limits.
The remaining Features (`common-utils`, `git`, `github-cli`) configure the container itself and are pinned there.

Adding a tool: add one line under `[tools]` in `mise.toml` with a fully qualified backend (`aqua:owner/repo`,
`pipx:`, `npm:`), run `task tools:install`, then `task tools:doctor`. If CI needs it, add the same key to the
`install-args` that job passes to setup-tools.

---

## Comments

This repository is read before it is run, so its comments are part of the interface.

**Comment the non-obvious.** The code states *what*; a comment earns its line by stating *why*. The test: could
someone who has never seen this code write the comment just by reading the line below it? If so, delete it.

**Write each rationale once, then reference it.** A decision explained at every call site is a decision that will
disagree with itself within a release. The full account lives in one document (this file, a decision, or a
`.claude/rules/` file); code carries a one-line summary and a pointer.

**Keep file headers short.** A header says what the file is and the one constraint a reader must not violate.

**Library functions are the exception.** Every function in `.devcontainer/scripts/lib/` carries a full header, per
the [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html): tags in Google's order
(`Globals`, `Arguments`, `Outputs`, `Returns`), with access mode annotated (`— read`, `— modified (export)`).

---

## Editor

All editor settings and extensions live in `devcontainer.json` → `customizations.vscode`. The extensions cover what
this repository edits: YAML (with the content schemas mapped through `yaml.schemas`), Rego (OPA), Vale, markdownlint,
TOML, ShellCheck, GitHub Actions and Ruff. The markdownlint and Vale extensions are pointed at the same `.config/`
files the gates use.

### Why there is no `.editorconfig`

Editor intent is expressed once, in `devcontainer.json` → `customizations.vscode.settings` (final newline, trimmed
trailing whitespace, rulers at 80/120). Adding `.editorconfig` would create a second place to state the same thing,
and the two would drift.

The tradeoff is deliberate: those settings only reach VS Code *inside the container*. Two things backstop the gap:
`.gitattributes` enforces LF line endings for every file Git checks out regardless of editor, and the lint gates
(`task check`, and the same tasks in CI) fail on violations no matter what wrote the file.

---

## Lifecycle

| Hook | Runs | Does |
| --- | --- | --- |
| `postCreateCommand` | Once, on container creation | `scripts/post-create.sh`: `mise install` from `mise.toml`, Claude Code, then the lefthook hooks |

There is no `initializeCommand` and no `postStartCommand`: this container runs no services and reads no env file.
`task setup` repeats the same steps outside a container (tools, the CLI's virtualenv, hooks).

```text
post-create.sh              ← Entry point (installs the hooks)
  └── lib/base-setup.sh     ← Reusable orchestrator (config/cache dirs, mise install, Claude Code)
        └── lib/common.sh   ← Shared utilities (log, retry, has_cmd, ensure_writable_dir)
```

`scripts/verify-toolchain.sh` is the runtime check: the baked mise matches its ARG, and `mise ls --current --missing`
is empty. `task tools:doctor` and the `Dev Container` job of the `Validate` workflow run it.

---

## Directory Map

```text
engineering-conventions/      The product (see LAYOUT.md)
LAYOUT.md                     Which level a file belongs to: repository or product
CONFIGURATION.md              Where a file goes within the repository level (this file)
.config/                      Tool configuration (see "Where Configuration Lives")
  README.md                   Index: every file, its tool, and how it is reached
  lefthook.yml                Git hooks (top-level: lefthook's search stops at .config/lefthook.*)
  lefthook-local.yml          Personal hook overrides (gitignored, auto-merged)
  actions/actionlint.yaml     Workflow lint          (-config-file)
  actions/zizmor.yml          Workflow security      (--config)
  markdown/markdownlint.jsonc Markdown rules         (--config)
  markdown/vale.ini           Prose rules            (--config)
  rego/regal.yaml             Rego lint              (--config-file)
  security/gitleaks.toml      Secret scan            (--config)
  spelling/typos.toml         Spelling               (--config)
  yaml/yamllint.yaml          YAML rules             (-c)
.repo/conventions.yaml        This repository's conventions declaration
.claude/                      settings.json, hooks/no-merge-guard.sh, path-scoped rules/
.github/
  CODEOWNERS                  One owner for everything
  conventional-commits.yaml   Commit types and scopes (commit-msg hook and PR title)
  dependabot.yml              Weekly, grouped, 7-day cooldown: actions, devcontainers, uv
  actions/setup-tools/        The one jdx/mise-action reference
  workflows/                  Validate, Validate Pull Request, Release, Publish
  release-please/             Release configuration and manifest
  rulesets/                   Branch and tag protection as committed JSON (+ RULESETS.md)
  scripts/                    lint-commit-msg.sh, list-files.sh
taskfiles/                    Task modules, flattened into the root Taskfile.yml
Taskfile.yml                  Task entry point (cannot move — root-only discovery)
.gitattributes                Line endings; generated files marked linguist-generated
.devcontainer/
  Dockerfile                  The image: mise, pinned by ARG
  .dockerignore               Empties the build context (`*`)
  devcontainer.json           Features, extensions, settings, mounts
  devcontainer-lock.json      Feature digests (refreshed by Dependabot)
  mise.toml                   Every other pinned CLI — the single anchor
  scripts/
    post-create.sh            One-time setup entry point
    verify-toolchain.sh       Asserts mise and every mise.toml pin are what is installed
    lib/
      base-setup.sh           Reusable setup orchestrator
      common.sh               Shared utilities
```
