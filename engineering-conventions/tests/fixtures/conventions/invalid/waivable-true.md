---
id: EC-0908
title: Waivable true
summary: Only waivable false is meaningful, so the schema rejects an explicit true.
status: draft
topic: example
applies_to:
  paths: ["**/*"]
created: 2026-10-24
authority: self
migration: authoritative
requirements:
  - id: EXA-01
    title: Something
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: review
    waivable: true
---

# Waivable true
