---
id: EC-0010
title: Repository names
summary: >-
  A repository is named <system>-<component>: a registered system, then what
  the repository holds, in lowercase kebab-case of at most 40 characters,
  with no token the organization, the declaration or the history already
  says. The declared name is the actual one, and a rename moves everything
  that names the repository in one change.
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
  - title: "GitHub: Renaming a repository"
    url: https://docs.github.com/en/repositories/creating-and-managing-repositories/renaming-a-repository
requirements:
  - id: REPO-07
    title: The declared name is the repository's actual name
    status: proposed
    severity: warning
    since: 0.5.0
    validation:
      engine: conftest
      package: conventions.checks.repository.names
  - id: REPO-08
    title: A repository name is a system and a component in lowercase kebab-case, at most 63 characters
    status: proposed
    severity: warning
    since: 0.5.0
    validation:
      engine: conftest
      package: conventions.checks.repository.names
  - id: REPO-09
    title: A repository name starts with a registered system
    status: proposed
    severity: warning
    since: 0.5.0
    validation:
      engine: conftest
      package: conventions.checks.repository.names
  - id: REPO-10
    title: A repository name holds no banned token and no version
    status: proposed
    severity: warning
    since: 0.5.0
    validation:
      engine: conftest
      package: conventions.checks.repository.names
  - id: REPO-11
    title: A repository name is at most 40 characters
    status: proposed
    severity: warning
    since: 0.5.0
    validation:
      engine: conftest
      package: conventions.checks.repository.names
  - id: REPO-12
    title: The component names what the repository holds
    status: proposed
    severity: warning
    since: 0.5.0
    validation:
      engine: review
  - id: REPO-13
    title: A rename changes everything that names the repository in one change, and the old name is never reused
    status: proposed
    severity: warning
    since: 0.5.0
    validation:
      engine: review
---

# Repository names

A repository's name is the most copied string about it. It is in every clone URL, every `uses:` line that calls one of
its actions, every image path under `ghcr.io`, every `mise` pin and every link in every other repository's
documentation. A name that says nothing about what the repository holds has to be explained everywhere it appears,
and a name that has to change breaks every one of those copies at once.

The grammar is strict and short:

```text
<system>-<component>
platform-api         sdk-python         engineering-conventions
```

The **system** is a registered token that groups repositories by what they provide together; the **component** is
what this repository holds within it. Reading a name tells you where it belongs; sorting names groups each system's
repositories together.

## Scope

This convention covers the name of every repository checked against a release of `musher-dev/engineering-conventions`,
as declared in `.repo/repository.toml` ([EC-0009](identity-declaration.md)) and as it is on GitHub. It does not govern
the names of what a repository publishes: a package, an image or a binary is named in the
[outputs declaration](../outputs/outputs-declaration.md), and keeps its name when the repository is renamed.

GitHub reserves `.github` and `.github-private` for an organization's default community health files and profile.
They are exempt from every requirement here, and so is an archived repository, which the checks never run on.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirements are `proposed` at
severity `warning`, like every requirement in the 0.x series
([decision 0012](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0012-repository-names.md)).

## Which name is checked

The checks compare the declared name with the repository's actual name when they can learn it, and otherwise judge
the declared name alone. `conventions check` learns the actual name, in order, from:

1. `--repository NAME`, or the `CONVENTIONS_REPOSITORY` environment variable;
2. `GITHUB_REPOSITORY` in GitHub Actions, only when the directory checked is `GITHUB_WORKSPACE`;
3. the last segment of the `origin` remote's URL, only when the directory checked is the root of a git work tree;
4. otherwise, nothing: REPO-07 is not checked, and REPO-08 to REPO-11 judge the declared name.

Every finding is reported on `.repo/repository.toml`, the file a fix or a waiver starts from.

## Requirements

### REPO-07

**The declared name is the repository's actual name.**

The declaration is what tools read in place of the repository's settings, so a declaration that names another
repository misleads every one of them. The usual cause is a rename that did not update the file, or a file copied
from another repository. While a rename is pending, a waiver on REPO-07 records it.

**Correct:**

```toml
# in musher-dev/platform-api
name = "platform-api"
```

**Incorrect:**

```toml
# in musher-dev/platform-api
name = "platform-web"         # copied from another repository
```

Checked by: conftest · Severity: warning · Since: 0.5.0

### REPO-08

**A repository name is a system and a component in lowercase kebab-case, at most 63 characters.**

The name ends up in places with stricter rules than GitHub's: image paths are lowercase, and a Kubernetes object, a
DNS label or a hostname derived from the name allows at most 63 characters of lowercase letters, digits and hyphens.
A name that already fits them is used as it is everywhere, instead of being translated a little differently in each
place. It has at least two tokens, so it always carries both a system and a component. When the name only differs in
case or separators, the message gives the corrected name.

**Correct:**

```text
platform-api
platform-operator-console
```

**Incorrect:**

```text
Platform_API                  # use platform-api
platform                      # no component
```

Checked by: conftest · Severity: warning · Since: 0.5.0

### REPO-09

**A repository name starts with a registered system.**

The first token is what groups a repository with the others of its system, and what an organization ruleset, a team
or a catalog uses to find them. An unregistered first token is a system nobody agreed on, usually a team, a technology
or a kind standing in for one (`frontend-console`, `go-cli`, `service-api`). The message lists the registered
systems.

**Correct:**

```text
platform-console
sdk-cli
```

**Incorrect:**

```text
frontend-console              # a team or a technology, not a system
musher-cli                    # the organization, not a system (REPO-10)
```

Checked by: conftest · Severity: warning · Since: 0.5.0

### REPO-10

**A repository name holds no banned token and no version.**

