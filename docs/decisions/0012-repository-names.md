---
title: A repository is named <system>-<component>, from a registered system
date: 2026-09-27
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0012 — Repository names

## Context

The organization's repositories have no shared naming grammar. Prefixes are mixed (`musher-cli`, `python-sdk`,
`host-agent`), some names hide what the repository holds (`foundation-bootstrap` beside `infra`), and several
repositories that hold the same kind of content are named unrelated things. A reader cannot tell from a name which part
of Musher a repository belongs to, and no tool can group repositories by name.

The platform monorepo is about to be split into one repository per deployable unit. Every split creates repositories,
and a repository is cheap to name and expensive to rename: its name is copied into clone URLs, `uses:` lines, image
paths, tool pins and other repositories' documentation, and GitHub redirects only some of those copies. Deciding the
grammar before the split lets each new repository be created under its final name.

The [charter](0000-charter.md) makes this repository the home of shared repository structures. It does not own teams,
which belong to the organization, or the operation that applies a name, which belongs to the repository that manages
the GitHub organization.

## Decision

**A repository is named `<system>-<component>`: a registered system token, a hyphen, and a component naming what the
repository holds.** The name is lowercase kebab-case, at most 40 characters and never more than 63. It holds no token
the organization, GitHub, the declaration or the history already says (`musher`, `repo`, `common`, `shared`, `utils`,
`util`, `misc`, `new`, `legacy`, `old`) and no version (`v2`). The rules are
[EC-0010](../../engineering-conventions/definitions/conventions/repository/repository-names.md), family `REPO`, in the
new `repository` topic, with every requirement `proposed` at `warning`.

- **Systems are terminology.** Each is a term tagged `repository.system` in
  `definitions/terminology/global.yml`, projected into `index.json` like the other token vocabularies
  ([decision 0007](0007-terminology-and-generated-artifacts.md)). The first nine are `platform`, `host`, `sdk`,
  `infra`, `observability`, `engineering`, `brand`, `company` and `catalog`. A new system is a term, not a schema
  change.
- **A system is never a team.** It is named for what its repositories provide. One team owns each system
  ([decision 0013](0013-identity-declaration.md)), but teams reorganize and a name that tracks them has to change
  with them.
- **The grammar is strict.** Every repository carries a system, including one that is alone in its system.
- **Banned tokens are aliases in a scope of their own**, `repository-name`, so they are checked in repository names
  and nowhere else: not in workflow filenames (GHA-05) and not in prose.
- **The checks learn the actual name** from `--repository`, `GITHUB_REPOSITORY` in the workspace, or the `origin`
  remote at a work-tree root, and compare it with the declared name (REPO-07). Otherwise they judge the declared name.
- **`.github`, `.github-private` and archived repositories are exempt.** GitHub reserves the first two, and an
  archived repository runs no checks.
- **Renames happen in one change, and an old name is never reused** (REPO-13).

## Consequences

### Positive

- A name says which part of Musher a repository belongs to, and repositories sort into their systems.
- New repositories from the platform split are created under their final names.
- Organization rulesets and teams can target a system by name, or by the property synced from the declaration.

### Negative

- Most existing repositories do not conform and have to be renamed. The renames are staged, private repositories
  first, and each follows REPO-13's checklist because GitHub does not redirect Actions `uses:` references, container
  image paths under `ghcr.io`, Go module paths or GitHub Pages URLs. Until a repository is renamed, it holds a
  waiver for its findings.
- Every repository needs a system, so a repository that is alone in its system still carries the prefix.
- An old name is lost for good; it cannot be reused for a different repository.

### Neutral

- Package, image and binary names are declared in the outputs declaration and do not change with the repository's
  name: a command-line tool keeps its binary name whatever its repository is called.
- Which repository is in which system, and the name each existing repository moves to, is organization data kept by
  the repository that manages the organization, not a convention here.

## Enforcement

- REPO-07 to REPO-11 (EC-0010) are conftest checks with fixture repositories, including one proving that `.github` is
  exempt; `conventions invariants` fails when a requirement has no fixture.
- REPO-12 and REPO-13 are `review-only`: a reviewer checks that the component names what the repository holds, and that
  a rename is planned as one change across everything that names the repository.
- `tests/test_launcher.py` holds the launcher and the authoring CLI to the same name sources, including the guard that
  keeps `GITHUB_REPOSITORY` from naming a directory other than the workspace.
- This repository declares `engineering-conventions`, and `task conventions:self` checks it against the `origin`
  remote.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Flat names | Any descriptive name, as today | rejected: nothing groups repositories, and the drift that prompted this continues |
| Kind prefix (`service-api`, `lib-python`) | Name by what kind of repository it is | rejected: kinds change as a repository grows, and a kind is the declaration's field, not the name's |
| Organization prefix (`musher-api`) | Prefix every name with the company | rejected: the organization already says it in every URL, and it groups nothing |
| System prefix, singletons unprefixed | `<system>-<component>` only where a system has several repositories | rejected: a second repository in the system forces the first to be renamed, and a reader cannot tell a system from a component |
| Strict `<system>-<component>` from a registered system | Every repository carries a registered system | **chosen** |

Prior art: Backstage models components within systems within domains; Kubernetes SIGs name related repositories
`cluster-api` and `cluster-api-provider-<name>`; OpenTelemetry prefixes its repositories `opentelemetry-`; the Azure SDKs
are `azure-sdk-for-<language>`; Zalando's guidelines name a repository `<functional-domain>-<functional-component>`.

## References

- [EC-0009 Identity declaration](../../engineering-conventions/definitions/conventions/repository/identity-declaration.md)
- [EC-0010 Repository names](../../engineering-conventions/definitions/conventions/repository/repository-names.md)
- [Decision 0013: A repository declares its identity in .repo/repository.toml](0013-identity-declaration.md)
- [Backstage: System model](https://backstage.io/docs/features/software-catalog/system-model/)
- [GitHub: Renaming a repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/renaming-a-repository)
- [kubernetes-sigs/cluster-api](https://github.com/kubernetes-sigs/cluster-api)
