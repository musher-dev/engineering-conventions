# Repository

These conventions govern a repository as a whole: what it says about itself, what it is called, and where it keeps its
product. Every repository states its identity in one file, and its name and product directory follow from that
identity.

The governing rule, in one sentence:

> **Declare what the repository is in `.repo/repository.toml`, and name it `<system>-<component>` from a registered
> system.**

The declaration sits beside the conventions and outputs declarations under `.repo/`. It is the one place a
repository's system, kind, owner, lifecycle, audience and tier are written down; anything that labels or catalogs
repositories reads it rather than keeping its own copy.

## Status

Every convention here is a **draft**, owned by this repository, and every requirement is `proposed` at severity `warning`.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0009 Identity declaration](identity-declaration.md) | REPO-01 – REPO-06 | The file, its registered values, how its kind selects a profile, and who owns a system |
| [EC-0010 Repository names](repository-names.md) | REPO-07 – REPO-13 | The name's grammar and length, the tokens it may not hold, and how a repository is renamed |
| [EC-0018 Repository layout](layout.md) | REPO-14 – REPO-22 | The product directory named after the repository, a root without product content, and Dependabot and the Taskfile naming the same directory |

The reasoning is recorded in
[decision 0012](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0012-repository-names.md)
(names) and
[decision 0013](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0013-identity-declaration.md)
(the declaration).

## Quick reference

| Field | Example | Values |
| --- | --- | --- |
| `name` | `platform-api` | `<system>-<component>`, lowercase kebab-case, at most 40 characters |
| `system` | `platform` | A registered system |
| `component` | `api` | What the repository holds within its system |
| `kind` | `service` | `service`, `website`, `library`, `tool`, `infrastructure`, `specification`, `content`, `documentation`, `template` |
| `owner` | `@musher-dev/platform` | The GitHub team that owns the system |
| `lifecycle` | `production` | `experimental`, `production`, `deprecated` |
| `audience` | `internal` | `internal`, `public` |
| `tier` | `1` | `1`, `2`, `3` |
| `[layout] product` | `platform-api` | The repository's name, or `""` when it has no product directory |

The registered values are terms in
[`definitions/terminology/global.yml`](../../terminology/global.yml), tagged `repository.system`, `repository.kind`,
`repository.lifecycle` and `repository.audience`.