Some tokens say nothing a reader does not already know, or say something that will stop being true. The
organization's name is on every repository (`musher`), and so is the fact that it is a repository (`repo`). `common`,
`shared`, `utils`, `util` and `misc` say who uses a repository, or nothing at all, instead of what it holds. `new`,
`legacy` and `old` name a lifecycle, and a version such as `v2` names a release; both change, while the name must not.
A lifecycle belongs in the declaration's `lifecycle`, and a version in a release. The banned tokens are terms in
[`definitions/terminology/global.yml`](../../terminology/global.yml), with the advice the message prints.

**Correct:**

```text
sdk-cli
platform-api                  # lifecycle = "experimental" in .repo/repository.toml
```

**Incorrect:**

```text
sdk-musher-cli                # the organization is already in every URL
platform-shared-utils         # say what it holds
platform-api-v2               # a version, which the next release makes wrong
platform-new-api              # a lifecycle, which the next year makes wrong
```

Checked by: conftest · Severity: warning · Since: 0.5.0

### REPO-11

**A repository name is at most 40 characters.**

A long name is typed, read and wrapped in more places than any other string about the repository: paths, image
references, badges, the tabs of a browser. Forty characters leaves room for a system and a component of two or three
words. Past that, the component usually describes the repository instead of naming it; shorten it and put the
description in the README.

**Correct:**

```text
platform-membership
```

**Incorrect:**

```text
platform-organization-membership-reconciler   # 43 characters
```

Checked by: conftest · Severity: warning · Since: 0.5.0

### REPO-12

**The component names what the repository holds.**

The component is the part a reader has to understand, and the part most tempting to fill with something else. It
names what the repository holds, not the team that works on it (`platform-backend-team`), the technology it is built
with (`host-packer`), its kind (`platform-service`), its lifecycle or its version. A technology belongs in the
component only when it is what tells two repositories apart, as the language does for each SDK (`sdk-python`,
`sdk-typescript`). The reviewer asks what someone who has never seen the repository would expect to find in it, and
compares that with what it holds.

**Correct:**

```text
platform-api                  # the API
sdk-python                    # the Python SDK
host-images                   # the host images
```

**Incorrect:**

```text
platform-backend-team         # a team
platform-service              # a kind; which service?
host-packer                   # a tool it happens to use
```

Checked by: review · Severity: warning · Since: 0.5.0

### REPO-13

**A rename changes everything that names the repository in one change, and the old name is never reused.**

GitHub redirects clones, fetches and web links from an old repository name to the new one, but not everything
follows. A rename that is not finished breaks consumers later, one at a time, when the redirect they relied on turns
out not to exist. The reviewer checks that the rename is planned as one change, and that each item below is updated
in it or in the same coordinated set of pull requests:

- The declaration: `name` and `component` in `.repo/repository.toml`, and any waiver held for the old name.
- GitHub Actions: every `uses:` line that names an action or reusable workflow in the repository. A workflow that
  references the old name is not redirected.
- Container images: image paths under `ghcr.io/<organization>/<old-name>`, and the
  `org.opencontainers.image.source` annotation. A package does not follow its repository's rename.
- Go modules: the module path in `go.mod`, which Go resolves from the repository path; move to a vanity path or
  release a new module path.
- GitHub Pages: a project site's URL contains the repository name and is not redirected.
- Pins and automation: `mise` `github:` entries, Renovate rules, `.ref` files and vendoring jobs that name the
  repository.
- Required checks and rulesets that target the repository by name.
- CODEOWNERS, README and documentation links, and badges.

The old name is never used again, for a new repository or a different one. GitHub's redirects stop the moment a
repository with the old name exists, and every consumer still using them is silently pointed at the wrong repository.

**Correct:**

```text
Rename python-sdk to sdk-python: one plan covering the declaration, the workflows that
use its actions, its image paths and the pins in every consuming repository.
The name python-sdk is retired.
```

**Incorrect:**

```text
Rename python-sdk to sdk-python in the settings; fix the builds that break as they are noticed.
Create a new python-sdk repository for the next major version.
```

Checked by: review · Severity: warning · Since: 0.5.0

## The registered systems

This section is informative. The systems are terms in [`definitions/terminology/global.yml`](../../terminology/global.yml),
tagged `repository.system`, and that file is where they are defined and changed.

| System | Holds |
| --- | --- |
| `platform` | The hosted Musher product: the API and the applications, sites and contracts that serve its users and operators |
| `host` | The software that runs on Musher compute, gateway and storage hosts: the agent, its configuration and the images that carry them |
| `sdk` | The client libraries and command-line tool developers use to reach the platform from their own code and terminals |
| `infra` | The infrastructure-as-code that provisions and governs the estate: the landing zone, the platform's infrastructure and the GitHub organization |
| `observability` | How the estate is observed: the registry of telemetry names and the stack that collects and shows the telemetry |
| `engineering` | How Musher builds software: the conventions, contributor documentation, the development container and engineering tools |
| `brand` | Musher's public presence and visual identity: the website and the design system |
| `company` | How Musher operates as an organization, and the sites that present it to its members and investors |
| `catalog` | The curated content users install through the platform: catalog items and example applications |

Which repository belongs to which system, and the name each existing repository moves to, is organization data rather
than a convention. It is kept, with the renames still to come, in `config/repositories.yaml` in
`musher-dev/infra-github`, the repository that applies names and properties to the organization.

## References

- [EC-0009 Identity declaration](identity-declaration.md)
- [Decision 0012: A repository is named `<system>-<component>`, from a registered system](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0012-repository-names.md)
- [GitHub: Renaming a repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/renaming-a-repository)
- [Backstage: System model](https://backstage.io/docs/features/software-catalog/system-model/)
