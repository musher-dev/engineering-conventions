---
title: Rules adopted from other repositories get new families, and keep their old IDs as aliases
date: 2026-09-28
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0016 — Rules adopted from other repositories get new families, and keep their old IDs as aliases

## Context

Two repositories enforce general governance with their own `repo` CLIs, written before this repository existed:

- `musher-dev/platform` checks tool configuration (CFG-01..09), agent context (MF-01..03), git hooks (LH-01..08),
  Taskfiles (TF-01..23), toolchain pins (TC-*), environment schemas (the `G-` grammar), decision records (DC-*),
  and more of its workflows (CI-*, DL-*).
- `musher-dev/development-container` checks tool configuration (CFG-01..09), layout (LAYOUT-01..11), paths
  (PATH-01..04), environment schemas (ENV-*), toolchain pins (TC-01..03) and hook parity (HOOK-01..04).

The same idea has two implementations and the same ID means two things: CFG-09 is "a referenced `.config/` path
exists" in one and "a trivyignore entry has a statement and expiry" in the other; TC-01..03 differ entirely. The
platform is about to split into service repositories, and each would otherwise copy one of these CLIs. The rules
that are not specific to either repository move here, as the charter says a useful local rule should
([decision 0000](0000-charter.md), [decision 0002](0002-authority-and-migration.md)).

Two questions follow. Which IDs do the moved rules carry, and does the charter let this repository own rules about
the dev container's toolchain, hooks and environment, when the charter gives the dev-container scaffold to
`musher-dev/development-container`?

## Decision

**New families, fresh numbers, old IDs as aliases.** A rule adopted from another repository is written as a new
requirement in a family registered here, numbered from 01, with every ID it had upstream in `aliases` as
`<repository>:<ID>` (`platform:CFG-03`, `development-container:CFG-03`). A family prefix is chosen so that it
matches no prefix either upstream repository uses, so a diagnostic ID is never ambiguous while both run:

| Prefix | Topic | Adopts |
| --- | --- | --- |
| CONF | Tool configuration | platform and development-container CFG |
| AGENT | Agent context | platform MF |
| HOOKS | Git hooks | platform LH, development-container PATH-01 |
| TASK | Tasks | platform TF, development-container PATH-03 |
| TOOL | Toolchain | platform and development-container TC, reframed on mise |
| ENVS | Environment contract | platform `env.schema.yaml` format and grammar, development-container ENV and LAYOUT-10/11 |
| DEC | Decision records | platform DC |

Rules that fit an existing family join it: repository layout (development-container LAYOUT) continues REPO, and
workflow rules (platform CI and DL, development-container PATH-02) continue GHA. Each adopted rule is authored here
with `authority: self`; upstream retires its copy in one pull request per family, pinning the release that carries
it. A rule adopted in part (one clause of a check that did several things) is aliased with a letter suffix, such as
`platform:CI-13b`.

**What is adopted.** Only rules the engines consumers already run can check
([decision 0001](0001-validation-engines.md), [decision 0015](0015-the-runner-reads-what-conftest-cannot-select.md)).
Rules that need code parsing, execution or network access (comment quality, which variables code reads, generated
code being current) stay upstream and are re-evaluated later.

**The charter boundary.** `musher-dev/development-container` owns the scaffold: the container, how it installs its
toolchain, its stacks. This repository owns the rules any repository's files are checked against, including files
the scaffold creates: where a tool's configuration lives, that every tool version is pinned once in mise and
anything outside mise matches it, what a hook configuration must hold, and the shape of an environment schema. A
rule about *how* the scaffold is built (which Features it uses, how its scripts run) stays there.

## Consequences

### Positive

- One ID per rule across the organization, and a consumer who knows `CFG-03` finds `CONF-03` through its alias.
- The upstream CLIs shrink to the rules only their repository needs.
- New service repositories are born pinned to one release instead of copying a CLI.

### Negative

- Familiar IDs change. Aliases, and ADOPT-04's hint when a waiver names one, soften this.
- While a family is being retired upstream, both checks run; the migration issues sequence one family per pull
  request to keep that short.

### Neutral

- Upstream rules that were documented but never implemented (platform G-03, G-06, G-08..G-10) are written here
  from their intent, not from code.

## Enforcement

- `task invariants` fails on a prefix not registered in `families.yml`, a reused ID, or a removed alias.
- The frontmatter schema accepts an alias only as `<repository>:<ID>` with an optional letter suffix.
- That a new prefix collides with no upstream prefix, and that an adopted rule fits the charter boundary, is
  `review-only`: the reviewer checks the upstream CLIs' prefixes and that the rule governs files, not how the
  scaffold is built.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Keep upstream IDs | Port CFG-01..09 and the rest unchanged, as issue #10 first proposed | rejected: CFG-09 and TC-01..03 name different rules upstream, and one would have to be renumbered anyway |
| Reuse upstream prefixes, renumber | `CFG-01` here means something new | rejected: the same printed ID would mean different things in the two runners during migration |
| New prefixes, upstream IDs as aliases | This decision | **chosen** |

## References

- [Decision 0000: Charter](0000-charter.md)
- [Decision 0002: Authority and migration](0002-authority-and-migration.md)
- [Decision 0004: Identifiers and diagnostic URLs](0004-identifiers-and-diagnostic-urls.md)
- [Decision 0015: The runner reads what conftest cannot select](0015-the-runner-reads-what-conftest-cannot-select.md)
- Issue #10: Port development-container's LAYOUT, CFG, HOOK, TC and CMT rules
