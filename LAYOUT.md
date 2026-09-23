# Repository Layout

**Two levels.** The repository root holds what *acts on* the product: collaboration, the dev environment, CI,
governance, and the documents people open first. One directory, named after the repository, holds what the product
*is built from*.

This file decides **which level** a file belongs to. [CONFIGURATION.md](CONFIGURATION.md) decides where it goes
*within* the repository level. What is mechanically enforced is listed under [Invariants](#invariants).

## The Rule

```text
<repo>/                         repository level: acts ON the product
├── .devcontainer/ .github/     integration homes whose location the tool mandates
├── .config/  .repo/            repo tool config; governance (+ layout.toml)
├── Taskfile.yml  taskfiles/    orchestration entry points
├── README.md  LAYOUT.md …      human entry points (AGENTS.md, docs/, SECURITY.md …)
└── <repo>/                     product level: what the product is built from
    ├── Cargo.toml | package.json | pyproject.toml | go.mod …
    ├── native tool configs     rust-toolchain.toml, .cargo/, rustfmt.toml, ruff.toml …
    ├── env.schema.yaml         the runtime environment contract
    └── sources, tests, contracts, fixtures, schemas
```

The product directory is the ecosystem's native build root. With the working directory set to it, `cargo build`,
`npm test` or `uv run pytest` behave exactly as they would in a single-purpose repository, because every file those
tools discover by walking upward is inside it.

The repository level is there because a product never ships alone: it arrives with a dev container, CI, release
automation and review policy. Keeping them one level up means someone working on the product sees only the
product, and a new piece of repository machinery has an obvious home that is not mistaken for implementation.

The name repeats (`host-agent/host-agent/`) on purpose. The two levels have different jobs, and naming the inner
one after the repository means every Musher repo agrees on where its product lives.

## The Placement Test

Ask in order and stop at the first "yes":

| # | Question | Level |
| --- | --- | --- |
| 1 | Does the product's native build or test read it, or does a product tool find it by walking up from the product? | Product |
| 2 | Does it describe the product's runtime interface: its env contract, API schemas, protocol? | Product |
| 3 | Does it act on the repository: collaboration, dev environment, CI, release, governance, human docs? | Repository |

Worked examples:

| File | Level | Why |
| --- | --- | --- |
| `rustfmt.toml`, `.cargo/config.toml`, `rust-toolchain.toml` | Product | cargo and rustup discover them from the working directory upward |
| `tsconfig.json`, `ruff.toml` for product code | Product | Same: walk-up discovery from the file being checked |
| Test fixtures, contract schemas, `proto/` | Product | The build or the tests read them |
| `env.schema.yaml` (runtime) | Product | It is the product's interface, see [The Env Contract](#the-env-contract) |
| `.config/markdown/markdownlint.jsonc` | Repository | Lints the repository's prose, passed by explicit path |
| `Taskfile.yml` | Repository | Orchestrates; reaches the product with `dir: '{{.PRODUCT_DIR}}'` |
| `.github/workflows/*`, `.devcontainer/*` | Repository | The tool mandates the location |
| `docs/` about the project | Repository | Written for people, not read by the build |

When the answer is genuinely both, as with a script CI and developers both run against the product, it goes up a
level and points down: repository machinery may name product paths, but the product never reaches upward.

## Declaring the Product

The product directory is declared once, in [`.repo/layout.toml`](.repo/layout.toml):

```toml
product = "host-agent"
```

- The value is a single path segment, and matches the repository name (`LAYOUT-03`).
- `product = ""` means *no product*: the state this template ships in. Rules that need a product skip; the rule that
  the root holds no product content still applies. A missing file or key is an error, not "no product", so deleting
  the declaration cannot silently switch the rules off.
- Nothing else can read this file: devcontainer.json, Dependabot and workflows need literal paths. So they state the
  product path literally, and `repo layout check` fails if any of them disagrees with the declaration.
- The Taskfile carries it as `PRODUCT_DIR: '{{.ROOT_DIR}}/<product>'`. That name is used across the org;
  "workspace" means something specific to Cargo and pnpm.

## Root Exceptions

A root file that `LAYOUT-05` would reject can be kept on purpose, with a reason, in `.repo/layout.toml`:

```toml
[root-exceptions]
"package.json" = "Repo-level tooling only (commitlint); the product has its own under host-agent/."
```

An exception without a reason, or one whose file is gone, fails `LAYOUT-06`: the list cannot quietly widen.

## Invariants

| # | Invariant | Enforced by |
| --- | --- | --- |
| 1 | Zero or one product directory, declared, existing, named after the repository | `LAYOUT-01`..`03` |
| 2 | The product directory contains its build manifest | `LAYOUT-04` |
| 3 | The root holds no manifest, lockfile, toolchain file, walk-up config or source tree | `LAYOUT-05`, `LAYOUT-06` |
| 4 | Machinery names the product by literal path, and each literal agrees with the declaration; no product-ecosystem Dependabot update scans the manifest-free root | `LAYOUT-07`..`09` |
| 5 | Every configured glob, directory and path var still resolves | `PATH-01`..`04`, `CFG-09` |
| 6 | The product declares its env contract at `<product>/env.schema.yaml`, in the shared shape | `LAYOUT-10`, `LAYOUT-11`, `ENV-01` |
| 7 | The product is self-contained: nothing in it references a path above it | Not yet enforced |
| 8 | Build output lives under the product, on a volume where the dev container provides one | Placement only (`LAYOUT-07`) |

Invariant 7 is documented rather than checked. A cheap detector scanning manifests for `../` would flag legitimate
cases such as Cargo's `license-file = "../LICENSE"`, and a real escape surfaces loudly anyway: the product stops
building when checked out on its own. The silent failures are what the checks target.

## The Env Contract

The environment a product reads at runtime is part of its interface, so it is declared beside the manifest:
`<product>/env.schema.yaml`. Not in a `config/` folder: `LAYOUT-11` fails a schema anywhere else, `config/`
included, and names the root location in its fix.

It is the canonical example of the placement test, because there are two env files with one word in common:

| File | Level | Read by |
| --- | --- | --- |
| `<product>/env.schema.yaml` | Product | The shipped product, at runtime |
| `.devcontainer/env.schema.yaml` | Repository | The dev environment, see CONFIGURATION.md |

Both share one minimal shape (`ENV-01`), the vocabulary Musher schemas already use:

```yaml
service: host-agent
runtime: rust
bindings:
  HOST_ID:
    type: string
    required: true
    sensitivity: internal     # public | internal | secret
    description: UUID of the host row this agent represents.
```

Top-level `service`, `runtime` and `bindings` are required; each binding needs `type`, `sensitivity` and
`description`, and `required` must be a boolean when present. Any richer vocabulary a product needs (formats,
generators, naming grammar) is its own to add; the shared check only asserts the common core.

## Why Moves Fail Silently

A layout change can preserve every line of code and still change what runs. None of these produce an error:

- **A glob that matches nothing.** A lefthook `glob:`, a paths-filter entry or a `.gitattributes` pattern that names a
  moved file just scopes its job to nothing.
- **Cargo from the wrong directory.** `cargo --manifest-path <product>/Cargo.toml` selects the manifest, not
  `.cargo/config.toml` or `rust-toolchain.toml`: both are discovered from the working directory upward. From the
  root, cargo silently uses the default toolchain and skips the linker config.
- **`defaults.run.working-directory`** applies to `run:` steps only. Action inputs (`with:`) still resolve from the
  repository root.
- **A build-output volume at the old path.** The build still works, now on the slow bind mount.
- **Dependabot scanning `/`.** It finds no manifest and opens no PRs, which looks exactly like "nothing to update".

That is why [Invariant](#invariants) 5 exists: `repo paths check` makes every such reference name something.

## Ecosystem Adapters

What each ecosystem needs once its manifest sits below the root. Rust is proven in the org (musher-dev/host-agent);
the others are the expected settings, to verify on first adoption and then record here.

| Concern | Rust (proven) | Node | Python | Go |
| --- | --- | --- | --- | --- |
| Tasks | `dir: '{{.PRODUCT_DIR}}'` on every task reaching cargo/rustup | `dir:` on npm/bun tasks | `dir:` on uv tasks | `dir:` on go tasks |
| Build-output volume | `<product>/target` | `<product>/node_modules` | `<product>/.venv` | Module cache is already global |
| Editor | `rust-analyzer.linkedProjects: ["<product>/Cargo.toml"]` (`LAYOUT-07`) | `eslint.workingDirectories` | `python.defaultInterpreterPath` | `go.work` at the product, or gopls `build.directoryFilters` |
| Dependabot | `cargo`, `directory: /<product>` (`LAYOUT-08`) | `npm`/`bun` | `pip`/`uv` | `gomod` |
| CI | `working-directory: <product>` on run steps; rust-cache `workspaces: <product> -> target` | `setup-node` `cache-dependency-path` | `setup-uv` `working-directory` | `setup-go` `go-version-file` |
| Release | release-please `extra-files` on `<product>/Cargo.toml` and `Cargo.lock` | package path in config | package path in config | Tags carry the module path |

Deno and Java follow the same shape. `LAYOUT-04` and `LAYOUT-05` recognise their manifests already.

A dev container mount for the product's build output looks like this:

```jsonc
"source=musher-${devcontainerId}-target,target=/workspaces/${localWorkspaceFolderBasename}/<product>/target,type=volume"
```

## Integration Compatibility Gate

Before adopting the layout, or a new tool once adopted, confirm the tool accepts a manifest below the root as
*configuration*. A setting is fine; a duplicated manifest, a sync shim or a patched tool is not.

When a tool cannot express it, use the tool's generic mechanism rather than moving the manifest back up:

| Tool | Limitation | Use instead |
| --- | --- | --- |
| release-please `cargo-workspace` plugin | Reads `Cargo.toml` and `Cargo.lock` from the root only | The `simple` strategy with `extra-files` jsonpath updates on `<product>/Cargo.toml` and `<product>/Cargo.lock` |

Add a row when you find the next one.

## Adopting the Layout

One structural PR, with no behaviour change riding along. The sequence host-agent used:

1. `git mv` the manifest, lockfile, toolchain and native configs, sources and product inputs into `<repo>/`.
2. Set `product = "<repo>"` in `.repo/layout.toml`.
3. Add `PRODUCT_DIR` to the Taskfile, and `dir: '{{.PRODUCT_DIR}}'` to every task that reaches the native toolchain.
4. Move the build-output mount and add the editor link in devcontainer.json.
5. Point Dependabot at `/<repo>`; add `working-directory` and action inputs in CI; update release config.
6. Run `repo check` until it is green. It lists every literal that still names the old layout.
7. Rebuild the dev container, so the build-output volume remounts at its new path.

## Out of Scope: Multi-Product Repos

This pattern covers repositories with one product. A repository with several peer products, such as
musher-dev/platform's `apps/` and `packages/` under a root `package.json`, is a different shape: its root *is* a
workspace root. Such a repository either stays at `product = ""` with `[root-exceptions]` recording why, or does not
adopt these checks. A multi-product variant will be designed when a second repository needs one.

## Evidence

What other projects did, and what each case does and does not show.

- **Noosphere and Fluence moved to the root under protest.** In
  [release-please#1724](https://github.com/googleapis/release-please/issues/1724) (opened 2022-10-26, still open), a
  developer with a workspace at `rust/Cargo.toml` passed an explicit path and release-please still could not process
  it; moving the manifest to the root worked, though they "would prefer to keep the Cargo.toml in the rust
  sub-directory". [fluencelabs/spell#10](https://github.com/fluencelabs/spell/pull/10) (merged 2022-12-13) made the
  same move for the same reason. *Shows:* one tool's root assumption can defeat configuration. *Not:* that nesting
  is unsound. The response is the [compatibility gate](#integration-compatibility-gate).
- **Flox moved its manifest up for convenience.** [flox#3997](https://github.com/flox/flox/pull/3997) (merged
  2026-02-13) moved `Cargo.toml` and `Cargo.lock` from `cli/` to the root so editors and tools needed no manifest
  path, and kept the packages under `cli/`. *Shows:* some teams prefer a root entry point. *Not:* a defect; the
  path configuration it removed is what this pattern accepts on purpose.
- **PyCA cryptography did the same.** [cryptography#11836](https://github.com/pyca/cryptography/pull/11836) (merged
  2024-10-27) moved the workspace manifest to the root so `cargo check` and `cargo fmt` work there. Same reading as
  Flox.
- **ZKsync moved the other way.** [zksync-era#3456](https://github.com/matter-labs/zksync-era/pull/3456) (merged
  2025-01-16) moved `Cargo.toml` from the root into `core/` to separate workspaces properly and satisfy a
  release-please component boundary. *Shows:* a nested build root can express a real ownership boundary.
- **musher-dev/host-agent is the in-org reference.** [host-agent#23](https://github.com/musher-dev/host-agent/pull/23)
  moved its Cargo workspace into `host-agent/` and shipped `scripts/check-path-refs.py` with it, because every path
  it missed failed silently. That script is where `repo paths check` came from.

No case found a defect in nesting itself. Every documented cost was a tool that equated "repository root" with
"build root", which is what the gate and the checks here exist to catch.
