# Example consumer

A miniature repository that meets every GitHub Actions, adoption, repository, output, release, task, environment,
toolchain and dev container requirement in this release. Copy from it; the comments explain the choices that are not obvious.

| File | Shows |
| --- | --- |
| [`.config/mise/config.toml`](.config/mise/config.toml) | One line pinning the release (ADOPT-09), beside the two tools GHA-33 delegates to and the `min_version` of mise, in the one place mise reads ([EC-0017](../../definitions/conventions/toolchain/tool-pins.md)). No `.repo/conventions.toml` is needed without waivers ([EC-0001](../../definitions/conventions/adoption/conventions-declaration.md)) |
| [`.config/mise/mise.lock`](.config/mise/mise.lock) | What `mise lock` writes: each tool's download URL and checksum per platform (TOOL-05). Here release-please raises the release pin, so until someone runs `mise lock` the entry for the release can lag one release behind; in your repository the lockfile changes with the pin |
| [`.repo/repository.toml`](.repo/repository.toml) | The repository's identity ([EC-0009](../../definitions/conventions/repository/identity-declaration.md)): `platform-api`, a `service` in the `platform` system, whose kind selects the `service` profile, and whose `[layout]` names its product directory ([EC-0018](../../definitions/conventions/repository/layout.md)) |
| [`platform-api/env.schema.yaml`](platform-api/env.schema.yaml) | The service's environment contract ([EC-0019](../../definitions/conventions/environment/env-contract.md)): every variable it reads, in the format of [EC-0020](../../definitions/conventions/environment/env-schema.md), with a component vocabulary and a secret that commits only a loopback address |
| [`.repo/outputs.toml`](.repo/outputs.toml) | The one output the repository publishes, an `image`, and the workflow that publishes it ([EC-0007](../../definitions/conventions/outputs/outputs-declaration.md)) |
| [`platform-api/go.mod`](platform-api/go.mod) | The product directory, named after the repository and holding the build manifest, so the root keeps only what acts on the product |
| [`platform-api/Dockerfile`](platform-api/Dockerfile), [`platform-api/README.md`](platform-api/README.md) | The image, built from the product directory alone, and the document the output declaration points at: how to run it, pin it and verify it ([EC-0008](../../definitions/conventions/outputs/publishing-and-consuming.md)) |
| [`.github/release-please/`](.github/release-please/config.json) | The release-please config and release-please manifest ([EC-0024](../../definitions/conventions/releases/release-configuration.md)): one package tagged `vX.Y.Z`, drafted with its tag, both pre-1.0 bump settings, and a changelog that shows only the commit types that cut a release. [`version.txt`](version.txt) is the file release-please owns |
| [`.github/workflows/release.yml`](.github/workflows/release.yml) | The release workflow ([EC-0026](../../definitions/conventions/releases/release-workflows.md)): release-please with the release App's token, the image built from the tag with its OCI annotations and provenance, then the draft published last and checked immutable. The image goes to a registry, so the release carries no assets |
| [`.github/rulesets/release-tags.json`](.github/rulesets/release-tags.json) | The tag ruleset ([EC-0025](../../definitions/conventions/releases/release-tags.md)): no release tag is created, moved or deleted except by the release App. Its `actor_id` is a placeholder for your App's ID |
| [`Taskfile.yml`](Taskfile.yml) | The task interface ([EC-0016](../../definitions/conventions/tasks/task-interface.md)): `setup`, `check` and `lint`, plus `build`, `test` and `dev` for a service, written in the style of [EC-0015](../../definitions/conventions/tasks/taskfile-style.md) |
| [`.github/workflows/validate.yml`](.github/workflows/validate.yml) | An entry-point `validate` workflow: derived `name:`, `<Subject>` job names that GitHub shows after the workflow's name, snake_case IDs, least-privilege permissions, the standard concurrency group, timeouts, SHA pins, and a `Validate / Required` aggregate, the one job that leads with its workflow's name because a ruleset requires it, that treats anything but success as failure |
| [`.github/workflows/validate-pull-request.yml`](.github/workflows/validate-pull-request.yml) | A single-job workflow that is its own required check, with workflow permissions `{}` widened by the job |
| [`.github/rulesets/main-branch.json`](.github/rulesets/main-branch.json) | A ruleset that requires only aggregates (`Validate / Required`) and single-job workflows |
| [`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json) | A dev container ([EC-0027](../../definitions/conventions/dev-containers/dev-container-configuration.md)): an image with a fixed tag, its one Feature locked in [`devcontainer-lock.json`](.devcontainer/devcontainer-lock.json), a user other than root, a volume named for the container, and a post-create script the repository holds. It shows what the requirements accept; it is not a template to copy, and the organization's scaffold is `musher-dev/development-container` |
| [`.github/renovate.json`](.github/renovate.json) | Renovate, whose devcontainer and mise managers raise the dev container's image and Features and the release pin (DEVC-09) |

## What the Validate workflow runs

| Job | Does |
| --- | --- |
| `Workflows` | actionlint and zizmor at medium severity (GHA-33), at the versions in `.config/mise/config.toml` |
| `Conventions` | `conventions check --fail-on warning`, the command a developer runs locally |
| `Dev Container` | builds the dev container with `--frozen-lockfile` (DEVC-10) |
| `Validate / Required` | fails unless every job above succeeded |

The first two jobs install their tools with `jdx/mise-action`, so CI and a local run use the same versions. A real repository
adds its own jobs (`API / Tests`, `Repository / Lint`) and lists each in the aggregate's `needs:`. The ruleset does not
change: it requires the aggregate.

## Checking the example

From a checkout of this repository:

```sh
engineering-conventions/bin/conventions check -C engineering-conventions/examples/consumer --fail-on warning
```

It reports no findings.
