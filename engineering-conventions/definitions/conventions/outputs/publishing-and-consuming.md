---
id: EC-0008
title: Publishing and consuming outputs
summary: >-
  An output documents how to consume it, is published only from a release
  tag and never overwritten, carries its provenance when it is an image,
  names its own repository as its source when it is published to GHCR, and
  is consumed by an exact version.
status: draft
topic: outputs
applies_to:
  paths:
    - .repo/outputs.toml
    - .github/workflows/*.yml
    - .github/workflows/*.yaml
    - .github/actions/**/action.yml
    - "**/Dockerfile"
created: 2026-09-24
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "OCI image-spec: Pre-defined annotation keys"
    url: https://github.com/opencontainers/image-spec/blob/main/annotations.md
  - title: "Semantic Versioning 2.0.0"
    url: https://semver.org/
  - title: "GitHub Docs: Connecting a repository to a package"
    url: https://docs.github.com/en/packages/learn-github-packages/connecting-a-repository-to-a-package
  - title: "docker/metadata-action"
    url: https://github.com/docker/metadata-action
requirements:
  - id: OUT-08
    title: An output's docs say how to consume it
    status: proposed
    severity: warning
    since: 0.3.0
    validation:
      engine: review
  - id: OUT-09
    title: A version is published only from a release tag and is never overwritten
    status: proposed
    severity: warning
    since: 0.3.0
    validation:
      engine: review
  - id: OUT-10
    title: A container image carries the OCI source, revision and version annotations
    status: proposed
    severity: warning
    since: 0.3.0
    validation:
      engine: review
  - id: OUT-11
    title: A repository consumes another repository's output by an exact version
    status: proposed
    severity: warning
    since: 0.3.0
    validation:
      engine: review
  - id: OUT-13
    title: An image published to GHCR names its own repository in org.opencontainers.image.source
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.outputs.publishing
---

# Publishing and consuming outputs

[EC-0007](outputs-declaration.md) makes a repository say what it publishes. This convention says what a published
output promises, and how another repository relies on it. The model is the one this repository uses for itself: a
publisher releases a versioned output with a documented contract, and each consumer pins an exact version and upgrades
by changing it.

## Scope

This convention covers every output declared in `.repo/outputs.toml`, the workflows that publish them, and every
repository that consumes an output of another. The formats themselves (OCI images, package registries, API
description formats) are defined by their own specifications, which this convention links rather than restates.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirements are `proposed` at
severity `warning` and checked in review: whether a README explains consumption, or a pin is exact, needs a reader
until a check can tell reliably.

## Requirements

### OUT-08

**An output's docs say how to consume it.**

The `docs` entry of an output points at the one place a consumer starts. That section says where to get the output
(its coordinates), how to pin a version, and what a version change promises: which changes are breaking and how they
are announced. A consumer who has to read the publish workflow to learn this will guess instead.

**Correct:**

```markdown
## Run the image

Pull `ghcr.io/your-org/api` by digest, from a release's notes. Versions follow SemVer: a major version changes
the HTTP API, a minor adds to it.
```

**Incorrect:**

```markdown
## Docker

See the workflow.
```

Checked by: review · Severity: warning · Since: 0.3.0

### OUT-09

**A version is published only from a release tag and is never overwritten.**

