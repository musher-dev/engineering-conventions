---
id: EC-0043
title: Publishing container images
summary: >-
  A job that pushes an image scans it with Trivy first and fails on HIGH and
  CRITICAL vulnerabilities, and attests the pushed image's build provenance
  in the registry beside it, unless the repository is private.
status: draft
topic: container-images
applies_to:
  paths:
    - .github/workflows/*.yml
    - .github/workflows/*.yaml
    - .repo/repository.toml
created: 2026-10-13
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "Trivy: Container image scanning"
    url: https://trivy.dev/latest/docs/target/container_image/
  - title: "aquasecurity/trivy-action"
    url: https://github.com/aquasecurity/trivy-action
  - title: "actions/attest"
    url: https://github.com/actions/attest
  - title: "SLSA: Build provenance"
    url: https://slsa.dev/spec/v1.0/provenance
requirements:
  - id: IMAGE-11
    title: A job that pushes an image scans it first and fails on HIGH and CRITICAL vulnerabilities
    status: proposed
    severity: warning
    since: 0.9.0
    validation:
      engine: conftest
      package: conventions.checks.container_images.publishing
  - id: IMAGE-12
    title: A job that pushes an image attests its build provenance in the registry, unless the repository is private
    status: proposed
    severity: warning
    since: 0.9.0
    validation:
      engine: conftest
      package: conventions.checks.container_images.publishing
---

# Publishing container images

[EC-0039](image-layout.md) and [EC-0040](dockerfile-linting.md) govern how an image is built and how its Dockerfile is
linted. Neither says anything about the image a repository publishes: hadolint reads the Dockerfile, not the packages
the base image brings in, and nothing records where a pushed image was built. This convention adds the two checks a
published image needs before anyone pulls it: a vulnerability scan that can stop the push, and a provenance
attestation a consumer can verify.

## Scope

This convention covers each job of a release, publish or deploy workflow
([EC-0002](../github-actions/workflow-files.md#gha-02)) that pushes an image to a registry: a
`docker/build-push-action` or `docker/bake-action` step whose `push` is `true` or an expression, or a `run:` line that
runs `docker push` or a build with `--push`. A push to a registry on the runner (`localhost`) publishes nothing and is
not read, and an image built in a validate workflow is checked, not published.

The image's storage record in the organization's linked artifacts is
[OUT-14](../outputs/publishing-and-consuming.md#out-14)'s. The two do not check the same thing: IMAGE-12 asks for the
attestation and the permissions that sign and store it, OUT-14 for the record and the permission that writes it.
`actions/attest` with `push-to-registry: true` and `artifact-metadata: write` meets both in one step.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirements are `proposed` at severity
`warning`, like every requirement in the 0.x series. Both are checked by what a workflow wires, not by what Trivy or
the attestation reports. The reasons are in [decision
0035](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0035-published-and-deployed-artifacts-are-recorded.md).

## How it fits together

```text
build (load)  ->  trivy image --exit-code 1 --severity HIGH,CRITICAL   IMAGE-11
              ->  push                                                  OUT-13 (source label)
              ->  actions/attest push-to-registry: true                 IMAGE-12, OUT-14 (storage record)
```

## Requirements

### IMAGE-11

**A job that pushes an image scans it first and fails on HIGH and CRITICAL vulnerabilities.**

A base image brings in packages its Dockerfile never names, and a vulnerability in one is published with every image
built on it. Scanning the built image before it is pushed is the last point at which a known HIGH or CRITICAL
vulnerability can stop the publish rather than be found in production. Trivy reports a vulnerability and exits 0
unless it is told otherwise, so a scan that is not given a non-zero exit code only prints. A finding the repository
accepts goes in `.config/security/trivyignore.yaml`, with a statement and an expiry
([CONF-10](../configuration/suppressions.md#conf-10)), and Trivy is pinned in mise like any tool the repository runs
([EC-0017](../toolchain/tool-pins.md)). `--ignore-unfixed` keeps the scan to what an upgrade can fix.

The check reports a pushing job with no scan step before its first push, or on the same step. A scan step is:

- a `run:` line that runs `trivy image` with `--exit-code` set to a non-zero value, or with the step's
  `TRIVY_EXIT_CODE` set to one, or that names a Trivy configuration with `--config`; and whose `--severity`, if it
  gives one, names both `HIGH` and `CRITICAL`; directly, or through a task that runs such a line; or
- an `aquasecurity/trivy-action` step scanning an image (its default `scan-type`), with a non-zero `exit-code` and a
  `severity`, if it gives one, that names both.

Because `docker/build-push-action` builds and pushes in one step, a job that uses it builds the image first with
`load: true`, scans it, and pushes it in a later step, which the build cache makes cheap.

**Correct:**

```yaml
steps:
  - name: Build the image
    uses: docker/build-push-action@<sha>
    with:
      load: true
      tags: ghcr.io/example-org/example-api:${{ github.ref_name }}
  - name: Scan the image
    run: >-
      trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed
      --ignorefile .config/security/trivyignore.yaml ghcr.io/example-org/example-api:${{ github.ref_name }}
  - name: Push the image
    id: push
    uses: docker/build-push-action@<sha>
    with:
      push: true
      tags: ghcr.io/example-org/example-api:${{ github.ref_name }}
```

**Incorrect:**

```yaml
steps:
  - uses: docker/build-push-action@<sha>
    with:
      push: true
      tags: ghcr.io/example-org/example-api:${{ github.ref_name }}
  - run: trivy image ghcr.io/example-org/example-api:${{ github.ref_name }}   # after the push, and exits 0
```

Checked by: conftest · Severity: warning · Since: 0.9.0

### IMAGE-12

**A job that pushes an image attests its build provenance in the registry, unless the repository is private.**

The OCI labels ([OUT-10](../outputs/publishing-and-consuming.md#out-10)) say where an image claims to come from; a
provenance attestation proves it. `actions/attest` (or `actions/attest-build-provenance`) signs a statement of the
workflow, commit and runner that built the pushed digest, and with `push-to-registry: true` stores it in the registry
beside the image, where `gh attestation verify oci://<image>` and a cluster's admission policy find it. It needs
`id-token: write` to sign and `attestations: write` to store the attestation, and `packages: write` to push it to
GHCR. With `artifact-metadata: write` the same step writes the storage record OUT-14 asks for.

GitHub offers artifact attestations only in public repositories, unless the organization is on GitHub Enterprise
Cloud. As for release assets ([REL-18](../releases/release-workflows.md#rel-18)), a repository that declares
`visibility = "private"` or `"internal"` in its
[identity declaration](../repository/identity-declaration.md#the-declaration-file) is exempt; its image carries its
provenance and SBOM in the registry from the build instead (`provenance: mode=max`, `sbom: true`), and it still posts
its storage record (OUT-14). A repository that does not declare its visibility is held to the attestation.

The check reports a pushing job with no attestation step that has `push-to-registry: true`, and a job with one that
lacks `id-token: write` or `attestations: write` in its permissions, or the workflow's when the job sets none.

**Correct:**

```yaml
permissions:
  contents: read
  packages: write
  id-token: write
  attestations: write
  artifact-metadata: write
steps:
  - id: push
    uses: docker/build-push-action@<sha>
    with:
      push: true
      tags: ghcr.io/example-org/example-api:${{ github.ref_name }}
  - uses: actions/attest@<sha>  # v4
    with:
      subject-name: ghcr.io/example-org/example-api
      subject-digest: ${{ steps.push.outputs.digest }}
      push-to-registry: true
```

**Incorrect:**

```yaml
steps:
  - uses: docker/build-push-action@<sha>
    with:
      push: true
      tags: ghcr.io/example-org/example-api:${{ github.ref_name }}   # nothing proves where it was built
```

Checked by: conftest · Severity: warning · Since: 0.9.0

## References

- [Trivy: Container image scanning](https://trivy.dev/latest/docs/target/container_image/)
- [aquasecurity/trivy-action](https://github.com/aquasecurity/trivy-action)
- [actions/attest](https://github.com/actions/attest)
- [SLSA: Build provenance](https://slsa.dev/spec/v1.0/provenance)
- [EC-0008 Publishing and consuming outputs](../outputs/publishing-and-consuming.md)
