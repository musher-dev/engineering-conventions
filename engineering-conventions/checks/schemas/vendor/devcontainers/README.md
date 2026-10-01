# Vendored Dev Container schema

An unmodified copy of the Dev Container specification's base schema from
[devcontainers/spec](https://github.com/devcontainers/spec). The repository publishes its code, the schemas included,
under the MIT License ([LICENSE-CODE](LICENSE-CODE)) and the rest of its content under Creative Commons Attribution
4.0 ([LICENSE](LICENSE)); both are copied here unchanged. Copyright © Microsoft Corporation. DEVC-17 (EC-0027) checks
each `devcontainer.json` against it rather than restating the specification's properties in Rego.

| File | Validates | Read by |
| --- | --- | --- |
| `devContainer.base.schema.json` | `.devcontainer/devcontainer.json`, `.devcontainer/<name>/devcontainer.json`, `.devcontainer.json` | DEVC-17 |

It is byte-identical to `schemas/devContainer.base.schema.json` at devcontainers/spec commit
[`c95ffeed1d059abfe9ffbe79762dc2fa4e7c2421`](https://github.com/devcontainers/spec/blob/c95ffeed1d059abfe9ffbe79762dc2fa4e7c2421/schemas/devContainer.base.schema.json)
(git blob `86709ecabe9673252a3c5bf13d412342d437b5d7`), where the file last changed in commit `d424cc1`.

The schema is draft 2019-09, and OPA's `json.match_schema` implements draft-07, which reads it differently in two ways:
it ignores a `$ref`'s sibling keywords, and it has no `unevaluatedProperties`. Read as it is, the schema rejects every
valid configuration and accepts a misspelt property. So `task generate` embeds a rewritten form in
`checks/data/index.json` (`schemas.for_draft_07` in the authoring CLI): a `$ref` with siblings becomes an `allOf` of
the two, and `unevaluatedProperties: false` becomes a `propertyNames` list of every property the schema and its
subschemas declare. The rewrite can only be more lenient than the original: it still rejects a property no branch
declares, and lets through one that a branch the file does not use declares. `tests/test_schemas.py` checks that the
two forms agree on valid and invalid configurations.

To refresh it, download the file at a newer commit, record that commit and the blob here, run `task generate`, and
read the findings snapshot diff: a schema that tightens can make a configuration that passed fail.
