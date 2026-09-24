# Consuming the conventions

How to check a repository against a release of these conventions. The short version is one line in `mise.toml` and
one command, the same locally and in CI.

## Try it without adopting anything

```sh
mise exec github:musher-dev/engineering-conventions@0.3.0 -- conventions check  # x-release-please-version
```

mise downloads that release, verifies it and runs it against the repository you are in. Nothing is written to the
repository. The run reports ADOPT-09, because nothing pins a release yet.

Name a version rather than `@latest`. mise hides a release younger than its `minimum_release_age` setting, so for a
while after each release `@latest` resolves to an older one, and 0.1.0, the oldest, predates the `conventions`
launcher: mise then fails with `"conventions" couldn't exec process: Permission denied`. To see every release, run
`MISE_MINIMUM_RELEASE_AGE=0 mise ls-remote github:musher-dev/engineering-conventions`.

## Adopt it

Pin the release in `mise.toml` (or `.devcontainer/mise.toml`):

```toml
[tools]
"github:musher-dev/engineering-conventions" = "0.3.0"  # x-release-please-version
```

Then run it:

```sh
mise install
conventions check                      # report findings; fail only on errors
conventions check --fail-on warning    # fail on every finding, as CI should in the 0.x series
conventions prose                      # lint Markdown with the MusherConventions Vale style
```

That is the whole adoption. What mise does with the line:

- It downloads the release's tarball and verifies its checksum and its GitHub build-provenance attestation, which
  proves the `Publish` workflow built it from the `v<version>` tag. `mise lock` records both in `mise.lock`.
- It puts `conventions` on PATH. The command runs conftest (and Vale for `prose`) through `mise exec` at the versions
  the release was tested with, so the release pin is the only pin to maintain.
- Renovate's mise manager raises the version like any other tool.

`conventions check` runs from anywhere in the work tree, or against another directory with `-C DIR`. It needs only
POSIX `sh` and `git`. `--output` takes any conftest format: `json`, or `github` for annotations in a workflow.

A Taskfile needs no more than one task:

```yaml
tasks:
  conventions:
    desc: Check the repository against the pinned engineering conventions.
    cmds: [conventions check --fail-on warning]
```

## In CI

```yaml
- uses: jdx/mise-action@c2a87611a18de5b3828c5652fe268e992400cb5c  # v4.3.0
- name: Check the repository against its conventions
  run: conventions check --fail-on warning
```

[`examples/consumer`](../engineering-conventions/examples/consumer/) is a complete, conforming repository: the
`mise.toml`, a `Validate` workflow that runs the step above as its `Conventions` job, a pull-request-title workflow,
and a ruleset that requires only the aggregate.

## Declare only what differs

A repository that uses the `base-repo` profile and holds no waivers needs no other file. Add `.repo/conventions.yaml`
when it needs a different profile, its own display forms, or a waiver:

```yaml
schema_version: 1
profile: base-repo
waivers: []
```

The full format is [EC-0001](../engineering-conventions/definitions/conventions/adoption/conventions-declaration.md). ADOPT-02
checks the file against its schema as part of `conventions check`; no separate validator is needed.

## Declare what you publish

A repository with a `publish` workflow lists what it publishes in `.repo/outputs.yaml`, one entry per container image,
library, command-line tool, contract or bundle:

```yaml
schema_version: 1
outputs:
  - id: api-image
    kind: image
    source: api/
    publish_workflow: publish-api.yml
    location: ghcr.io/your-org/api
    docs: api/README.md#run-the-image
```

`conventions check` reports OUT-01 on a publish workflow until the file exists, and checks that each kind is known and
each path and workflow it names exists. The format is
[EC-0007](../engineering-conventions/definitions/conventions/outputs/outputs-declaration.md); what a published output
promises its consumers is [EC-0008](../engineering-conventions/definitions/conventions/outputs/publishing-and-consuming.md).

## Without mise

