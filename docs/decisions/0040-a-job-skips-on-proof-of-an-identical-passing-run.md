---
title: A job skips on proof of an identical passing run, behind a kill switch
date: 2026-10-24
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0040 — A job skips on proof of an identical passing run, behind a kill switch

## Context

Every push to a pull request reruns every job in `validate.yml` except the dev container build, which `detect`
already scopes to its own inputs. Most of those reruns re-prove a result nothing has changed: a pull request that
edits one Markdown file still lints the Rego rules, runs their tests and rebuilds the release bundle. Nothing records
that a job already passed on the exact files it reads, so nothing can skip it.

`musher-dev/platform` solved the same problem with pass markers. A job that passes saves a tiny Actions cache entry
whose key hashes the inputs it read. A later run of the same pull request finds the entry, re-proves it against the
API, and skips the job only when every check holds. A repository variable turns the mechanism off. This repository
takes that design, scaled down to one workflow and one shell script.

The risk is the shape GHA-14 exists to prevent: a gate that can skip itself reports green forever. A skip is
therefore never trusted from a job's own say-so. It needs a marker that CI wrote and that `detect` proves against
the run that wrote it, and `Validate / Required` accepts it only for a job `detect` named.

## Decision

**A job in `validate.yml` whose inputs are identical to those of a verified run in which it passed may skip. CI
writes the proof, CI reads it, and the mechanism is off unless the repository variable `CI_PASS_MARKERS` is `on`.**

- **The key.** `.github/scripts/ci-pass.sh key <job>` is a sha256 over a format version, the job ID, the runner
  OS and the git object ID, at `HEAD`, of every path the job reads. The script holds the one table of eligible jobs
  and their paths. Every job also reads `.config/mise`, `validate.yml`, `.github/actions`, `.github/scripts`,
  `Taskfile.yml` and `taskfiles`. A git object ID is a content hash, so an edit anywhere under a listed directory
  changes the key. On a pull request the checkout is the merge commit, so a change that lands on `main` changes
  the key too.
- **The record.** Each eligible job ends with `.github/actions/sync-pass-marker`. It runs only when every earlier
  step succeeded, and only on a same-repository `pull_request` or a `push` to `main`. It saves a cache entry keyed
  `ci-pass-<key>-<run_id>-<run_attempt>`. The run ID and attempt are in the key because the caches API lists keys
  and never contents. A failed, cancelled, fork or merge-group run writes nothing. The action's name follows
  GHA-20: `sync` is the token for an action that changes state outside the run, here the repository's Actions
  cache.
- **The claim.** On a same-repository `pull_request`, and only with the switch on, `detect` gains `actions: read`
  and runs `ci-pass.sh prove`. It lists the `ci-pass-` entries on this pull request's ref and on `refs/heads/main`.
  For each eligible job, it accepts the newest marker that passes every check:
  1. the marker's key is the one this checkout recomputes;
  2. its cache entry is on this pull request's ref, or on `main`;
  3. the recorded run is a run of `validate.yml` in this repository, with its head in this repository. A marker on
     this pull request's ref must come from a `pull_request` run for this branch. A marker on `main` must come from
     a `push` to `main`;
  4. that run has the recorded attempt, and the job of that name concluded `success` in it;
  5. `.github/workflows` and `.github/actions` at the recorded run's head equal this pull request head's. A
     workflow edited to write a marker for a later tree, then reverted, cannot vouch for the revert.

  `detect` outputs the jobs it proved as `passed_jobs`, a JSON array. With the switch off, on any other event, or
  when the caches cannot be listed, the array is `[]` and every job runs. A marker that cannot be read is refused
  with a warning; it never fails `detect`.
- **The skip.** An eligible job needs `detect` and runs unless it is in `passed_jobs`. If `detect` fails, the
  eligible jobs skip and `Validate / Required` fails, because `detect` did not succeed.
- **The aggregate.** `Validate / Required` accepts `skipped` for a job only when `detect` succeeded and listed the
  job in `passed_jobs`. This is its second written exception, beside the dev container's.
- **Markers are never read on `push`, `merge_group` or a fork's pull request.** A push to `main` and a merge-group
  run prove the default branch in full.

### Eligible jobs

| Job | Reads | What a skip needs |
| --- | --- | --- |
| `repository_lint` | the whole tree: the spelling check reads every file | an identical tree |
| `checks` | `.config`, `engineering-conventions/checks`, the OpenAPI fixtures | no change to the rules, the index or the tool configs |
| `content` | `.config`, `.github`, `.repo`, `docs`, `engineering-conventions` and the root Markdown that the prose lint reads | no change to the content, the schemas, the generator or the prose |
| `conventions` | the whole tree: `conventions check .` inventories every file | an identical tree |
| `bundle` | `engineering-conventions`, `version.txt` | no change to the product directory |

