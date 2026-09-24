# How this repository is organized

Where a file goes, and why. The reasoning behind the layout is
[decision 0009](decisions/0009-definitions-and-checks.md); this page is the working reference.

## Two levels

The repository root holds what *acts on* the product: the dev environment, tool configuration, CI, release
automation, contributor documentation and the decisions. One directory, `engineering-conventions/`, holds the product
itself, which is what a consumer pins.

```text
engineering-conventions/               repository level: acts on the product
├── .devcontainer/  .github/           integration homes whose location the tool mandates
├── .config/                           tool configuration (linters, hooks), passed by explicit path
├── .claude/  CLAUDE.md  AGENTS.md     agent contract and path-scoped rules
├── .repo/conventions.yaml             this repository's own conventions declaration
├── Taskfile.yml  taskfiles/           orchestration; reaches the product through PRODUCT_DIR
├── docs/                              contributor documentation and decisions
├── README.md  CONTRIBUTING.md  SECURITY.md  CHANGELOG.md  version.txt
└── engineering-conventions/           product level: what a consumer pins
    ├── definitions/                   DEFINED: what is decided, the source of truth
    │   ├── conventions/               EC-NNNN documents by topic, families.yml
    │   ├── terminology/               global.yml
    │   └── profiles/                  convention profiles
    ├── checks/                        CHECKED: rego/, schemas/, data/ (generated), vale/ (generated)
    ├── examples/                      SHOWN: a worked, conforming consumer
    ├── bin/conventions                TOOLING: the launcher a consumer runs (mise puts bin/ on PATH)
    ├── src/  tests/                   TOOLING: the authoring CLI and its tests (not shipped)
    └── pyproject.toml  uv.lock  .python-version
```

The product directory is a native uv project root: with the working directory set to it, `uv run pytest` or
`ruff check .` behave as they would in a single-purpose repository.

## The placement test

Ask in order and stop at the first "yes":

| # | Question | Level |
| --- | --- | --- |
| 1 | Does a consumer need it to run the checks, or read it through a diagnostic link? | Product |
| 2 | Does the authoring CLI's tooling (uv, ruff, basedpyright, pytest) find it by walking up from the product? | Product |
| 3 | Does it act on the repository: dev environment, CI, release, review policy, contributor docs? | Repository |

When the answer is genuinely both, the file goes up a level and points down. Repository machinery may name product
paths, but the product never references a path above `engineering-conventions/`, so a consumer can vendor the
directory on its own.

Within the product, one more question places a file:

| Question | Home |
| --- | --- |
| Does it state what is decided: a requirement, a term, a profile? | `definitions/` |
| Does it find violations of a definition: a Rego policy, a schema, generated check data? | `checks/` |
| Does it show a conforming repository? | `examples/` |
| Does it run the checks or build the generated files? | `bin/` (shipped) or `src/` (not shipped) |

`bin/` and `src/` stay where their tools look for them: mise puts a released tool's `bin/` on PATH, and `src/` is the
standard Python layout that uv and pytest expect beside `pyproject.toml`.

## Where configuration goes

Within the repository level:

| Need | Home |
| --- | --- |
| A tool that loads only from the root (Task, git) | The root: `Taskfile.yml`, `.gitattributes`, `.gitignore` |
| A linter, formatter, rule tool or git hooks | `.config/<concern>/<tool>.<ext>` |
| A CLI version | `.devcontainer/mise.toml` |
| The container: Features, mounts, editor settings, environment | `.devcontainer/devcontainer.json` |
| GitHub's own configuration | `.github/`: workflows, rulesets, Dependabot, release-please, commit types |
| Agent permissions and path-scoped policy | `.claude/` |

Four rules keep `.config/` predictable:

- **Bucket by concern.** Use `.config/<concern>/<tool>.<ext>`, with no leading dot on the filename. The one exception
  is `lefthook.yml`, which sits at the top level because lefthook's own search stops at `.config/lefthook.*`.
- **Pass the path explicitly.** Every caller names its config with the tool's flag (`--config`, `-c`); only lefthook
  discovers its file. Relying on default discovery is what scatters dotfiles across the root.
- **Every config has a caller** in `taskfiles/` or `.config/lefthook.yml`, and CI runs the same tasks.
- **Every ignore has a reason** beside it. Nothing is suppressed inline in the code it concerns.

There is no `.editorconfig`. Editor settings live once, in `devcontainer.json` → `customizations.vscode.settings`.
`.gitattributes` enforces LF endings, and the lint gates fail on anything an editor gets wrong.

## Toolchain

| Tier | Home | Holds |
| --- | --- | --- |
| Baked into the image | `.devcontainer/Dockerfile` → `ARG MISE_VERSION` | mise, and only mise, because mise cannot pin itself |
| Pinned by mise | `.devcontainer/mise.toml` | Every CLI the gates run, and their runtimes |
| Container Features | `devcontainer.json` → `features` | `gh`, git and zsh, which configure the container itself |

The dev container (post-create), `task setup` and CI (through `.github/actions/setup-tools`) all install from
`mise.toml`, so a version lives in one place and a local run and CI cannot disagree. The few pins mise cannot express
move in lockstep; they are listed in [`.claude/rules/toolchain-pins.md`](../.claude/rules/toolchain-pins.md).

To add a tool, add one line under `[tools]` with a fully qualified backend (`aqua:owner/repo`, `pipx:`, `npm:`), then
run `task tools:install` and `task tools:doctor`.

## Generated files and the bundle

Some product files are written by `task generate` from `definitions/`: the conventions' frontmatter, `families.yml`,
the profiles and the terminology. They are committed, so a consumer never needs the authoring CLI, and are never
edited by hand: `task generate:check` fails when one is stale. [`.gitattributes`](../.gitattributes) lists them, marked
`linguist-generated`.

A release is the product directory as a consumer runs it. `task bundle:build` writes it to `dist/`: the tarball
without the authoring side (`src/`, `tests/`, the Python project files) or the Rego unit tests, which conftest would
load as policy. It also writes the Vale package, `manifest.json` and `SHA256SUMS`. The build is reproducible, and
`task bundle:verify` fails on any entry outside the allowed set. The exact contents are defined in
[`taskfiles/bundle.Taskfile.yml`](../taskfiles/bundle.Taskfile.yml).

## Comments

A comment earns its line by stating *why*, not *what*. Write a rationale once, in this page, a decision or a
`.claude/rules/` file, and leave a one-line pointer at the call site.
