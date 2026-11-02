---
paths:
  - "engineering-conventions/checks/rego/**"
---

# Rego checks

The contract for `engineering-conventions/checks/rego/`: the conftest checks that
implement every `engine: conftest` requirement. Consumers run these files with
conftest and nothing else, so what is written here is what a consumer executes.

## Rules

- **MUST** keep a check pure. A package under `conventions.checks.<topic>.<convention>`
  (the topic with `_` for `-`, such as `github_actions`) defines only `findings contains f if { ... }`, with
  `f := {"id", "path", "message"}`. Severity, profiles, waivers and time belong to
  `package main` alone, so changing a severity is a frontmatter edit, never a
  Rego change.
- **MUST** emit a requirement ID that the convention's frontmatter declares, and
  carry `# METADATA` with `custom.convention: EC-NNNN` on the package.
- **MUST** write a `message` a reader can act on without the URL: what is wrong
  and what to change it to.
- **MUST** ship a fixture repo for every requirement a check emits, a passing
  near-miss (`<id-lower>-passes-<slug>/`) for one first released after 0.6.2,
  and a current `tests/fixtures/findings.snapshot.json`, whose diff you read.
  A changed message is a `fix`. The procedure is docs/authoring.md, "Adding a
  requirement", steps 5 and 6.
- **MUST** keep the shared test index in `lib/testdata_test.rego` to the real
  index's shape; `lib/testdata_shape_test.rego` fails when it drifts.
- **MUST** put a `*_test.rego` beside every policy file. `task checks:test` fails
  below 80% coverage and on zero tests.
- **MUST** use OPA v1 syntax (`if`, `contains`) and no conftest-only builtins
  (`parse_config*`), so `opa check`, `opa test` and `conftest` all load the same
  files.
- **MUST** handle a workflow's trigger key both ways: unquoted `on:` arrives as
  `"true"` (YAML 1.1), quoted `"on":` as `"on"`.
- **MUST NOT** hand-edit `checks/data/index.json`; the checks read it as
  `data.conventions.index`, and `task generate` writes it.
- **MUST NOT** silence Regal inline. A rule that is wrong for this repository is
  turned off in `.config/rego/regal.yaml`, with the reason beside it.

## Enforced vs reviewed

| Rule | How |
| --- | --- |
| Formatting | `task checks:fmt:check` (opa fmt) |
| Lint, v1 syntax | `task checks:lint` (Regal), `task checks:compile` (`opa check --strict`) |
| Tests exist and cover | `task checks:test` (`conftest verify`, then one `opa test` pass with the coverage threshold and `--fail-on-empty`) |
| Declared IDs, fixture per requirement | `task cli:test` (fixture repos), `task cli:invariants` |
| Near-miss per new requirement | `task cli:invariants` |
| Messages, links, duplicate findings | `task cli:test` (findings snapshot, per-finding checks in `fixtures.py`) |
| Shared test index matches the real one | `task checks:test` (`lib/testdata_shape_test.rego`) |
| Purity, actionable messages | Review |
