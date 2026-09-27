---
title: A repository declares its identity in .repo/repository.toml, and its kind selects its profile
date: 2026-09-27
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0013 — Identity declaration

## Context

No repository in the organization carries machine-readable identity. Which system a repository belongs to, what kind
of repository it is, who owns it, whether it is safe to depend on and who its outputs are for are known to people, not
recorded anywhere a tool can read. The consequences are visible: code-owner files name teams that do not exist,
rulesets are maintained per repository by hand and miss repositories they should cover, and each repository that is
not the default kind has to name its convention profile explicitly.

[Decision 0012](0012-repository-names.md) names repositories from a registered system, so the system is already part
of every name. What a name cannot carry (the kind, the owner, the lifecycle, the audience and the tier) needs a home,
and so does the system itself, so that no reader has to parse it out of the name.

This repository already owns two declarations under `.repo/` ([EC-0001](../../engineering-conventions/definitions/conventions/adoption/conventions-declaration.md),
[EC-0007](../../engineering-conventions/definitions/conventions/outputs/outputs-declaration.md)) and the convention
profiles, which are "the set of requirements for one kind of repository". It runs nothing for other repositories.

## Decision

**Every repository declares its identity in `.repo/repository.toml`: `name`, `system`, `component`, `kind`, `owner`,
`lifecycle`, `audience` and `tier`, all required. Its `kind` selects the convention profile of the same name.** The
format and its requirements are
[EC-0009](../../engineering-conventions/definitions/conventions/repository/identity-declaration.md), family `REPO`,
included in `base-repo`, with every requirement `proposed` at `warning`.

- **The values are terminology.** Kinds, lifecycles and audiences are terms tagged `repository.kind`,
  `repository.lifecycle` and `repository.audience`, projected into `index.json` beside the systems. The schema checks
  only their type, and REPO-03 checks the tokens, so each problem is reported once with the registered values listed.
- **The kind selects the profile.** The profile is the one `.repo/conventions.toml` names, else the kind's, else
  `base-repo`. Every kind has a profile (the `kinds_have_profiles` invariant), and each inherits `base-repo` until
  requirements specific to it exist, so declaring a kind never loosens a check. `profile` in the conventions
  declaration becomes an override.
- **The owner is a team, and one team owns a system** (REPO-05). The schema requires `@musher-dev/<team>`. Which teams
  exist is the organization's decision.
- **The declaration is the one source** (REPO-06). Two readers are planned, and both run elsewhere:
  - GitHub custom properties `system`, `kind`, `owner`, `lifecycle`, `audience` and `tier`, single-select and editable
    only by organization actors, synced from each repository's declaration by `musher-dev/infra-github`, with the
    allowed values taken from the pinned release's `index.json`. Rulesets target repositories by these properties.
  - A Backstage catalog entry, generated when one is wanted: a `Component` whose `metadata.name` is `name`,
    `spec.system` is `system`, `spec.type` is `kind`, `spec.owner` is the owning group and `spec.lifecycle` is
    `lifecycle`, with `audience` and `tier` as labels.

## Consequences

### Positive

- One reviewed file states what a repository is, and every tool that needs it reads the same values.
- A repository is held to its kind's requirements without a conventions declaration, and a kind's future
  requirements reach every repository of that kind.
- Organization rulesets and properties follow the declarations instead of a hand-maintained list.

### Negative

- Every repository gains a file, and REPO-01 reports its absence in each one until it is added.
- The values are only as current as the file. REPO-07 catches a stale name; nothing here catches a stale lifecycle or
  owner, which the property sync reports as drift instead.
- Nine kind profiles exist that, for now, apply exactly what `base-repo` does.

### Neutral

- The sync into custom properties, and any catalog, are built and run by the repository that manages the organization;
  this repository only defines the file and ships the vocabulary.

## Enforcement

- REPO-01 to REPO-04 (EC-0009) are conftest checks with fixture repositories; REPO-02 validates the file against
  `checks/schemas/repository.schema.json`, embedded in `index.json`.
- REPO-05 and REPO-06 are `review-only`: a reviewer checks that the owner is the system's team, and that no second file
  states a repository's identity.
- `conventions invariants` fails when a kind has no profile, and `lib/profile.rego`'s tests cover each step of the
  profile selection.
- This repository declares its own identity, and `task conventions:self` holds it to it.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Identity fields in `.repo/conventions.toml` | One file for everything | rejected: that file is optional and says which rules apply, not what the repository is, as [decision 0010](0010-outputs-declaration.md) found for outputs |
| A Backstage `catalog-info.yaml` | A known format with tooling | rejected: `v1alpha1`, a larger surface, and it would duplicate the outputs declaration; it can be generated from this file instead |
| GitHub custom properties as the source of truth | Set identity in the organization settings | rejected: unversioned, editable by repository administrators, and changed without review; they are synced from the file instead |
| A file at the repository root | `repository.toml` beside the README | rejected: `.repo/` already holds the declarations, and one CODEOWNERS entry can protect all of them |
| `.repo/repository.toml`, the kind selecting the profile | A small, schema-checked declaration beside the others | **chosen** |

## References

- [EC-0009 Identity declaration](../../engineering-conventions/definitions/conventions/repository/identity-declaration.md)
- [Decision 0012: Repository names](0012-repository-names.md)
- [Decision 0011: The .repo/ declarations are TOML](0011-declarations-are-toml.md)
- [Backstage: Descriptor format of catalog entities](https://backstage.io/docs/features/software-catalog/descriptor-format/)
- [GitHub: Managing custom properties for repositories in your organization](https://docs.github.com/en/organizations/managing-organization-settings/managing-custom-properties-for-repositories-in-your-organization)
