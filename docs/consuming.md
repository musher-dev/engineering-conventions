# Consuming the conventions

How to check a repository against a release of these conventions. The short version is one line in the mise
configuration and one command, the same locally and in CI.

## Try it without adopting anything

```sh
mise exec github:musher-dev/engineering-conventions@0.7.0 -- conventions check  # x-release-please-version
```

mise downloads that release, verifies it and runs it against the repository you are in. Nothing is written to the
repository. The run reports ADOPT-09, because nothing pins a release yet, and REPO-01, because the repository does
not declare its identity.

Name a version rather than `@latest`. mise hides a release younger than its `minimum_release_age` setting, so for a
while after each release `@latest` resolves to an older one, and 0.1.0, the oldest, predates the `conventions`
launcher: mise then fails with `"conventions" couldn't exec process: Permission denied`. To see every release, run
`MISE_MINIMUM_RELEASE_AGE=0 mise ls-remote github:musher-dev/engineering-conventions`.

## Adopt it

Pin the release in the repository's one mise configuration, `.config/mise/config.toml`, where mise finds it without
being told ([EC-0017](../engineering-conventions/definitions/conventions/toolchain/tool-pins.md)):

```toml
min_version = "2026.9.12"   # the mise that CI and the dev container install

[tools]
"github:musher-dev/engineering-conventions" = "0.7.0"  # x-release-please-version
```

Then lock it, commit `.config/mise/mise.lock` beside the configuration, and run it:

```sh
mise lock
mise install --locked
conventions check                      # report findings; fail only on errors
conventions check --fail-on warning    # fail on every finding, as CI should in the 0.x series
conventions prose                      # lint Markdown with the MusherConventions Vale style
```

With the identity declaration below, that is the whole adoption. What mise does with the line:

- It downloads the release's tarball and verifies its checksum and its GitHub build-provenance attestation, which
  proves this repository's release workflow built it. `mise lock` records both in
  `.config/mise/mise.lock`.
- It puts `conventions` on PATH. The command runs conftest and jq (and Vale for `prose`) through `mise exec` at the
  versions the release was tested with, so the release pin is the only pin to maintain.
- Renovate's mise manager raises the version like any other tool.

`conventions check` runs from anywhere in the work tree, or against another directory with `-C DIR`. It needs only
POSIX `sh` and `git`.

| `--output` | For | Prints |
| --- | --- | --- |
| `text` (default) | A person at a terminal | The report below, in colour on a terminal unless `NO_COLOR` is set |
| `json` | A program, through a pipe | A JSON array of findings: `convention`, `enforced`, `id`, `message`, `path`, `severity`, `url` |
| `github`, `sarif`, `junit`, `tap`, `table` | CI tools | conftest's own format, passed through |

