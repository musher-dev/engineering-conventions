# OpenAPI

These conventions govern the OpenAPI documents a repository offers as interfaces: the Spectral ruleset that lints
them, and the task and workflow step that run it.

The governing rule, in one sentence:

> **Lint every OpenAPI interface in validation with Spectral and a ruleset that extends `spectral:oas` and the OWASP
> API security ruleset at an exact release, and exempt a rule only in that ruleset, with the reason beside it.**

The topic is named for the document format, not for interfaces in general: the [interfaces](../interfaces/README.md)
topic declares every interface whatever its format, and this one adds what only an OpenAPI document needs. API-design
rules, such as casing or error formats, are the owning repository's: it adds them to its own ruleset.

## Status

The convention is a **draft**, owned by this repository, and every requirement is `proposed` at severity `warning`.

## Who is checked

`base-repo` selects the family, so every profile does, but OAS-02 and OAS-03 have nothing to find until
`.repo/outputs.toml` declares an interface with `format = "openapi"`.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0037 OpenAPI documents](openapi-documents.md) | OAS-01 – OAS-03 | The repository's ruleset, the upstream rulesets it extends, running it in validation |

## Quick reference

| File or command | Holds or does |
| --- | --- |
| `.config/openapi/spectral.yaml` | The repository's ruleset: extends `spectral:oas` and the OWASP ruleset; its own rules and exemptions |
| `conventions openapi [--ruleset FILE] [FILE...]` | Lints the given files, or every `openapi` interface's documents, with the repository's ruleset |
