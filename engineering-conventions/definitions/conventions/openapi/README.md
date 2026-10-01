# OpenAPI

These conventions govern the OpenAPI documents a repository offers as interfaces: the rules every document passes,
the Spectral ruleset that holds them, and the task and workflow step that run it.

The governing rule, in one sentence:

> **Lint every OpenAPI interface with Spectral and a ruleset that extends the one the conventions ship, in
> validation, and exempt a rule only in that ruleset, with the reason beside it.**

The topic is named for the document format, not for interfaces in general: the [interfaces](../interfaces/README.md)
topic declares every interface whatever its format, and this one adds what only an OpenAPI document needs.

## Status

The convention is a **draft**, owned by this repository, and every requirement is `proposed` at severity `warning`.

## Who is checked

`base-repo` selects the family, so every profile does, but OAS-02 and OAS-03 have nothing to find until
`.repo/outputs.toml` declares an interface with `format = "openapi"`. OAS-04 reports a committed link in any
repository.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0037 OpenAPI documents](openapi-documents.md) | OAS-01 – OAS-04 | The shipped Spectral ruleset and its ten rules, the repository's ruleset, running it in validation, the link |

## Quick reference

| File or command | Holds or does |
| --- | --- |
| `checks/openapi/musher.spectral.yaml` | The shipped ruleset: `spectral:oas` recommended and ten `musher-*` rules |
| `.config/openapi/spectral.yaml` | The repository's ruleset: `extends: [../../.conventions/openapi.spectral.yaml]`, its own rules and exemptions |
| `.conventions/openapi.spectral.yaml` | The link `conventions openapi` writes to the shipped ruleset; ignored by git |
| `conventions openapi [--ruleset FILE] [FILE...]` | Refreshes the link, then lints the given files, or every `openapi` interface's documents |
