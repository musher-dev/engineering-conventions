# Contributing

Thank you for helping improve the conventions. This repository is public; everything in it, including issues and pull
requests, is published. Do not include secrets, internal hostnames, customer information or strategy material.

## Proposing a change

Start with an issue, using the matching form:

| Form | Use it to |
| --- | --- |
| **Propose a requirement** | add a new normative requirement to a convention |
| **Change a requirement** | tighten, relax, clarify, or retire an existing requirement |
| **Propose a term** | add a token, display form, alias or definition to the terminology |

Describe the failure the change prevents, with a real example. Requirements owned by another repository (their
convention names an `authority`) are changed there first and then here; see
[decision 0002](docs/decisions/0002-authority-and-migration.md).

## Making the change

1. Branch from `main`.
2. Follow [Authoring conventions](docs/authoring.md): allocate the ID, add the frontmatter entry and the `### <ID>`
   section, implement the check and its fixtures.
3. Run `task generate`, then `task check`. Commit the regenerated files with the change.
4. Open a pull request. Its title is a Conventional Commit (`type(scope): subject`), checked by
   `Validate Pull Request / Title`. Choose the type by consumer impact, from the change-classification table in
   [decision 0005](docs/decisions/0005-status-severity-and-versioning.md#change-classification).
5. Fill in the pull request template's consumer-impact section: requirement IDs touched, change class, breaking or not.

`Validate / Required` must pass. It fails unless every job in the `Validate` workflow succeeded. The one planned
exception is the dev container build: on a pull request that touches none of the files the image is built from, it
skips, and the aggregate accepts that skip.

## Commits and hooks

`task setup` installs git hooks: fast checks run before each commit, the commit message is checked against the
rules in `.config/commits/committed.toml` (by [committed](https://github.com/crate-ci/committed)), and the Rego tests and
the self-check run before each push. Pull requests are squash-merged, so the pull request title becomes the commit on `main`.

### Fast local checks

Where the checkout lives decides how long `task check` takes. On a Windows drive bind-mounted into the dev container
(WSL2 serves it over 9p), every file read is a round trip: the full check takes about 20 minutes, against about 3 on
a native filesystem. Clone the repository inside the WSL filesystem (for example `~/src`), or open it with **Dev
Containers: Clone Repository in Named Container Volume**, and reopen it in the container from there. The dev container
already keeps the CLI's virtualenv on a volume of its own.

On a slow disk the pre-push jobs also compete for it. Run them one at a time with a personal
`.config/lefthook-local.yml`, which git ignores:

```yaml
pre-push:
  parallel: false
```

## Decisions

A change to how the repository works, rather than to a convention, is recorded as a decision in
[`docs/decisions/`](docs/decisions/README.md) using its template.

## Review

Code owners review every pull request, against the
[review checklist](docs/authoring.md#review-checklist).
