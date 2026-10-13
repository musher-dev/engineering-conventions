# Vendored variable lists

The environment variable names two vendors define, extracted from their documentation so that ENVS-29 can tell a
name the vendor reads from one made up under its prefix ([EC-0020](../../../definitions/conventions/environment/env-schema.md#envs-29)).
They are lists of names only: what each variable means stays with its vendor, and the files link to the pages that
say.

| File | Vendor | Prefixes | Sources |
| --- | --- | --- | --- |
| `opentelemetry.json` | OpenTelemetry | `OTEL_` | The SDK environment variable specification and the OTLP exporter specification |
| `github-actions.json` | GitHub Actions | `GITHUB_`, `RUNNER_`, `ACTIONS_` | The default variables, `GITHUB_TOKEN`, the OIDC token request variables, the debug logging switches |

Each file records its `sources` and the date it was `retrieved`. `definitions/environment/grammar.yml` names which file
holds a reserved prefix's names, and `task generate` embeds each list in `checks/data/index.json` under
`env_grammar.reserved_prefixes`, so the checks and a consumer read the index alone.

To refresh a list, read each source page again, replace `names` with every variable it defines, set `retrieved`, run
`task generate`, and read the findings snapshot diff: a name the vendor dropped is reported from then on.
