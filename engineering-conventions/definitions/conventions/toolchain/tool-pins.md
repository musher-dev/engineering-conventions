---
id: EC-0017
title: Tool pins
summary: >-
  One mise configuration, at .config/mise/config.toml, pins every tool a
  repository runs to an exact version with a qualified backend, requires the
  mise version that reads it, and is locked. Anything that pins a tool outside
  mise (a Dockerfile, a dev container Feature, packageManager, a setup action
  or a version file) pins the same version.
status: draft
topic: toolchain
applies_to:
  paths:
    - .config/mise/config.toml
    - .config/mise/mise.lock
    - "**/mise.toml"
    - "**/Dockerfile"
    - "**/*.Dockerfile"
    - .devcontainer/devcontainer.json
    - "**/package.json"
    - .github/workflows/*.yml
    - .github/actions/**/action.yml
    - "**/.nvmrc"
    - "**/.node-version"
    - "**/.python-version"
    - "**/.tool-versions"
created: 2026-09-28
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
implementations:
  - repo: musher-dev/platform
    check: TC-01
    mode: blocking
  - repo: musher-dev/platform
    check: TC-02
    mode: blocking
  - repo: musher-dev/platform
    check: TC-03
    mode: blocking
  - repo: musher-dev/platform
    check: TC-12
    mode: blocking
  - repo: musher-dev/development-container
    check: TC-02
    mode: blocking
  - repo: musher-dev/development-container
    check: TC-03
    mode: blocking
references:
  - title: "mise: Configuration"
    url: https://mise.jdx.dev/configuration.html
  - title: "mise: Lockfile"
    url: https://mise.jdx.dev/dev-tools/mise-lock.html
  - title: "mise: Core tools"
    url: https://mise.jdx.dev/core-tools.html
  - title: "mise: Registry"
    url: https://mise.jdx.dev/registry.html
  - title: "jdx/mise-action"
    url: https://github.com/jdx/mise-action
requirements:
  - id: TOOL-01
    title: A repository has one mise configuration, at .config/mise/config.toml
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.toolchain.tool_pins
  - id: TOOL-02
    title: Every tool in the mise configuration names its backend, except mise's core tools
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.toolchain.tool_pins
  - id: TOOL-03
    title: Every tool in the mise configuration is pinned to one exact version
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.toolchain.tool_pins
  - id: TOOL-04
    title: The mise configuration sets min_version, and every place that installs mise installs that version
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.toolchain.tool_pins
  - id: TOOL-05
    title: The mise lockfile is committed beside the configuration
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.toolchain.tool_pins
  - id: TOOL-06
    title: A Dockerfile's version argument defaults to one exact version
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.toolchain.tool_pins
    aliases: ["development-container:TC-02"]
  - id: TOOL-07
    title: A Dockerfile's image of a tool mise pins uses the pinned version
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.toolchain.tool_pins
    aliases: ["platform:TC-01", "platform:TC-02", "platform:TC-03"]
  - id: TOOL-08
    title: A dev container Feature that installs a tool mise pins installs the pinned version
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.toolchain.tool_pins
    aliases: ["platform:TC-03"]
  - id: TOOL-09
    title: package.json's packageManager is the version mise pins
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.toolchain.tool_pins
    aliases: ["platform:TC-01"]
  - id: TOOL-10
    title: A setup action installs the version mise pins
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.toolchain.tool_pins
    aliases: ["platform:TC-01", "platform:TC-02", "platform:TC-12", "development-container:TC-03"]
  - id: TOOL-11
    title: A runtime version file says what mise pins, and there is no .tool-versions
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.toolchain.tool_pins
    aliases: ["platform:TC-03"]
---

# Tool pins

