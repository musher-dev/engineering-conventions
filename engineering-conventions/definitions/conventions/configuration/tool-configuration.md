---
id: EC-0011
title: Tool configuration
summary: >-
  A tool's configuration lives in .config/<concern>/<tool>.<ext>, never at
  the repository root, and is passed to the tool by path. .config/ holds
  declarations only, is indexed in its README, and every file in it has a
  caller that names it, as every path a caller names exists.
status: draft
topic: configuration
applies_to:
  paths:
    - .config/**
    - "*"
created: 2026-09-28
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
implementations:
  - repo: musher-dev/platform
    check: CFG-01
    mode: blocking
  - repo: musher-dev/platform
    check: CFG-02
    mode: blocking
  - repo: musher-dev/platform
    check: CFG-03
    mode: blocking
  - repo: musher-dev/platform
    check: CFG-04
    mode: blocking
  - repo: musher-dev/platform
    check: CFG-05
    mode: blocking
  - repo: musher-dev/platform
    check: CFG-06
    mode: blocking
  - repo: musher-dev/platform
    check: CFG-07
    mode: blocking
  - repo: musher-dev/platform
    check: CFG-08
    mode: blocking
  - repo: musher-dev/development-container
    check: CFG-01
    mode: blocking
  - repo: musher-dev/development-container
    check: CFG-02
    mode: blocking
  - repo: musher-dev/development-container
    check: CFG-03
    mode: blocking
  - repo: musher-dev/development-container
    check: CFG-04
    mode: blocking
  - repo: musher-dev/development-container
    check: CFG-05
    mode: blocking
  - repo: musher-dev/development-container
    check: CFG-06
    mode: blocking
  - repo: musher-dev/development-container
    check: CFG-07
    mode: blocking
  - repo: musher-dev/development-container
    check: CFG-08
    mode: blocking
  - repo: musher-dev/development-container
    check: CFG-09
    mode: blocking
references:
  - title: "lefthook: Configuration"
    url: https://lefthook.dev/configuration/
  - title: "mise: Configuration"
    url: https://mise.jdx.dev/configuration.html
  - title: "XDG Base Directory Specification"
    url: https://specifications.freedesktop.org/basedir-spec/latest/
requirements:
  - id: CONF-01
    title: A known tool's configuration does not sit at the repository root
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.configuration.tool_configuration
    aliases: ["platform:CFG-07", "development-container:CFG-07"]
  - id: CONF-02
    title: A repository with a .config/ directory indexes it in .config/README.md
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.configuration.tool_configuration
    aliases:
      - "platform:CFG-01"
      - "platform:CFG-02"
      - "development-container:CFG-01"
      - "development-container:CFG-02"
  - id: CONF-03
    title: Every file under .config/ is named in .config/README.md
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.configuration.tool_configuration
    aliases: ["platform:CFG-03", "development-container:CFG-03"]
  - id: CONF-04
    title: Every file under .config/ has a caller that names it by path
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.configuration.tool_configuration
    aliases: ["platform:CFG-04", "development-container:CFG-04"]
  - id: CONF-05
    title: No filename inside .config/ starts with a dot
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.configuration.tool_configuration
    aliases: ["platform:CFG-05", "development-container:CFG-05"]
  - id: CONF-06
    title: No lefthook configuration at the root shadows .config/lefthook.yml
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.configuration.tool_configuration
    aliases: ["platform:CFG-06", "development-container:CFG-06"]
  - id: CONF-07
    title: A tool's configuration sits in a concern directory under .config/
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.configuration.tool_configuration
    aliases: ["platform:CFG-07", "development-container:CFG-07"]
  - id: CONF-08
    title: .config/ holds no programs
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.configuration.tool_configuration
    aliases: ["platform:CFG-08", "development-container:CFG-08"]
  - id: CONF-09
    title: Every .config/ path a caller names exists
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.configuration.tool_configuration
    aliases: ["development-container:CFG-09"]
---

# Tool configuration

Every linter, formatter, scanner and hook runner a repository uses has a configuration file, and each tool's own
documentation says to drop it at the repository root. Follow each of them and the root fills with dotfiles, a reader
cannot tell which of them must be there and which only happen to be, and a tool that finds its configuration by
searching can pick up a stray file from anywhere on its path. This convention gives tool configuration one home,
`.config/`, and makes every file in it accountable: indexed, named by a caller, and nothing but configuration.

## Scope

This convention covers the repository root and the `.config/` directory. A repository that keeps no tool
configuration meets every requirement. Where a tool's *version* is pinned is a separate question; this convention
decides only where its configuration lives and how the tool is pointed at it. Rules about what a configuration
*contains* belong to the tool, except the suppressions governed by [EC-0012](suppressions.md).

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). It adopts the CFG checks that
`musher-dev/platform` and `musher-dev/development-container` each run today, which retire there once a release
carries these requirements
([decision 0016](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)).
Its requirements are `proposed` at severity `warning`, like every requirement in the 0.x series.

### Differences from the upstream checks

| Upstream | Here | Why |
| --- | --- | --- |
| CFG-01 reports a missing `.config/` | Nothing requires the directory; CONF-02 asks for the index once it exists | A repository with no tool configuration has nothing to put there |
| CFG-03 matches a backticked path or name | A backticked directory also indexes every file under it | Generated trees, such as mise's per-tool locks, are indexed as one row |
| CFG-04 and CFG-09 search the callers' raw text, comments included | They read the strings of parsed callers | A comment that mentions a path does not run the tool |
| CFG-04 reads Taskfiles, workflows, lefthook and shell scripts | Taskfiles, lefthook, workflows, composite actions, `devcontainer.json` and `package.json` | Shell scripts are not parsed; a script's caller names the configuration instead |
| CFG-07's list of root files differs in the two repositories | One list, in the check | One answer everywhere |
| platform CFG-09 means a suppression's expiry | [CONF-10](suppressions.md#conf-10) | The two repositories' CFG-09 are different checks |

## The layout

```text
.config/
├── README.md                  the index: one row per file, its tool and its caller
├── lefthook.yml               where lefthook's search ends, so it cannot go deeper
├── lefthook-local.yml         one person's hook overrides, ignored by git
├── mise/config.toml           where mise reads project configuration unprompted
├── actions/actionlint.yaml
├── markdown/markdownlint.jsonc
├── security/gitleaks.toml
└── yaml/yamllint.yaml
```

A concern is a coarse bucket (`markdown`, `security`, `yaml`, `actions`), not a directory per tool. The file keeps its
tool's usual name without the leading dot. Every caller passes the path with the tool's flag (`--config`, `-c`,
`--ignorefile`), so nothing depends on where the tool would search.

Some files must stay at the root, because their tool finds them only there or because they are the entry point
itself. None of them is reported:

| File | Why it stays at the root |
| --- | --- |
| `Taskfile.yml` | Task's entry point; `task` finds it from any subdirectory |
| `.gitignore`, `.gitattributes` | git reads them from the directories they govern, with no flag |
| `.dockerignore` | Docker reads it from the root of the build context |
| `.editorconfig` | Editors search for it upward from the file being edited |
| `package.json` and lockfiles | The package manager's project root |
| `.nvmrc`, `.node-version`, `.python-version` | Version managers read them from the working directory |
| `eslint.config.js` and other configuration written as a program | `.config/` holds declarations only (CONF-08) |

## Requirements

### CONF-01

**A known tool's configuration does not sit at the repository root.**

A configuration at the root works because the tool searches for it there, and so does the next one, until the root is
a list of dotfiles and nobody can tell which are required. The check reports a root file that a known tool searches
for: markdownlint, yamllint, codespell, typos, actionlint, zizmor, Prettier, ESLint, Stylelint, ShellCheck, hadolint,
gitleaks, Trivy, Vale, Regal, Taplo, Ruff and lychee. Move the file to `.config/<concern>/`, drop its leading dot, and
pass the new path from every caller.

**Correct:**

```text
.config/yaml/yamllint.yaml      yamllint -c .config/yaml/yamllint.yaml .
```

**Incorrect:**

```text
.yamllint.yaml                  yamllint .
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CFG-07, development-container CFG-07

### CONF-02

**A repository with a `.config/` directory indexes it in `.config/README.md`.**

The index is what lets a reader open the directory and know, for each file, which tool reads it, what it configures
and what runs it, without searching the repository for callers. Add one row per file. A `.config/` that holds only
files their tools find by themselves (`lefthook.yml`, and mise's `mise/config.toml`, `mise/mise.lock` and
`mise/locks/`) needs no index: the tool's own documentation says what they are.

**Correct:**

```markdown
| File | Tool | Configures | Caller |
| --- | --- | --- | --- |
| `yaml/yamllint.yaml` | yamllint | YAML lint | `task lint:yaml`, the pre-commit hook |
```

**Incorrect:**

```text
.config/yaml/yamllint.yaml      (no .config/README.md)
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CFG-01 and CFG-02,
development-container CFG-01 and CFG-02

### CONF-03

**Every file under `.config/` is named in `.config/README.md`.**

A file missing from the index is invisible to the next reader, who cannot tell which tool consumes it or whether it is
still used. The check looks for the file in backticks anywhere in the index: its path under `.config/`
(`yaml/yamllint.yaml`), its name (`yamllint.yaml`), its full path, or a directory that holds it (`mise/locks/`) for a
generated tree. `README.md` files, `lefthook-local.yml` and the files a tool finds by itself (see CONF-02) need not
be indexed.

**Correct:**

```markdown
| `yaml/yamllint.yaml` | yamllint | YAML lint | `task lint:yaml` |
| `spelling/typos.toml` | typos | Spelling | `task lint:spelling` |
```

**Incorrect:**

```markdown
| `yaml/yamllint.yaml` | yamllint | YAML lint | `task lint:yaml` |
```

with `.config/spelling/typos.toml` in the repository.

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CFG-03, development-container CFG-03

### CONF-04

**Every file under `.config/` has a caller that names it by path.**

Configuration is passed by path, so a file no caller names is either dead or read through a search the layout exists
to avoid. Either way it still reads as authoritative. The check looks for the path in the strings of the files that
run tools: Taskfiles, lefthook configuration, workflows, composite actions, `devcontainer.json` and `package.json`. A
caller may name the file or a directory that holds it, and may prefix it with a variable for the repository root
(`{{.ROOT_DIR}}/`, `${workspaceFolder}/`). Files a tool finds inside `.config/` on its own are exempt:
`lefthook.yml`, `lefthook-local.yml`, `mise/config.toml`, `mise/mise.lock` and `mise/locks/`.

**Correct:**

```yaml
# Taskfile.yml
vars:
  YAML_CONFIG: .config/yaml/yamllint.yaml
tasks:
  lint:yaml:
    cmds:
      - yamllint -c {{.YAML_CONFIG}} --strict .
```

**Incorrect:**

```yaml
# Taskfile.yml
tasks:
  lint:yaml:
    cmds:
      - yamllint --strict .
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CFG-04, development-container CFG-04

### CONF-05

**No filename inside `.config/` starts with a dot.**

A leading dot says a tool finds the file by searching. Inside `.config/` every file is passed by path, so the dot
advertises a mechanism that is not in use, and the directory is already hidden. Rename the file without the dot and
update its callers.

**Correct:**

```text
.config/markdown/markdownlint.jsonc
```

**Incorrect:**

```text
.config/markdown/.markdownlint.jsonc
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CFG-05, development-container CFG-05

### CONF-06

**No lefthook configuration at the root shadows `.config/lefthook.yml`.**

lefthook searches `lefthook.*`, then `.lefthook.*`, then `.config/lefthook.*`, and uses the first it finds. A root
`lefthook.yml`, in any of lefthook's extensions, silently wins: the hooks in `.config/lefthook.yml` stop running, and
nothing says so. Move the root file's jobs into `.config/lefthook.yml` and delete it.

**Correct:**

```text
.config/lefthook.yml
```

**Incorrect:**

```text
.config/lefthook.yml
lefthook.yml
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CFG-06, development-container CFG-06

### CONF-07

**A tool's configuration sits in a concern directory under `.config/`.**

The top level of `.config/` holds only `README.md`, `lefthook.yml` and `lefthook-local.yml`: lefthook's search stops at
`.config/lefthook.*`, so its files cannot go deeper. Everything else goes in `.config/<concern>/<tool>.<ext>`, which
keeps related tools together and the top level readable.

**Correct:**

```text
.config/yaml/yamllint.yaml
```

**Incorrect:**

```text
.config/yamllint.yaml
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CFG-07, development-container CFG-07

### CONF-08

**`.config/` holds no programs.**

A script in `.config/` looks like configuration, is reviewed as configuration, and is missed by every check that looks
for code where code lives. The check reports a file with a program's extension: `.sh`, `.bash`, `.zsh`, `.py`, `.js`,
`.mjs`, `.cjs`, `.ts`, `.mts`, `.cts`, `.rb`, `.pl` or `.ps1`. It keys on the extension alone, because many
legitimate configuration files have none. Move the program beside what runs it.

**Correct:**

```text
scripts/banner.sh
.config/markdown/vale.ini
```

**Incorrect:**

```text
.config/scripts/banner.sh
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CFG-08, development-container CFG-08

### CONF-09

**Every `.config/` path a caller names exists.**

A tool given a missing configuration path either fails, or worse, falls back to its defaults and passes. CONF-04
proves every file has a caller; this proves every caller's path has a file, so a rename that missed a caller is
caught. The check reads the same callers as CONF-04, accepts a path to a file or a directory, and ignores a path under
a home directory (`~/.config/gh`, `/home/vscode/.config`, `$HOME/.config`), which is the user's, not the
repository's, and `lefthook-local.yml`, which git ignores.

**Correct:**

```yaml
- markdownlint-cli2 --config .config/markdown/markdownlint.jsonc "**/*.md"
```

**Incorrect:**

```yaml
- markdownlint-cli2 --config .config/markdownlint.jsonc "**/*.md"
```

after the file moved to `.config/markdown/`.

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container CFG-09

## Rationale

The XDG base-directory convention already puts a user's tool configuration in `~/.config/`; a repository's `.config/`
applies the same idea one level down. Keeping configuration out of the root makes the root a list of what the
repository *is*, not of what it runs. Passing every path explicitly makes each tool's configuration a visible
dependency of its caller: a moved file breaks loudly (CONF-09) instead of silently reverting to defaults, and a
developer's personal configuration can never change what CI accepts.

## References

- [lefthook: Configuration](https://lefthook.dev/configuration/), the search order CONF-06 and CONF-07 depend on
- [mise: Configuration](https://mise.jdx.dev/configuration.html), the files CONF-04 exempts
- [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/)
