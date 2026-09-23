# Example consumer

A miniature repository that meets every GitHub Actions and adoption requirement in this release. Copy from it; the
comments explain the choices that are not obvious.

| File | Shows |
| --- | --- |
| [`.repo/conventions.yaml`](.repo/conventions.yaml) | A conventions declaration pinning a release and the `base-repo` profile, with a commented waiver ([EC-0001](../../conventions/adoption/conventions-declaration.md)) |
| [`.github/workflows/validate.yml`](.github/workflows/validate.yml) | An entry-point `validate` workflow: derived `name:`, `<Subject>` job names that GitHub shows after the workflow's name, snake_case IDs, least-privilege permissions, the standard concurrency group, timeouts, SHA pins, and a `Validate / Required` aggregate, the one job that leads with its workflow's name because a ruleset requires it, that treats anything but success as failure |
| [`.github/workflows/validate-pull-request.yml`](.github/workflows/validate-pull-request.yml) | A single-job workflow that is its own required check, with workflow permissions `{}` widened by the job |
| [`.github/rulesets/main-branch.json`](.github/rulesets/main-branch.json) | A ruleset that requires only aggregates (`Validate / Required`) and single-job workflows |

## What the Validate workflow runs

| Job | Does |
| --- | --- |
| `Workflows` | actionlint and zizmor at medium severity (GHA-33) |
| `Conventions` | downloads the release named in the declaration, checks `SHA256SUMS` and the provenance attestation, validates the declaration against its schema (ADOPT-02), and runs `conftest` with the bundled checks against the workflows, actions, rulesets and declaration |
| `Validate / Required` | fails unless both jobs above succeeded |

A real repository adds its own jobs (`API / Tests`, `Repository / Lint`) and lists each in the aggregate's `needs:`.
The ruleset does not change: it requires the aggregate.

Tools are installed from their GitHub releases with checksum verification, so the only third-party action in
`validate.yml` is `actions/checkout`. A repository with a shared setup action (for example `setup-tools`, built on a
pinned tool manager) can use that instead.

## Checking the example

From a checkout of this repository:

```sh
uv run --project engineering-conventions --locked conventions check engineering-conventions/examples/consumer --fail-on warning
```

It reports no findings.
