---
paths:
  - ".config/mise/**"
  - "engineering-conventions/bin/conventions"
  - ".devcontainer/Dockerfile"
  - ".github/actions/setup-tools/**"
  - ".config/lefthook.yml"
---

# Toolchain pins

`.config/mise/config.toml` pins every CLI this repository runs
(docs/repository.md → "Toolchain"). The only exceptions are the lockstep
pairs below, which mise cannot express.

## Rules

- **MUST** pin a new CLI in `.config/mise/config.toml` with a fully qualified
  backend (`aqua:owner/repo`, `pipx:`, `npm:`), and nowhere else.
- **MUST NOT** add a tool to the Dockerfile. It bakes mise only, because mise
  cannot pin itself.
- **MUST NOT** point mise at its config with `MISE_GLOBAL_CONFIG_FILE` or a
  flag. mise discovers `.config/mise/config.toml` itself.
- **MUST** commit `.config/mise/mise.lock` and `.config/mise/locks/` in the
  same commit as the pin they lock. Every install runs `--locked`, so a stale
  lockfile fails the install.
- **MUST** move each lockstep pair in the same commit:

| Pin | Must equal | Why |
| --- | --- | --- |
| `ARG MISE_VERSION` in `.devcontainer/Dockerfile` (without its `v`) | `version:` of `jdx/mise-action` in `.github/actions/setup-tools/action.yml`, and `min_version` in `.config/mise/config.toml` | The container and CI must resolve pins with the same mise, and an older mise must refuse the config |
| `aqua:open-policy-agent/opa` | The OPA version the pinned conftest embeds (`conftest --version`) | `opa test` locally and `conftest` for consumers must evaluate the same language |
| `aqua:evilmartians/lefthook` | `min_version` in `.config/lefthook.yml` | The hook config uses what that version supports |
| `aqua:open-policy-agent/conftest`, `aqua:vale-cli/vale`, `aqua:jqlang/jq`, `aqua:stoplightio/spectral`, `aqua:hadolint/hadolint` | `CONFTEST_VERSION`, `VALE_VERSION`, `JQ_VERSION`, `SPECTRAL_VERSION`, `HADOLINT_VERSION` in `engineering-conventions/bin/conventions` | Consumers run the checks with the versions this repository tested them with (`tests/test_launcher.py` fails otherwise) |

- **MUST** run `task tools:lock`, `task tools:install`, then
  `task tools:doctor`, after changing a pin.

## Enforced vs reviewed

| Rule | How |
| --- | --- |
| Installed versions match the pins | `task tools:doctor` (`verify-toolchain.sh`), the Dev Container CI job |
| opa and conftest agree | `task checks:test` (`conftest verify` runs the tests under conftest's OPA) |
| lefthook is new enough | lefthook refuses to run below `min_version` |
| mise is new enough | mise refuses to load the config below `min_version` |
| The lockfile covers every pin | `mise install --locked` (`task tools:install`, `setup-tools`) |
| mise versions agree, backends qualified, versions exact | `task conventions:self` (TOOL-02, TOOL-03, TOOL-04, EC-0017) |
| `.python-version` equals the python pin | `task conventions:self` (TOOL-11) |
