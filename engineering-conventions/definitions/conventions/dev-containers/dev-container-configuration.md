---
id: EC-0027
title: Dev container configuration
summary: >-
  A dev container's configuration lives at .devcontainer/devcontainer.json,
  locks its Features, builds on an image that moves only with a commit, runs
  as a user other than root, runs lifecycle scripts the repository holds,
  commits no secret, names its volumes for the container and mounts them in
  the remote user's home, gives the container no fixed name, and is kept
  current by Dependabot or Renovate and built in CI.
status: draft
topic: dev-containers
applies_to:
  paths:
    - .devcontainer.json
    - .devcontainer-lock.json
    - .devcontainer/**/devcontainer.json
    - .devcontainer/**/devcontainer-lock.json
    - .devcontainer/**/Dockerfile
    - .github/dependabot.yml
    - .github/workflows/*.yml
created: 2026-09-29
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "Dev Container specification: devcontainer.json reference"
    url: https://containers.dev/implementors/json_reference/
  - title: "Dev Container specification: Lockfile"
    url: https://github.com/devcontainers/spec/blob/main/docs/specs/devcontainer-lockfile.md
  - title: "Dev Container specification: Prebuilding images"
    url: https://containers.dev/guide/prebuild
  - title: "GitHub Docs: Dependabot's devcontainers ecosystem"
    url: https://docs.github.com/en/code-security/dependabot/ecosystems-supported-by-dependabot/supported-ecosystems-and-repositories
  - title: "Renovate: devcontainer manager"
    url: https://docs.renovatebot.com/modules/manager/devcontainer/
requirements:
  - id: DEVC-01
    title: A dev container's configuration lives at .devcontainer/devcontainer.json or .devcontainer/<name>/devcontainer.json
    status: proposed
    severity: warning
    since: 0.6.3
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.configuration
  - id: DEVC-02
    title: A dev container that uses Features commits its lockfile beside its configuration
    status: proposed
    severity: warning
    since: 0.6.3
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.configuration
  - id: DEVC-03
    title: The lockfile records exactly the Features the configuration uses
    status: proposed
    severity: warning
    since: 0.6.3
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.configuration
  - id: DEVC-04
    title: A dev container's base image names a fixed tag or a digest
    status: proposed
    severity: warning
    since: 0.6.3
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.configuration
  - id: DEVC-05
    title: A dev container sets remoteUser, and neither remoteUser nor containerUser is root
    status: proposed
    severity: warning
    since: 0.6.3
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.configuration
  - id: DEVC-06
    title: Every script a lifecycle command runs is a file the repository holds
    status: proposed
    severity: warning
    since: 0.6.3
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.configuration
  - id: DEVC-07
    title: A dev container commits no value for a variable an environment schema marks secret
    status: proposed
    severity: warning
    since: 0.6.3
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.configuration
  - id: DEVC-08
    title: A named volume a dev container mounts is musher-${devcontainerId}-<purpose>
    status: proposed
    severity: warning
    since: 0.6.3
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.configuration
  - id: DEVC-09
    title: Dependabot's devcontainers ecosystem or Renovate keeps a dev container's image and Features current
    status: proposed
    severity: warning
    since: 0.6.3
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.configuration
  - id: DEVC-10
    title: A workflow builds the dev container, with --frozen-lockfile when it has a lockfile
    status: proposed
    severity: warning
    since: 0.6.3
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.configuration
  - id: DEVC-14
    title: A dev container does not give its container a fixed name
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.configuration
  - id: DEVC-15
    title: A volume mounted under /home belongs to remoteUser
    status: proposed
    severity: warning
    since: 0.7.0
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.configuration
---

# Dev container configuration

A dev container is the environment every contributor, human or agent, and often CI, works in. Its configuration is
code that runs on every machine that opens the repository, so the same things that make a build reproducible apply
to it: it is found where tools look, its inputs are locked, it changes only with a commit, and something proves it
still builds. These requirements check the files a dev container is made of. How a scaffold builds its container
(which Features, which scripts, which tools) belongs to that scaffold ([decision 0020](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0020-dev-container-files-get-their-own-family.md)).

## Scope

Every requirement applies only to a repository that has a dev container: a `devcontainer.json` under `.devcontainer/`,
or the root `.devcontainer.json`. A repository without one has no finding here.

Where a value is written with a variable (`${localEnv:…}`, `${VERSION}` in a `FROM`), the check leaves it alone: the
environment or the build decides it.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`), and every requirement is `proposed` at
severity `warning`. The dev container scaffold is `musher-dev/development-container`'s; this convention holds any
repository's dev container to the same bar, that one's included.

## Requirements

### DEVC-01

**A dev container's configuration lives at `.devcontainer/devcontainer.json` or `.devcontainer/<name>/devcontainer.json`.**

Editors, the Dev Container CLI, Codespaces and Dependabot look in exactly these places. The root `.devcontainer.json`
is allowed by the specification, but nothing can sit beside it: its Dockerfile, scripts, lockfile and environment
schema end up at the repository root. A configuration nested deeper than one directory is never found at all.

**Correct:**

```text
.devcontainer/devcontainer.json
.devcontainer/python/devcontainer.json   # one of several
```

**Incorrect:**

```text
.devcontainer.json
.devcontainer/tools/python/devcontainer.json
```

Checked by: conftest · Severity: warning · Since: 0.6.3

### DEVC-02

**A dev container that uses Features commits its lockfile beside its configuration.**

A Feature is referenced by a tag such as `:2`, which moves whenever the Feature publishes. Without a lockfile, two
rebuilds a week apart install different code, and a broken Feature release breaks every container at once.
`devcontainer-lock.json` records the version and digest each reference resolved to, and Dependabot raises it in a
reviewed pull request. The root form's lockfile is `.devcontainer-lock.json`.

**Correct:**

```text
.devcontainer/devcontainer.json
.devcontainer/devcontainer-lock.json
```

**Incorrect:**

```text
.devcontainer/devcontainer.json          # uses Features, no lockfile
```

Checked by: conftest · Severity: warning · Since: 0.6.3

### DEVC-03

**The lockfile records exactly the Features the configuration uses.**

A Feature added without regenerating the lockfile is unlocked, and one removed leaves an entry that looks as if it
still installs. Either way the lockfile no longer describes the container. A Feature that another Feature pulls in
through `dependsOn` is locked without being named in the configuration, and is not reported.

**Correct:**

```jsonc
// devcontainer.json
"features": { "ghcr.io/devcontainers/features/git:1": {} }
// devcontainer-lock.json
"features": { "ghcr.io/devcontainers/features/git:1": { "version": "1.3.8", "resolved": "…", "integrity": "…" } }
```

**Incorrect:**

```jsonc
// devcontainer.json
"features": { "ghcr.io/devcontainers/features/git:1": {}, "ghcr.io/devcontainers/features/github-cli:1": {} }
// devcontainer-lock.json: github-cli is missing
"features": { "ghcr.io/devcontainers/features/git:1": { … } }
```

Run `devcontainer upgrade --workspace-folder .` to rewrite the lockfile.

Checked by: conftest · Severity: warning · Since: 0.6.3

### DEVC-04

**A dev container's base image names a fixed tag or a digest.**

The base image is the largest input to the container. An image without a tag, or tagged `latest`, `main`, `stable`
or another moving name, changes under the repository with no commit to review or revert. This applies to `image` in
the configuration and to the `FROM` lines of the Dockerfile its `build` names. A FROM that names an earlier stage is
not an image.

**Correct:**

```jsonc
"image": "mcr.microsoft.com/devcontainers/base:ubuntu-24.04"
```

```dockerfile
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04
```

**Incorrect:**

```jsonc
"image": "mcr.microsoft.com/devcontainers/base:latest"
```

```dockerfile
FROM mcr.microsoft.com/devcontainers/base
```

Checked by: conftest · Severity: warning · Since: 0.6.3

### DEVC-05

**A dev container sets remoteUser, and neither remoteUser nor containerUser is root.**

A container whose tools run as root writes root-owned files into the bind-mounted workspace, which the host user then
cannot edit or delete, and gives every tool and script in it full control of the container. When `remoteUser` is
unset, the user is whatever the image's metadata says, which a reader of the configuration cannot see.

**Correct:**

```jsonc
"remoteUser": "vscode"
```

**Incorrect:**

```jsonc
"remoteUser": "root"
```

Checked by: conftest · Severity: warning · Since: 0.6.3

### DEVC-06

**Every script a lifecycle command runs is a file the repository holds.**

`initializeCommand`, `onCreateCommand`, `updateContentCommand`, `postCreateCommand`, `postStartCommand` and
`postAttachCommand` name scripts by path. When a script moves and the command does not, the container still starts,
the step is skipped with an error in a log nobody reads, and the environment is silently half set up. The check reads
each relative path to a script (`.sh`, `.bash`, `.py`, `.js`, `.mjs`, `.cjs`, `.ts`, `.ps1`) in the command's text.

**Correct:**

```jsonc
"postCreateCommand": ["bash", ".devcontainer/scripts/post-create.sh"]
```

**Incorrect:**

```jsonc
// the script moved to .devcontainer/scripts/
"postCreateCommand": "bash .devcontainer/post-create.sh"
```

Checked by: conftest · Severity: warning · Since: 0.6.3

### DEVC-07

**A dev container commits no value for a variable an environment schema marks secret.**

`containerEnv` and `remoteEnv` are committed. A secret written there is a credential in version control, shared with
everyone who can read the repository. A variable that any `env.schema.yaml` in the repository marks
`sensitivity: secret` ([EC-0020](../environment/env-schema.md)) may appear there only as a reference to the host's
environment, or empty; Codespaces users receive it through `secrets` (ENVS-15).

**Correct:**

```jsonc
"remoteEnv": { "OPENAI_API_KEY": "${localEnv:OPENAI_API_KEY}" }
```

**Incorrect:**

```jsonc
"remoteEnv": { "OPENAI_API_KEY": "sk-live-…" }
```

Checked by: conftest · Severity: warning · Since: 0.6.3

### DEVC-08

**A named volume a dev container mounts is `musher-${devcontainerId}-<purpose>`.**

Named volumes keep state a rebuild would otherwise lose, such as the GitHub CLI's login or an agent's history. Docker
has one volume namespace per host, so a volume named `gh-config` is shared by every repository's container on the
machine, and a volume named after nothing is orphaned when its container goes. `${devcontainerId}` is stable across
rebuilds and unique to the container, and the `musher-` prefix and the purpose say whose volume it is and what it
holds. `<purpose>` is lower-case words joined by hyphens. Bind mounts and anonymous volumes are not named volumes.

**Correct:**

```jsonc
"mounts": ["source=musher-${devcontainerId}-gh-config,target=/home/vscode/.config/gh,type=volume"]
```

**Incorrect:**

```jsonc
"mounts": ["source=gh-config,target=/home/vscode/.config/gh,type=volume"]
```

Checked by: conftest · Severity: warning · Since: 0.6.3

### DEVC-09

**Dependabot's devcontainers ecosystem or Renovate keeps a dev container's image and Features current.**

A locked, pinned container that nothing updates falls behind on security fixes until someone notices. Dependabot's
`devcontainers` ecosystem raises Feature references and the lockfile; Renovate's `devcontainer` manager, on by
default, raises them and the image. Either is enough; the check looks for a `devcontainers` update in
`.github/dependabot.yml`, or a Renovate configuration file.

**Correct:**

```yaml
# .github/dependabot.yml
updates:
  - package-ecosystem: "devcontainers"
    directory: "/"
    schedule:
      interval: "weekly"
```

**Incorrect:**

```yaml
# .github/dependabot.yml: nothing updates the dev container
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

Checked by: conftest · Severity: warning · Since: 0.6.3

### DEVC-10

**A workflow builds the dev container, with --frozen-lockfile when it has a lockfile.**

A dev container that only people build breaks on the first machine that rebuilds it after a bad change, and every
Dependabot update to it merges unproven. A workflow step that runs the Dev Container CLI's `build` or `up`, or the
`devcontainers/ci` action, proves it builds. With a lockfile, `--frozen-lockfile` also fails the build when the
lockfile is stale, which is how DEVC-03 is enforced beyond the references this check can read.

**Correct:**

```yaml
- name: Build the dev container
  run: npx -y @devcontainers/cli@0.89.0 build --workspace-folder . --frozen-lockfile
```

**Incorrect:**

```yaml
# No job builds .devcontainer/, or one does without --frozen-lockfile:
- run: npx -y @devcontainers/cli@0.89.0 build --workspace-folder .
```

Checked by: conftest · Severity: warning · Since: 0.6.3

### DEVC-14

**A dev container does not give its container a fixed name.**

Docker allows one container per name on a host. A `--name` in `runArgs` makes a rebuild fail while the old container
still exists, and makes a second worktree or a second clone of the repository collide with the first. Without it,
Docker gives each container a unique name, and the Dev Container CLI finds its container by the labels it sets for
the workspace folder. The check reads
`--name <value>` and `--name=<value>` in `runArgs`.

**Correct:**

```jsonc
"runArgs": ["--cap-add=SYS_PTRACE"]
```

**Incorrect:**

```jsonc
"runArgs": ["--name", "platform-api-dev"]
```

Checked by: conftest · Severity: warning · Since: 0.7.0

### DEVC-15

**A volume mounted under /home belongs to remoteUser.**

A volume that keeps a tool's state, such as the GitHub CLI's login or an agent's history, works only where the tool
looks, and the tools a contributor runs look in the remote user's home. A volume mounted under another user's home,
often left behind when the image's user changed, is written where nothing reads it: the container starts, and the
state is silently lost on every rebuild. The check compares the user in each volume's `/home/<user>` target with
`remoteUser`; when `remoteUser` is unset or root, DEVC-05 reports that instead. Bind mounts are not checked.

**Correct:**

```jsonc
"remoteUser": "vscode",
"mounts": ["source=musher-${devcontainerId}-gh-config,target=/home/vscode/.config/gh,type=volume"]
```

**Incorrect:**

```jsonc
"remoteUser": "vscode",
"mounts": ["source=musher-${devcontainerId}-gh-config,target=/home/node/.config/gh,type=volume"]
```

Checked by: conftest · Severity: warning · Since: 0.7.0
