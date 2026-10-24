---
title: GitHub judges whether CODEOWNERS owners resolve, through its own command
date: 2026-10-24
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0041 — GitHub judges whether CODEOWNERS owners resolve, through its own command

## Context

A CODEOWNERS line protects nothing when GitHub cannot use its owner: a user or team that does not exist, a renamed
team, a person who left, or an owner without explicit write access to the repository. GitHub skips the line without a
failing check, so a ruleset that requires a code owner's review stops asking anyone about those paths. COMM-03,
COMM-04 and COMM-10 check the file's place, syntax and paths offline, and COMM-09 bans the catch-all, but whether an
owner resolves depends on the organization's people and teams, which change without a commit
([issue #118](https://github.com/musher-dev/engineering-conventions/issues/118)).

GitHub already answers the question. `GET /repos/{owner}/{repo}/codeowners/errors`, with an optional `ref`, lists
every line it could not apply with the line number and the reason, such as `Unknown owner on line 3: make sure @mona
exists and has write access to the repository`. It is the authority: it reports exactly what GitHub will honour when
it requests reviewers.

`conventions check` is offline by design. Its findings depend on the repository and the date alone
([decision 0015](0015-the-runner-reads-what-conftest-cannot-select.md)), and consumers need only conftest, jq and Vale
([decision 0001](0001-validation-engines.md)). It also has no token in a fixture, a fork or an air-gapped run. The
launcher already has one command that reaches the network on request: `conventions waivers --check-tracking` asks the
GitHub CLI for each tracking issue's state.

## Decision

We will check that every CODEOWNERS owner resolves by asking GitHub, in a command of its own:

- **COMM-11**, *GitHub reports no errors in CODEOWNERS*, is a `delegated` requirement (`tool: gh`, `check: conventions
  codeowners`). No new engine is added: GitHub's API is the tool, as Spectral and hadolint are for OAS-01 and
  IMAGE-06.
- **`conventions codeowners [--repository OWNER/NAME] [--ref REF] [--fail-on error|warning] [--output text|json]`**
  in `bin/conventions` calls the endpoint through `gh api`. The repository is `--repository`, else
  `GITHUB_REPOSITORY`, else the origin remote. The file is the one at `--ref`, else on the default branch. It first
  reads the repository itself, so a repository it cannot read is an error, not a repository without a CODEOWNERS:
  GitHub answers 404 to both. A repository without one gets no findings, since COMM-08 reports that offline.
- **Findings come in the shape of `conventions check`.** `bin/codeowners.jq` turns GitHub's errors into conftest's
  result shape, one COMM-11 finding per error with its line and GitHub's reason, at the requirement's severity and
  with its diagnostic URL. `bin/report.jq` renders them, so the text report, `--output json` and `--fail-on` behave
  as they do for `conventions check`.
- **COMM-11 is not waivable** (`waivable: false`). A waiver suppresses findings `conventions check` produces, and this
  command applies none, so a waiver naming COMM-11 would only ever be stale. ADOPT-06 reports it as one that cannot
  be waived.
- **This repository runs it in CI**, in its own `Repository / Code Owners` job in `Validate`, against the pull
  request's head commit, with `contents: read` and the job's token. The job is not eligible for a pass marker
  ([decision 0040](0040-a-job-skips-on-proof-of-an-identical-passing-run.md)): GitHub's answer changes when a team
  does, with identical inputs. `task conventions:codeowners` runs the same command locally and skips with a note,
  outside CI only, when `gh` is not signed in.

## Consequences

### Positive

- A renamed team or a departed owner is caught on the next pull request, by the system that decides reviewers,
  rather than when a change merges with no code owner's review.
- No parser or organization data is restated here. GitHub's answer is the check.
- A consumer reads the result as it reads every other finding, by requirement ID and URL.

### Negative

- The command needs the network, `gh` and a token with read access to the repository. A run without them cannot
  check COMM-11.
- The answer depends on state outside the repository, so the same commit can pass today and fail tomorrow. That is
  the failure being caught, but the job cannot be cached.
- A profile that raises COMM-11's severity is not applied: the command reports at the requirement's own severity, and
  applies no staged adoption.

### Neutral

- `conventions check` stays offline, and its findings still depend on the repository and the date alone.
- The command does not judge syntax again. GitHub's errors include lines it cannot parse, which COMM-04 also reports
  offline.

## Enforcement

- `tests/test_launcher.py` runs `conventions codeowners` against a stand-in `gh` and checks the findings, the JSON
  output, `--fail-on`, the `ref` passed to the API, a repository without a CODEOWNERS and a repository that cannot be
  read. No test calls GitHub.
- `Validate / Repository / Code Owners` runs it on every pull request, push to `main` and merge-group run, and fails
  on any finding (`--fail-on warning`).
- `tests/test_generate.py` checks that COMM-09 and COMM-11 are marked not waivable in the index.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Reach GitHub from `conventions check` | Ask the API during the offline check, when a token is present | rejected: the check's findings would depend on the network and the token, and a fixture could not reproduce them (decision 0015) |
| Resolve owners offline | Ship the organization's users and teams with the release, and match owners against them | rejected: restates data another repository owns, is stale by the next membership change, and cannot see write access |
| Document the `gh api` call only | Tell each repository to run the endpoint itself, as COMM-09 did in 0.9.2 | rejected: every repository writes its own parsing and failure condition, and nothing cites a requirement ID |
| A delegated requirement with its own command | `conventions codeowners` asks GitHub and reports in the standard shape | **chosen** |

## References

- [Issue #118: a shared CODEOWNERS check](https://github.com/musher-dev/engineering-conventions/issues/118)
- [GitHub REST API: List CODEOWNERS errors](https://docs.github.com/en/rest/repos/repos#list-codeowners-errors)
- [EC-0036 Community files](../../engineering-conventions/definitions/conventions/community-files/community-files.md),
  COMM-08 to COMM-11
- [Decision 0001: Validation engines](0001-validation-engines.md)
- [Decision 0015: The runner reads what conftest cannot select](0015-the-runner-reads-what-conftest-cannot-select.md)
