---
id: EC-0044
title: Tool strictness
summary: >-
  A tool's configuration starts from the tool's own preset and states every
  departure from it with a reason: yamllint extends default, markdownlint
  keeps its default rules, pyright checks at strict, a tsconfig.json turns
  strict on, Biome keeps its recommended rules and gitleaks its default
  rules. A tool's warnings fail the gate that runs it.
status: draft
topic: configuration
applies_to:
  paths:
    - .config/**
    - "**/pyproject.toml"
    - "**/pyrightconfig.json"
    - "**/tsconfig.json"
    - "**/biome.json"
    - "**/biome.jsonc"
    - Taskfile.yml
    - taskfiles/**
created: 2026-10-24
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "yamllint: Configuration"
    url: https://yamllint.readthedocs.io/en/stable/configuration.html
  - title: "markdownlint: Configuration"
    url: https://github.com/DavidAnson/markdownlint#optionsconfig
  - title: "Pyright: Configuration"
    url: https://microsoft.github.io/pyright/#/configuration
  - title: "basedpyright: Configuration"
    url: https://docs.basedpyright.com/latest/configuration/config-files/
  - title: "TypeScript: strict"
    url: https://www.typescriptlang.org/tsconfig/#strict
  - title: "Biome: Configuration"
    url: https://biomejs.dev/reference/configuration/
  - title: "gitleaks: Configuration"
    url: https://github.com/gitleaks/gitleaks#configuration
requirements:
  - id: CONF-16
    title: A yamllint configuration extends the default preset
    status: proposed
    severity: warning
    since: 0.9.2
    validation:
      engine: conftest
      package: conventions.checks.configuration.tool_strictness
  - id: CONF-17
    title: A markdownlint configuration keeps the default rules on
    status: proposed
    severity: warning
    since: 0.9.2
    validation:
      engine: conftest
      package: conventions.checks.configuration.tool_strictness
  - id: CONF-18
    title: pyright and basedpyright check types at strict or above
    status: proposed
    severity: warning
    since: 0.9.2
    validation:
      engine: conftest
      package: conventions.checks.configuration.tool_strictness
  - id: CONF-19
    title: A tsconfig.json turns strict on
    status: proposed
    severity: warning
    since: 0.9.2
    validation:
      engine: conftest
      package: conventions.checks.configuration.tool_strictness
  - id: CONF-20
    title: A Biome configuration keeps the recommended rules on
    status: proposed
    severity: warning
    since: 0.9.2
    validation:
      engine: conftest
      package: conventions.checks.configuration.tool_strictness
  - id: CONF-21
    title: A gitleaks configuration that extends keeps the default rules
    status: proposed
    severity: warning
    since: 0.9.2
    validation:
      engine: conftest
      package: conventions.checks.configuration.tool_strictness
  - id: CONF-22
    title: A tool's warnings fail the gate that runs it
    status: proposed
    severity: warning
    since: 0.9.2
    validation:
      engine: review
  - id: CONF-23
    title: Every departure from a tool's preset carries its reason beside it
    status: proposed
    severity: warning
    since: 0.9.2
    validation:
      engine: review
---

# Tool strictness

Every linter, type checker and scanner ships a preset: the rule set its authors maintain, tune and extend from release
to release. A configuration that starts from nothing and lists the rules it wants, or that turns the preset off,
freezes the rule set on the day it was written; every rule the tool adds afterwards is silently not run. A
configuration that starts from the preset and turns off what does not fit, each with its reason, keeps getting
stricter as the tool improves, and tells a reviewer exactly where the repository departs from the tool's own
judgment. This convention sets that floor for the tools whose configuration a check can read, and the two rules every
tool follows.

## Scope

This convention covers what a tool's configuration *contains*: which preset it starts from and how its departures are
written. Where the configuration lives is [EC-0011](tool-configuration.md); how an ignore file's entries are
justified and expired is [EC-0012](suppressions.md). It covers the repository's quality configuration in `.config/`
and the product's language toolchain wherever it lives (`pyproject.toml`, `tsconfig.json`, `biome.json`).

It sets a floor, not a ceiling. Nothing here asks for every rule a tool has: Ruff's `select = ["ALL"]` or
basedpyright's `all` turn on rules that contradict each other or that a tool's own authors mark as matters of
taste, and a repository that adopts one spends its time writing exceptions. A repository may pick a stricter
preset where the tool has one; it may not start below the floor.

Two floors are set where the tool's whole convention is:

- **hadolint**: the failure threshold and the rules turned off, in [IMAGE-07](../container-images/dockerfile-linting.md#image-07).
- **actionlint and zizmor**: the severity and persona the audit runs at, in [GHA-33](../github-actions/execution-hygiene.md#gha-33).

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirements are `proposed` at
severity `warning`, like every requirement in the 0.x series.

## The floor

| Tool | Configuration it reads | Floor | Requirement |
| --- | --- | --- | --- |
| yamllint | `yamllint.yaml` | `extends: default` | CONF-16 |
| markdownlint | `markdownlint.jsonc`, `markdownlint-cli2.jsonc` | `default` not `false` | CONF-17 |
| pyright, basedpyright | `[tool.pyright]`, `[tool.basedpyright]`, `pyrightconfig.json` | `typeCheckingMode` `strict`, or basedpyright's `recommended` or `all` | CONF-18 |
| TypeScript | `tsconfig.json` | `compilerOptions.strict: true` | CONF-19 |
| Biome | `biome.json`, `biome.jsonc` | `linter.rules.recommended` not `false` | CONF-20 |
| gitleaks | `gitleaks.toml` | an `[extend]` sets `useDefault = true` | CONF-21 |
| hadolint | `hadolint.yaml` | [IMAGE-07](../container-images/dockerfile-linting.md#image-07) | |
| actionlint, zizmor | `actionlint.yaml`, `zizmor.yml` | [GHA-33](../github-actions/execution-hygiene.md#gha-33) | |
| Every tool | its configuration and its caller | warnings fail; every departure has a reason | CONF-22, CONF-23 |

The checks read the configurations under `.config/`, a root configuration where the tool finds one by itself, a
`pyproject.toml` up to two directories deep, and a `tsconfig.json`, `pyrightconfig.json` or `biome.json` up to three.
A configuration that `extends` another file is judged only on what it sets itself: the file it extends is not
followed.

## Requirements

### CONF-16

**A yamllint configuration extends the `default` preset.**

A yamllint configuration with no `extends` runs only the rules it lists, and `relaxed` lowers most of the rest to
warnings or turns them off, so a new rule in yamllint's `default` never reaches the repository. Extend `default`, and
relax or disable a rule under `rules:` with its reason beside it. A configuration that extends another file by path is
not judged.

**Correct:**

```yaml
extends: default

rules:
  # GitHub Actions requires the key `on:`, which YAML 1.1 reads as boolean true.
  truthy:
    check-keys: false
```

**Incorrect:**

```yaml
rules:
  line-length:
    max: 120
```

Checked by: conftest · Severity: warning · Since: 0.9.2

### CONF-17

**A markdownlint configuration keeps the default rules on.**

`"default": false` turns off every rule the configuration does not name, so the file becomes an allow list that new
markdownlint rules never join. Leave `default` unset or `true`, and turn off a rule by name with its reason. In a
`markdownlint-cli2` configuration the rules sit under `config`, and the same applies there.

**Correct:**

```jsonc
{
  "default": true,
  // Bare URLs are fine in reference docs where the URL is the content.
  "MD034": false
}
```

**Incorrect:**

```jsonc
{
  "default": false,
  "MD001": true,
  "MD003": true
}
```

Checked by: conftest · Severity: warning · Since: 0.9.2

### CONF-18

**pyright and basedpyright check types at `strict` or above.**

pyright's default mode, `standard`, accepts untyped functions, unknown types and missing imports that `strict` reports,
and code that type-checks below strict is code a later change to strict has to fix all at once. Set
`typeCheckingMode = "strict"` in `[tool.pyright]`, `[tool.basedpyright]` or `pyrightconfig.json`; basedpyright's own
`recommended` and `all` are above the floor, and `recommended` is the default of a `[tool.basedpyright]` section. Turn
off a rule by name, with its reason, rather than lowering the mode. A `[tool.pyright]` section or a
`pyrightconfig.json` that sets no mode is reported, because pyright reads it at `standard`.

**Correct:**

```toml
[tool.basedpyright]
typeCheckingMode = "strict"
```

**Incorrect:**

```toml
[tool.pyright]
typeCheckingMode = "basic"
```

Checked by: conftest · Severity: warning · Since: 0.9.2

### CONF-19

**A `tsconfig.json` turns `strict` on.**

`strict` is TypeScript's own floor: it turns on `strictNullChecks`, `noImplicitAny` and the rest of the family, and
each TypeScript release adds to it. A project without it accepts `null` where a value is required and `any` wherever
inference gives up. Set `compilerOptions.strict` to `true`, and turn off one member of the family by name with its
reason. A `tsconfig.json` that `extends` another and leaves `strict` unset inherits it and is not judged; one that sets
`strict` to `false` is reported either way.

**Correct:**

```jsonc
{
  "compilerOptions": {
    "strict": true
  }
}
```

**Incorrect:**

```jsonc
{
  "compilerOptions": {
    "target": "es2022"
  }
}
```

Checked by: conftest · Severity: warning · Since: 0.9.2

### CONF-20

**A Biome configuration keeps the recommended rules on.**

Biome's recommended set is the rules its authors judge right for every project, and it grows with each release.
`"recommended": false` turns all of them off except the ones the file names. Leave it unset or `true`, and turn off a
rule by name with its reason.

**Correct:**

```jsonc
{
  "linter": {
    "rules": {
      "recommended": true
    }
  }
}
```

**Incorrect:**

```jsonc
{
  "linter": {
    "rules": {
      "recommended": false,
      "suspicious": { "noDebugger": "error" }
    }
  }
}
```

Checked by: conftest · Severity: warning · Since: 0.9.2

### CONF-21

**A gitleaks configuration that extends keeps the default rules.**

An `[extend]` section is how a gitleaks configuration adds to a base. Without `useDefault = true`, and without a `path`
to another configuration, the base is empty and the scan runs only the rules the file defines, so every secret format
gitleaks learns to recognise is missed. Set `useDefault = true`, and allowlist a finding with its reason rather than
dropping the rules that found it. An `[extend]` with a `path` is not judged.

**Correct:**

```toml
[extend]
useDefault = true
```

**Incorrect:**

```toml
[extend]
disabledRules = ["generic-api-key"]
```

Checked by: conftest · Severity: warning · Since: 0.9.2

### CONF-22

**A tool's warnings fail the gate that runs it.**

A warning that never fails anything is read once and then scrolls past in every run, and the next one joins it. Run
each tool so that what it reports fails the task, the hook and the CI job that call it: yamllint with `--strict`, Regal
with `--fail-level warning`, Vale with no alert passing silently, hadolint at its configuration's
`failure-threshold`. A rule that should not fail the gate is turned off in the configuration with its reason
(CONF-23), not left to warn.

**Correct:**

```yaml
lint:yaml:
  cmds:
    - yamllint -c .config/yaml/yamllint.yaml --strict .
```

**Incorrect:**

```yaml
lint:yaml:
  cmds:
    - yamllint -c .config/yaml/yamllint.yaml .   # warnings print and pass
```

Checked by: review · Severity: warning · Since: 0.9.2

### CONF-23

**Every departure from a tool's preset carries its reason beside it.**

A rule turned off, a threshold relaxed or a word added to a dictionary is a decision about the repository, and the next
reader cannot tell a deliberate one from a workaround nobody revisited. Write the reason as a comment on the line above
the setting, in the configuration itself. A setting that only restates the preset is no departure and is deleted. A
check cannot hold this yet: the parsers the checks use drop comments, so a reviewer looks for one comment per
setting that differs from the preset.

**Correct:**

```toml
[default.extend-words]
# Both spellings are standard; this one is the usual one in programming prose.
unparseable = "unparseable"
```

**Incorrect:**

```toml
[default.extend-words]
unparseable = "unparseable"
```

Checked by: review · Severity: warning · Since: 0.9.2

## Rationale

A tool's preset is maintained by the people who know the tool best and is improved in every release; a hand-picked
list is maintained by whoever last edited it. Starting from the preset makes a tool upgrade the way a repository gets
stricter, and the reasons beside each departure make that upgrade reviewable: a new release that reports something
the repository already decided against is turned off with one more line and its reason. Making warnings fail removes
the third state between passing and failing, which is where findings accumulate.

## References

- [yamllint: Configuration](https://yamllint.readthedocs.io/en/stable/configuration.html), the `default` and
  `relaxed` presets
- [markdownlint: Configuration](https://github.com/DavidAnson/markdownlint#optionsconfig), `default`
- [Pyright: Configuration](https://microsoft.github.io/pyright/#/configuration) and
  [basedpyright: Configuration](https://docs.basedpyright.com/latest/configuration/config-files/), `typeCheckingMode`
- [TypeScript: strict](https://www.typescriptlang.org/tsconfig/#strict)
- [Biome: Configuration](https://biomejs.dev/reference/configuration/), `linter.rules.recommended`
- [gitleaks: Configuration](https://github.com/gitleaks/gitleaks#configuration), `[extend]`
