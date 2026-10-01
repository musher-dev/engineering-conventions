---
title: Commit messages are checked by committed, against one configuration in .config/commits/
date: 2026-10-01
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0025 — Commit messages are checked by committed, against one configuration in .config/commits/

## Context

Every repository in the organization releases from Conventional Commit messages: release-please reads the type to
choose the version and the subject to write the changelog ([decision 0017](0017-releases-from-drafts.md)). Each one
checks those messages its own way. This repository and `musher-dev/platform` keep the types and scopes in
`.github/conventional-commits.yaml`, read at commit time by a hand-written Bash script, `lint-commit-msg.sh`, that
extracts the lists with `awk` and matches the header against one regular expression, and on the pull request title by
`amannn/action-semantic-pull-request` fed from the same file through `yq`. Other repositories have no commit-message
check at all.

The script checks only the header's shape. It does not check the header's length, the mood of the subject, the blank
line before a body, or a work-in-progress commit, and every repository that copies it copies its gaps. Its YAML parser
reads one indentation and one list form, so a valid edit to the manifest can silently empty a list. REL-06 already
reads the manifest to confirm that a release pull request's title passes the rules, so the file's location is part of
what a release requirement checks.

[committed](https://github.com/crate-ci/committed) is a maintained, single-binary commit linter (MIT or Apache-2.0)
that reads its rules from one TOML file and checks a message file, standard input, a commit or a range. It checks the
Conventional Commit header, the allowed types and scopes, the header's length, the imperative mood, trailing
punctuation, the blank line after the header, and `WIP` and `fixup!` commits. It cannot require a scope or a
lowercase subject.

## Decision

We will check every commit message and pull request title with committed, against `.config/commits/committed.toml`,
and publish that as the commit conventions: topic `commits`, family `COMMIT`, convention
[EC-0035](../../engineering-conventions/definitions/conventions/commits/commit-messages.md).

- **One file holds the rules.** `.config/commits/committed.toml` sets `style = "conventional"`, the repository's
  `allowed_types` and `allowed_scopes`, a header of at most 72 columns, an imperative subject without trailing
  punctuation, and no `WIP` commits (COMMIT-01). It is the one list of types and scopes: the hook, the title check and
  REL-06 read it, and `.github/conventional-commits.yaml` is removed (COMMIT-06). It sits in a concern directory under
  `.config/`, like every tool's configuration ([EC-0011](../../engineering-conventions/definitions/conventions/configuration/tool-configuration.md),
  CONF-07), and every caller passes it with `--config`.
- **committed is pinned in mise** (COMMIT-02), with the `github:` backend: aqua's registry entry has no Linux arm64
  asset, which the dev container needs on Apple silicon.
- **It runs twice.** Lefthook's `commit-msg` hook runs `committed --config .config/commits/committed.toml
  --commit-file {1}`, skipping merges and rebases (COMMIT-03). A pull request workflow pipes the title, from an
  environment variable, into `committed --commit-file -`, and keeps `action-semantic-pull-request` only for what
  committed cannot do: `requireScope: true` and `subjectPattern: ^[a-z].+$`, with its `types` and `scopes` read from
  the TOML file (COMMIT-04).
- **The rules a message passes are committed's** (COMMIT-05, delegated): the conventions runner does not lint history,
  so a failing message is reported where it is written and where it is titled.
- **A breaking change is marked as Conventional Commits 1.0.0 allows.** A `!` before the colon is enough; a
  `BREAKING CHANGE:` footer is not also required.

The prefix `COMMIT` collides with no upstream family: `musher-dev/development-container`'s `CMT` rules govern code
comments, not commits, and are not adopted here ([decision 0016](0016-adopted-rules-get-new-families.md)).

## Consequences

### Positive

- The header length, the mood, the blank line and `WIP` commits are checked where they were not, in every repository
  the same way.
- No repository maintains a commit-message script, and the rules are configuration a reviewer reads.
- The types and scopes live in one file in every repository, beside every other tool's configuration.

### Negative

- Every repository migrates: a new file, a pin, a hook and a workflow step, and REL-06 now reads the new file, so a
  repository that only moved halfway sees findings in both families until it finishes.
- Two tools still check the title, because committed cannot require a scope or a lowercase subject.
- A `git revert` message (`Revert "…"`) fails the hook, and is reworded with a type before it is committed.

### Neutral

- `fixup!` commits are allowed, because they are squashed before a merge.
- committed checks the length of the header up to its last word, so the last word may run past column 72.

## Enforcement

- COMMIT-01 to COMMIT-04 and COMMIT-06 are conftest checks in `conventions.checks.commits.messages`, each with a
  fixture that fires and a near-miss that stays quiet; they fail on a missing or weakened configuration, a missing pin,
  a hook or workflow that does not run committed on the message, and a leftover manifest.
- COMMIT-05 is delegated to committed, which fails the commit-msg hook and `Validate Pull Request / Title`.
- REL-06 reports a `.config/commits/committed.toml` whose lists leave out the `chore` type or the `release` scope.
- This repository runs all of it on itself: `task conventions:self` reports no finding.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Keep the Bash script and the YAML manifest | What this repository and the platform run today | rejected: checks the header's shape only, and each repository maintains its own copy |
| commitlint | The JavaScript commit linter | rejected: needs Node and an npm dependency tree in repositories that have neither |
| cocogitto (`cog verify`) | A Rust Conventional Commits toolbox | rejected: also bumps versions and writes changelogs, which release-please owns |
| committed | A Rust binary with one TOML configuration | **chosen** |
| committed alone on the title | Drop action-semantic-pull-request | rejected: committed cannot require a scope or a lowercase subject |
| `.config/committed.toml` | The configuration at the top of `.config/` | rejected: CONF-07 keeps the top of `.config/` to lefthook's files and the index |
| Require a `BREAKING CHANGE:` footer with `!` | Both markers on a breaking change | rejected: Conventional Commits 1.0.0 accepts `!` alone, and release-please reads it |

## References

- [committed: reference](https://github.com/crate-ci/committed/blob/main/docs/reference.md)
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
- [amannn/action-semantic-pull-request](https://github.com/amannn/action-semantic-pull-request)
- [Decision 0005: Status, severity and versioning](0005-status-severity-and-versioning.md)
- [Decision 0016: Rules adopted from other repositories get new families](0016-adopted-rules-get-new-families.md)
- [Decision 0017: Releases from drafts](0017-releases-from-drafts.md)