A consumer pins a version because it means the same bytes every time. A version published from a branch, or
republished after a fix, breaks that promise without any change on the consumer's side. A fix is a new version.
Moving aliases such as `latest` or a major-version tag may move; a full version may not. A release workflow that
publishes in the run that creates the tag, as release-please does, publishes from that tag: it checks out the tag it
just created and publishes only when a release was created
([decision 0014](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0014-release-workflows-may-publish.md)).
For GitHub Release assets, the release conventions check this: the release is drafted with its tag
([REL-07](../releases/release-configuration.md#rel-07)), its assets are attached before it is published
([REL-19](../releases/release-workflows.md#rel-19)), and nothing writes to it afterwards
([REL-17](../releases/release-workflows.md#rel-17)).

For a `site`, the versions are its versioned paths: once a path such as `/schema/v1.2.0/` is served, its bytes never
change, while aliases such as `/schema/v1/` may move
([decision 0018](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0018-a-site-is-an-output.md)).

**Correct:**

```yaml
on:
  push:
    tags: ["v*"]
```

```yaml
# release.yml, on push to main
- id: release
  uses: googleapis/release-please-action@<sha>
- if: ${{ steps.release.outputs.release_created }}
  uses: actions/checkout@<sha>
  with:
    ref: ${{ steps.release.outputs.tag_name }}   # publishes the tag it just cut
```

**Incorrect:**

```yaml
on:
  push:
    branches: [main]     # publishes a version from whatever main holds
```

Checked by: review · Severity: warning · Since: 0.3.0

### OUT-10

**A container image carries the OCI source, revision and version annotations.**

`org.opencontainers.image.source`, `org.opencontainers.image.revision` and `org.opencontainers.image.version` tie an
image back to the repository, commit and release that produced it, so anyone holding the image can find its
declaration and its docs. The keys and their meaning are defined by the
[OCI image-spec](https://github.com/opencontainers/image-spec/blob/main/annotations.md), not here.

**Correct:**

```yaml
- uses: docker/metadata-action@<sha>  # sets the OCI annotations and labels from the Git context
```

**Incorrect:**

```dockerfile
# no source, revision or version annotation on the image
FROM gcr.io/distroless/static
```

Checked by: review · Severity: warning · Since: 0.3.0

### OUT-11

**A repository consumes another repository's output by an exact version.**

An exact version, or an image digest, makes a consumer's build reproducible and its upgrades visible as reviewed
changes, which a dependency bot can raise. A range or a moving tag changes what a repository runs without a change in
that repository. [DEPS-04](../dependencies/dependencies-declaration.md#deps-04) checks the pins it can read: the dependencies
declaration and `@musher-dev/` packages.

**Correct:**

```toml
[tools]
"github:musher-dev/engineering-conventions" = "X.Y.Z"
```

**Incorrect:**

```toml
[tools]
"github:musher-dev/engineering-conventions" = "latest"
```

Checked by: review · Severity: warning · Since: 0.3.0

### OUT-13

**An image published to GHCR names its own repository in `org.opencontainers.image.source`.**

The GitHub Container Registry connects a package to a repository when the package is first published, from the
image's `org.opencontainers.image.source` label. Without the label the package is connected to no repository: it is
missing from the repository's page, does not inherit its access, and a reader holding the image cannot find where it
came from. With another repository's URL, the package is connected there instead. So an image a workflow pushes to
`ghcr.io` carries the label, and it names `https://github.com/<organization>/<name>`: the organization of the team in
`owner` and the `name` of [`.repo/repository.toml`](../repository/identity-declaration.md). This is the static half:
whether the package GHCR shows is in fact connected, and to the repository the publisher means, is not checked here.

The check reads each job of a workflow, and each composite action, for a step that publishes to GHCR:

- a `docker/build-push-action` step whose `push` is `true` or an expression, and whose `tags` name `ghcr.io/`, directly
  or through the `tags` output of a `docker/metadata-action` step whose `images` do; or
- a `run:` line that runs `docker push`, or `docker build` or `docker buildx build` with `--push`, naming `ghcr.io/`.

A value written as `${{ env.NAME }}` is read from the workflow's, job's or step's `env:`. The label counts as set when:

- the `docker/build-push-action` step's `labels` sets it, or takes the `labels` output of a `docker/metadata-action`
  step, which sets the label to the repository the workflow runs in;
- for a `run:` push, a `run:` line in the same job passes `--label org.opencontainers.image.source=…`, or reads a
  `docker/metadata-action` step's labels (`steps.<id>.outputs.labels` or `DOCKER_METADATA_OUTPUT_LABELS`); or
- a Dockerfile in the repository sets it with `LABEL`.

A label written as a literal URL for another repository is reported, in the workflow or, in a repository that
publishes to GHCR, in the Dockerfile. A value computed when the workflow or build runs, such as
`${{ github.server_url }}/${{ github.repository }}` or a build argument, is not judged.

**Correct:**

```yaml
- id: meta
  uses: docker/metadata-action@<sha>
  with:
    images: ghcr.io/musher-dev/platform-api
- uses: docker/build-push-action@<sha>
  with:
    push: true
    tags: ${{ steps.meta.outputs.tags }}
    labels: ${{ steps.meta.outputs.labels }}   # includes org.opencontainers.image.source
```

**Incorrect:**

```yaml
- uses: docker/build-push-action@<sha>
  with:
    push: true
    tags: ghcr.io/musher-dev/platform-api:${{ github.ref_name }}   # no source label anywhere
```

Checked by: conftest · Severity: warning · Since: 0.7.1

## References

- [EC-0007 Outputs declaration](outputs-declaration.md)
- [OCI image-spec: Pre-defined annotation keys](https://github.com/opencontainers/image-spec/blob/main/annotations.md)
- [Semantic Versioning 2.0.0](https://semver.org/)
