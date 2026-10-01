# Vendored SchemaStore schemas

Unmodified copies of four JSON Schemas from [SchemaStore](https://github.com/SchemaStore/schemastore), which publishes
them under the Apache License 2.0 ([LICENSE](LICENSE), [NOTICE](NOTICE)). The community files checks (EC-0036) validate
a repository's GitHub forms against them rather than restating GitHub's form syntax in Rego.

| File | Validates | Read by |
| --- | --- | --- |
| `github-issue-forms.json` | `.github/ISSUE_TEMPLATE/*.yml`, except `config.yml` | COMM-01 |
| `github-issue-config.json` | `.github/ISSUE_TEMPLATE/config.yml` | COMM-02 |
| `github-funding.json` | `.github/FUNDING.yml` | COMM-03 |
| `github-discussion.json` | `.github/DISCUSSION_TEMPLATE/*.yml` | COMM-08 |

Each is byte-identical to `src/schemas/json/<file>` at SchemaStore commit
[`9fb5bdbcdd9f0288b236230155c61e2e88345963`](https://github.com/SchemaStore/schemastore/tree/9fb5bdbcdd9f0288b236230155c61e2e88345963/src/schemas/json),
which is what `https://json.schemastore.org/<file>` served on 2026-10-01. They are draft-07 and self-contained, so
`task generate` embeds them in `checks/data/index.json` as they are and the checks read them with `json.match_schema`.

To refresh them, download each from `https://json.schemastore.org/<file>`, record the commit it matches here, run
`task generate`, and read the findings snapshot diff: a schema that tightens can make a form that passed fail.
