---
paths:
  - ".devcontainer/mise.toml"
  - ".devcontainer/Dockerfile"
  - ".github/actions/setup-tools/**"
  - ".config/lefthook.yml"
---

# Toolchain pins

`.devcontainer/mise.toml` is the single anchor for every CLI this repository
runs: the dev container, a local `task` run and CI (through
`.github/actions/setup-tools`) all install from it. A version lives in exactly
one place, except for the lockstep pairs below, which mise cannot express.

## Rules

- **MUST** pin a new CLI in `.devcontainer/mise.toml` with a fully qualified
  backend (`aqua:owner/repo`, `pipx:`, `npm:`), and nowhere else.
- **MUST NOT** add a tool to the Dockerfile. It bakes mise only, because mise
  cannot pin itself.
- **MUST** move each lockstep pair in the same commit:

| Pin | Must equal | Why |
| --- | --- | --- |
| `ARG MISE_VERSION` in `.devcontainer/Dockerfile` | `version:` of `jdx/mise-action` in `.github/actions/setup-tools/action.yml` | The container and CI must resolve pins with the same mise |
| `aqua:open-policy-agent/opa` | The OPA version the pinned conftest embeds (`conftest --version`) | `opa test` locally and `conftest` for consumers must evaluate the same language |
| `aqua:evilmartians/lefthook` | `min_version` in `.config/lefthook.yml` | The hook config uses what that version supports |

- **MUST** run `task tools:install`, then `task tools:doctor`, after changing a
  pin.

## Enforced vs reviewed

| Rule | How |
| --- | --- |
| Installed versions match the pins | `task tools:doctor` (`verify-toolchain.sh`), the Dev Container CI job |
| opa and conftest agree | `task checks:test` (`conftest verify` reruns the tests under conftest's OPA) |
| lefthook is new enough | lefthook refuses to run below `min_version` |
| mise pair, backends qualified | Review |
