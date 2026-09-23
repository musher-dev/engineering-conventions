---
id: EC-0903
title: Conftest without package
summary: A conftest requirement must name its package.
status: draft
topic: example
applies_to:
  paths: ["**/*"]
created: 2026-09-23
authority: self
migration: authoritative
requirements:
  - id: EXA-01
    title: Checked by nothing
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
---

# Conftest without package
