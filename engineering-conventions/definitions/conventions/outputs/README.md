# Outputs

These conventions govern what a repository publishes for others to consume: container images, libraries,
command-line tools, contracts and bundles. They cover how a repository declares its outputs, what a published output
promises, and how another repository relies on one.

The governing rule, in one sentence:

> **Declare every output where a reader can find it, publish each version once from a tag, and consume it by an exact
> version.**

The declaration lives in `.repo/outputs.yaml`, beside the conventions declaration. It is a declaration, not a catalog:
these conventions own its format, and anything that collects declarations across repositories reads them.

## Status

Both conventions are **drafts**, owned by this repository, and every requirement is `proposed` at severity `warning`.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0007 Outputs declaration](outputs-declaration.md) | OUT-01 – OUT-07 | The file, the output kinds, and the checks on it |
| [EC-0008 Publishing and consuming outputs](publishing-and-consuming.md) | OUT-08 – OUT-11 | Consumption docs, immutable versions, image provenance, exact pins |

The reasoning is recorded in
[decision 0010](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0010-outputs-declaration.md).

## Quick reference

| Field | Example |
| --- | --- |
| `id` | `api-image` |
| `kind` | `image`, `library`, `cli`, `contract`, `bundle` |
| `source` | `api/` |
| `publish_workflow` | `publish-api.yml` |
| `location` | `ghcr.io/your-org/api` |
| `docs` | `api/README.md#run-the-image` |
| `format`, `definition` (contract only) | `openapi`, `api/openapi.yaml` |
