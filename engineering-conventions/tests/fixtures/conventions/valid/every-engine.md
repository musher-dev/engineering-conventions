---
id: EC-0901
title: Every engine
summary: One requirement per validation engine, and a retired tombstone.
status: active
topic: example
applies_to:
  paths:
    - .github/workflows/*.yml
created: 2026-09-23
updated: 2026-09-24
owners:
  - "@octocat"
authority:
  repo: musher-dev/platform
  ref: https://github.com/musher-dev/platform/issues/1
migration: mirrored
implementations:
  - repo: musher-dev/platform
    check: CI-99
    mode: blocking
references:
  - title: An example reference
    url: https://example.com/reference
supersedes: [EC-0900]
requirements:
  - id: EXA-01
    title: A conftest requirement
    status: active
    severity: error
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.example.every_engine
    aliases: ["platform:CI-99"]
  - id: EXA-02
    title: A jsonschema requirement
    status: deprecated
    severity: warning
    since: 0.1.0
    validation:
      engine: jsonschema
      schema: checks/schemas/conventions-declaration.schema.json
  - id: EXA-03
    title: A vale requirement
    status: proposed
    severity: warning
    since: 0.2.0
    validation:
      engine: vale
      style: MusherConventions.Terms
  - id: EXA-04
    title: A delegated requirement
    status: proposed
    severity: warning
    since: 0.2.0
    validation:
      engine: delegated
      tool: actionlint
      check: actionlint
  - id: EXA-05
    title: A retired requirement
    status: retired
    severity: warning
    since: 0.1.0
    validation:
      engine: review
    replaced_by: [EXA-01]
---

# Every engine
