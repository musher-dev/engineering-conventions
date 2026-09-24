---
paths:
  - ".github/workflows/**"
  - ".github/actions/**"
---

# GitHub workflows and actions

This repository publishes the GitHub Actions conventions, so its own workflows
are held to them first. This file routes; it restates none of them.

- **The conventions**: `engineering-conventions/definitions/conventions/github-actions/`,
  one document per concern (workflow files, jobs and steps, composite actions,
  execution hygiene, units and renames). Every `GHA-NN` a check prints links to
  its heading there.
- **The vocabulary**: `engineering-conventions/definitions/terminology/global.yml`, which
  holds the responsibility, capability and action tokens and the display forms.
- **The proof**: `task conventions:self` runs this repository through its own
  conventions and MUST report zero findings, warnings included. There are no waivers
  in `.repo/conventions.yaml`, and adding one here needs a very good reason.
- **Security**: `task lint:actions` (actionlint) and `task lint:actions:security`
  (zizmor, config in `.config/actions/zizmor.yml`).
- **Tools in CI**: installed only through `.github/actions/setup-tools`, the one
  `jdx/mise-action` reference, from `.devcontainer/mise.toml`. MUST NOT install
  a tool any other way.
- **Required checks**: `.github/rulesets/RULESETS.md`. A new gate joins the
  `Validate / Required` aggregate; renaming a job that a ruleset lists breaks
  every open PR (GHA-36).

## Enforced vs reviewed

| Rule | How |
| --- | --- |
| The GHA conventions | `task conventions:self` |
| Workflow and action security | `task lint:actions lint:actions:security` |
| Workflow schema, job timeouts | `task schemas:validate` |
| Choosing a unit, naming for responsibility (GHA-34..37) | Review |
