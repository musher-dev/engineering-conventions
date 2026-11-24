---
title: A release another repository deploys carries its change manifest, written while it is a draft
date: 2026-11-24
status: proposed
deciders: ["@justinmerrell"]
supersedes: []
---

# 0045 — A release another repository deploys carries its change manifest, written while it is a draft

## Context

Musher is adopting the [DORA metrics](https://dora.dev/guides/dora-metrics/), starting with change lead time: the
time from a change's first commit to the end of the production deployment that delivered it. DORA measures it per
change, here per merged pull request, and reports its median and 90th percentile per service.

A change to a service crosses two repositories. In the repository that builds the service, the pull request merges,
release-please's release pull request merges, `release.yml` cuts a draft release and publishes it
([decision 0017](0017-releases-from-drafts.md)). In `musher-dev/platform`, which deploys it, the release is pinned,
deployed to staging, taken into a platform release and deployed to production. Only the deploying repository knows when
production finished; only the releasing repository's history says which pull requests a release carried, and that
answer takes release-please's rules to read:

- A release covers the commits since the package's previous tag that change the package's path. A repository with
  several packages, such as one that releases two documentation sites, tags each `<component>/vX.Y.Z`, and a commit to
  one site is no change to the other.
- The release notes list only the commits whose type a section shows (`feat`, `fix`, `perf` and breaking changes), by
  a link to the squash commit. One squash commit can appear twice, and a subject can lack its `(#N)`.
- release-please reuses its release pull request and refreshes it by force-pushing, so the pull request's creation
  can predate a change it carries by hours.
- The first commit of a pull request is not in any release record, and its history can be rewritten after it opens.

The releasing repository's half has to be fixed when the release is cut. A published release is immutable
([REL-17](../../engineering-conventions/definitions/conventions/releases/release-workflows.md#rel-17)), so nothing can
be added to it later, and history read later can differ from history at release time: branches are deleted, titles
edited, tags moved before the ruleset existed.

## Decision

**A release whose artifact another repository deploys carries a change manifest, `changes.json`, in its contracts
bundle, written by `conventions release changes` while the release is still a draft.**

- **When.** The release job runs it after release-please has cut the draft and before the bundle's `release.json` is
  written, so the record lists the manifest with its digest, and before the job publishes the draft
  ([REL-19](../../engineering-conventions/definitions/conventions/releases/release-workflows.md#rel-19)). It cannot run
  later: a published release takes no new asset and no changed bundle.
- **What it holds.** The format is
  [`checks/schemas/change-manifest.schema.json`](../../engineering-conventions/checks/schemas/change-manifest.schema.json),
  a file of its own because `release-record.schema.json` admits no other keys. For the release: its repository,
  package path, version, tag, previous tag and commit, and the release pull request, with its creation, merge, merge
  commit and every refresh. For each pull request whose merge commit the release covers: its number, URL and title, the
  Conventional Commits type and breaking mark of its squash commit, who opened it by kind only (`human`, `agent`,
  `dependency-bot` or `automation`, never a login), its creation, merge and merge commit, its first commit (the
  earliest author date, marked `rewritten` when that is after the pull request opened and `truncated` when GitHub lists
  only 250 of its commits), whether the version's changelog section lists it, and when the release pull request first
  carried it.
- **How it reads a release.** The package is the one in `.github/release-please/config.json` at the tag whose tag form
  the tag has. The previous tag is the package's highest lower `X.Y.Z` tag; a first release starts after the
  configuration's `bootstrap-sha`, as release-please does, or else at the start of the history. The commits are the
  comparison of the two. A commit's change is the pull request that merged as it, carried when the commit belongs to
  the package as release-please decides it: by the pull request's files, or by the commit's own when there is no pull
  request or GitHub lists more than a page of its files; one of them is under the package's path, or there are none,
  since release-please counts an empty change in every package. A pull request whose changes reached the branch
  before it merged changes no file, and neither does its squash commit. The one that merged as the tagged commit is
  the release pull request, never a change. A pull
  request is listed when an entry of the version's section links its squash commit, or, when an entry's links resolve
  to none, by the entry's last `#N` that is a pull request of the release; a breaking-change note without a commit link
  repeats a linked entry and is skipped. A change was first carried when the release pull request opened or was next
  refreshed after the change merged, or else at the change's own merge.
- **Where it runs.** The command reads GitHub at the tag through the GitHub CLI, with no clone, so the deploying
  repository runs the same command, with `--repository`, for a release cut before the manifest existed, and gets the
  same answer the release job would have.
- **What it leaves out.** Everything from the release's publication on (the pin, staging, the platform release and
  production) belongs to the deploying repository, which joins it with the manifest.

## Consequences

### Positive

- The deploying repository measures each change from its first commit without restating any releasing repository's
  release rules; one implementation, tested against recorded releases, reads every releasing repository the same way.
- The releasing repository's half is fixed and checksummed with the bundle when the release is cut, so later edits to
  history, titles or branches do not change what was measured.
- An agent's pull requests can be compared with a person's by kind, without recording who opened either.
- Every pull request is kept with its `listed` mark, so the measure can widen from releasable changes to every change
  without a new format.

### Negative

- Each such release job runs one more step, with a token that reads the repository's contents and pull requests, and
  the step asks GitHub once per commit the release covers. A call that fails for a reason that can pass (a network
  error, a 5xx, a 429, a secondary rate limit or GitHub's GraphQL timeout) is tried up to three more times, after 2, 4
  and 8 seconds, so a release job or a backfill can take a few seconds longer.
- What it reports is what GitHub associates: a commit pushed without a pull request is no change, and the first commit
  of a pull request with more than 250 commits may be missing, which the manifest marks.
- `listed` depends on the links release-please writes into its notes; a release whose notes were edited by hand is
  read as edited.

### Neutral

- Releases cut before a repository adopts the command carry no manifest; the deploying repository writes one with the
  same command when it needs it.
- The release job of a repository whose artifact nothing deploys does not run it.

## Enforcement

- `tests/test_release.py` runs the command against ten releases recorded from GitHub, against a stand-in for `gh`,
  and holds each manifest to the schema and to its committed expected copy; edited recordings cover the rules no
  recorded release exercises, and failures the stand-in plans cover the retries. `tests/test_schemas.py` holds the
  schema to valid and invalid manifests, and
  `bundle:verify` fails a bundle without `bin/changes.jq`.
- That a deployed repository's release job writes the manifest before building its bundle is `review-only` until a
  requirement checks release workflows for it: a reviewer looks for the step, and for `changes.json` among the files of
  an interface the bundle delivers.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| A script in the deploying repository | `musher-dev/platform` reads each releasing repository's tags, notes and pull requests itself | rejected: the rules that say what a release carries belong to every releasing repository, a second deployer would copy them, and nothing fixes the releasing repository's half at release time |
| Reconstruct everything when production finishes | No manifest; the deploying repository rebuilds each delivered release's changes after it deploys | rejected as the rule: it reads history that may have changed since the release, and puts a burst of API calls behind every deploy; kept as the fallback for releases without a manifest, through the same command |
| A release asset of its own | `changes.json` attached beside the bundle | rejected: the bundle's `release.json` already lists each file a consumer reads with its digest, and the deploying repository already fetches the bundle |
| The manifest in the contracts bundle, written while the release is a draft | `conventions release changes` in the release job | **chosen** |

## References

- [DORA: software delivery performance metrics](https://dora.dev/guides/dora-metrics/)
- [Decision 0017: Repositories release with release-please from a draft](0017-releases-from-drafts.md)
- [Decision 0022: Interfaces and dependencies](0022-interfaces-and-dependencies.md)
- [EC-0031 Publishing interfaces](../../engineering-conventions/definitions/conventions/interfaces/publishing-interfaces.md),
  the release record
- [release-please: the manifest releaser](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md)
- [GitHub GraphQL API: `associatedPullRequests` and `HeadRefForcePushedEvent`](https://docs.github.com/en/graphql/reference/objects#headrefforcepushedevent)
- [GitHub REST API: compare two commits](https://docs.github.com/en/rest/commits/commits#compare-two-commits)
