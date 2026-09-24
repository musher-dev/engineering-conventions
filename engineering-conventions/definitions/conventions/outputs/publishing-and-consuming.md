---
id: EC-0008
title: Publishing and consuming outputs
summary: >-
  An output documents how to consume it, is published only from a release
  tag and never overwritten, carries its provenance when it is an image, and
  is consumed by an exact version.
status: draft
topic: outputs
applies_to:
  paths:
    - .repo/outputs.yaml
    - .github/workflows/*.yml
    - .github/workflows/*.yaml
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
---

# Publishing and consuming outputs

[EC-0007](outputs-declaration.md) makes a repository say what it publishes. This convention says what a published
output promises, and how another repository relies on it. The model is the one this repository uses for itself: a
publisher releases a versioned output with a documented contract, and each consumer pins an exact version and upgrades
by changing it.

## Scope

This convention covers every output declared in `.repo/outputs.yaml`, the workflows that publish them, and every
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
Moving aliases such as `latest` or a major-version tag may move; a full version may not.

**Correct:**

```yaml
on:
  push:
    tags: ["v*"]
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
that repository.

**Correct:**

```toml
[tools]
"github:musher-dev/engineering-conventions" = "0.3.0"
```

**Incorrect:**

```toml
[tools]
"github:musher-dev/engineering-conventions" = "latest"
```

Checked by: review · Severity: warning · Since: 0.3.0

## References

- [EC-0007 Outputs declaration](outputs-declaration.md)
- [OCI image-spec: Pre-defined annotation keys](https://github.com/opencontainers/image-spec/blob/main/annotations.md)
- [Semantic Versioning 2.0.0](https://semver.org/)
