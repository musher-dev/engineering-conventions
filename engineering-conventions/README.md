# engineering-conventions (the product)

This directory is what a consuming repository pins. A release bundle is this directory, minus the authoring tooling,
plus `checks/data/release.json` naming the version. Everything a consumer needs to check a repository is here, and
nothing here needs Python to use.

It has three layers. `definitions/` is the source of truth; `checks/` validates it; the tooling runs the checks.

| Layer | Path | Contents | Generated |
| --- | --- | --- | --- |
| Defined | `definitions/conventions/` | The conventions (`EC-NNNN`) by topic, one Markdown document each, with the requirement catalog in YAML frontmatter | |
| Defined | `definitions/conventions/families.yml` | The registered requirement-ID prefixes | |
| Defined | `definitions/conventions/README.md` | An index of every convention and requirement ID, retired ones included | yes |
| Defined | `definitions/terminology/` | `global.yml`: terms, display forms and aliases | |
| Defined | `definitions/profiles/` | Convention profiles, such as `base-repo` | |
| Defined | `definitions/copy/` | `style.yml`: the MusherCopy style and the Vale packages the copy rules adopt | |
| Checked | `checks/rego/` | The Conftest checks and the `main` router that applies profiles, severities and waivers | |
| Checked | `checks/schemas/` | JSON Schemas for the declarations (conventions, outputs, repository, dependencies), the environment schema, release records, the frontmatter of conventions, decisions, skills and subagents, terminology, profiles, families and the copy style; `vendor/` holds the upstream schemas the checks use | |
| Checked | `checks/data/index.json` | Requirements, profiles and vocabulary, read by the Rego checks | yes |
| Checked | `checks/vale/MusherConventions/` | The Vale style for prose-scope aliases | yes |
| Checked | `checks/vale/MusherCopy/`, `checks/vale/MusherProse.ini` | The Vale style for public copy, and the `.vale.ini` of the `MusherProse` package | yes |
| Shown | `examples/consumer/` | A worked repository that meets every check | |
| Shown | `examples/staged-consumer/` | The same repository part-way through a staged adoption, with a waiver | |
| Tooling | `bin/conventions`, `bin/*.jq` | The launcher a consumer runs, and the jq programs it uses to build the inventory, render the report, derive the environment contract and select OpenAPI documents; mise puts `bin/` on PATH | |

Not shipped in the bundle (tooling): `src/` and `tests/` (the `conventions` authoring CLI and its tests),
`pyproject.toml` and `uv.lock`. They generate the files marked above and run the meta-checks; see [authoring](https://github.com/musher-dev/engineering-conventions/blob/main/docs/authoring.md).

## Using it

1. Declare the repository's identity in `.repo/repository.toml`
   ([EC-0009](definitions/conventions/repository/identity-declaration.md)), and any profile override or waiver in
   `.repo/conventions.toml` ([EC-0001](definitions/conventions/adoption/conventions-declaration.md)).
2. Pin or download and verify a release, then run `bin/conventions check`.

The commands are in [Consuming the conventions](https://github.com/musher-dev/engineering-conventions/blob/main/docs/consuming.md),
and [`examples/consumer/`](examples/consumer/) shows them in a workflow.

## Checking from a checkout

Contributors to this repository can run the same checks through the authoring CLI, which builds the file list and
inventory itself:

```sh
uv run --project engineering-conventions --locked conventions check <repo_dir>
```

It prints one diagnostic per finding and exits nonzero on a finding at or above `--fail-on` (default `error`).

Two programs are called `conventions`, and they do different jobs:

| | The authoring CLI | The launcher |
| --- | --- | --- |
| Run as | `uv run --project engineering-conventions conventions …` | `bin/conventions …`, or `conventions …` once mise pins a release |
| Ships in the bundle | No (`src/`, Python) | Yes (POSIX `sh` and jq) |
| Commands | `generate`, `invariants`, `classify`, `check`, `fixtures` | `check`, `prose`, `openapi`, `hadolint`, `env-contract`, `env-file`, `version` |
| For | Authoring this repository: generating files, meta-checks, the fixture suite | Checking a repository, as consumers and CI do |

Both `check`s select the same files (from the patterns in `bin/conventions`) and run the same Rego, and
`tests/test_launcher.py` holds the launcher to the authoring CLI's findings on a sample of the fixtures. They differ
on a file that does not parse. The authoring CLI parses every file it passes to conftest first, and reports one that
fails as a `PARSE` error, checking the rest. The launcher parses only `devcontainer.json` files and Dockerfiles first;
any other file conftest cannot parse, such as a workflow with a YAML syntax error, stops the check with exit status 2
and conftest's message.