A repository pins the version of every tool it runs in one file, the [mise](https://mise.jdx.dev) configuration at
`.config/mise/config.toml`. The dev container, a developer's shell and CI install from that file, so a local run and
a CI run use the same versions, and a version changes in one line of one pull request.

Some places cannot read mise: a Dockerfile's `FROM`, a dev container Feature's options, `packageManager` in
`package.json`, a setup action's input, a `.nvmrc`. When one of them pins a tool mise also pins, it pins the same
version. Before checks like these existed, the same tool ran at different versions in CI, the dev container and
production, and nobody had chosen any of them.

## Scope

This convention covers the mise configuration and every file that pins a tool mise pins. A repository with no mise
configuration gets only TOOL-06 and the `.tool-versions` half of TOOL-11. What mise itself accepts (the file format,
the backends, the lockfile) is defined by mise and linked from each requirement, not restated here.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirements are `proposed` at
severity `warning`. They replace the lockstep checks `musher-dev/platform` and `musher-dev/development-container`
run today, which each repository retires when it pins the release that carries them; each requirement lists the
check it replaces in `aliases`.

### Differences from platform TC and development-container TC

| Difference | Upstream today | Here |
| --- | --- | --- |
| The anchor | platform: a different file per tool (`packageManager` for bun, the setup-uv action's default for uv, `.nvmrc` for node, an image's `ARG TASK_VERSION` for task) | The mise configuration, for every tool |
| Node | platform TC-03 compares the major version only | The whole version (TOOL-07, TOOL-08, TOOL-11) |
| A setup action's version | platform TC-02 forbids overriding the shared setup-uv action's pin | Any setup action's version input equals the mise pin (TOOL-10); the better fix is `jdx/mise-action` |
| Baked tools | development-container TC-01 keeps bun, uv and task out of Features by baking them into the Dockerfile, and TC-02 requires their `ARG`s | **Superseded, not ported.** mise installs them from the configuration, and the Dockerfile bakes only mise. TOOL-06 keeps the exactness half of TC-02 |
| Not adopted | platform TC-04 (the Python Feature against `requires-python`), TC-05 (a pinned-versions table), TC-07 (dev container wiring), TC-09 (one CLI's install) | These are specific to the platform and stay there |

## What mise reads

mise looks for configuration in several places and merges every file it finds
([configuration](https://mise.jdx.dev/configuration.html)). This convention allows one:

```toml
# .config/mise/config.toml
min_version = "2026.9.12"

[tools]
node = "24.21.0"
python = "3.13.15"
"aqua:astral-sh/uv" = "0.12.18"
"aqua:go-task/task" = "3.53.1"
"github:musher-dev/engineering-conventions" = "0.5.0"
```

```text
.config/mise/config.toml   the configuration
.config/mise/mise.lock     the lockfile mise writes beside it
```

`.config/mise/config.toml` is a location mise reads without being told, so nothing points mise at it, and it keeps
the repository root for the files whose tool reads only the root.

**Prefer `jdx/mise-action` in CI.** A workflow that installs its tools with
[`jdx/mise-action`](https://github.com/jdx/mise-action) installs the versions in the configuration, and has no second
pin to keep equal. A `setup-node` or `setup-uv` step is a second pin; TOOL-10 checks it, but the simpler fix is to
remove it.

## Requirements

### TOOL-01

**A repository has one mise configuration, at `.config/mise/config.toml`.**

mise merges every configuration it finds, and a file closer to the working directory overrides one further away. A
second file (a root `mise.toml`, a `.devcontainer/mise.toml` an environment variable points at, a `mise.ci.toml`, a
`mise.toml` in a subdirectory) splits the pins, and which version runs depends on where the command is run. Every
location mise reads is reported except `.config/mise/config.toml` at the root. A `mise.local.toml` is personal and
never committed.

The release pin that ADOPT-09 looks for is still found in any of those files; TOOL-01 only asks for it to move.

**Correct:**

```text
.config/mise/config.toml
```

**Incorrect:**

```text
mise.toml
.devcontainer/mise.toml       # read through MISE_GLOBAL_CONFIG_FILE
```

Checked by: conftest · Severity: warning · Since: 0.6.0

### TOOL-02

**Every tool in the mise configuration names its backend, except mise's core tools.**

A bare name like `uv` is looked up in mise's [registry](https://mise.jdx.dev/registry.html), which maps it to a
backend that can change between mise versions, so the same line can install from a different source after an
upgrade. A qualified name (`aqua:astral-sh/uv`, `npm:markdownlint-cli2`, `pipx:yamllint`) says where the tool comes
from. mise's [core tools](https://mise.jdx.dev/core-tools.html) (`bun`, `deno`, `dotnet`, `elixir`, `erlang`, `go`,
`java`, `node`, `python`, `ruby`, `rust`, `swift`, `zig`) are built into mise, so their bare names are exact; `core:`
may be written but is not needed.

**Correct:**

```toml
[tools]
node = "24.21.0"
"aqua:astral-sh/uv" = "0.12.18"
```

**Incorrect:**

```toml
[tools]
uv = "0.12.18"                # resolved through the registry
```

Checked by: conftest · Severity: warning · Since: 0.6.0

### TOOL-03

**Every tool in the mise configuration is pinned to one exact version.**

`latest`, `lts`, a range, a `prefix:`, `ref:`, `path:` or `sub-` version, or a partial version such as `24` or
`3.13` resolves to a different release as new ones appear
([tool versions](https://mise.jdx.dev/configuration.html)). Two checkouts of the same commit then run different
tools, and an upgrade arrives without a pull request. A version with one or two numeric parts counts as partial; a
tool whose releases really have two parts is waived.

**Correct:**

```toml
[tools]
node = "24.21.0"
python = "3.13.15"
```

**Incorrect:**

```toml
[tools]
node = "lts"
python = "3.13"
"aqua:astral-sh/uv" = "latest"
```

Checked by: conftest · Severity: warning · Since: 0.6.0

### TOOL-04

**The mise configuration sets `min_version`, and every place that installs mise installs that version.**

mise cannot pin itself, so its version is set wherever mise is installed: the `version` input of
`jdx/mise-action`, and `ARG MISE_VERSION` in a Dockerfile that bakes it. `min_version`
([minimum mise version](https://mise.jdx.dev/configuration.html#minimum-mise-version)) makes an older mise refuse the
configuration instead of resolving it differently, and holding the other two equal to it keeps the dev container and
CI on the same mise. A `jdx/mise-action` step with no `version` installs the latest mise, and is reported. A leading
`v` is ignored; a `min_version` with only a `soft` minimum does not count.

**Correct:**

```toml
# .config/mise/config.toml
min_version = "2026.9.12"
```

```yaml
- uses: jdx/mise-action@c2a87611a18de5b3828c5652fe268e992400cb5c  # v4.3.0
  with:
    version: 2026.9.12
```

```dockerfile
ARG MISE_VERSION=v2026.9.12
```

**Incorrect:**

```yaml
- uses: jdx/mise-action@c2a87611a18de5b3828c5652fe268e992400cb5c  # v4.3.0
                              # no version: the latest mise
```

Checked by: conftest · Severity: warning · Since: 0.6.0

### TOOL-05

**The mise lockfile is committed beside the configuration.**

A version names a release, not a file. The [lockfile](https://mise.jdx.dev/dev-tools/mise-lock.html) records the
download URL and checksum of each tool for each platform, so every install fetches the same bytes, and
`mise install --locked` fails instead of resolving a tool the lockfile does not cover. The lockfile of
`.config/mise/config.toml` is `.config/mise/mise.lock`. Run `mise lock` after changing a pin, and commit both in
the same change.

**Correct:**

```text
.config/mise/config.toml
.config/mise/mise.lock
```

**Incorrect:**

```text
.config/mise/config.toml      # no mise.lock
```

Checked by: conftest · Severity: warning · Since: 0.6.0

### TOOL-06

**A Dockerfile's version argument defaults to one exact version.**

An `ARG` whose name ends in `_VERSION` is how a Dockerfile pins what it installs, and a default of `latest`, `stable`
or `24` builds a different image each time. The same exactness rules apply as in TOOL-03, and a leading `v` is
ignored. An `ARG` without a default, or one that defaults to another argument (`${NODE_VERSION}`), is left to the
build.

**Correct:**

```dockerfile
ARG MISE_VERSION=v2026.9.12
```

**Incorrect:**

```dockerfile
ARG MISE_VERSION=latest
ARG NODE_VERSION=24
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: development-container TC-02

### TOOL-07

**A Dockerfile's image of a tool mise pins uses the pinned version.**

An image built on `node:24` or `oven/bun:latest` runs whatever the registry holds today, while the dev container and
CI run the version mise pins, so a service is tested on one version and shipped on another. The check reads each
`FROM` and each `COPY --from=` image, resolving `${ARG}` from the Dockerfile's own defaults, for the official images
of `node`, `python`, `golang`, `rust`, `ruby`, `oven/bun`, `denoland/deno` and `ghcr.io/astral-sh/uv`, when mise
pins that tool. The version in the tag (`24.21.0` in `node:24.21.0-slim`, `2.5.0` in `denoland/deno:alpine-2.5.0`)
must equal the pin. A tag with no version is reported, unless the image is pinned by digest, which is exact but does
not say which version it holds; prefer a versioned tag with the digest.

**Correct:**

```dockerfile
FROM node:24.21.0-slim
COPY --from=ghcr.io/astral-sh/uv:0.12.18 /uv /usr/local/bin/
```

**Incorrect:**

```dockerfile
FROM node:24-slim             # mise pins 24.21.0
FROM oven/bun:latest
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform TC-01, TC-02, TC-03

### TOOL-08

**A dev container Feature that installs a tool mise pins installs the pinned version.**

A Feature is installed when the container is built, before mise runs, so a Feature and mise can put two versions of
the same tool on PATH, and which one a command finds depends on PATH order. The better fix is to drop the Feature and
let mise install the tool. Where a Feature stays, its `version` option equals the pin, and a Feature with no
`version` installs its own default, which floats. `"none"` installs nothing and is not reported. The Features read
are the `devcontainers` ones for node, python, go, rust, ruby, java and dotnet, and the `devcontainers-extra` (or
`devcontainers-contrib`) ones for bun, deno, uv, go-task and pnpm.

**Correct:**

```jsonc
"features": {
  "ghcr.io/devcontainers/features/node:1": { "version": "24.21.0" }
}
```

**Incorrect:**

```jsonc
"features": {
  "ghcr.io/devcontainers/features/node:1": { "version": "lts" },
  "ghcr.io/devcontainers-extra/features/uv:1": {}
}
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform TC-03

### TOOL-09

**`package.json`'s `packageManager` is the version mise pins.**

`packageManager` is what Corepack and Bun honour, and the version that wrote the lockfile. If mise installs a
different version, a developer's install rewrites a lockfile that CI then rejects, or resolves a tree no image build
produces. The check reads every `package.json` at the root or up to two directories down, when mise pins the manager
it names; a `+sha…` suffix is ignored.

**Correct:**

```json
{ "packageManager": "bun@1.3.14" }
```

**Incorrect:**

```json
{ "packageManager": "bun@1.3.9" }
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform TC-01

### TOOL-10

**A setup action installs the version mise pins.**

A step that installs a tool with its own action (`actions/setup-node`, `actions/setup-python`, `actions/setup-go`,
`astral-sh/setup-uv`, `arduino/setup-task`, `oven-sh/setup-bun`, `denoland/setup-deno`, `ruby/setup-ruby`,
`pnpm/action-setup`) is a second pin of a tool mise pins. Its version input equals the pin; a step with no version
input and no version-file input installs the action's default, which floats. A value that is a GitHub expression
is not checked. The simpler fix is to replace the step with `jdx/mise-action`, which installs every pin at once.

**Correct:**

```yaml
- uses: jdx/mise-action@c2a87611a18de5b3828c5652fe268e992400cb5c  # v4.3.0
  with:
    version: 2026.9.12
```

```yaml
- uses: actions/setup-node@<commit-sha>  # v4
  with:
    node-version: 24.21.0
```

**Incorrect:**

```yaml
- uses: arduino/setup-task@<commit-sha>  # v2
  with:
    version: 3.x              # mise pins 3.53.1
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform TC-01, TC-02, TC-12;
development-container TC-03

### TOOL-11

**A runtime version file says what mise pins, and there is no `.tool-versions`.**

`.nvmrc`, `.node-version` and `.python-version` are read by tools other than mise: nvm, `actions/setup-node`, uv,
pyenv. When one exists anywhere in the repository and mise pins its runtime, its version equals the pin, or those
tools run a different runtime than mise installs. Delete it if nothing but mise reads it. `.tool-versions` is asdf's
pin file, which mise also reads, so it is always a second source of versions.

**Correct:**

```text
# .python-version, read by uv; mise pins python = "3.13.15"
3.13.15
```

**Incorrect:**

```text
# .nvmrc; mise pins node = "24.21.0"
lts/*
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform TC-03

## References

- [mise: Configuration](https://mise.jdx.dev/configuration.html)
- [mise: Lockfile](https://mise.jdx.dev/dev-tools/mise-lock.html)
- [mise: Core tools](https://mise.jdx.dev/core-tools.html)
- [mise: Registry](https://mise.jdx.dev/registry.html)
- [jdx/mise-action](https://github.com/jdx/mise-action)
