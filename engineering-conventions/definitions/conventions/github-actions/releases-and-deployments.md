---
id: EC-0023
title: Releases and deployments
summary: >-
  A force push names the commit it replaces, release-please runs with a token
  whose events start workflows, the last jobs of a release, publish or deploy
  workflow cannot be skipped into a green run, and nothing that acts on
  production runs on a push to a branch. A job's environment, a secret's
  name and a GitHub App's credentials follow one form, and a deploy job
  records what it deployed in GitHub's linked artifacts.
status: draft
topic: github-actions
applies_to:
  paths:
    - .github/workflows/*.yml
    - .github/workflows/*.yaml
    - .github/actions/*/action.yml
    - .github/actions/*/action.yaml
created: 2026-09-28
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
implementations:
  - repo: musher-dev/platform
    check: CI-09
    mode: blocking
  - repo: musher-dev/platform
    check: CI-10
    mode: blocking
  - repo: musher-dev/platform
    check: DL-18
    mode: blocking
  - repo: musher-dev/platform
    check: DL-21
    mode: blocking
references:
  - title: "Git: git-push --force-with-lease"
    url: https://git-scm.com/docs/git-push#Documentation/git-push.txt---force-with-leaseltrefnamegtltexpectgt
  - title: "GitHub Docs: Triggering a workflow from a workflow"
    url: https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/triggering-a-workflow#triggering-a-workflow-from-a-workflow
  - title: "GitHub Docs: Status check functions"
    url: https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/evaluate-expressions-in-workflows-and-actions#status-check-functions
  - title: "release-please-action"
    url: https://github.com/googleapis/release-please-action
  - title: "GitHub Docs: Managing environments for deployment"
    url: https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments
  - title: "GitHub Docs: Linked artifacts"
    url: https://docs.github.com/en/code-security/concepts/supply-chain-security/linked-artifacts
  - title: "GitHub REST API: Artifact metadata"
    url: https://docs.github.com/en/rest/orgs/artifact-metadata
  - title: "actions/create-github-app-token"
    url: https://github.com/actions/create-github-app-token
requirements:
  - id: GHA-46
    title: A force push leases on the commit it expects to replace
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.releases_and_deployments
    aliases: ["platform:CI-09"]
  - id: GHA-47
    title: release-please runs with a token other than the default GITHUB_TOKEN
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.releases_and_deployments
    aliases: ["platform:CI-10a"]
  - id: GHA-48
    title: The last jobs of a release, publish or deploy workflow run unless the run is cancelled
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.releases_and_deployments
    aliases: ["platform:DL-18"]
  - id: GHA-49
    title: A workflow that acts on production does not run on a push to a branch
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.releases_and_deployments
    aliases: ["platform:DL-21"]
  - id: GHA-50
    title: A job's GitHub environment that names a deployment environment uses its name
    status: proposed
    severity: warning
    since: 0.9.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.releases_and_deployments
  - id: GHA-51
    title: A secret or variable's name carries no deployment environment
    status: proposed
    severity: warning
    since: 0.9.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.releases_and_deployments
  - id: GHA-52
    title: A GitHub App's credentials are a client-ID variable and a private-key secret
    status: proposed
    severity: warning
    since: 0.9.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.releases_and_deployments
  - id: GHA-53
    title: A deploy job records the deployment in GitHub's linked artifacts
    status: proposed
    severity: warning
    since: 0.9.0
    validation:
      engine: conftest
      package: conventions.checks.github_actions.releases_and_deployments
---

# Releases and deployments

Release and deploy workflows fail differently from validation workflows. A validation failure is a red check on a
pull request; a release or deploy failure is often a green run that did not do what it reports. A push that
overwrote someone's commit, a release pull request whose checks never start, a deploy job that was skipped, a probe
that tested the previous release: each of these reads as success. GHA-46 to GHA-49 close those four gaps.

A deploy also has to be findable afterwards. GHA-50 to GHA-53 make each one say where it went in the same words
everywhere: the job's GitHub environment carries the deployment environment's name, the secrets and variables it reads
are scoped by that environment rather than named after it, the GitHub App it authenticates as is named one way, and
the deploy leaves a record in the organization's linked artifacts
([decision 0035](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0035-published-and-deployed-artifacts-are-recorded.md)).

## Scope

This convention covers every workflow under `.github/workflows/` and every composite action under `.github/actions/`.
GHA-48 applies to the workflows whose responsibility token ([EC-0002](workflow-files.md#gha-02)) is `release`,
`publish` or `deploy`, including reusable ones such as `reusable-deploy-api.yml`. GHA-49 applies to the workflows that
act on production: one whose filename has a `production` or `prod` token, or with a job whose `environment` is
`production` or `prod`. GHA-50 applies to every job's `environment`, GHA-51 and GHA-52 to every secret and variable a
workflow or action reads, and GHA-53 to the jobs of deploy workflows that name an environment.

The deployment environments, and the slug each may be shortened to where a system caps a name's length, are registered
in the [terminology](../../terminology/global.yml) under the `deployment.environment` tag: `production` (`prod`),
`staging`, `development` (`dev`) and `test`. Their names are the ones every name is written in
([decision 0034](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0034-deployment-environments-have-one-name.md)).

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`), and every requirement is `proposed` at
severity `warning`. The requirements are adopted from checks in `musher-dev/platform`
([decision 0016](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)),
which keeps its own copies until it pins a release that carries these and retires them.

| Upstream check | Requirement | Difference |
| --- | --- | --- |
| platform `CI-09` | GHA-46 | The platform reports a bare `--force-with-lease` only when it pushes to a URL. Here every force push must name the commit it expects, and `--force`, `-f` and a `+` refspec are reported too. |
| platform `CI-10` (part a) | GHA-47 | The platform checks `release.yml` for `secrets.GITHUB_TOKEN`. Here every workflow and action is checked, and a missing `token` and `github.token` are reported too. |
| platform `DL-18` | GHA-48 | The platform checks jobs with the IDs `deploy` and `smoke_test` and accepts `always()`. Here the last jobs of every release, publish and deploy workflow are checked, and only `!cancelled()` passes. |
| platform `DL-21` | GHA-49 | The platform finds a production workflow by the production hosts it names. Here the filename or the `environment` says so, since hosts are not declared anywhere the check reads. |

GHA-50 to GHA-53 have no upstream check; they are this repository's own.

## Requirements

### GHA-46

**A force push leases on the commit it expects to replace.**

`git push --force` replaces whatever the remote branch holds, including a commit someone pushed a second ago.
`--force-with-lease` is meant to prevent that, but its bare form compares the remote with the local remote-tracking
ref, and in CI that ref is either missing (a shallow checkout, a push to a URL rather than a named remote) or was
fetched by the same job moments before, so the lease protects nothing. With a missing ref git refuses every push as
`stale info`, which reads exactly like a lost race. The explicit form, `--force-with-lease=<branch>:<expected-sha>`,
is the only one git documents as working without a tracking ref: the push succeeds only if the branch is still at the
commit the job read.

The check reads each `git push` in a `run:` block and reports `--force`, `-f` (alone or combined, such as `-fu`),
`--force-with-lease` without `=<ref>:<expected>`, and a `+<refspec>`. A `git push` the step only shows its reader
is text, not a command: the body of a heredoc and a line that only runs `echo` or `printf` are not read.

**Correct:**

```yaml
- name: Move the release branch
  env:
    EXPECTED: ${{ steps.read.outputs.sha }}
  run: git push --force-with-lease="release:${EXPECTED}" origin HEAD:release
```

**Incorrect:**

```yaml
- run: git push --force origin HEAD:release
- run: git push --force-with-lease origin HEAD:release   # leases on a ref CI does not have
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CI-09

### GHA-47

**release-please runs with a token other than the default `GITHUB_TOKEN`.**

GitHub starts no workflow for an event raised with the default `GITHUB_TOKEN`. A release pull request opened with it
never runs its checks, so its required contexts never report and it can only merge by bypassing branch protection;
a tag or release created with it never starts the workflow that publishes the release. Mint a GitHub App installation
token (for example with `actions/create-github-app-token`, scoped to `contents` and `pull-requests`) and pass it as
`token`. The check reports a `googleapis/release-please-action` step with no `token`, or one that passes
`secrets.GITHUB_TOKEN` or `github.token`.

**Correct:**

```yaml
- name: Mint the release token
  id: app_token
  uses: actions/create-github-app-token@<sha>  # pinned as GHA-24 asks
  with:
    client-id: ${{ vars.RELEASE_APP_CLIENT_ID }}  # the release App (REL-16)
    private-key: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
    permission-contents: write
    permission-pull-requests: write
- name: Open or update the release pull request
  uses: googleapis/release-please-action@<sha>  # pinned as GHA-24 asks
  with:
    token: ${{ steps.app_token.outputs.token }}
```

**Incorrect:**

```yaml
- uses: googleapis/release-please-action@<sha>  # pinned as GHA-24 asks
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CI-10

### GHA-48

**The last jobs of a release, publish or deploy workflow run unless the run is cancelled.**

A job with the default condition runs only if every job it needs succeeded, and a skip spreads: when any job upstream
is skipped (an optional check switched off by a variable, say), every job downstream of it is skipped too, even
through jobs that override the condition themselves. A skipped job is not a failure, so the run goes green, and a
deploy that deployed nothing or a publish that published nothing reports success. The last jobs of the workflow, the
ones no other job needs, therefore state their condition: `!cancelled()`, so they are evaluated whatever happened
upstream, combined with the results they actually depend on.

Only `!cancelled()` passes, not `always()`. `always()` also runs the job after someone cancels the run, and for a job
that deploys or publishes, a cancel has to stop it. This is stricter than the aggregate in
[GHA-14](jobs-and-steps.md#gha-14), which accepts either: an aggregate only reports, so running it after a cancel
does no harm. An aggregate in a release, publish or deploy workflow uses `!cancelled()`, which satisfies both.

A job that needs nothing is not checked: nothing upstream can skip it.

**Correct:**

```yaml
jobs:
  build:
    name: Build
  deploy:
    name: Deploy
    needs: [build, migrate]
    if: ${{ !cancelled() && needs.build.result == 'success' && needs.migrate.result != 'failure' }}
```

**Incorrect:**

```yaml
jobs:
  deploy:
    name: Deploy
    needs: [build, migrate]      # skipped, and green, whenever migrate is skipped
  smoke_test:
    name: Smoke Test
    needs: deploy
    if: always()                 # still runs after the run is cancelled
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform DL-18

### GHA-49

**A workflow that acts on production does not run on a push to a branch.**

A merge to the default branch does not release anything: production moves when a release is cut. A workflow that
deploys to, probes or reports on production and runs on `push` therefore acts on the previous release every time.
A deploy on push ships whatever was merged, bypassing the release; a probe on push reports on a build that does not
contain the merge that started it, so its green runs prove nothing about that merge and its red ones are blamed on
it. Run it from the release instead: a tag, `release: published`, a `workflow_call` from the deploy, a schedule or
`workflow_dispatch`.

Two `push` forms pass. A push limited to `tags` (with no `branches` or `branches-ignore`) is the release itself. A
push whose `paths` name only the workflow's own file re-runs it when it changes and claims nothing about the rest of
the tree. A deploy to staging on push is out of scope: it has no `production` or `prod` token and no `production`
environment. Production is recognised by its registered name and its slug, `prod`, in the filename or the
environment, since a workflow written before [GHA-50](#gha-50) may still use the slug.

**Correct:**

```yaml
# deploy-production-api.yml
on:
  push:
    tags: ["api-v*"]
  workflow_dispatch:
```

**Incorrect:**

```yaml
# verify-production.yml
on:
  push:
    branches: [main]   # probes the last release, not this merge
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform DL-21

### GHA-50

**A job's GitHub environment that names a deployment environment uses its name.**

A GitHub environment is where a deployment's protection rules, reviewers, secrets and variables live, and its name is
what the deployments page, the environment's history and a deployment record show. When one repository deploys to
`prod` and the next to `production`, a reader cannot tell whether they are the same environment, an organization
ruleset or a search for `production` misses half of them, and the secrets set on one are not there for the other.
The deployment environment's name is the one name
([decision 0034](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0034-deployment-environments-have-one-name.md));
its slug is for a system that caps a name's length, and a GitHub environment caps nothing a tier name reaches.

The check reads each job's `environment`, as a string or as its `name`, and reports one that is, in any case, a
registered slug (`prod`, `dev`) or a common synonym for a deployment environment: `prd` and `live` for `production`,
`stg`, `stage` and `preprod` for `staging`, `local` for `development`. The message names the deployment environment
to use. An environment that is not a deployment environment, such as the publish gates `release`, `pypi`, `testpypi`
or `npm`, is not reported, and neither is a name computed by an expression, such as `${{ inputs.environment }}`.

**Correct:**

```yaml
jobs:
  deploy:
    name: Deploy
    environment:
      name: production
      url: https://example.com
  publish:
    name: Publish
    environment: pypi        # a publish gate, not a deployment environment
```

**Incorrect:**

```yaml
jobs:
  deploy:
    name: Deploy
    environment: prod        # the slug; the name is production
  deploy_staging:
    name: Deploy Staging
    environment: stg         # staging
```

Checked by: conftest · Severity: warning · Since: 0.9.0

### GHA-51

**A secret or variable's name carries no deployment environment.**

A value that differs by deployment environment belongs to that environment: set it on the GitHub environment, under
the same name in each, and read it from a job that names the environment. The job then gets production's value only
when it deploys to production, behind production's protection rules, and the step that reads it is the same for every
environment. A name such as `PROD_DATABASE_URL` or `API_KEY_STAGING` does the scoping in the name instead: every job
in the repository can read every environment's value, a protection rule guards none of them, and each environment
needs its own copy of the step.

The check reads every `secrets.<NAME>` and `vars.<NAME>` a workflow or composite action refers to, splits the name on
`_`, and reports one with a word that is a deployment environment's name, its slug or a synonym: `PRODUCTION`,
`PROD`, `PRD`, `STAGING`, `STG`, `STAGE`, `PREPROD`, `DEVELOPMENT` or `DEV`. `TEST` and `LIVE` are not read, since in
a name they most often mean a service's own mode (a payment provider's test or live keys, TestPyPI) rather than a
deployment environment. Each name is reported once per file.

**Correct:**

```yaml
jobs:
  deploy:
    name: Deploy
    environment: production
    steps:
      - name: Migrate the database
        env:
          ORDERS_DATABASE_URL: ${{ secrets.ORDERS_DATABASE_URL }}   # set on the production environment
        run: task migrate
```

**Incorrect:**

```yaml
      - name: Migrate the database
        env:
          ORDERS_DATABASE_URL: ${{ secrets.PROD_ORDERS_DATABASE_URL }}
          API_BASE_URL: ${{ vars.API_BASE_URL_STAGING }}
```

Checked by: conftest · Severity: warning · Since: 0.9.0

### GHA-52

**A GitHub App's credentials are a client-ID variable and a private-key secret.**

A workflow authenticates as a GitHub App with two values. The client ID names the App; it is not secret, and kept as
the Actions variable `<PURPOSE>_APP_CLIENT_ID` it shows in logs and can be read when a token fails. The private key
signs for the App; it is the secret `<PURPOSE>_APP_PRIVATE_KEY`, with the same `<PURPOSE>`, so the pair is found,
rotated and audited together. `actions/create-github-app-token` names an App by `client-id`; its `app-id` input, and
the numeric App ID it takes, are the older form. A client ID kept as a secret is masked in every log for no gain, and
a key kept as a variable is readable by anyone who can read the repository's settings.

The check reports:

- an `actions/create-github-app-token` step with an `app-id` input, a `client-id` that is not
  `${{ vars.<PURPOSE>_APP_CLIENT_ID }}`, a `private-key` that is not `${{ secrets.<PURPOSE>_APP_PRIVATE_KEY }}`, or
  the two with different purposes;
- anywhere else in a workflow or action, a reference to `secrets.<NAME>_APP_ID`, `vars.<NAME>_APP_ID`,
  `secrets.<NAME>_APP_CLIENT_ID` or `vars.<NAME>_APP_PRIVATE_KEY`.

The release App is the one exception to who checks it: the App token steps of `release.yml` are
[REL-16](../releases/release-workflows.md#rel-16)'s, which also says which App they use, so GHA-52 does not read
them. A reference to the release App's credentials anywhere else is GHA-52's.

**Correct:**

```yaml
- name: Mint the deploy App token
  id: app_token
  uses: actions/create-github-app-token@<sha>  # v3
  with:
    client-id: ${{ vars.DEPLOY_APP_CLIENT_ID }}
    private-key: ${{ secrets.DEPLOY_APP_PRIVATE_KEY }}
    permission-contents: read
```

**Incorrect:**

```yaml
- uses: actions/create-github-app-token@<sha>  # v3
  with:
    app-id: ${{ secrets.DEPLOY_APP_ID }}        # an App ID, and kept as a secret
    private-key: ${{ secrets.DEPLOY_KEY }}      # not DEPLOY_APP_PRIVATE_KEY
```

Checked by: conftest · Severity: warning · Since: 0.9.0

### GHA-53

**A deploy job records the deployment in GitHub's linked artifacts.**

The organization's linked artifacts page shows each artifact the organization builds, where it is stored and where it
runs, with its provenance. A deployment record is what puts an artifact in an environment there: it marks the artifact
as deployed, lets code scanning and Dependabot alerts be filtered to what is running, and lets an organization ruleset
target the repositories whose code is deployed. GitHub does not write it on its own; the deploy posts it to
`POST /orgs/{org}/artifacts/metadata/deployment-record`, and a teardown posts `status: decommissioned`. What the
record states is set in [decision
0035](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0035-published-and-deployed-artifacts-are-recorded.md):
`name` is the output's published name (an image's registry path without its tag), `version` is the release, never
`latest`, `logical_environment` is the deployment environment's name (`production`, never `prod`),
`physical_environment` is the provider and region, and `deployment_name` is unique within its `cluster`.

The check reads each job, in a workflow whose responsibility token ([EC-0002](workflow-files.md#gha-02)) is `deploy`,
that names an `environment` and runs steps. It reports the job when no step posts the record: a `run:` line that
names `artifacts/metadata/deployment-record`, directly or through a task that runs it, or a local composite action
whose steps do. It also reports a job that posts the record without `artifact-metadata: write` in its permissions
(or the workflow's, when the job sets none), which the job's `GITHUB_TOKEN` needs to write it. A job that calls a
reusable workflow is not read: the called workflow's jobs are.

**Correct:**

```yaml
# deploy-production-api.yml
jobs:
  deploy:
    name: Deploy
    environment: production
    permissions:
      contents: read
      artifact-metadata: write   # post the deployment record
    steps:
      - name: Deploy the service
        id: deploy
        run: task deploy
      - name: Record the deployment
        env:
          GH_TOKEN: ${{ github.token }}
          DIGEST: ${{ steps.deploy.outputs.digest }}
          VERSION: ${{ github.ref_name }}
        run: |
          gh api -X POST "orgs/${GITHUB_REPOSITORY_OWNER}/artifacts/metadata/deployment-record" \
            -f name=ghcr.io/example-org/example-api -f digest="$DIGEST" -f version="$VERSION" \
            -f status=deployed -f logical_environment=production \
            -f physical_environment=example-cloud/us-east -f deployment_name=example-api \
            -f github_repository="$GITHUB_REPOSITORY"
```

**Incorrect:**

```yaml
jobs:
  deploy:
    name: Deploy
    environment: production
    steps:
      - name: Deploy the service
        run: task deploy        # nothing records what was deployed where
```

Checked by: conftest · Severity: warning · Since: 0.9.0

## References

- [Git: git-push --force-with-lease](https://git-scm.com/docs/git-push#Documentation/git-push.txt---force-with-leaseltrefnamegtltexpectgt)
- [GitHub Docs: Triggering a workflow from a workflow](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/triggering-a-workflow#triggering-a-workflow-from-a-workflow)
- [GitHub Docs: Status check functions](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/evaluate-expressions-in-workflows-and-actions#status-check-functions)
- [release-please-action](https://github.com/googleapis/release-please-action)
- [GitHub Docs: Managing environments for deployment](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)
- [GitHub Docs: Linked artifacts](https://docs.github.com/en/code-security/concepts/supply-chain-security/linked-artifacts)
- [GitHub REST API: Artifact metadata](https://docs.github.com/en/rest/orgs/artifact-metadata)
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
- [EC-0003 Jobs and steps](jobs-and-steps.md)
