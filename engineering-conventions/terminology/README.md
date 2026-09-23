# Terminology

The words the conventions are written in, and the naming vocabulary their
checks enforce. Terms are data, so the same list drives the Rego checks, the
Vale style and this documentation; nothing restates it by hand.

| File | What it holds |
| --- | --- |
| [`global.yml`](global.yml) | Every term that applies everywhere |
| [`areas/`](areas/README.md) | Area overlays: terms that apply to one part of the organisation |

Both are validated against
[`terminology.schema.json`](../checks/schemas/terminology.schema.json).

## The model

A **term** has a permanent `id` (`gha.responsibility.validate`), the
`display_name` used in prose, `tags` that group it, and a `stability`,
`stable` or `provisional`. In the 0.x series a `provisional` term may still
change in a minor release; from 1.0.0, removing any term is a major change.
How each kind of terminology change is released is the table in
[decision 0005](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0005-status-severity-and-versioning.md#change-classification).
A term that names an identifier token, such as a
workflow responsibility, also carries that `token`.

A term either **defines** itself (`definition`) or **points** at the document
that does (`authority`). Never both: a definition lives in exactly one place.

An **alias** is a word to avoid in favour of the term:

- `status: banned` is reported at the severity of the check that reads it
  (GHA-05 for filename tokens; an error in the Vale style);
  `status: discouraged` warns.
- `scope` says where the alias is checked. `identifier` means filenames,
  directory names and IDs, which the conventions that govern them check (for
  example GHA-05 for workflow filenames). `prose` means documentation, which
  the `MusherConventions` Vale style checks.
- `suggest` says what to write instead when that is not simply the term: its
  `token` in an identifier, its `display_name` in prose.

A **display form** says how a token is written when a display name is derived
from it: `api` is written `API`, so `deploy-api.yml` is named `Deploy API`.

## What is generated from it

`conventions generate` projects this directory into committed artifacts:

| Source | Generated |
| --- | --- |
| Terms tagged `gha.responsibility`, `gha.capability`, `gha.action` | the token lists in `checks/data/index.json` |
| Banned `identifier` aliases | `banned_identifier_tokens` in `checks/data/index.json` |
| `display_forms` | `display_forms` in `checks/data/index.json` |
| Banned `prose` aliases | `checks/vale/MusherConventions/Terms.yml` (error) |
| Discouraged `prose` aliases | `checks/vale/MusherConventions/Discouraged.yml` (warning) |

A consuming repository may add display forms of its own in its conventions
declaration (`vocabulary.display_forms`); it cannot remove or change these.

## Overlays add, never redefine

An area overlay may **add** terms, aliases on global terms (`extend`), and
display forms. It may never **redefine** anything global: a term ID, a
display form token, or an alias already owned by another term. `conventions
invariants` enforces this.

## Authority references

Some terms are defined by another repository and matter here only because
the conventions use them. Those entries carry `authority: {repo, path}`
instead of a definition, so a reader can follow the link and nobody can
drift a second copy. `audit`, `drift`, `gate` and `conformance` are listed
this way, pointing at the platform's terminology rule.

GitHub Actions uses two of those words in a narrower, automation sense. That
sense is a separate term with its own ID: `gha.responsibility.audit` (a
workflow responsibility) and the `drift` alias of `gha.responsibility.monitor`
(a banned filename token). The IDs never overlap, so one definition cannot
leak into the other.

## What is not mirrored here

These vocabularies stay with the repository that owns them, and are not
copied or checked here:

- Product positioning and the words it bans.
- The customer-facing glossary.
- Platform domain nouns (the bounded-context language of the platform).
- Telemetry attribute and metric names.

Their owners' own checks enforce them. A term from one of them appears here
only as an authority reference, and only when a convention needs it.
