# `.repo/` — Repository Governance

The structural policies this repo enforces on itself, and the `repo` CLI that
runs them.

The `.repo/` prefix mirrors `.github/` and `.devcontainer/`: infrastructure that
operates on the repository rather than being part of its content. It is
deliberately not `tools/` (junk-drawer risk) or `scripts/` (names the
implementation, not the purpose).

## Why this exists

This repository is a template. Whatever layout it ships is replicated into every
repo scaffolded from it, so a convention that holds only while someone remembers
it will not hold. The policies here turn the layout rules into something that
fails a build instead of a code review.

That choice has a cost worth stating: a checker enforces *what*, not *why*. So
every violation this CLI reports carries its own rationale and the action that
resolves it — the `reason` and `fix` fields are not decoration, they are the
documentation. The prose version lives in
[`CONFIGURATION.md`](../CONFIGURATION.md).

## Use

```bash
task repo:check            # every policy (this is what CI and pre-commit run)
task repo:check:config     # one policy
repo check                 # same thing, without Task
repo config check
```

The CLI is installed by the devcontainer bootstrap
(`base_install_repo_cli` in `.devcontainer/scripts/lib/base-setup.sh`, which
runs `uv tool install ./.repo`). To reinstall after editing it:
`task repo:install` — it passes `--reinstall`, because uv otherwise reuses the
cached build of an unchanged version and your edit never takes effect.

## Policies

| Policy | Codes | Enforces |
| --- | --- | --- |
| `config` | `CFG-01`..`CFG-09` | Tool config lives in `.config/<concern>/` buckets, every file is indexed and has a caller, every caller's path exists, nothing at the root shadows it, no executables |
| `layout` | `LAYOUT-01`..`LAYOUT-11` | The root holds no product content; the declared product dir exists, is named after the repo, has its manifest and `env.schema.yaml`; mounts, Dependabot and `PRODUCT_DIR` agree with the declaration ([LAYOUT.md](../LAYOUT.md#invariants)) |
| `paths` | `PATH-01`..`PATH-04` | Every lefthook glob, `.gitattributes` pattern, paths-filter, `working-directory`, Dependabot directory and Taskfile path var still names something |
| `env` | `ENV-01` | Every `env.schema.yaml` has the shared shape ([LAYOUT.md](../LAYOUT.md#the-env-contract)) |
| `ports` | `PORT-01`..`PORT-05` | The port table, `forwardPorts`/`portsAttributes`, and compose published ports all agree and stay in the reserved range |
| `hooks` | `HOOK-01`..`HOOK-04` | Every lefthook job has a CI counterpart and vice versa, or a recorded reason why not |
| `rulesets` | `RS-01`..`RS-04` | Committed branch rulesets stay valid and in step with the CI jobs they require |
| `toolchain` | `TC-01`..`TC-03` | The tools the image bakes stay out of the Features block, keep exact pins, and stay in step with CI |
| `comments` | `CMT-01`..`CMT-03` | Comment blocks stay short, the allowlist stays honest, and every `docs:` pointer still resolves |

### Why `toolchain` exists

`TC-01` is the policy least likely to be guessed from the code it guards: bun, uv and
task are installed by [`.devcontainer/Dockerfile`](../.devcontainer/Dockerfile) rather
than by their Features, because those Features fail on rate-limited build hosts.
Re-adding one looks like a harmless simplification, which is exactly why it is a check.
Full account: [`CONFIGURATION.md`](../CONFIGURATION.md) → "Runtimes & Tools".

### The one-way-check tables

`hooks` is the policy most likely to be argued with, so its exceptions are
explicit. `LOCAL_ONLY` and `CI_ONLY` in
[`policies/hooks/check.py`](governance/policies/hooks/check.py) list
every check that deliberately runs in only one place, each with a reason —
`build` is minutes long, `compose` needs a Docker daemon, `block-devcontainer-env`
has nothing to assert in CI. Adding a job on either side without registering it
fails `HOOK-01`/`HOOK-03`, and an entry that outlives what it excused fails
`HOOK-04`. The allowlist cannot quietly widen.

## Layout

```text
.repo/
  pyproject.toml                 uv project; declares the `repo` console-script
  layout.toml                    The product declaration -- this repo's data
  tests/                         pytest suite; fixtures are built in tmp_path
  governance/
    cli.py                       Argument parsing and exit codes
    reporting.py                 The Violation record and its rendering
    repo.py                      Repo-root discovery, YAML/JSONC/TOML readers, tracked files
    globs.py                     Glob matching shared by the path policies
    envschema.py                 The shared env.schema.yaml shape
    policies/
      __init__.py                The policy registry
      <name>/
        violations.py            What can go wrong, and why the rule exists
        check.py                 Whether it has gone wrong
```

Each policy splits declaration from detection on purpose: `violations.py` is
where the reasoning lives and is the file to read first when a check fires.
The shared `Violation` and `Report` primitives are in `reporting.py` -- named
so that it is never confused with a policy's own `violations.py`.

There is no `src/` directory. Its purpose is to stop Python from importing a
local source tree in place of the installed package, which only happens when
the package sits in the working directory -- and this one sits under `.repo/`,
which is never where anyone works. `.repo/` already provides the separation,
so `src/` would only add a level to every path.

`layout.toml` is the one file under `.repo/` that belongs to the repository
rather than the template: `governance/` is code that syncs from the template,
`layout.toml` is what this repository declares about itself. Keeping them apart
is what lets the code update without merge conflicts.

## Tests

Most `layout` rules only fire once a product is declared, which the template
never does, so `repo check` passing here proves little about them. The suite
builds a throwaway git repository per case and asserts each code fires:

```bash
task repo:test             # uv run --project .repo --group dev pytest .repo/tests
```

## Adding a policy

1. Create `policies/<name>/` with `violations.py`, `check.py`, and an
   `__init__.py` re-exporting `run`.
2. `run()` returns a `Report`; give every violation a stable code, a `reason`,
   and a `fix`.
3. Register it in `POLICIES` in `policies/__init__.py` — it joins `repo check`
   and gains a `repo <name> check` subcommand automatically. That is the only
   wiring; `cli.py` never names an individual policy.
4. Add a row to the table above, and a test under `tests/` for every code.

## The `env` group

`env` is the one policy with developer commands beside its check, because the
schema it validates is also what renders `.devcontainer/.env.example` and what
tells a developer which values are still missing:

```bash
repo env check     # policy: shape, rendering freshness, compose parity (CI)
repo env doctor    # local: what the enabled stacks still need
repo env setup     # local: fill it in, interactively
repo env sync      # local: add new bindings, mint local secrets
repo env render    # local: rewrite .env.example from the schema
```

The check half is blocking and reads only tracked files. The other four read
the developer's gitignored `.env`, so they are never part of `repo check`.
This is also what retired `.devcontainer/scripts/lib/env-check.sh`, whose
parity job ENV-02 now does from the schema.
