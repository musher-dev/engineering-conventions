---
id: EC-0039
title: Container image layout
summary: >-
  The files that build a container image live together in a docker/
  directory beside what they build: each Dockerfile named Dockerfile or
  <name>.Dockerfile, its BuildKit ignore file beside it, and the compose
  files that run it. A dev container keeps its own files in .devcontainer/.
status: draft
topic: container-images
applies_to:
  paths:
    - "**/Dockerfile"
    - "**/*.Dockerfile"
    - "**/*.dockerignore"
    - "**/.dockerignore"
    - "**/compose*.yaml"
    - "**/compose*.yml"
    - "**/docker-compose*.yaml"
    - "**/docker-compose*.yml"
created: 2026-10-03
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "Docker: Build context, filename and location"
    url: https://docs.docker.com/build/concepts/context/#filename-and-location
  - title: "Docker: .dockerignore files"
    url: https://docs.docker.com/build/concepts/context/#dockerignore-files
  - title: "Docker Compose: The Compose file"
    url: https://docs.docker.com/compose/intro/compose-application-model/#the-compose-file
requirements:
  - id: IMAGE-01
    title: Every Dockerfile outside .devcontainer/ and test fixtures lives in a docker/ directory
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.container_images.layout
  - id: IMAGE-02
    title: A Dockerfile is named Dockerfile or <name>.Dockerfile, and one of several is named <name>.Dockerfile
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.container_images.layout
  - id: IMAGE-03
    title: Every Dockerfile outside .devcontainer/ has its ignore file beside it, named <Dockerfile>.dockerignore
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.container_images.layout
  - id: IMAGE-04
    title: No .dockerignore is committed outside .devcontainer/
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.container_images.layout
  - id: IMAGE-05
    title: A compose file lives in a docker/ directory or in .devcontainer/
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.container_images.layout
---

# Container image layout

A container image is built from a Dockerfile, a build context and the ignore file that trims the context, and it is
run locally from a compose file. When those files sit wherever each was first added, a reader cannot tell what builds
what: one repository keeps its Dockerfile at the root, another beside the manifest, a third in a `docker/` folder with
its compose file somewhere else. This convention puts them in one place, a `docker/` directory beside what they build,
so the files that make an image are found, reviewed and moved together.

## Scope

This convention covers every Dockerfile, Docker ignore file and compose file a repository holds, except those of a dev
container under `.devcontainer/` ([EC-0027](../dev-containers/dev-container-configuration.md)) and those under a
`tests/` or `fixtures/` directory, which are test input. What an image contains, which base it starts from and how it
is published are the product's own business and [EC-0008](../outputs/publishing-and-consuming.md)'s; how a Dockerfile
is written is hadolint's ([EC-0040](dockerfile-linting.md)).

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirements are `proposed` at severity
`warning`, like every requirement in the 0.x series. The reasons are in [decision
0030](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0030-container-images-live-in-docker-directories.md).

## How it fits together

```text
platform-api/                       the product directory (EC-0018)
├── go.mod
└── docker/
    ├── Dockerfile                  IMAGE-01, IMAGE-02
    ├── Dockerfile.dockerignore     IMAGE-03: BuildKit reads it beside the Dockerfile
    ├── compose.yaml                IMAGE-05
    └── entrypoint.sh
```

The build names the Dockerfile and keeps whichever context the image needs: the product directory, or the
repository root for an image that copies shared files.

```sh
docker build -f platform-api/docker/Dockerfile platform-api
```

