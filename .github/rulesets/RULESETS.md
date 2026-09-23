# Repository Rulesets

Version-controlled GitHub Repository Rulesets for
`musher-dev/engineering-conventions`. The shape is the one musher-dev/host-agent
and musher-dev/host-config commit; this file records what they protect here and
how to apply them.

| File | GitHub Ruleset | Scope |
| --- | --- | --- |
| `main-branch.json` | `Main Branch` | The default branch: PR required, squash-only, linear history, code-owner review, the two required checks, deletion and force-push blocked |
| `release-tags.json` | `Release Tags` | Release tags (`v*`): creation, deletion and non-fast-forward updates blocked for everyone but the musher-automation App |

Org-level rulesets may also apply. Every rule that actually binds this
repository is listed at <https://github.com/musher-dev/engineering-conventions/checks>.

## Why not the org `pr-workflow` ruleset

The org `pr-workflow` ruleset requires one approval on the repositories it
includes, and rulesets aggregate most-restrictive. Including this repository
would override `required_approving_review_count: 0` below and leave the
steward's own PRs waiting for an approval nobody else is positioned to give.
Keep this repository off its include list; the code-owner gate below is the
review requirement.

## The review gate

`main-branch.json` pairs `required_approving_review_count: 0` with
`require_code_owner_review: true`. `.github/CODEOWNERS` is a single `*` line, so
every PR is codeowned: a PR from anyone other than the owner waits for the
owner's approval, and the owner's own PRs merge on green checks, because GitHub
waives the code-owner requirement for the PR author.
`require_last_push_approval` MUST stay `false`: combined with zero approvals it
makes a PR unmergeable.

## Required checks

There are two, and both are literal check-run names:

- `Validate / Required`: the aggregate job in `.github/workflows/validate.yml`.
  It needs every other `Validate` job and fails unless each succeeded, so a new
  gate joins the aggregate rather than becoming a third context here (GHA-14,
  GHA-16).
- `Validate Pull Request / Title`: the PR-title job in
  `.github/workflows/validate-pull-request.yml`. It is a workflow of its own
  because it re-runs on an `edited` PR, which must not re-run or cancel
  `Validate`.

A job's `name:` must be the full context string. GitHub does not prefix a job's
check-run name with its workflow's name, so a job named `Required` reports as
`Required` and the context never resolves. GHA-15 checks that every context
listed here is emitted by some job.

`integration_id: 15368` is the GitHub Actions app.

## Who may create a release tag

A `vX.Y.Z` tag is what consumers pin, and what every diagnostic URL a released
bundle prints points at, so a tag must never move or disappear.
`release-tags.json` blocks tag creation as well as deletion and force-updates,
and exempts exactly one actor:

- `Integration` `4691573`, `bypass_mode: always`: the org-owned
  **musher-automation** GitHub App. `release.yml` creates the tag and its GitHub
  Release with that App's installation token when the release PR merges. A tag
  created with the default `GITHUB_TOKEN` would start no workflow, so `Publish`
  would never attach the bundle; that is why the App, and not GitHub Actions, is
  the bypass actor.

There is no `OrganizationAdmin` bypass: an administrator cannot push a `v*` tag
by hand either. Cutting a release outside `release.yml` means changing this
ruleset first.

## Applying

The default `GITHUB_TOKEN` cannot write rulesets, so there is no apply
workflow. Use a fine-grained PAT with **Administration: Write** on this
repository, or an org-admin `gh` login.

First-time apply:

```bash
gh api --method POST /repos/musher-dev/engineering-conventions/rulesets \
  --input .github/rulesets/main-branch.json

gh api --method POST /repos/musher-dev/engineering-conventions/rulesets \
  --input .github/rulesets/release-tags.json
```

Updating an existing ruleset:

```bash
RULESET_ID=$(gh api /repos/musher-dev/engineering-conventions/rulesets \
  --jq '.[] | select(.name == "Main Branch") | .id')

gh api --method PUT "/repos/musher-dev/engineering-conventions/rulesets/$RULESET_ID" \
  --input .github/rulesets/main-branch.json
```

After applying, confirm that no classic branch protection is left on `main`.
Classic rules aggregate with rulesets. `404` is the answer you want:

```bash
gh api /repos/musher-dev/engineering-conventions/branches/main/protection
```

## Detecting drift

Nothing here detects drift automatically: the default token lacks
`administration: read`. Compare each live ruleset with its committed file by
hand:

```bash
for pair in "Main Branch=main-branch.json" "Release Tags=release-tags.json"; do
  RULESET_ID=$(gh api /repos/musher-dev/engineering-conventions/rulesets \
    --jq ".[] | select(.name == \"${pair%%=*}\") | .id")
  diff -u \
    <(jq -S . ".github/rulesets/${pair#*=}") \
    <(gh api "/repos/musher-dev/engineering-conventions/rulesets/$RULESET_ID" \
        --jq '{name, target, enforcement, bypass_actors, conditions, rules}' | jq -S .)
done
```

A `GET` returns server fields (`id`, `node_id`, `source`, `_links`,
timestamps). Never commit them back.
