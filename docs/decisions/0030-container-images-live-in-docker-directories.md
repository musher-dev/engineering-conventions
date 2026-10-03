---
title: Container images live in docker/ directories with their own ignore files, and hadolint lints every Dockerfile
date: 2026-10-03
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0030 — Container images live in docker/ directories with their own ignore files, and hadolint lints every Dockerfile

## Context

Nothing said where the files that build an image go, and the repositories chose differently.
`musher-dev/platform-api` keeps `Dockerfile` and `.dockerignore` loose in its product directory, beside `go.mod`, and
its compose files and entrypoint script in `platform-api/docker/`. `musher-dev/platform` keeps everything an app's
image needs in `apps/<app>/docker/`: `build.Dockerfile`, `build.Dockerfile.dockerignore`, `compose.yaml` and its
scripts. `musher-dev/infra` keeps a Dockerfile in each `images/<name>/`, and `musher-dev/examples` one at each app's
root. [EC-0011](../../engineering-conventions/definitions/conventions/configuration/tool-configuration.md) said only
that `.dockerignore` stays at the root of the build context.

Two repositories lint their Dockerfiles with hadolint, configured in `.config/docker/hadolint.yaml`; neither the pin
nor the hook nor the CI step is the same, and the other repositories with Dockerfiles, this one included, lint none.

## Decision

**The files that build an image live in a `docker/` directory beside what it builds, and every Dockerfile passes a
pinned hadolint with one configuration.**

- [EC-0039](../../engineering-conventions/definitions/conventions/container-images/image-layout.md), IMAGE-01 to
  IMAGE-05: a Dockerfile outside `.devcontainer/` and test input lives in a `docker/` directory, is named `Dockerfile`
  or `<name>.Dockerfile`, and has BuildKit's `<Dockerfile>.dockerignore` beside it; no `.dockerignore` is committed
  outside `.devcontainer/`; a compose file lives in a `docker/` directory or `.devcontainer/`.
- [EC-0040](../../engineering-conventions/definitions/conventions/container-images/dockerfile-linting.md), IMAGE-06 to
  IMAGE-10: every Dockerfile passes hadolint, delegated; hadolint is configured at `.config/docker/hadolint.yaml`,
  pinned in mise, run by lefthook on staged Dockerfiles and by a validate workflow.
- A new family, `IMAGE`, in the topic `container-images`, selected by `base-repo`. It is not `DOCKER`, because
  `musher-dev/platform` has a check of its own named DOCKER-01.
- `conventions hadolint` runs the hadolint release the bundle pins over every Dockerfile, as `conventions openapi`
  runs Spectral.
- This repository pins hadolint and lints its dev container's Dockerfile.

The build keeps whichever context the image needs and names the Dockerfile with `-f`. A dev container keeps its
context-root `.dockerignore`, because the dev container CLI builds an image that uses Features from a copy of its
context where the file beside the Dockerfile is not found.

## Consequences

### Positive

- Everything that makes and runs an image is in one directory, reviewed and moved together.
- The ignore file belongs to its image, whatever context the build passes, so images that share a context each say
  what they send.
- Every repository lints Dockerfiles with the same tool, pinned the same way, on commit and in CI.

### Negative

- `docker build .` from the product directory no longer finds the Dockerfile; the `build` task, and any script, passes
  `-f`.
- Repositories move their Dockerfiles: `platform-api` two files, `infra` and `examples` more.
- Every repository with a Dockerfile, a dev container's included, adds a pin, a configuration file, a hook job and a
  task.

### Neutral

- Which hadolint rules a repository turns off, and which registries it trusts, stay its own, in its configuration.

## Enforcement

- IMAGE-01 to IMAGE-05 in `checks/rego/container_images/layout.rego` and IMAGE-07 to IMAGE-10 in
  `checks/rego/container_images/hadolint.rego`, with fixtures `image-01-*` to `image-10-*`, each with a near-miss.
- IMAGE-06 is delegated to hadolint; `conventions hadolint` runs it.
- `task conventions:self` and `task lint:docker` hold this repository to it.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Dockerfile at the root of what it builds | Docker's default: `docker build .` works | rejected: the compose files and scripts still need a home, and one `.dockerignore` serves every image that shares the context |
| One name, `build.Dockerfile`, everywhere | `musher-dev/platform`'s layout exactly | rejected: `Dockerfile` is the name every tool expects for a directory's one image |
| Lint only, no layout | Require hadolint and leave the files where they are | rejected: the layout is the inconsistency the repositories asked about |
| `docker/` directories and hadolint | This decision | **chosen** |

## References

- [Docker: Build context, filename and location](https://docs.docker.com/build/concepts/context/#filename-and-location)
- [hadolint](https://github.com/hadolint/hadolint)