BuildKit, Docker's builder since Docker Engine 23, looks for `<Dockerfile>.dockerignore` beside the Dockerfile before
it looks for `.dockerignore` at the root of the context, so the ignore file belongs to the image whatever context the
build passes. A monorepo whose images share one context gives each its own ignore file without one `.dockerignore`
serving them all. The `build` task ([TASK-11](../tasks/task-interface.md#task-11)) hides the `-f`.

A dev container is the exception. The dev container CLI builds a dev container that uses Features from a copy of its
context in a temporary directory, where the file beside the Dockerfile is not found, so `.devcontainer/` keeps the
context-root `.dockerignore`.

## Requirements

### IMAGE-01

**Every Dockerfile outside `.devcontainer/` and test fixtures lives in a `docker/` directory.**

A Dockerfile at the repository root, or loose beside a manifest, says nothing about what it builds, and the files that
go with it (the ignore file, the compose file, an entrypoint script) end up in other places. A `docker/` directory
beside what the image is built from holds all of them. The check reports a Dockerfile, `Dockerfile` or
`<name>.Dockerfile` or any other name Docker reads, whose directory is not named `docker`.

**Correct:**

```text
platform-api/docker/Dockerfile
apps/console/docker/build.Dockerfile
```

**Incorrect:**

```text
Dockerfile
platform-api/Dockerfile
```

Checked by: conftest · Severity: warning · Since: 0.8.0

### IMAGE-02

**A Dockerfile is named `Dockerfile` or `<name>.Dockerfile`, and one of several is named `<name>.Dockerfile`.**

Docker reads `Dockerfile` by default, and names any other with the `.Dockerfile` suffix, which editors and linters
recognise. A suffix after the name, as in `Dockerfile.dev`, hides the file from both, and a bare `Dockerfile` beside
named ones leaves a reader to guess which image is the default. A directory with one image keeps `Dockerfile`; a
directory with several names each. `Containerfile`, Podman's name, is reported too: one name is enough.

**Correct:**

```text
platform-api/docker/Dockerfile
apps/console/docker/build.Dockerfile
tools/docker/runner.Dockerfile
tools/docker/worker.Dockerfile
```

**Incorrect:**

```text
platform-api/docker/Dockerfile.dev
tools/docker/Dockerfile
tools/docker/worker.Dockerfile
```

Checked by: conftest · Severity: warning · Since: 0.8.0

### IMAGE-03

**Every Dockerfile outside `.devcontainer/` has its ignore file beside it, named `<Dockerfile>.dockerignore`.**

Without an ignore file the build sends the whole context to the builder: `.git`, local `.env` files, caches and
whatever a developer has lying around, which slows every build and can copy a secret into a layer. The ignore file
beside the Dockerfile is read whatever context the build passes, and it is reviewed with the Dockerfile it trims.
Start from `*` and list what the image needs, so a new file stays out until someone adds it.

**Correct:**

```text
platform-api/docker/Dockerfile
platform-api/docker/Dockerfile.dockerignore
```

```gitignore
# platform-api/docker/Dockerfile.dockerignore: the context is platform-api/
*
!go.mod
!go.sum
!cmd/
!internal/
```

**Incorrect:**

```text
platform-api/docker/Dockerfile         # no ignore file: the build sends everything
```

Checked by: conftest · Severity: warning · Since: 0.8.0

### IMAGE-04

**No `.dockerignore` is committed outside `.devcontainer/`.**

A `.dockerignore` applies to every build whose context is its directory, so it belongs to no image in particular, and
BuildKit ignores it as soon as a Dockerfile has its own ignore file. Keeping both is two files that disagree about what
the build sends. Move its patterns into the `<Dockerfile>.dockerignore` of each image that uses that context.

**Correct:**

```text
platform-api/docker/Dockerfile.dockerignore
.devcontainer/.dockerignore
```

**Incorrect:**

```text
platform-api/.dockerignore
```

Checked by: conftest · Severity: warning · Since: 0.8.0

### IMAGE-05

**A compose file lives in a `docker/` directory or in `.devcontainer/`.**

A compose file runs the image the `docker/` directory builds, with the ports, volumes and variables it needs, so it
sits beside the Dockerfile. A compose file for the dev environment's stacks stays under `.devcontainer/`, where
[EC-0028](../dev-containers/dev-container-stacks.md) checks it. The check reports `compose.yaml`, `compose.yml`,
`docker-compose.yaml`, `docker-compose.yml` and their `compose.<variant>.yaml` forms anywhere else.

**Correct:**

```text
platform-api/docker/compose.yaml
platform-api/docker/compose.coolify.yaml
.devcontainer/stacks/postgres/compose.yaml
```

**Incorrect:**

```text
docker-compose.yml
platform-api/compose.yaml
```

Checked by: conftest · Severity: warning · Since: 0.8.0

## References

- [Docker: Build context, filename and location](https://docs.docker.com/build/concepts/context/#filename-and-location)
- [Docker: .dockerignore files](https://docs.docker.com/build/concepts/context/#dockerignore-files)
- [EC-0040 Dockerfile linting](dockerfile-linting.md)
- [EC-0018 Repository layout](../repository/layout.md)