`repository_lint` and `conventions` read the whole tree, so they skip only when the tree is identical: a rerun, or
a push that changes nothing they read. Their table rows say so instead of naming a narrower set that would miss a
file. A path in a row widens when its job's tasks start reading more.

### Excluded jobs

- **`repository_secrets`** scans the history, not the tree. Two commits with identical trees can carry different
  histories.
- **`workflows`** runs zizmor's online audits, whose verdict moves with GitHub's advisories and the upstream
  repositories rather than with this tree.
- **`cli`** checks the content invariants against the base commit, so its verdict depends on more than `HEAD`.
- **`devcontainer`** is already scoped to its inputs by `detect`.

### The security model

- **Only CI writes markers, and only CI reads them.** A local result never counts. Task's own up-to-date check
  is a developer convenience and proves nothing to CI.
- **The pull request head is the gate.** No merge queue is configured here, so the commit that merges is the one
  its pull request's last run checked. A skip on that run rests on a proved marker, and a push to `main` reruns
  every job.
- **Accepted residual risk.** Code that runs inside a job of a pull request, such as a test or a task, can write a
  cache entry under that pull request's ref. It could forge a marker for a later tree of the same pull request that
  names an earlier run in which the job passed. Check 5 stops the edit-then-revert trick only for `.github/`. The
  risk is bounded. A forged marker works only within the pull request whose ref wrote it. Only same-repository
  authors can write one, and they already have write access. The push to `main` reruns every job. The kill switch
  is the response if it is ever abused.

### Trying it

The variable merges unset, so merging this changes nothing. To trial it, a repository administrator sets the
repository variable `CI_PASS_MARKERS` to `on` (Settings, Secrets and variables, Actions, Variables) and opens a trial
pull request:

1. **Push 1.** Every job runs, and each eligible job's last step saves a `ci-pass-` cache entry.
2. **Push 2, changing only a file under `docs/`.** `detect` lists `checks` and `bundle` in `passed_jobs`. They skip,
   the aggregate prints "inputs identical to a verified passing run", and `Validate / Required` is green.
   `repository_lint`, `content` and `conventions` run.
3. **Push 3, touching `.config/mise/`.** Every key changes, so every job runs.
4. **A forged marker.** Edit `validate.yml` in one push, revert it in the next. The marker written by the edited
   run is refused by check 5, with a warning that names it.

Setting the variable to anything but `on`, or deleting it, turns the mechanism off on the next run. Markers already
written are then ignored and expire with the rest of the cache.

## Consequences

### Positive

- A pull request that changes only prose stops re-running the Rego tests and the bundle build on every push.
- Every skip names its reason in the aggregate's log, and rests on a marker `detect` proved against the API.
- The kill switch returns the workflow to its earlier behaviour without a commit.

### Negative

- The five eligible jobs now wait for `detect`, which adds its run time before they start.
- `detect` makes API calls on every pull request run while the switch is on: one listing per ref, and up to three
  reads per marker it proves.
- A table of input paths can fall behind what a job's tasks read. A missing path lets a job skip a change it would
  have failed. The rows are kept wide for that reason, and a reviewer of a change to a job's tasks checks its row.
- The residual forgery risk above.

### Neutral

- `.config/actions/actionlint.yaml` declares `CI_PASS_MARKERS`, and Dependabot updates the new action's pins.
- An attestation of each passing run on `main`, for audit only, is a possible follow-up and not part of this pilot.

## Enforcement

- **`Validate / Required`** fails when an eligible job skipped and `detect` did not succeed or did not list it.
  Any other skip fails as before.
- **`ci-pass.sh prove`** refuses a marker that fails any of the five checks, and claims nothing when the caches
  cannot be listed.
- **`task lint:actions lint:actions:security`** and **`task conventions:self`** hold the new workflow steps and the
  action to the GitHub Actions conventions.
- **review-only**: that each row of the job table in `ci-pass.sh` names every path its job's tasks read, and that a
  new job is added to the table only when its verdict depends on nothing but the tree.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| A | Keep rerunning every job on every push | rejected: re-proves unchanged results on every push |
| B | Workflow-level `paths` filters | rejected: a workflow that emits a required check cannot have one (GHA-32) |
| C | Scope each job by a `detect` diff, as the dev container is | rejected: a diff against the base reruns every job the pull request ever touched, on every push |
| D | Trust Task's local up-to-date check, or a result a developer reports | rejected: a local result is not proof |
| E | Pass markers keyed on input trees, proved by `detect`, behind a kill switch | **chosen** |

## References

- `musher-dev/platform`'s pass markers, whose design this follows.
- [GHA-14](../../engineering-conventions/definitions/conventions/github-actions/jobs-and-steps.md#gha-14) and
  [GHA-32](../../engineering-conventions/definitions/conventions/github-actions/execution-hygiene.md#gha-32).
- `.github/scripts/ci-pass.sh`, `.github/actions/sync-pass-marker/action.yml`, `.github/workflows/validate.yml`.
