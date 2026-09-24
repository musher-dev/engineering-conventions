---
paths:
  - "engineering-conventions/definitions/terminology/**"
  - "engineering-conventions/checks/vale/**"
---

# Terminology

`definitions/terminology/` is the source for three things at once: the
vocabulary the Rego checks read (`index.json`), the MusherConventions Vale
style, and the words the conventions use. Change it here and regenerate; never edit an output.

## Rules

- **MUST NOT** hand-edit `checks/vale/MusherConventions/**`. `task generate`
  writes it from `definitions/terminology/`; `task generate:check` fails on drift.
- **MUST** keep a term's `id` stable; it is referenced from outside this file.
- **MUST** point at the owner instead of restating a definition this
  repository does not own: an `authority` entry carries no `definition`.
- **MUST NOT** mirror positioning vocabulary, a customer glossary, platform
  domain nouns or telemetry names. They stay with their owners
  (docs/decisions/0000-charter.md).
- **MUST** classify a terminology change, and read what `provisional`
  stability permits, from the one table in
  docs/decisions/0005-status-severity-and-versioning.md. A terminology change
  is never `docs`.
- Words are checked against the platform's and the orchestrators' vocabularies
  (Temporal, Nomad, Kubernetes) before a new one is added.

## Enforced vs reviewed

| Rule | How |
| --- | --- |
| Shape | `task schemas:validate` |
| Overlays never redefine a global term | `task invariants` |
| Vale style and index current | `task generate:check` |
| This repository's prose uses the terms | `task prose:lint` |
| Collision check, what not to mirror | Review |
