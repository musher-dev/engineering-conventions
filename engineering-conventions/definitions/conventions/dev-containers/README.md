# Dev containers

These conventions govern the files a repository's dev container is made of: its configuration under
`.devcontainer/`, its lockfile, the Dockerfile it builds, and the compose stacks it starts beside it.

The governing rule, in one sentence:

> **A dev container is found where tools look, locked, fixed to images that change only with a commit, run as a user
> other than root, kept current, and proved in CI; and the services it starts stay on the machine.**

The dev container scaffold itself, the container most repositories start from, is `musher-dev/development-container`'s.
These conventions hold every repository's dev container to the same bar, that one's included
([decision 0020](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0020-dev-container-files-get-their-own-family.md)).

## Status

Both conventions are **drafts**, owned by this repository, and every requirement is `proposed` at severity `warning`.

## Who is checked

The `base-repo` profile selects the family, so every kind of repository is checked, but only a repository with a dev
container has anything to find: each requirement reads a `devcontainer.json` or a compose file under `.devcontainer/`.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0027 Dev container configuration](dev-container-configuration.md) | DEVC-01 – DEVC-10, DEVC-14, DEVC-15 | Where the configuration lives, the lockfile, the base image, the user, lifecycle scripts, secrets, named volumes and where they mount, the container name, updates and the CI build |
| [EC-0028 Dev container stacks](dev-container-stacks.md) | DEVC-11 – DEVC-13, DEVC-16 | The images and published ports of the compose stacks under `.devcontainer/`, and the version of a capability a stack labels |

Related requirements in other families:

- A dev container Feature that installs a tool mise pins installs the pinned version (TOOL-08).
- The dev environment's schema is `.devcontainer/env.schema.yaml` (ENVS-02), and `secrets` names every variable it
  takes from the host (ENVS-15).

## Quick reference

| In the dev container | Must be | Requirement |
| --- | --- | --- |
| `devcontainer.json` | At `.devcontainer/` or `.devcontainer/<name>/` | DEVC-01 |
| `devcontainer-lock.json` | Committed when there are Features, and matching them | DEVC-02, DEVC-03 |
| `image`, and the `FROM` of the Dockerfile `build` names | A fixed tag or a digest | DEVC-04 |
| `remoteUser`, `containerUser` | Set, and not root | DEVC-05 |
| A script a lifecycle command runs | A file in the repository | DEVC-06 |
| A secret in `containerEnv` or `remoteEnv` | `${localEnv:…}` or empty | DEVC-07 |
| A named volume in `mounts` | `musher-${devcontainerId}-<purpose>` | DEVC-08 |
| A volume's target under `/home` | In `remoteUser`'s home | DEVC-15 |
| `runArgs` | No `--name` | DEVC-14 |
| Updates | Dependabot `devcontainers`, or Renovate | DEVC-09 |
| CI | A build, with `--frozen-lockfile` | DEVC-10 |
| A stack service's `image` | A fixed tag or a digest | DEVC-11 |
| A stack's published port | `127.0.0.1`, from 15432–15460 | DEVC-12, DEVC-13 |
| A stack service labelled `dev.musher.capability` | Its `dev.musher.capability-version` in every environment schema's range | DEVC-16 |
