---
title: What a repository publishes and deploys is recorded in GitHub's linked artifacts
date: 2026-10-13
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0035 — What a repository publishes and deploys is recorded in GitHub's linked artifacts

## Context

The declarations say what a repository means to do. `.repo/outputs.toml`
([EC-0007](../../engineering-conventions/definitions/conventions/outputs/outputs-declaration.md)) says what it
publishes and where, and `.repo/dependencies.toml`
([EC-0032](../../engineering-conventions/definitions/conventions/dependencies/dependencies-declaration.md)) what it
vendors. Neither says what was in fact built, which digest a registry holds, or which release runs in which
environment. Today that is found by reading each repository's workflow runs, registry pages and deploy logs, one
repository at a time.

GitHub's [linked artifacts](https://docs.github.com/en/code-security/concepts/supply-chain-security/linked-artifacts)
page holds those facts for the whole organization. It lists each artifact the organization builds with GitHub Actions
from two kinds of record. A **storage record** says an artifact, by name and digest, is stored in a registry, built
from a repository, with its attestations; `actions/attest` with `push-to-registry: true` writes it when the job has
`artifact-metadata: write`, and `POST /orgs/{org}/artifacts/metadata/storage-record` writes it without an
attestation. A **deployment record** says the artifact is deployed (or decommissioned) in a logical environment, a
physical environment and a cluster, with its runtime risks (`critical-resource`, `internet-exposed`,
`lateral-movement`, `sensitive-data`); it is written by `POST /orgs/{org}/artifacts/metadata/deployment-record`, and
nothing writes it for a deploy that does not post it. Runtime risks filter code scanning and Dependabot alerts and
security campaigns, and the `deployed` and `deployable` filters let an organization ruleset target the repositories
whose code runs.

Artifact attestations in a private repository need GitHub Enterprise Cloud, which is why
[REL-18](../../engineering-conventions/definitions/conventions/releases/release-workflows.md#rel-18) exempts a private
repository from attesting its release assets. The storage-record and deployment-record endpoints need no attestation.

## Decision

**Every image a repository publishes has a storage record, and every deploy posts a deployment record, in the
organization's linked artifacts.** The declarations stay the statement of intent; the records are the observed facts,
and the organization's graph, assembled from every repository's declarations in `musher-dev/pelorus`
([decision 0022](0022-interfaces-and-dependencies.md)), joins the two: a declared output with no record was never
published, and a record with no declaration is an output nobody declared.

What each record states is fixed, so a record from one repository reads like a record from the next:

| Field | Value |
| --- | --- |
| `name` | The output's published name: for an image, its registry path without a tag (`ghcr.io/<org>/<name>`) |
| `version` | The release version the artifact was built from; never `latest` or another moving alias |
| `digest` | The digest the push reported |
| `logical_environment` | The deployment environment's name, as the terminology registers it: `production`, never `prod` ([decision 0034](0034-deployment-environments-have-one-name.md)) |
| `physical_environment` | Where it runs: the provider and region, such as `example-cloud/us-east` |
| `deployment_name` | A name unique within its `cluster` |
| `status` | `deployed` when a deploy succeeds; a teardown posts `decommissioned` |
| `github_repository` | The repository that built it, required by the storage-record API when no attestation names it |

The requirements that hold it:

- [OUT-14](../../engineering-conventions/definitions/conventions/outputs/publishing-and-consuming.md#out-14): a job
  that pushes an image writes its storage record, by an attestation with `push-to-registry: true` or by posting it,
  with `artifact-metadata: write`. A release asset or package should have one too; that is checked in review.
- [IMAGE-12](../../engineering-conventions/definitions/conventions/container-images/image-publishing.md#image-12): a
  job that pushes an image attests its build provenance in the registry, unless the repository declares itself
  private or internal. The attestation and the record are separate requirements so that a private repository, exempt
  from the first, is still held to the second.
- [IMAGE-11](../../engineering-conventions/definitions/conventions/container-images/image-publishing.md#image-11): the
  image is scanned with Trivy before it is pushed, failing on HIGH and CRITICAL vulnerabilities (issue #89).
- [GHA-53](../../engineering-conventions/definitions/conventions/github-actions/releases-and-deployments.md#gha-53): a
  deploy job that names an environment posts a deployment record, with `artifact-metadata: write`.
- [GHA-50](../../engineering-conventions/definitions/conventions/github-actions/releases-and-deployments.md#gha-50) to
  [GHA-52](../../engineering-conventions/definitions/conventions/github-actions/releases-and-deployments.md#gha-52):
  the job's GitHub environment carries the deployment environment's name, which is what `logical_environment`
  repeats; secrets and variables are scoped by that environment rather than named after it; and a GitHub App's
  credentials are `vars.<PURPOSE>_APP_CLIENT_ID` and `secrets.<PURPOSE>_APP_PRIVATE_KEY`.

## Consequences

### Positive

- One page shows, for every repository, what it built, where it is stored and where it runs, with the provenance to
  check it, without reading any repository's workflows.
- Alerts can be filtered to what is deployed and internet-exposed, and a ruleset can target deployed repositories.
- The organization's graph can tell a declaration that was acted on from one that was not.
- A private repository still records what it publishes and deploys, though it cannot attest.

### Negative

- Each deploy workflow carries one more step, and each job that pushes or deploys one more permission.
- The checks see only what a workflow wires. A record posted by a script the check cannot read, or by a deployment
  tool outside GitHub Actions, is not seen, and its job is reported until it is waived or the post is moved where the
  check reads it.
- A record is a fact GitHub keeps, not a file in the repository: what it says is reviewed in the workflow, and wrong
  values are corrected by posting again.

### Neutral

- Storage records for release assets and packages are recommended now and checked when a check can tell what a job
  published from what it built.
- The integrations GitHub offers for other registries and runtimes may write the same records; a repository that uses
  one meets the intent, and waives the requirement the check cannot see it meet.

## Enforcement

OUT-14 (`conventions.checks.outputs.publishing`), IMAGE-11 and IMAGE-12 (`conventions.checks.container_images.publishing`)
and GHA-50 to GHA-53 (`conventions.checks.github_actions.releases_and_deployments`), each with a fixture and a
near-miss. Whether a record's values follow the table above is review-only: a reviewer reads the step that posts it.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| A | Keep the declarations as the only record, and infer what was published from registries | rejected: each registry is read differently, and nothing says where an artifact runs |
| B | A deployment declaration in `.repo/` listing environments | rejected: it states intent again, not what was deployed |
| C | Linked-artifact storage and deployment records, posted by the workflows that publish and deploy | **chosen** |
| D | One requirement for attestation and record together | rejected: a private repository cannot attest but can still record |

## References

- [GitHub Docs: Linked artifacts](https://docs.github.com/en/code-security/concepts/supply-chain-security/linked-artifacts)
- [GitHub Docs: Uploading storage and deployment data to the linked artifacts page](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/upload-linked-artifacts)
- [GitHub REST API: Artifact metadata](https://docs.github.com/en/rest/orgs/artifact-metadata)
- [Decision 0022: Interfaces and dependencies](0022-interfaces-and-dependencies.md)
- [Decision 0034: Deployment environments have one name](0034-deployment-environments-have-one-name.md)
- [Issue #89: Require published container images to be scanned and attested](https://github.com/musher-dev/engineering-conventions/issues/89)
