---
title: A repository declares the outputs it publishes in .repo/outputs.yaml
date: 2026-09-24
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0010 — Outputs declaration

## Context

Musher's repositories publish different kinds of things: container images, libraries, command-line tools, API
contracts and bundles like this repository's own release. Nothing says which repository publishes what. To find out,
a reader opens a repository's workflows, guesses which one publishes, and reads it to learn the registry and the tag
scheme. Two questions go unanswered for every output: *what does this repository produce*, and *how do I consume it*.

The GitHub Actions conventions already name the workflow that publishes (the `publish` responsibility, EC-0002), so
a repository's publish workflows can be found. What they publish, from where, and how it is meant to be consumed is
not recorded anywhere a reader or a tool can find it.

The [charter](0000-charter.md) makes this repository the home of shared repository structures and implementation
expectations, and it already owns one declaration format, the conventions declaration. It does not own product
vocabulary or document specifications, and `musher-dev/specifications`' catalog format describes products, not
repositories' build outputs.

## Decision

**A repository that publishes declares each output in `.repo/outputs.yaml`.** The format and the requirements on it
are [EC-0007](../../engineering-conventions/definitions/conventions/outputs/outputs-declaration.md). What a published
output promises, and how another repository consumes it, are
[EC-0008](../../engineering-conventions/definitions/conventions/outputs/publishing-and-consuming.md). Both are in the
new `outputs` topic, family `OUT`, included in `base-repo`, with every requirement `proposed` at `warning`.

- **This repository owns the declaration format**, the same kind of thing as the conventions declaration the charter
  already lists. It does not own the formats an output carries (OCI, OpenAPI, AsyncAPI, registries' package formats)
  and links them instead.
- **Output kinds are terminology**, tagged `outputs.kind` and projected into `index.json` like the GitHub Actions
  tokens ([decision 0007](0007-terminology-and-generated-artifacts.md)), so a new kind is a term, not a schema change.
- **The shape maps onto Backstage's descriptor format**: kind and type, `providesApis`-style contracts with a
  definition file. A `catalog-info.yaml` can be generated from a declaration without the repository keeping a second
  file.
- **Aggregating declarations is out of scope.** A catalog, a crawler or a GitHub custom property can read the files;
  none of them is built or hosted here, because this repository does not run anything for other repositories.

## Consequences

### Positive

- One file answers what a repository produces and where its consumers start.
- A publish workflow without a declaration is reported, so the file cannot quietly go missing.
- A future catalog has a single, schema-checked input in every repository.

### Negative

- Every publishing repository gains a file to keep current. OUT-05 and OUT-06 report the drift that is likely, a moved
  path or a renamed workflow, but not an output published without being declared by a workflow of another
  responsibility.
- The mapping to Backstage uses two types (`tool`, `bundle`) that are not among Backstage's well-known ones.

### Neutral

- Repositories that publish nothing are unaffected.

## Enforcement

- OUT-01 to OUT-07 (EC-0007) are conftest checks with fixture repositories; `conventions invariants` fails when a
  requirement has no fixture.
- OUT-02 validates the file against `checks/schemas/outputs.schema.json`, embedded in `index.json`.
- OUT-08 to OUT-11 (EC-0008) are `review-only`: a reviewer checks the docs a declaration points at, the publish
  triggers, image annotations and consumers' pins.
- This repository declares its own outputs, and `task conventions:self` holds it to them.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Adopt Backstage `catalog-info.yaml` | A known format with ingestion tooling | rejected for now: `v1alpha1`, a much larger surface, no native kinds for images or command-line tools; kept reachable through the mapping |
| An `outputs:` block in `.repo/conventions.yaml` | One file per repository | rejected: mixes the rules a repository follows with what it produces, and breaks "declare only what differs" |
| GitHub repository custom properties | Organization-level labels | rejected: a property labels a repository and cannot list its outputs, their paths or their docs |
| `.repo/outputs.yaml`, mappable to Backstage | A small, schema-checked declaration | **chosen** |

## References

- [EC-0007 Outputs declaration](../../engineering-conventions/definitions/conventions/outputs/outputs-declaration.md)
- [EC-0008 Publishing and consuming outputs](../../engineering-conventions/definitions/conventions/outputs/publishing-and-consuming.md)
- [Backstage: Descriptor format of catalog entities](https://backstage.io/docs/features/software-catalog/descriptor-format/)
- [OCI image-spec: Pre-defined annotation keys](https://github.com/opencontainers/image-spec/blob/main/annotations.md)
- [Decision 0000: Charter](0000-charter.md)
