---
id: EC-0009
title: Identity declaration
summary: >-
  Every repository declares in .repo/repository.toml its name, the system it
  belongs to, the component it is, its kind, the team that owns it, its
  lifecycle, its audience and its tier. The kind selects the convention
  profile, and the declaration is the one source of the repository's catalog
  entry and organization properties.
status: draft
topic: repository
applies_to:
  paths:
    - .repo/repository.toml
created: 2026-09-27
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "Backstage: System model"
    url: https://backstage.io/docs/features/software-catalog/system-model/
  - title: "Backstage: Descriptor format of catalog entities"
    url: https://backstage.io/docs/features/software-catalog/descriptor-format/
  - title: "GitHub: Managing custom properties for repositories in your organization"
    url: https://docs.github.com/en/organizations/managing-organization-settings/managing-custom-properties-for-repositories-in-your-organization
requirements:
  - id: REPO-01
    title: A repository declares its identity in .repo/repository.toml
    status: proposed
    severity: warning
    since: 0.5.0
    validation:
      engine: conftest
      package: conventions.checks.repository.identity
  - id: REPO-02
    title: The identity declaration is valid against its schema
    status: proposed
    severity: warning
    since: 0.5.0
    validation:
      engine: conftest
      package: conventions.checks.repository.identity
  - id: REPO-03
    title: The declared system, kind, lifecycle and audience are registered values
    status: proposed
    severity: warning
    since: 0.5.0
    validation:
      engine: conftest
      package: conventions.checks.repository.identity
  - id: REPO-04
    title: The declared name is the system and the component joined by a hyphen
    status: proposed
    severity: warning
    since: 0.5.0
    validation:
      engine: conftest
      package: conventions.checks.repository.identity
  - id: REPO-05
    title: One team owns every repository of a system
    status: proposed
    severity: warning
    since: 0.5.0
    validation:
      engine: review
  - id: REPO-06
    title: The identity declaration is the only source of a repository's catalog entry and organization properties
    status: proposed
    severity: warning
    since: 0.5.0
    validation:
      engine: review
---

# Identity declaration

Every repository says what it is in one file: `.repo/repository.toml`. It answers the questions a reader, a reviewer
or a tool asks before anything else. Which part of Musher is this? What kind of thing is it? Who owns it? Is it safe
to depend on? Who is it for? How much breaks when it does? Without the file, the answers live in people's heads, in a
README that drifts, or in organization settings that nobody reviews.

The declaration also selects how the repository is checked. Its `kind` names the
[convention profile](../../profiles/README.md) of the same name, so a service is held to what services share without
a separate conventions declaration.

## Scope

