---
title: A site is an output, and a deploy workflow may publish it
date: 2026-09-29
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
amends: ["0010", "0014"]
---

# 0018 — A site is an output, and a deploy workflow may publish it

## Context

[Decision 0010](0010-outputs-declaration.md) gave `.repo/outputs.toml` five output kinds: `image`, `library`, `cli`,
`contract` and `bundle`. Each is a versioned thing a consumer pins and fetches from a registry or a release. Two
adopting repositories publish something that none of them describes.

- `musher-dev/specifications` serves its JSON Schemas at the URLs their `$id` names, with pinned versioned paths, moving
  major-version aliases, a version list and an editor catalog. Validators and editors fetch from that origin. Calling
  the whole origin a `contract` is wrong: a contract names one definition file, and the origin also serves the
  catalog, the version lists and the reference pages.
- A host-image repository bakes bootable machine images that hosts are created from. `image` means an OCI container
  image, and every other kind is a released file or package.

Both had to leave these outputs undeclared, so a reader or catalog cannot see them.

A site also breaks the rule in [decision 0014](0014-release-workflows-may-publish.md) and OUT-06, that an output's
publishing workflow is a `publish` or `release` workflow. GitHub Actions naming gives `deploy` to "changing what a
running environment serves" ([EC-0002](../../engineering-conventions/definitions/conventions/github-actions/workflow-files.md#responsibility-tokens)).
For a site, the running environment is the output: the workflow that pushes its files to the host is the one that
makes it available, and that workflow is `deploy`.

## Decision

- Two output kinds join the terminology, tagged `outputs.kind`:
  - **`site`**: files served at a stable HTTPS origin that people or tools fetch by URL.
  - **`vmimage`**: a bootable virtual machine disk image that hosts are created from. Its display form is "machine
    image". The token is one word because output-kind tokens are lower-case letters and digits.
- **OUT-06** accepts a `deploy` workflow as the publishing workflow of a `site`, and of no other kind. It still accepts
  `publish` and `release` workflows for every kind, a site included.
- **New OUT-12**: a site's `location` is an `https://` origin.
- **OUT-09** says what "never overwritten" means for a site: its versioned paths never change once served, and
  aliases may move.
- **OUT-01 does not change.** A `deploy` workflow is not taken to publish an output, because most deploy workflows
  roll out a service, and a service is not an output.

## Consequences

### Positive

- specifications can declare its schema host, and a host-image repository can declare its images, without inventing
  a kind or misusing `image`.
- A catalog built from the declarations sees websites as `Component` entities of type `website`, which is Backstage's
  own well-known type.

### Negative

- `deploy` now carries two meanings in OUT-06: rolling out a service, which publishes nothing, and pushing a site,
  which publishes the site. The output's kind decides which applies.
- The site kind cannot say which of its paths are versioned. That stays in the documentation its `docs` field points
  at, and OUT-09 is checked in review.

### Neutral

- A site published from `release.yml`, as specifications does after each release, already passed OUT-06 and still
  does.
- The new kinds are `provisional` terms, like the other output kinds.

## Enforcement

- **OUT-03** in `checks/rego/outputs/declaration.rego` accepts `site` and `vmimage`, because the kinds are read from
  the generated vocabulary.
- **OUT-06** reports a `site` whose workflow is not `publish`, `release` or `deploy`, and any other kind whose
  workflow is not `publish` or `release`. The fixture `out-06-deploy-site` proves a site passes with
  `deploy-docs.yml`, and `out-06-deploy-image` proves an image still fails with `deploy.yml`.
- **OUT-12** reports a site whose `location` does not start with `https://`. The fixture is `out-12-site-location`.
- That a site's versioned paths are never overwritten is review-only (OUT-09).

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Model the site as `contract` outputs | One contract per schema, with the site URL as its location | rejected: covers the schemas but not the origin, its catalog or version lists, nor documentation sites |
| Add `site` and accept `deploy` for it | A new kind; OUT-06 lets the deploy workflow publish it | **chosen** |
| Add `site` and require a `publish` workflow | Rename every site's deploy workflow to `publish-*` | rejected: pushing files to a running host is what `deploy` means, so the name would mislead |
| Leave sites and machine images undeclared | Keep the five kinds | rejected: two repositories already have outputs the declaration cannot show |

## References

- [Decision 0010: A repository declares the outputs it publishes](0010-outputs-declaration.md)
- [Decision 0014: A release workflow may publish what it releases](0014-release-workflows-may-publish.md)
- [EC-0007 Outputs declaration, OUT-06 and OUT-12](../../engineering-conventions/definitions/conventions/outputs/outputs-declaration.md)
- [EC-0008 Publishing and consuming outputs, OUT-09](../../engineering-conventions/definitions/conventions/outputs/publishing-and-consuming.md)
- [Backstage: Descriptor format of catalog entities](https://backstage.io/docs/features/software-catalog/descriptor-format/)
