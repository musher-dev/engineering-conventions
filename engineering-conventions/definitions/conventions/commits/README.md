# Commits

These conventions govern a repository's commit messages and pull request titles: the lines release-please reads to
choose the next version and write the changelog, and that every history and review shows.

The governing rule, in one sentence:

> **Every commit and pull request title passes committed against the repository's one list of types and scopes.**

## Status

The convention is a **draft**, owned by this repository, and every requirement is `proposed` at severity `warning`.
Why the rules are delegated to committed is recorded in
[decision 0025](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0025-commit-messages-delegate-to-committed.md).

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0035 Commit messages](commit-messages.md) | COMMIT-01 – COMMIT-06 | The committed configuration, its pin, the commit-msg hook, the pull request title check, and the rules a message passes |

## Quick reference

| File | Holds |
| --- | --- |
| `.config/commits/committed.toml` | `style = "conventional"`, the types and scopes, the header length (COMMIT-01) |
| `.config/mise/config.toml` | `"github:crate-ci/committed" = "1.1.11"` (COMMIT-02) |
| `.config/lefthook.yml` | `commit-msg`: `committed --config .config/commits/committed.toml --commit-file {1}` (COMMIT-03) |
| `.github/workflows/validate-pull-request.yml` | committed on the title through stdin, and `action-semantic-pull-request` with `requireScope: true` (COMMIT-04) |

No `.github/conventional-commits.yaml` (COMMIT-06).
