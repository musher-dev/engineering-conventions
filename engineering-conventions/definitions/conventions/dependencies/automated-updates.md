---
id: EC-0042
title: Automated dependency updates
summary: >-
  Something proposes every dependency update as a pull request: Renovate,
  or a Dependabot update for the actions in the workflows and each
  composite action, for every directory that holds a Dockerfile, and for
  the product's manifest in the product directory. A Dependabot version
  update is quiet: monthly, with every dependency in one group, and reads
  what its directories hold: a manifest of its ecosystem, and Bun's
  lockfile only as bun.
status: draft
topic: dependencies
applies_to:
  paths:
    - .github/dependabot.yml
    - .github/dependabot.yaml
    - renovate.json
    - .github/renovate.json
created: 2026-10-03
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "GitHub Docs: Dependabot options reference"
    url: https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference
  - title: "Renovate: Managers"
    url: https://docs.renovatebot.com/modules/manager/
  - title: "OpenSSF Scorecard: Dependency-Update-Tool"
    url: https://github.com/ossf/scorecard/blob/main/docs/checks.md#dependency-update-tool
requirements:
  - id: DEPS-11
    title: An updater keeps the actions of every workflow and composite action current
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.dependencies.updates
  - id: DEPS-12
    title: An updater keeps the base images of every Dockerfile current
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.dependencies.updates
  - id: DEPS-13
    title: An updater keeps the product's dependencies current from the product directory
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.dependencies.updates
  - id: DEPS-17
    title: Every Dependabot version update runs monthly or less often and groups every dependency
    status: proposed
    severity: warning
    since: 0.9.4
    validation:
      engine: conftest
      package: conventions.checks.dependencies.updates
  - id: DEPS-18
    title: Every directory a Dependabot update scans holds a manifest its ecosystem reads
    status: proposed
    severity: warning
    since: 0.9.8
    validation:
      engine: conftest
      package: conventions.checks.dependencies.updates
  - id: DEPS-19
    title: A directory whose dependencies bun.lock records is updated as bun, not npm
    status: proposed
    severity: warning
    since: 0.9.8
    validation:
      engine: conftest
      package: conventions.checks.dependencies.updates
---

# Automated dependency updates

A pinned dependency is safe only while someone moves the pin. The SHA an action is pinned to, the tag a Dockerfile's
base image names and the versions a lockfile records all fall behind the day after they are written, and a security
fix reaches the repository only when someone notices. Renovate and Dependabot notice for you, one reviewed pull
request at a time. This convention asks that every ecosystem a repository pins has one of them watching it.

## Scope

