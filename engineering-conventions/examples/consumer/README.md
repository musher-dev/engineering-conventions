# Example consumer

A miniature repository that meets every GitHub Actions and adoption requirement in this release. Copy from it; the
comments explain the choices that are not obvious.

| File | Shows |
| --- | --- |
| [`mise.toml`](mise.toml) | The whole adoption: one line pinning the release (ADOPT-09), beside the two tools GHA-33 delegates to. No `.repo/conventions.yaml` is needed for the default profile and no waivers ([EC-0001](../../conventions/adoption/conventions-declaration.md)) |
| [`.github/workflows/validate.yml`](.github/workflows/validate.yml) | An entry-point `validate` workflow: derived `name:`, `<Subject>` job names that GitHub shows after the workflow's name, snake_case IDs, least-privilege permissions, the standard concurrency group, timeouts, SHA pins, and a `Validate / Required` aggregate, the one job that leads with its workflow's name because a ruleset requires it, that treats anything but success as failure |
| [`.github/workflows/validate-pull-request.yml`](.github/workflows/validate-pull-request.yml) | A single-job workflow that is its own required check, with workflow permissions `{}` widened by the job |
| [`.github/rulesets/main-branch.json`](.github/rulesets/main-branch.json) | A ruleset that requires only aggregates (`Validate / Required`) and single-job workflows |

## What the Validate workflow runs

| Job | Does |
| --- | --- |
| `Workflows` | actionlint and zizmor at medium severity (GHA-33), at the versions in `mise.toml` |
| `Conventions` | `conventions check --fail-on warning`, the command a developer runs locally |
| `Validate / Required` | fails unless both jobs above succeeded |

Both jobs install their tools with `jdx/mise-action`, so CI and a local run use the same versions. A real repository
adds its own jobs (`API / Tests`, `Repository / Lint`) and lists each in the aggregate's `needs:`. The ruleset does not
change: it requires the aggregate.

## Checking the example

From a checkout of this repository:

```sh
engineering-conventions/bin/conventions check -C engineering-conventions/examples/consumer --fail-on warning
```

It reports no findings.
