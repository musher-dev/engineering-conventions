# Branch Rulesets

Branch protection for this repository, committed as JSON so it is reviewable
and restorable rather than living only in the GitHub UI.

| File | Applies to | Effect |
| --- | --- | --- |
| `main-branch.json` | The default branch | No deletion, no force-push, PR with one approval and squash merge, every CI job green and up to date |

## Applying a ruleset

These files are **not** applied automatically — nothing in CI has permission to
change branch protection, by design. Import one from the repository settings
(Settings → Rules → Rulesets → New ruleset → Import a ruleset), or with a token
carrying `administration:write`:

```bash
gh api -X POST repos/musher-dev/development-container/rulesets \
  --input .github/rulesets/main-branch.json
```

To update an existing ruleset, `PUT` to `.../rulesets/<id>` instead.

## Detecting drift

`repo rulesets check` validates the committed file's **shape** and its
agreement with CI. It deliberately does not diff against live GitHub state:
reading a repository's rulesets requires `administration:read`, which the
default `GITHUB_TOKEN` does not have, so a workflow-based drift detector would
need a long-lived personal access token or fail open. Compare manually when it
matters:

```bash
gh api repos/musher-dev/development-container/rulesets --jq '.[] | {id, name}'
gh api repos/musher-dev/development-container/rulesets/<id> > /tmp/live.json
diff <(jq -S . .github/rulesets/main-branch.json) <(jq -S . /tmp/live.json)
```

## What is enforced automatically

`repo rulesets check` runs in pre-commit and in the `Repo Structure` CI job:

| Code | Fails when |
| --- | --- |
| `RS-01` | A ruleset file is not valid JSON |
| `RS-02` | A ruleset is missing a required top-level key |
| `RS-03` | A required status check names a job no CI workflow produces |
| `RS-04` | A CI job exists that no ruleset requires |

`RS-03` is the one that matters most. A required status check is matched by the
job's **display name**, so renaming a job in `validate.yaml` without updating
this directory leaves every pull request waiting forever on a check that can
never report — and unblocking it needs admin access at exactly the moment the
repository has become unmergeable.

`RS-04` is the mirror: a job that runs but is not required is advisory, and a
red run can still merge. If a job is genuinely meant to be non-blocking, record
it in `ADVISORY_JOBS` in
[`check.py`](../../.repo/governance/policies/rulesets/check.py) with a
reason instead of leaving the gap silent.

## Consuming projects

A repository scaffolded from this template gets these files but **not** the
protection — rulesets are repository state, not repository content. Import the
ruleset once after creating the repo, then adjust the required status checks to
match whatever CI that project actually runs.
