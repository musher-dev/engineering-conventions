---
title: Data documents and systemd units are interface formats, a dependency may be fetched, and a gated break is marked, not numbered
date: 2026-10-01
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
amends: ["0022"]
---

# 0027 — Data documents and systemd units are interface formats, a dependency may be fetched, and a gated break is marked, not numbered

## Context

[Decision 0022](0022-interfaces-and-dependencies.md) asked every producer to declare each file in its contracts
directory as part of an interface with a registered format, and every consumer to vendor what it builds against,
proved offline by the producer's release record. The first repositories to adopt it in 0.7.0 found four gaps.

A service publishes data documents that other repositories read and assert against: a registry of problem types,
closed vocabularies, rate cards, transition tables. They are instances, not schemas, so declaring them `json-schema`
is false, and moving them out of `contracts/` hides published interfaces
([#72](https://github.com/musher-dev/engineering-conventions/issues/72)). An agent's systemd units are installed by
the repository that configures its hosts, yet no format names them, so they sat outside `contracts/` and their
consumer had no conventional way to pin or prove them
([#83](https://github.com/musher-dev/engineering-conventions/issues/83)).

A conformance suite reads a corpus of hundreds of files at test time. Vendoring it puts every file in review for no
reader, and keeping its pin elsewhere is what DEPS-07 reports
([#75](https://github.com/musher-dev/engineering-conventions/issues/75)).

Decision 0022 said a `gated` break ships only in a major release. In the 0.x series a commit marked breaking cuts a
minor release, so a consumer who reads the promise literally waits for 1.0.0
([#78](https://github.com/musher-dev/engineering-conventions/issues/78)).

## Decision

We will extend decision 0022 as follows. The rest of it stands.

- **`data` is an interface format** (`interfaces.format.data`): one or more JSON or YAML documents that are themselves
  the published fact. A `gated` data interface's `contracts:breaking` compares the members a consumer relies on, which
  the producer names, and treats a released member that is gone or a value that changed as a break (EC-0030, EC-0031).
- **`systemd-unit` is an interface format** (`interfaces.format.systemd-unit`): unit files another repository installs
  on the hosts it configures. They are offered from `<product>/contracts/` like any interface, and a consumer vendors
  them unchanged under `contracts/vendor/` by the existing path, deploying from the copy or deriving a copy in its own
  build (EC-0030, EC-0032). A surface another repository deploys is an interface, so no second consumption path is
  needed for non-interface bundles.
- **A dependency may be fetched.** A `[[dependencies]]` entry with `fetched = true` pins an exact release whose assets
  the consumer downloads at test or build time and verifies against the release's `SHA256SUMS`. It is a deliberate
  exception to 0022's offline proof: `SHA256SUMS` is the proof, at the time of the fetch, and DEPS-05 and DEPS-06 skip
  the entry. The pin still lives in the declaration, so DEPS-07 has a home to point at, the scheduled update raises
  it, and the graph shows the edge. A fetched dependency is never also vendored: DEPS-01 reports a copy of one.
- **A gated break is marked, not numbered.** A break ships only in a release marked breaking: a major release from
  1.0.0, a minor release in the 0.x series, as Semantic Versioning §4 allows. Either is cut by a commit marked `!` or
  carrying `BREAKING CHANGE`, and `contracts:breaking` checks the mark, not the number. The `gated` term, EC-0030's
  compatibility table and IFACE-10 say so.

## Consequences

### Positive

- A producer can declare every published document in `contracts/` truthfully, without waiving IFACE-02.
- A host-configuration repository pins and proves the units it deploys the same way it would any interface.
- A large test corpus has a declared pin and no vendored copy.
- A 0.x producer and its consumers read the same promise.

### Negative

- A fetched dependency is not proved offline: a check that cannot reach the network cannot see that the consumer
  verified what it fetched. That rests on the consumer's fetch step.
- A `data` interface has no format tool, so each producer writes its own comparison of the members it names.

### Neutral

- IFACE-02 stays reported on the declaration file; letting a waiver name one interface is left for later.

## Enforcement

- IFACE-02 accepts `data` and `systemd-unit` from the terminology, proved by the fixture repositories
  `iface-02-passes-data-format` and `iface-02-passes-systemd-unit`.
- `dependencies.schema.json` accepts `fetched`; DEPS-05 and DEPS-06 skip a fetched entry (`deps-05-passes-fetched`),
  DEPS-01 reports a copy of one (`deps-01-fetched-with-copy`), and a vendored units bundle passes DEPS-05 and DEPS-06
  (`deps-06-passes-vendored-units`).
- The breaking mark is `review-only` through IFACE-10: a reviewer checks that a gated break is released by a commit
  marked `!` or carrying `BREAKING CHANGE`.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Declare data documents as `json-schema` | No new term | rejected: they are instances, not schemas |
| A consumption path for non-interface bundles | Pin and prove any bundle | rejected: a second path for the same proof; units another repository deploys are an interface |
| Vendor the test corpus | No exception to offline proof | rejected: hundreds of files in review for no reader |
| Keep "major release" for gated | No wording change | rejected: false for every 0.x producer |
| Formats, fetched entries and the breaking mark as above | Extend decision 0022 | **chosen** |

## References

- [Decision 0022: Interfaces and dependencies](0022-interfaces-and-dependencies.md)
- [Decision 0005: Status, severity and versioning](0005-status-severity-and-versioning.md)
- [Semantic Versioning 2.0.0, §4](https://semver.org/#spec-item-4)
- [systemd.unit](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
