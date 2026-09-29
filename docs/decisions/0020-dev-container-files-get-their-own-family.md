---
title: Dev container files get their own family, and the scaffold is consumed by pinning an image
date: 2026-09-29
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0020 — Dev container files get their own family, and the scaffold is consumed by pinning an image

## Context

`musher-dev/development-container` is a GitHub template repository. A new repository is created from it once, and
the copy then drifts on its own: the template has no releases or tags, so a consumer cannot even say which version it
started from (development-container#24). About ten repositories carry a copy of its scaffold, and four carry a copy of its
`repo` CLI. This is the failure company decision 0012 predicted for templates, and the reason the
[charter](0000-charter.md) rejected the template model for conventions.

[Decision 0016](0016-adopted-rules-get-new-families.md) moved the CLI's general rules here (CONF, REPO, ENVS, HOOKS,
TASK, TOOL). What it left behind concerns the dev container itself. Nothing here checks what a `devcontainer.json`
configures: whether its Features are locked, whether its base image moves under it, which user it runs as, whether
the scripts its lifecycle commands name exist, or whether a stack's ports are reachable from the local network. The
runner already parses every `devcontainer.json` ([decision 0015](0015-the-runner-reads-what-conftest-cannot-select.md)),
and TOOL-08 is the only requirement that reads it.

That raised the question of moving the scaffold itself here, as a reference every repository copies, so that the rules
and the thing they describe live together.

## Decision

- **The scaffold stays in `musher-dev/development-container`.** This repository does not hold a dev container
  template, Feature or image. The charter's boundary stands: the scaffold is the thing, and this repository owns the
  rules about things.
- **A new family, `DEVC`, topic `dev-containers`,** holds the requirements every repository's dev container files are
  checked against. They cover where the configuration lives, the lockfile, the base image, the user, lifecycle
  scripts, secrets, named volumes, dependency updates, a CI build, and the ports and images of the compose stacks
  under `.devcontainer/`. Each requirement fires only when its file exists, so a repository without a dev container
  is unaffected. Rules adopted from development-container keep their IDs as aliases, as decision 0016 sets out.
- **The scaffold is consumed by pinning, not copying.** When development-container publishes a prebuilt dev container
  image, it declares it as an ordinary `image` output ([decision 0010](0010-outputs-declaration.md)). A consumer's
  `devcontainer.json` then names a released version, and falling behind shows up as a version number, as it does for
  the conventions. No new output kind is needed. A requirement that consumers build from that image waits until the
  image has a release.
- **An example is not a template.** A conforming `.devcontainer/` may appear under `examples/` to show what the
  requirements accept. Nothing applies it to a repository.

## Consequences

### Positive

- A consumer's dev container is checked against the same versioned bar as the rest of the repository, including
  development-container's own.
- development-container's remaining local checks shrink to what is specific to its scaffold.
- The rules stay independent of how any one scaffold is built, so they cannot drift into "whatever the template does
  is compliant".

### Negative

- Two repositories must agree on the dev container: the scaffold changes there, and the rules change here. A rule
  change that the scaffold does not yet meet is a finding in development-container until it catches up.
- Until an image is published, consumers still copy the scaffold, and only the checks here catch the drift.

### Neutral

- Host-side and privileged settings (`initializeCommand`, `privileged`, host networking, bind mounts outside the
  workspace) are not in the first release of the family. They are re-evaluated once the scaffold no longer needs
  `initializeCommand`.
- development-container's lefthook/CI parity (HOOK-01..04) and comment (CMT-*) rules are general rather than about
  dev containers. They are evaluated separately.

## Enforcement

- The DEVC requirements are conftest checks in `checks/rego/dev_containers/`, each proved by a fixture repository and
  a near-miss that passes.
- `task invariants` fails on the family if it is not registered in `families.yml`.
- That a DEVC requirement governs files and not how the scaffold is built is `review-only`, under the boundary
  decision 0016 sets: the reviewer rejects a requirement that names the scaffold's Features, scripts or stacks.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Move the scaffold here | One repository holds the dev container and the rules about it | rejected: releases of a toolchain image would become conventions releases; the Dev Container specification keeps templates, Features and images apart; and a rule written beside its only implementation tends to describe that implementation |
| Rules here, scaffold consumed by copying | Keep the template model and rely on the checks | rejected: the checks find drift but cannot remove it, and a copy records no version |
| Rules here, scaffold consumed by pinning an image | This decision | **chosen** |
| No dev container rules | Leave `devcontainer.json` to each repository | rejected: every repository has one, and the same unlocked Features, floating tags and exposed ports recur in each |

## References

- [Decision 0000: Charter](0000-charter.md)
- [Decision 0010: Outputs declaration](0010-outputs-declaration.md)
- [Decision 0015: The runner reads what conftest cannot select](0015-the-runner-reads-what-conftest-cannot-select.md)
- [Decision 0016: Rules adopted from other repositories get new families](0016-adopted-rules-get-new-families.md)
- [development-container#24: template bugs and drift found building a consumer](https://github.com/musher-dev/development-container/issues/24)
- [development-container#27: adopt the conventions release](https://github.com/musher-dev/development-container/issues/27)
- [Dev Container specification: Templates distribution](https://containers.dev/implementors/templates-distribution/)
- [Dev Container specification: Prebuilding images](https://containers.dev/guide/prebuild)
