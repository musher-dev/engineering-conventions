# `.config/` — Tool Configuration

Every linter, formatter, rule-tool and hook config lives here. One directory, one purpose: if a tool needs a config
file and it is not provisioning the container, it goes in here.

Policy and rationale: [`CONFIGURATION.md`](../CONFIGURATION.md).

## Index

| File | Tool | How it is reached |
| --- | --- | --- |
| `lefthook.yml` | lefthook | **Auto-discovered.** Lefthook searches `.config/lefthook.*` natively |
| `lefthook-local.yml` | lefthook | Auto-discovered and merged. Gitignored; personal overrides only |
| `actions/actionlint.yaml` | actionlint | `-config-file .config/actions/actionlint.yaml` |
| `actions/zizmor.yml` | zizmor | `--config .config/actions/zizmor.yml` |
| `markdown/markdownlint.jsonc` | markdownlint-cli2 | `--config .config/markdown/markdownlint.jsonc` |
| `markdown/vale.ini` | Vale | `--config .config/markdown/vale.ini` |
| `rego/regal.yaml` | Regal | `--config-file .config/rego/regal.yaml` |
| `security/gitleaks.toml` | gitleaks | `--config .config/security/gitleaks.toml` |
| `spelling/typos.toml` | typos | `--config .config/spelling/typos.toml` |
| `yaml/yamllint.yaml` | yamllint | `-c .config/yaml/yamllint.yaml` |

Call sites are the [`taskfiles/`](../taskfiles/) and [`lefthook.yml`](lefthook.yml); CI runs the same tasks. Tool
versions are pinned in one place, [`.devcontainer/mise.toml`](../.devcontainer/mise.toml), and CI resolves them from
that same file.

## Rules

1. **Bucket by concern.** `.config/<concern>/<tool>.<ext>`. A one-file bucket is fine and collects siblings over
   time. The single exception is `lefthook.yml`, which sits at the top level because lefthook's config search does
   not descend past `.config/lefthook.*`; bucketing it would silently stop every hook.
2. **No leading dot on filenames.** The directory is already dotted; a second dot adds nothing.
3. **Pass the path explicitly.** Except for lefthook, which finds this directory on its own, every caller names its
   config with the tool's config flag. Never rely on default discovery; that is what puts these files at the repo
   root in the first place.
4. **Every file must have a caller**, and appear in the index above.
5. **Every ignore needs a reason.** Suppressions, allowlists, excludes and disabled rules carry an inline comment
   explaining why the exception is acceptable. Nothing is suppressed inline in the code it concerns.
6. **Configuration only.** No executables. A script belongs beside what runs it (`.github/scripts/`,
   `.devcontainer/scripts/`).

## What does *not* live here

| Thing | Where | Why |
| --- | --- | --- |
| `Taskfile.yml` | Repo root | Task only discovers `Taskfile.*` at the root; `--taskfile` would break bare `task <name>` |
| `mise.toml` | `.devcontainer/` | It provisions the environment, rather than checking the code |
| `.gitattributes`, `.gitignore` | Repo root | Git reads these from the root only |
| VS Code settings | `devcontainer.json` | `customizations.vscode.settings` is the single editor source |
| The CLI's ruff, basedpyright and pytest settings | `engineering-conventions/pyproject.toml` | Their tools find them by walking up from the product; see [LAYOUT.md](../LAYOUT.md) |
| The MusherConventions Vale style | `engineering-conventions/checks/vale/` | It is product, generated and shipped; `vale.ini` here only points at it |

## A trap worth knowing

Lefthook's config search is **first-match-wins**, in this order:

```text
lefthook.*  →  .lefthook.*  →  .config/lefthook.*
```

A stray `lefthook.yml` at the repo root therefore **silently shadows** this directory's copy: no warning, no error,
just different hooks.
