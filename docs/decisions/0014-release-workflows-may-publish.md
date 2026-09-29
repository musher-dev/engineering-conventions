---
title: A release workflow may publish what it releases
date: 2026-09-27
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
amended_by: ["0017", "0018"]
---

# 0014 — A release workflow may publish what it releases

## Context

[Decision 0006](0006-github-actions-naming-vocabulary.md) split `publish` from `release`: `release` owns versioning
(release pull requests, version bumps, changelogs, tags and GitHub Releases) and `publish` owns pushing a versioned
artifact to a registry. The `release` token's definition said a release workflow builds and ships nothing, and
[OUT-06](../../engineering-conventions/definitions/conventions/outputs/outputs-declaration.md#out-06) required the
workflow an output names to have the responsibility `publish`.

The common release tool does not fit that split. release-please runs on a push to the default branch and decides
there whether a release is created, what its version is and what its tag is. Those facts exist only as outputs of
that run. The natural place to publish the release's image, package or assets is the next steps of the same job,
gated on the release having been created and checked out at the tag it just made.

Three repositories adopting the conventions publish from `release.yml` in exactly this way, and every one of them
gets an OUT-06 finding. The only ways to satisfy the requirement as written are to move publishing to a second
workflow triggered by the tag, which a tag created with the default `GITHUB_TOKEN` does not trigger without a
separate token or app, or to chain a `publish` workflow on `workflow_run`, which runs from the default branch rather
than the tag and loses the release's outputs. Both add moving parts to reach the same result.

## Decision

A release workflow may also publish the artifacts of the release it cuts, in the same run, when the version is known
only there. A workflow that only publishes is still `publish`.

- The `release` responsibility token (`gha.responsibility.release`, and its row in
  [EC-0002](../../engineering-conventions/definitions/conventions/github-actions/workflow-files.md#responsibility-tokens))
  says so. The GitHub Actions conventions' authority is `musher-dev/platform`
  ([decision 0002](0002-authority-and-migration.md)), so the change is listed in EC-0002's differences from the
  platform as a proposal the platform adopts at the handoff.
- OUT-06 accepts a `publish_workflow` whose responsibility is `publish` or `release`, and still reports any other
  (`validate`, `deploy` and the rest).
- OUT-01 is unchanged: only a `publish` workflow is taken to publish something, because a release workflow may cut
  releases that publish nothing.
- OUT-09 says how a release workflow publishes from a release tag: it checks out the tag it just created and publishes
  only when a release was created.

## Consequences

### Positive

- The usual release-please setup passes OUT-06 without a waiver or a second workflow.
- The version, tag and publish happen in one run, so there is no window in which a release exists without its
  artifacts, and no second trigger to fail silently.

### Negative

- `release` no longer names a single kind of outcome: a reader of `release.yml` has to open it to learn whether it
  publishes. `.repo/outputs.toml` answers that question, since an output names the workflow that publishes it.
- The boundary between `release` and `publish` is now a judgment (does the workflow cut the release?) rather than a
  rule about artifacts.

### Neutral

- A repository that already publishes from `publish.yml` is unaffected, and a separate `publish` workflow remains the
  choice when the version is known before the run, such as a tag pushed by a person.

## Enforcement

OUT-06 in `checks/rego/outputs/declaration.rego` reports an output whose `publish_workflow` exists but has a
responsibility other than `publish` or `release`. The fixture `out-06-release-workflow` proves a `release.yml` passes;
`out-06-publish-workflow` proves a `validate.yml` still fails. Whether a release workflow publishes only what it
releases is review-only: a reviewer looks for publishing steps gated on the release having been created.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Require a separate `publish` workflow | Keep `release` versioning-only; publish from a tag-triggered or `workflow_run` workflow | rejected: needs an extra token or loses the release's outputs, for the same result |
| Allow a release workflow to publish what it releases | `release` may publish the artifacts of the release it cuts; OUT-06 accepts `publish` or `release` | **chosen** |
| Drop OUT-06's responsibility check | Accept any existing workflow as the publish workflow | rejected: a `validate` or `deploy` workflow named as the publisher is a real mistake worth reporting |

## References

- [Decision 0006: GitHub Actions naming vocabulary](0006-github-actions-naming-vocabulary.md)
- [Decision 0010: A repository declares the outputs it publishes](0010-outputs-declaration.md)
- [EC-0007 Outputs declaration, OUT-06](../../engineering-conventions/definitions/conventions/outputs/outputs-declaration.md#out-06)
- [release-please action](https://github.com/googleapis/release-please-action)