This convention covers `.repo/repository.toml` in every repository checked against a release of
`musher-dev/engineering-conventions`. Its name is governed by [EC-0010](repository-names.md). Which team exists, and
who is in it, is not decided here: this convention only requires that the owner is a team, and that one team owns a
whole system.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`): the declaration is a new interface and no
other repository defines it. Its requirements are `proposed` at severity `warning`, like every requirement in the 0.x
series ([decision 0013](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0013-identity-declaration.md)).

## The declaration file

```toml
# .repo/repository.toml
schema_version = 1
name = "platform-api"
system = "platform"
component = "api"
kind = "service"
owner = "@musher-dev/platform"
lifecycle = "production"
audience = "internal"
tier = 1
```

The file is TOML ([decision 0011](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0011-declarations-are-toml.md)),
and every field above is required. An optional `[layout]` table says where the product lives; its rules are
[EC-0018](layout.md). An optional `visibility` says whether the repository is `public`, `private` or `internal` on
GitHub, which decides whether its release assets can be attested ([REL-18](../releases/release-workflows.md#rel-18)).

| Field | Meaning |
| --- | --- |
| `schema_version` | The file format version. Always `1`. |
| `name` | The repository's name on GitHub, without the organization. It is `<system>-<component>` (REPO-04) and follows [EC-0010](repository-names.md). |
| `system` | The registered system the repository belongs to (REPO-03). |
| `component` | What the repository holds within its system: the rest of its name. |
| `kind` | The repository's primary role, a registered kind (REPO-03). It selects the convention profile of the same name. |
| `owner` | The GitHub team that owns the repository, as `@musher-dev/<team>`. A team, never a person (REPO-05). |
| `lifecycle` | `experimental`, `production` or `deprecated` (REPO-03). |
| `audience` | Who the repository's outputs are for: `internal` or `public` (REPO-03). |
| `visibility` | Optional. The repository's visibility on GitHub: `public`, `private` or `internal`. It is not the same as `audience`: an internal tool can live in a public repository. A repository that omits it is treated as public by [REL-18](../releases/release-workflows.md#rel-18). |
| `tier` | How much depends on it: `1` when its failure stops customers or the platform, `2` when it stops Musher's own work, `3` otherwise. |

The authoritative shape is `checks/schemas/repository.schema.json`, and REPO-02 checks the file against it.

### Systems

A system groups the repositories that together provide one part of what Musher builds. Its token is the first token
of each of their names. A system is named for what its repositories provide, never for a team, a technology or a kind:
teams reorganize and technologies change, and a name that tracks either has to change with them.

The registered systems, and what each holds, are listed in
[EC-0010](repository-names.md#the-registered-systems). A new system is a terminology change: a term tagged
`repository.system` in [`definitions/terminology/global.yml`](../../terminology/global.yml).

### Kinds

The kind is the repository's primary role, which decides the requirements that fit it. What a repository publishes is
a separate question, answered by its [outputs declaration](../outputs/outputs-declaration.md): a `service` repository
may publish an image and a contract, and a `library` repository a package.

| Kind | Primary role |
| --- | --- |
| `service` | A deployable process: an API server, a worker or an agent |
| `website` | A site or browser application that people use through a web browser |
| `library` | Code other repositories import as a dependency |
| `tool` | A program people run from a terminal or a pipeline, such as a command-line tool |
| `infrastructure` | Infrastructure-as-code that provisions or configures environments, accounts or an organization |
| `specification` | A definition other repositories are built or checked against: a format, a schema, a contract or a set of conventions |
| `content` | Curated material consumed as data rather than run, such as catalog items or examples |
| `documentation` | Prose for people to read, published as a site or read in place |
| `template` | A starting point other repositories copy or build on, such as a development container or a project scaffold |

### Profile selection

| Situation | Profile used |
| --- | --- |
| `.repo/conventions.toml` names a profile the release defines | That profile |
| Otherwise, `kind` names a registered kind | The profile of the same name |
| Otherwise | `base-repo` |

Every kind has a profile, and each inherits `base-repo` and only adds to it, so declaring a kind never loosens a
check. A kind's own requirements, such as the `build`, `test` and `dev` tasks of
[EC-0016](../tasks/task-interface.md), are selected by its profile. `profile` in the conventions
declaration remains as an override ([EC-0001](../adoption/conventions-declaration.md)).

### Where the declaration is read

The declaration is written once and read by everything that needs a repository's identity. None of these readers is
run from here; each belongs to the repository that operates it.

| Reader | Reads | As |
| --- | --- | --- |
| The conventions checks | `kind` | The convention profile |
| GitHub custom properties | `system`, `kind`, `owner`, `lifecycle`, `audience`, `tier` | Single-select properties, editable only by the organization, which rulesets target |
| A Backstage catalog | `name`, `system`, `kind`, `owner`, `lifecycle`, `audience`, `tier` | A `Component` with `metadata.name`, `spec.system`, `spec.type`, `spec.owner` and `spec.lifecycle`; `audience` and `tier` as labels |

## Requirements

### REPO-01

**A repository declares its identity in `.repo/repository.toml`.**

A repository without the declaration cannot be told apart from any other by a tool: no profile follows from its kind,
no property says who owns it, and no catalog knows it exists. Every repository needs the file, whatever it holds.

**Correct:**

```text
.repo/repository.toml
```

**Incorrect:**

```text
# no .repo/repository.toml
```

Checked by: conftest · Severity: warning · Since: 0.5.0

### REPO-02

**The identity declaration is valid against its schema.**

Every other requirement in this topic reads the declaration's fields, and every reader outside it copies them. A
missing field, an owner that is a person, or a tier written as a string is a value nothing can use. One finding
reports the first problem and how many more there are.

**Correct:**

```toml
owner = "@musher-dev/platform"
tier = 1
```

**Incorrect:**

```toml
owner = "@octocat"            # a person; the owner is a team
tier = "1"                    # a string; the tier is a number
team = "platform"             # unknown key; the field is owner
```

Checked by: conftest · Severity: warning · Since: 0.5.0

### REPO-03

**The declared system, kind, lifecycle and audience are registered values.**

These four fields are what repositories are grouped, labeled and checked by. A free-form value (`backend` for
`platform`, `microservice` for `service`, `beta` for `experimental`) splits one group into several, and a ruleset or
profile that targets the registered value silently misses the repository. The message lists the registered values.

**Correct:**

```toml
system = "platform"
kind = "service"
lifecycle = "experimental"
audience = "internal"
```

**Incorrect:**

```toml
system = "backend"
kind = "microservice"
lifecycle = "beta"
audience = "private"
```

Checked by: conftest · Severity: warning · Since: 0.5.0

### REPO-04

**The declared name is the system and the component joined by a hyphen.**

`name`, `system` and `component` say the same thing three ways, so that a reader can find the system without parsing
the name. If they disagree, one of them is wrong, and every reader that trusts a different field reaches a different
answer. The repositories GitHub reserves, `.github` and `.github-private`, are exempt.

A name that does not follow the grammar at all, such as a single word from before the grammar existed, is reported
by [REPO-08](repository-names.md#repo-08) instead. Comparing it with `system` and `component` would only ask for a
replacement name, which is chosen when the repository is renamed, not by this check.

**Correct:**

```toml
name = "platform-api"
system = "platform"
component = "api"
```

**Incorrect:**

```toml
name = "platform-api"
system = "platform"
component = "server"          # makes platform-server
```

Checked by: conftest · Severity: warning · Since: 0.5.0

### REPO-05

**One team owns every repository of a system.**

A system is a unit of ownership as well as of naming. When its repositories are owned by different teams, a change
that spans the system has no single reviewer, and a question about it has no single place to go. The owner is a team
rather than a person so ownership survives someone leaving. The reviewer checks that `owner` is the team every other
repository of the system names. Which teams exist and who belongs to them is decided by the organization, not here.

**Correct:**

```toml
# platform-api
system = "platform"
owner = "@musher-dev/platform"

