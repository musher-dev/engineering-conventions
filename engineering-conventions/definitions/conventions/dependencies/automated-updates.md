---
id: EC-0042
title: Automated dependency updates
summary: >-
  Something proposes every dependency update as a pull request: Renovate,
  or a Dependabot update for the actions in the workflows and each
  composite action, for every directory that holds a Dockerfile, and for
  the product's manifest in the product directory.
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
ecosystem, and Renovate's mise manager is the one updater for them. How often the updater runs, and how it groups its
pull requests, is the repository's choice.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirements are `proposed` at severity
`warning`, like every requirement in the 0.x series. The reasons are in [decision
0032](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0032-every-dependency-ecosystem-has-an-updater.md).

## How it fits together

A Renovate configuration covers every ecosystem: its managers find workflows, Dockerfiles and manifests by
themselves. A repository on Dependabot names each ecosystem and the directories it scans:

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"         # DEPS-11
    directories: ["/", "/.github/actions/*"]
    schedule: { interval: "weekly" }
  - package-ecosystem: "docker"                 # DEPS-12
    directories: ["/.devcontainer", "/platform-api/docker"]
    schedule: { interval: "weekly" }
  - package-ecosystem: "gomod"                  # DEPS-13
    directory: "/platform-api"
    schedule: { interval: "weekly" }
```

A directory in `directories` may be a glob, as Dependabot allows.

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

## References

- [GitHub Docs: Dependabot options reference](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference)
- [Renovate: Managers](https://docs.renovatebot.com/modules/manager/)
- [OpenSSF Scorecard: Dependency-Update-Tool](https://github.com/ossf/scorecard/blob/main/docs/checks.md#dependency-update-tool)
