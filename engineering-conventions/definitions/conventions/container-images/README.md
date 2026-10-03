# Container images

These conventions govern the files that build and run a container image: where Dockerfiles, their ignore files and
compose files live, what they are named, and the linter every Dockerfile passes.

The governing rule, in one sentence:

> **Keep each image's Dockerfile, its ignore file and its compose files in a `docker/` directory beside what it
> builds, and lint every Dockerfile with a pinned hadolint and one configuration in `.config/docker/`.**

A dev container keeps its own Dockerfile and `.dockerignore` in `.devcontainer/`, which the
[dev containers](../dev-containers/README.md) topic governs; its Dockerfile is linted like any other.

## Status

Both conventions are **drafts**, owned by this repository, and every requirement is `proposed` at severity `warning`.

## Who is checked

`base-repo` selects the family, so every profile does, but a repository with no Dockerfile and no compose file has
nothing to report.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0039 Container image layout](image-layout.md) | IMAGE-01 – IMAGE-05 | The `docker/` directory, Dockerfile names, the ignore file beside each Dockerfile, and where compose files live |
| [EC-0040 Dockerfile linting](dockerfile-linting.md) | IMAGE-06 – IMAGE-10 | hadolint: passing it, its configuration, its pin, and running it on commit and in validation |

## Quick reference

| File or command | Holds or does |
| --- | --- |
| `<dir>/docker/Dockerfile` | An image's Dockerfile (IMAGE-01); `<name>.Dockerfile` when the directory builds several (IMAGE-02) |
| `<dir>/docker/Dockerfile.dockerignore` | What the build leaves out of the context, read beside the Dockerfile (IMAGE-03); no `.dockerignore` outside `.devcontainer/` (IMAGE-04) |
| `<dir>/docker/compose.yaml` | How to run the image locally (IMAGE-05) |
| `.config/docker/hadolint.yaml` | hadolint's configuration: its threshold and the rules turned off, with reasons (IMAGE-07) |
| `conventions hadolint [--config FILE] [FILE...]` | Lints the given files, or every Dockerfile, with the repository's configuration (IMAGE-06) |