Download the release tarball, verify it, and run its launcher with conftest (and Vale) on PATH:

```sh
version=0.2.0
gh release download "v${version}" -R musher-dev/engineering-conventions -p "engineering-conventions-${version}.tar.gz"
gh attestation verify "engineering-conventions-${version}.tar.gz" -R musher-dev/engineering-conventions \
  --signer-workflow musher-dev/engineering-conventions/.github/workflows/publish.yml \
  --source-ref "refs/tags/v${version}"
tar -xzf "engineering-conventions-${version}.tar.gz"
CONVENTIONS_NO_MISE=1 engineering-conventions/bin/conventions check
```

With no mise pin, the pin is `conventions.version` in the declaration; ADOPT-08 reports a declaration that names a
different release from the one being run. The release also attaches the Vale style alone, as `MusherConventions.zip`,
for a repository that runs Vale itself.

## Delegated checks

GHA-33 is delegated to actionlint and zizmor, which `conventions check` does not run. Pin them in `mise.toml` beside
the conventions and run them in the repository's own validation:

```sh
actionlint
zizmor --min-severity medium --persona regular .github/
```

## Reading a diagnostic

Each finding is one line:

```text
warning [GHA-07] .github/workflows/ci.yml — name "CI" should be "Validate Code": a workflow's name is its filename stem in Title Case. https://github.com/musher-dev/engineering-conventions/blob/v0.1.0/engineering-conventions/conventions/github-actions/workflow-files.md#gha-07
```

| Part | Meaning |
| --- | --- |
| `warning` | The effective severity under the repository's profile |
| `[GHA-07]` | The requirement ID; search for it, or waive it by this ID |
| `.github/workflows/ci.yml` | The file to change, relative to the repository root |
| message | What to change. It is enough to act on without the link |
| URL | The requirement's section in the pinned release, with the reasoning and examples |

`conftest` prints the line after its own prefix (`WARN - Combined - main - ...`). With `--output json`, each result
also carries `id`, `path`, `severity`, `url` and `convention` under `metadata`.

**A file that does not parse.** A workflow, action, ruleset, declaration or mise configuration that is not valid YAML,
JSON or TOML cannot be checked at all: conftest stops with a parse error naming the file. Fix the syntax and run
again.

**Fix filenames before names.** A workflow's `name:` (GHA-07), the workflow prefix of a required-check job (GHA-12) and
an action's `name:` (GHA-22) are derived from a filename or directory. While GHA-01, GHA-05, GHA-20 or GHA-21 asks for a
file to be renamed, the derived-name checks wait, so a first run can show fewer name findings than the second. Rename
files first, then fix the names the next run reports.

**No rulesets, no required-check findings.** GHA-15, GHA-16 and GHA-32 compare the workflows with the required
status checks in `.github/rulesets/*.json`. A repository that does not commit its rulesets there gets no findings from
them. That is not a pass: export the rulesets from the repository settings and commit them to have them checked.

## Waivers

When a repository cannot meet a requirement yet, it records a waiver in its declaration rather than ignoring the
finding:

```yaml
waivers:
  - requirement: GHA-32
    paths:
      - .github/workflows/validate-docs.yml
    reason: >-
      The docs workflow keeps its paths filter until its jobs move into validate-repository.yml.
    tracking: https://github.com/your-org/your-repo/issues/1
    expires: 2026-12-31
```

A waiver needs a reason of at least 20 characters, a tracking issue URL and an expiry at most 180 days away. It
suppresses matching findings until the expiry date; after that, the findings return along with an ADOPT-03 finding.
A waiver that matches nothing is reported as stale (ADOPT-06). `ADOPT` requirements cannot be waived. The full rules
are in [EC-0001](../engineering-conventions/definitions/conventions/adoption/conventions-declaration.md).

## Upgrading

Change the version in `mise.toml`, or accept Renovate's pull request that does. Read the release notes first: what
each kind of release can change is in [versioning](versioning.md).