# platform-console
system = "platform"
owner = "@musher-dev/platform"
```

**Incorrect:**

```toml
# platform-console
system = "platform"
owner = "@musher-dev/frontend"  # a second owner for one system
```

Checked by: review · Severity: warning · Since: 0.5.0

### REPO-06

**The identity declaration is the only source of a repository's catalog entry and organization properties.**

A repository's identity is useful only while every copy agrees. GitHub custom properties, a Backstage
`catalog-info.yaml` and the checks' profile all need the same fields, and each kept by hand drifts from the others. So
each is derived from the declaration, and a change starts there: a property edited in the organization settings, or a
catalog file written beside the declaration, is overwritten or reported as drift by the process that syncs it. The
reviewer checks that a change to a repository's identity changes `.repo/repository.toml`, and that no second file
states the same fields.

**Correct:**

```text
.repo/repository.toml         # kind = "service"; the kind property is synced from it
```

**Incorrect:**

```text
.repo/repository.toml         # kind = "service"
catalog-info.yaml             # spec.type: website, written by hand
```

Checked by: review · Severity: warning · Since: 0.5.0

## References

- [EC-0010 Repository names](repository-names.md)
- [Decision 0013: A repository declares its identity in .repo/repository.toml](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0013-identity-declaration.md)
- [Backstage: System model](https://backstage.io/docs/features/software-catalog/system-model/)
- [GitHub: Managing custom properties for repositories in your organization](https://docs.github.com/en/organizations/managing-organization-settings/managing-custom-properties-for-repositories-in-your-organization)
- `checks/schemas/repository.schema.json`
