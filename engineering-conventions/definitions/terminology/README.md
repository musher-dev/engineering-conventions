# Terminology

The words the conventions are written in, and the naming vocabulary their
checks enforce. Terms are data, so the same list drives the Rego checks, the
Vale style and this documentation; nothing restates it by hand.

| File | What it holds |
| --- | --- |
| [`global.yml`](global.yml) | Every term the conventions use |

It is validated against
[`terminology.schema.json`](../../checks/schemas/terminology.schema.json).

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
  the `MusherConventions` Vale style checks. `repository-name` means a token
  of a repository's own name, which REPO-10 checks; its `note` is required,
  because the check prints it as the advice. `action-token` means a word that
  stands in for an action token as the first token of a composite action's
  directory, such as `auth` for `authenticate`; GHA-20 suggests the term's
  token in its place. Each scope is projected on its own, so a token banned
  in repository names is not banned in filenames or prose, and an
  `action-token` alias such as `validate` stays a valid workflow
  responsibility token.
- `suggest` says what to write instead when that is not simply the term: its
  `token` in an identifier, its `display_name` in prose.

A **display form** says how a token is written when a display name is derived
from it: `api` is written `API`, so `deploy-api.yml` is named `Deploy API`.

## What is generated from it

`conventions generate` projects this directory into committed artifacts:

| Source | Generated |
| --- | --- |
| Terms tagged `gha.responsibility`, `gha.capability`, `gha.action`, `outputs.kind` | the token lists in `checks/data/index.json` |
| Terms tagged `repository.system`, `repository.kind`, `repository.lifecycle`, `repository.audience` | `repository_systems`, `repository_kinds`, `repository_lifecycles`, `repository_audiences` in `checks/data/index.json` |
| Banned `identifier` aliases | `banned_identifier_tokens` in `checks/data/index.json` |
| Banned `repository-name` aliases, with their notes | `banned_repository_tokens` in `checks/data/index.json` |
| Banned `action-token` aliases, each with its term's token | `action_synonyms` in `checks/data/index.json` |
| `display_forms` | `display_forms` in `checks/data/index.json` |
| Banned `prose` aliases | `checks/vale/MusherConventions/Terms.yml` (error) |
| Discouraged `prose` aliases | `checks/vale/MusherConventions/Discouraged.yml` (warning) |

A consuming repository may add display forms of its own in its conventions
declaration (`vocabulary.display_forms`); it cannot remove or change these.

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