The report goes to stdout. The progress line, and mise's messages when it installs a tool, go to stderr, and the
progress line only to a terminal, so `conventions check --output json | jq …` receives JSON alone. The exit status is
the same for every format: `0` when no enforced finding is at or above `--fail-on`, `1` when one is, and `2` when the
check could not run. Every finding is enforced unless the repository is [adopting in stages](#adopt-in-stages).

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
  with:
    version: 2026.9.12   # the min_version in .config/mise/config.toml (TOOL-04)
- name: Check the repository against its conventions
  run: conventions check --fail-on warning
```

[`examples/consumer`](../engineering-conventions/examples/consumer/) is a complete, conforming repository: the mise
configuration and its lockfile, a `Validate` workflow that runs the step above as its `Conventions` job, a
pull-request-title workflow, and a ruleset that requires only the aggregate.

## Declare the repository's identity

Every repository says what it is in `.repo/repository.toml`:

```toml
schema_version = 1
name = "platform-api"
system = "platform"
component = "api"
kind = "service"
owner = "@musher-dev/platform"
lifecycle = "production"
audience = "internal"
tier = 1

[layout]
product = "platform-api"
```

The `name` is the repository's name on GitHub, `<system>-<component>`, with the system taken from the registered
systems. The `kind` selects the convention profile of the same name, so a service is checked as a service without
any other file. `conventions check` reports REPO-01 until the file exists, and checks every value against the
registered ones. The format is
[EC-0009](../engineering-conventions/definitions/conventions/repository/identity-declaration.md), and the naming rules
are [EC-0010](../engineering-conventions/definitions/conventions/repository/repository-names.md). A repository that is
still to be renamed keeps its current name in the declaration: see [Legacy repository names](#legacy-repository-names).

The `[layout]` table says where the product lives: `product` is the directory, named after the repository, that holds
the product's build manifest, or `""` for a repository with no product directory. The root then holds no manifest,
lockfile or source tree, and Dependabot and the Taskfile's `PRODUCT_DIR` name the same directory. The rules are
[EC-0018](../engineering-conventions/definitions/conventions/repository/layout.md); a repository with several products
under one workspace root declares `product = ""` and waives REPO-18 until it is split. A repository that holds data
rather than a build, such as documents, schemas or configuration, also declares `product = ""`: it has no build
manifest for a product directory to hold, and its tooling, if any, lives in a directory of its own.

### How the checks learn the repository's name

REPO-07 compares the declared name with the repository's actual name. `conventions check` learns the actual name, in
order, from:

1. `--repository NAME`, or the `CONVENTIONS_REPOSITORY` environment variable;
2. `GITHUB_REPOSITORY` in GitHub Actions, only when the directory checked is `GITHUB_WORKSPACE`;
3. the last segment of the `origin` remote's URL, only when the directory checked is the root of a git work tree.

A directory checked with `-C` inside another work tree, or a copy with no remote, has no actual name: REPO-07 is not
checked, and the other naming requirements judge the declared name. Pass `--repository` when the remote does not carry
the repository's name, such as a mirror.

### Legacy repository names

A repository created before the naming grammar can adopt the conventions before it is renamed:

1. Declare the name the repository has today, and set `component` to what the repository holds, usually that same
   name. Set `system` to the registered system the repository belongs to.
2. Run `conventions check` and waive only the naming findings the current name actually produces. A waiver of a
   requirement that reports nothing is itself a finding (ADOPT-06).
3. Write each waiver's `reason` and its tracking issue about the current name, never about the next one.

Never declare, waive or write down a planned name in a repository before the rename happens. Declarations, waivers,
issues and CI logs are all readable by everyone who can read the repository, and a planned name belongs to whoever
plans it until the rename is applied. Update the declaration in the pull request after the rename, when REPO-07 starts
comparing it with the new name.

## Define the standard tasks

Every repository has a root `Taskfile.yml` that defines `setup`, `check` and `lint` (TASK-10). The kind adds to that:
a `library`, `tool`, `service` or `website` also defines `build` and `test` (TASK-11), and a `service` defines `dev`
(TASK-12). An alias or an included task counts, so a repository whose verbs have other names adds `aliases:` rather
than renaming. The interface is
[EC-0016](../engineering-conventions/definitions/conventions/tasks/task-interface.md), and how each Taskfile is
written is [EC-0015](../engineering-conventions/definitions/conventions/tasks/taskfile-style.md).

## Declare a service's environment

A repository whose kind is `service` declares every variable its product reads in `<product>/env.schema.yaml`, beside
the build manifest (ENVS-01). The dev environment's variables, if it declares them, go in
`.devcontainer/env.schema.yaml`; no other location is checked as a schema (ENVS-02).

```yaml
service: platform-api
runtime: python
naming:
  components: [API, DATABASE]
bindings:
  API_PORT:
    type: integer
    default: 8080
    sensitivity: internal
    description: TCP port the HTTP server listens on inside the container.
```

`conventions check` validates every schema against the published format and checks the naming grammar, retired
names, committed secrets and shared variables. The format is
[EC-0020](../engineering-conventions/definitions/conventions/environment/env-schema.md); the location is
[EC-0019](../engineering-conventions/definitions/conventions/environment/env-contract.md).

## Declare only what differs

A repository that holds no waivers, and whose kind selects the profile it needs, needs no other file. Add
`.repo/conventions.toml` when it needs a different profile, its own display forms, or a waiver:

```toml
schema_version = 1
profile = "base-repo"         # overrides the profile the kind selects
```

The declarations under `.repo/` are TOML.

The full format is [EC-0001](../engineering-conventions/definitions/conventions/adoption/conventions-declaration.md). ADOPT-02
checks the file against its schema as part of `conventions check`; no separate validator is needed.

## Declare what you publish

A repository with a `publish` workflow lists what it publishes in `.repo/outputs.toml`, one entry per container image,
library, command-line tool, bundle, site or machine image:

```toml
schema_version = 2

[[outputs]]
id = "api-image"
kind = "image"
source = "api/"
publish_workflow = "publish-api.yml"
location = "ghcr.io/your-org/api"
docs = "api/README.md#run-the-image"
```

`conventions check` reports OUT-01 on a publish workflow until the file exists, and checks that each kind is known and
each path and workflow it names exists. The format is
[EC-0007](../engineering-conventions/definitions/conventions/outputs/outputs-declaration.md); what a published output
promises its consumers is [EC-0008](../engineering-conventions/definitions/conventions/outputs/publishing-and-consuming.md).

## Declare the interfaces you offer

When other repositories build or run against something yours defines, such as an OpenAPI document, event schemas or
a protobuf package, declare each surface as its own interface in the same file, with the output that delivers it, and
keep its files in `<product>/contracts/`:

```toml
[[outputs]]
id = "contracts"
kind = "bundle"
source = "api/contracts/"
publish_workflow = "release.yml"
location = "https://github.com/your-org/your-repo/releases"
docs = "api/contracts/README.md"

[[interfaces]]
id = "public-http"
format = "openapi"
definitions = ["api/contracts/openapi/public.json"]
delivered_by = "contracts"
compatibility = "gated"
```

Define `contracts:check`, `contracts:breaking` and `contracts:bundle` (and `contracts:generate` when code writes the
definitions), run the first two in your validate workflow, and build the bundle with its `release.json` in the
workflow that publishes it. The rules are the [interfaces](../engineering-conventions/definitions/conventions/interfaces/README.md)
topic.

## Declare the interfaces you vendor

When your repository builds against another repository's interfaces, vendor the release into
`<product>/contracts/vendor/<repository>/<output>/`, with its `release.json` unchanged, and pin it in
`.repo/dependencies.toml`:

```toml
schema_version = 1

[[dependencies]]
repository = "platform-api"
output = "contracts"
interfaces = ["public-http"]
version = "0.36.1"
```

That file is the only place the pin lives: no `config/<repository>.ref`, no hand-kept lock. Packages and tools keep
their pins in their own manifests, at exact versions. Define `deps:check` and `deps:sync`, run `deps:check` in your
validate workflow, and run `deps:sync` from a scheduled `maintain-dependencies.yml`. At runtime, name what each
environment binding reaches: `target = "platform-api#public-http"` for another service, or a registered `capability`
such as `postgresql`. The rules are the [dependencies](../engineering-conventions/definitions/conventions/dependencies/README.md)
topic and [EC-0020](../engineering-conventions/definitions/conventions/environment/env-schema.md).

## Without mise

Download the release tarball, verify it, and run its launcher with conftest (and Vale) on PATH:

```sh
version=0.7.0  # x-release-please-version
gh release download "v${version}" -R musher-dev/engineering-conventions -p "engineering-conventions-${version}.tar.gz"
gh attestation verify "engineering-conventions-${version}.tar.gz" -R musher-dev/engineering-conventions \
  --signer-workflow musher-dev/engineering-conventions/.github/workflows/release.yml \
  --source-ref refs/heads/main
tar -xzf "engineering-conventions-${version}.tar.gz"
CONVENTIONS_NO_MISE=1 engineering-conventions/bin/conventions check
```

Releases up to 0.6.1 were attested by `publish.yml` from their tag: verify one of those with
`--signer-workflow musher-dev/engineering-conventions/.github/workflows/publish.yml --source-ref "refs/tags/v${version}"`.
Later releases are attested by `release.yml` in the run that cut them, on the default branch
([decision 0017](decisions/0017-releases-from-drafts.md)).

With no mise pin, the pin is `conventions.version` in the declaration; ADOPT-08 reports a declaration that names a
different release from the one being run. The release also attaches the Vale style alone, as `MusherConventions.zip`,
for a repository that runs Vale itself.

## Delegated checks

GHA-33 is delegated to actionlint and zizmor, which `conventions check` does not run. Pin them in
`.config/mise/config.toml` beside the conventions and run them in the repository's own validation:

```sh
actionlint
zizmor --min-severity medium --persona regular .github/
```

## Reading the report

The report has one block per requirement, errors first, then a summary:

```text
GHA-07  warning  1 finding
A workflow's name is its filename stem in Title Case
https://github.com/musher-dev/engineering-conventions/blob/vX.Y.Z/engineering-conventions/definitions/conventions/github-actions/workflow-files.md#gha-07
  .github/workflows/ci.yml
    name "CI" should be "Validate Code": a workflow's name is its filename stem in Title Case

1 warning, 0 errors in 1 requirement.
Warnings do not fail the check; --fail-on warning makes them fail.
```

| Part | Meaning |
| --- | --- |
| `GHA-07` | The requirement ID; search for it, or waive it by this ID |
| `warning` | The effective severity under the repository's profile |
| The title | What the requirement asks for |
| The URL | The requirement's section in the pinned release, with the reasoning and examples |
| An indented path | A file to change, relative to the repository root |
| A message under it | What to change in that file. It is enough to act on without the link |

With `--output json`, each finding is one object with the same parts.

**A file that does not parse.** A workflow, action, ruleset, declaration or mise configuration that is not valid YAML,
JSON or TOML cannot be checked at all: conftest stops with a parse error naming the file. Fix the syntax and run
again. A `devcontainer.json` or Dockerfile is parsed before the check ([decision 0015](decisions/0015-the-runner-reads-what-conftest-cannot-select.md)),
so one that does not parse is reported as a `PARSE` error and the rest of the repository is still checked.

**Fixtures.** Directories of test fixtures, such as sample repositories or files that are invalid on purpose, are
declared so the checks do not read them as the repository's own. This is for fixtures only. It does not expire, and a
finding in code you ship needs a waiver:

```toml
[paths]
fixtures = ["tests/fixtures/**"]
```

**Decision records elsewhere.** The DEC checks read decision records from `docs/decisions/`, one `NNNN-slug.md`
file each, and stay silent in a repository without them. A repository that keeps them in another directory, or as one
directory per record for a documentation site, declares where
([EC-0021](../engineering-conventions/definitions/conventions/decisions/decision-records.md#where-the-records-are)):

```toml
[decisions]
path = "docs/site/adrs"
form = "directory"
page = "+page.md"
```

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

```toml
[[waivers]]
requirement = "GHA-32"
paths = [".github/workflows/validate-docs.yml"]
reason = "The docs workflow keeps its paths filter until its jobs move into validate-repository.yml."
tracking = "https://github.com/your-org/your-repo/issues/1"
expires = "2026-12-31"
```

Quote the date. An unquoted `expires = 2026-12-31` is a TOML date rather than a string, and ADOPT-02 reports it.

A waiver needs a reason of at least 20 characters, a tracking issue URL and an expiry at most 180 days away. It
suppresses matching findings until the expiry date; after that, the findings return along with an ADOPT-03 finding.
A waiver that matches nothing is reported as stale (ADOPT-06). `ADOPT` requirements cannot be waived. The full rules
are in [EC-0001](../engineering-conventions/definitions/conventions/adoption/conventions-declaration.md).

## Adopt in stages

An established repository usually meets some families of requirements long before others. To make CI block on the
families it has cleaned up, while it still sees everything else, list those families in an `[adoption]` table:

```toml
[adoption]
enforce = ["ADOPT", "REPO", "OUT", "GHA"]
tracking = "https://github.com/your-org/your-repo/issues/2"
expires = "2027-01-31"
```

Until `expires`, only findings in the listed families count toward `--fail-on`. `ADOPT` findings and files that do not
parse always count. Every other finding is still printed, marked `not enforced`: the text report says
`warning (not enforced)` on the requirement's block and counts those findings in its summary, `--output json` sets
`"enforced": false`, and conftest's formats carry the mark in each message. So CI can run
`conventions check --fail-on warning` from the first day.

Adopting another family is one line: add it to `enforce` in the pull request that fixes its findings, or that retires
the local check it replaces. Delete the table once every family is enforced. Like a waiver, a staged adoption lasts
at most 180 days. When it expires, every family is enforced again and ADOPT-11 reports it. A family a later release
adds is not enforced until you list it. The rules are in
[EC-0001](../engineering-conventions/definitions/conventions/adoption/conventions-declaration.md#staged-adoption), and
[`examples/staged-consumer`](../engineering-conventions/examples/staged-consumer/) is a worked example.

## Upgrading

Change the version in `.config/mise/config.toml` and run `mise lock`, or accept Renovate's pull request that does. Read
the release notes first: what each kind of release can change is in [versioning](versioning.md).
