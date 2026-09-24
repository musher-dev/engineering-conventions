# Engineering conventions

`musher-dev/engineering-conventions` is the authoritative home for Musher's shared engineering language, repository
structures and implementation expectations. It defines what the conventions are and how they are validated, and
releases both as a versioned bundle that other repositories pin. It does not execute application code, and it does not
host CI for other repositories.

> **Status: v0, draft.** Every requirement is `proposed` at severity `warning`: a finding is advice, not a failure.
> The GitHub Actions conventions are derived from checks owned by `musher-dev/platform`, which stays their authority
> until a single handoff moves them here; where they differ from the platform, the difference is a proposal it adopts
> then ([decision 0002](docs/decisions/0002-authority-and-migration.md)).

## What is here

| Part | What it is | Where |
| --- | --- | --- |
| Conventions | Documents with an `EC-NNNN` ID, each holding requirements with IDs such as `GHA-07` | [`engineering-conventions/conventions/`](engineering-conventions/conventions/) |
| Terminology | The words the conventions use, their display forms and their banned aliases | `engineering-conventions/terminology/` |
| Profiles | Named selections of requirements for a kind of repository | `engineering-conventions/profiles/` |
| Checks | Conftest/Rego policies, JSON Schemas and a Vale style | `engineering-conventions/checks/` |
| Example | A complete repository that meets every check | [`engineering-conventions/examples/consumer/`](engineering-conventions/examples/consumer/) |
| Decisions | Why the repository works the way it does | [`docs/decisions/`](docs/decisions/README.md) |

The current conventions:

| ID | Convention | Requirements |
| --- | --- | --- |
| EC-0001 | [Conventions declaration](engineering-conventions/conventions/adoption/conventions-declaration.md) | ADOPT-01 – ADOPT-09 |
| EC-0002 | [Workflow files](engineering-conventions/conventions/github-actions/workflow-files.md) | GHA-01 – GHA-09 |
| EC-0003 | [Jobs and steps](engineering-conventions/conventions/github-actions/jobs-and-steps.md) | GHA-10 – GHA-19 |
| EC-0004 | [Composite actions](engineering-conventions/conventions/github-actions/composite-actions.md) | GHA-20 – GHA-23, GHA-38 |
| EC-0005 | [Execution hygiene](engineering-conventions/conventions/github-actions/execution-hygiene.md) | GHA-24 – GHA-33 |
| EC-0006 | [Units and renames](engineering-conventions/conventions/github-actions/units-and-renames.md) | GHA-34 – GHA-37 |

## Finding a requirement

- **By ID.** A diagnostic names the requirement (`[GHA-07]`) and links to its heading. In a convention, each
  requirement is the heading `### <ID>`, so `workflow-files.md#gha-07` is its permanent address. The generated
  [`conventions/README.md`](engineering-conventions/conventions/README.md) lists every ID ever issued, retired ones
  included.
- **By topic.** Start at a topic's README, such as
  [GitHub Actions](engineering-conventions/conventions/github-actions/README.md), which gives the reading order.
- **By machine.** `engineering-conventions/checks/data/index.json` holds every requirement with its title, status,
  severity, convention, path and anchor, plus the profiles and the vocabulary. It is generated and committed.

## Using the conventions in another repository

Pin a release in `mise.toml` and run one command, the same locally and in CI:

```toml
[tools]
"github:musher-dev/engineering-conventions" = "0.2.0"
```

```sh
conventions check
```

mise verifies the release's checksum and build provenance, and Renovate raises the pin. To try it without changing
anything: `mise exec github:musher-dev/engineering-conventions@latest -- conventions check`. The details, and the path
without mise, are in [Consuming the conventions](docs/consuming.md).

## Working on this repository

Open the repository in its dev container (or install the pinned tools with `mise`), then:

```sh
task setup     # install the pinned toolchain, the authoring CLI and the git hooks
task check     # every gate CI runs, except the dev container build
```

To add or change a requirement, read [Authoring conventions](docs/authoring.md) and [CONTRIBUTING.md](CONTRIBUTING.md).
Where a file goes, including why the product sits in a nested `engineering-conventions/` directory, is in
[How this repository is organized](docs/repository.md).

## Releases

Releases are cut by release-please from Conventional Commit titles. Each `vX.Y.Z` release attaches the bundle
tarball, the `MusherConventions` Vale package, a manifest, `SHA256SUMS`, and a build-provenance attestation. The
version number says what an upgrade can break; see [Versioning](docs/versioning.md).

## What this repository does not own

Company process, telemetry names, document specifications, positioning and customer vocabulary, platform domain
nouns, requirements local to one repository, and the development-container scaffold each have another home. The
[charter](docs/decisions/0000-charter.md) lists where each lives. A repository's own requirement may be stricter than a
convention here, never contradictory.

## Security

See [SECURITY.md](SECURITY.md) to report a vulnerability.