This convention covers what proposes updates to the packages, actions and images a repository depends on: a Renovate
configuration, or the updates in `.github/dependabot.yml`. A dev container's Features are
[DEVC-09](../dev-containers/dev-container-configuration.md#devc-09)'s; another Musher repository's vendored interfaces
are [EC-0033](keeping-dependencies-current.md)'s; the tools in `.config/mise/config.toml` have no Dependabot
ecosystem, and Renovate's mise manager is the one updater for them. How often Dependabot proposes version updates, and
how it groups them, is DEPS-17's; Renovate's schedule and grouping stay the repository's.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirements are `proposed` at severity
`warning`, like every requirement in the 0.x series. The reasons are in [decision
0032](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0032-every-dependency-ecosystem-has-an-updater.md)
and, for DEPS-17, in [decision
0042](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0042-dependency-currency-is-shown-not-proposed.md).

## How it fits together

A Renovate configuration covers every ecosystem: its managers find workflows, Dockerfiles and manifests by
themselves. A repository on Dependabot names each ecosystem and the directories it scans:

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"         # DEPS-11
    directories: ["/", "/.github/actions/*"]
    schedule: { interval: "monthly" }           # DEPS-17
    cooldown: { default-days: 7 }
    groups:
      github-actions: { patterns: ["*"] }       # DEPS-17: one pull request a month
      github-actions-security: { applies-to: security-updates, patterns: ["*"] }
  - package-ecosystem: "docker"                 # DEPS-12
    directories: ["/.devcontainer", "/platform-api/docker"]
    schedule: { interval: "monthly" }
    cooldown: { default-days: 7 }
    groups:
      docker: { patterns: ["*"] }
      docker-security: { applies-to: security-updates, patterns: ["*"] }
  - package-ecosystem: "gomod"                  # DEPS-13
    directory: "/platform-api"
    schedule: { interval: "monthly" }
    cooldown: { default-days: 7 }
    groups:
      gomod: { patterns: ["*"] }
      gomod-security: { applies-to: security-updates, patterns: ["*"] }
```

A directory in `directories` may be a glob, as Dependabot allows. Security updates are not subject to the schedule or
the cooldown: Dependabot opens one as soon as an advisory names a pinned version, in the update's
`applies-to: security-updates` group. They run only when Dependabot security updates are enabled in the repository's
code security settings, so enable them there.

## Requirements

### DEPS-11

**An updater keeps the actions of every workflow and composite action current.**

Every third-party action is pinned to a commit ([GHA-24](../github-actions/execution-hygiene.md#gha-24)), so nothing
moves it but an updater. Dependabot's `github-actions` update for `/` reads `.github/workflows/`, but not a composite
action under `.github/actions/`, which needs its own directory. The check reports the root when the repository has
workflows, and each `.github/actions/<name>/`, that no `github-actions` update scans.

**Correct:**

```yaml
  - package-ecosystem: "github-actions"
    directories: ["/", "/.github/actions/setup-tools"]
```

**Incorrect:**

```yaml
  - package-ecosystem: "github-actions"
    directory: "/"                       # misses .github/actions/setup-tools
```

Checked by: conftest · Severity: warning · Since: 0.8.0

### DEPS-12

**An updater keeps the base images of every Dockerfile current.**

A base image pinned to a tag or a digest ([DEVC-04](../dev-containers/dev-container-configuration.md#devc-04)) carries
its operating system's packages as they were that day. The check reports each directory holding a Dockerfile,
`.devcontainer/` included and test input excepted, that no `docker` update scans.

**Correct:**

```yaml
  - package-ecosystem: "docker"
    directories: ["/.devcontainer", "/platform-api/docker"]
```

**Incorrect:**

```yaml
  - package-ecosystem: "docker"
    directory: "/"                       # no Dockerfile at the root
```

Checked by: conftest · Severity: warning · Since: 0.8.0

### DEPS-13

**An updater keeps the product's dependencies current from the product directory.**

The product's manifest and lockfile hold most of what a repository depends on, and they sit in the product directory
([REPO-17](../repository/layout.md#repo-17)). The check reports a manifest there (`go.mod`, `package.json`,
`pyproject.toml`, `Cargo.toml`, a Maven or Gradle build) that no update of an ecosystem that reads it scans in that
directory. [REPO-20](../repository/layout.md#repo-20) reports an update aimed at the root instead. A Deno product has
no Dependabot ecosystem and needs Renovate.

**Correct:**

```yaml
  - package-ecosystem: "gomod"
    directory: "/platform-api"
```

**Incorrect:** no `gomod` update, with `platform-api/go.mod` in the repository.

Checked by: conftest · Severity: warning · Since: 0.8.0

### DEPS-17

**Every Dependabot version update runs monthly or less often and groups every dependency.**

A pull request per dependency per week is more than anyone reads, so they pile up unmerged, and the one that matters
is lost among them. A monthly schedule with one group whose `patterns` are `["*"]` opens at most one version-update
pull request per ecosystem a month, which a person can review in one sitting. Security updates are not affected: they
ignore the schedule and arrive as soon as an advisory does. The check reports each update whose `schedule.interval`
is not `monthly`, `quarterly`, `semiannually` or `yearly`, or that has no group with `patterns: ["*"]` for version
updates (`applies-to` absent or `version-updates`). An update with `open-pull-requests-limit: 0` runs only security
updates, and is not reported.

**Correct:**

```yaml
  - package-ecosystem: "gomod"
    directory: "/platform-api"
    schedule: { interval: "monthly" }
    cooldown: { default-days: 7 }
    groups:
      gomod: { patterns: ["*"] }
      gomod-security: { applies-to: security-updates, patterns: ["*"] }
```

**Incorrect:**

```yaml
  - package-ecosystem: "gomod"
    directory: "/platform-api"
    schedule: { interval: "weekly" }     # and no group: a pull request per module per week
```

Checked by: conftest · Severity: warning · Since: 0.9.4

### DEPS-18

**Every directory a Dependabot update scans holds a manifest its ecosystem reads.**

Dependabot aborts an update when a directory holds nothing its ecosystem reads (`Error during file fetching;
aborting: /.devcontainer/stacks/** not found`), and it says so only in the update's log, which nobody reads. The
directory exists, so [REPO-22](../repository/layout.md#repo-22) passes, while that ecosystem goes without
updates for as long as nobody looks. A `docker` update pointed at directories of `compose.yaml` files is the usual
case: Compose files are the `docker-compose` ecosystem's, and `docker` reads only Dockerfiles. The check reports each
directory, or each glob, under which no directory holds one of its ecosystem's manifests:

| Ecosystem | Manifests in the directory |
| --- | --- |
| `docker` | `Dockerfile`, `Containerfile`, `<name>.Dockerfile`, `Dockerfile.<suffix>` |
| `docker-compose` | `compose.yaml`, `docker-compose.yaml`, and their `.yml` and `.<name>.` forms |
| `devcontainers` | `.devcontainer/devcontainer.json`, `.devcontainer/<name>/devcontainer.json`, `.devcontainer.json` |
| `github-actions` | `.github/workflows/*.yml`, `action.yml`, and their `.yaml` forms |
| `npm`, `bun` | `package.json` |
| `pip` | `requirements*.txt`, `requirements*.in`, `pyproject.toml`, `setup.py`, `setup.cfg`, `Pipfile` |
| `uv` | `pyproject.toml`, `uv.lock` |
| `cargo`, `gomod`, `maven`, `gradle`, `terraform` | `Cargo.toml`, `go.mod`, `pom.xml`, `build.gradle` or `settings.gradle` (or `.kts`), `*.tf` |

A glob passes when any directory it matches holds one. An ecosystem the table does not list is not judged, and a
directory that does not exist is REPO-22's.

**Correct:**

```yaml
  - package-ecosystem: "docker-compose"
    directories: ["/.devcontainer/stacks/*"]   # each holds a compose.yaml
```

**Incorrect:**

```yaml
  - package-ecosystem: "docker"
    directories: ["/.devcontainer/stacks/**"]  # compose.yaml files only: no Dockerfile to read
```

Checked by: conftest · Severity: warning · Since: 0.9.8

### DEPS-19

**A directory whose dependencies bun.lock records is updated as bun, not npm.**

Dependabot refuses an `npm` update over a directory that holds `bun.lock` or `bun.lockb` (`Dependabot detected that
Bun is misconfigured`), and the refusal covers security updates too, so an advisory against a dependency opens no pull
request. The `bun` ecosystem reads the same `package.json` and updates `bun.lock` with it. The check reports each
directory an `npm` update scans that holds Bun's lockfile.

**Correct:**

```yaml
  - package-ecosystem: "bun"
    directory: "/platform-console"      # holds package.json and bun.lock
```

**Incorrect:**

```yaml
  - package-ecosystem: "npm"
    directory: "/platform-console"      # holds bun.lock: Dependabot refuses the update
```

Checked by: conftest · Severity: warning · Since: 0.9.8

## References

- [GitHub Docs: Dependabot options reference](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference)
- [Renovate: Managers](https://docs.renovatebot.com/modules/manager/)
- [OpenSSF Scorecard: Dependency-Update-Tool](https://github.com/ossf/scorecard/blob/main/docs/checks.md#dependency-update-tool)
