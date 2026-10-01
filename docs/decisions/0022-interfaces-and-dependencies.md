---
title: A repository declares the interfaces it offers and the dependencies it vendors, and a binding names what it reaches
date: 2026-09-30
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
amends: ["0010", "0015"]
amended_by: ["0026", "0027"]
---

# 0022 — A repository declares the interfaces it offers and the dependencies it vendors, and a binding names what it reaches

## Context

Splitting the API out of the platform monorepo made visible how repositories depend on each other, and that nothing
records it. The API server offers several surfaces from one source: an OpenAPI document per audience (public, agent,
control plane, webhooks and others), about a hundred event schemas, a registry of problem types, an environment
schema and a protobuf package. It publishes all of them as one opaque `bundle` output, so no one can say which
consumer builds against which surface, or which surface a change breaks. The outputs declaration
([decision 0010](0010-outputs-declaration.md)) has one `contract` kind for all of this, and it conflates two things:
the file a consumer downloads and the interface it builds against.

The consuming side is worse. Repositories pin each other in four different ways: a mise `github:` pin, a
`config/<repository>.ref` file beside a `config/vendor/<repository>/` copy, a hand-written lock file, and npm ranges.
Several pins are bare commit SHAs of files that were never released, so nothing says which version a consumer is on.
No consumer edge is declared anywhere, and vendored copies form build cycles (the platform vendors from the API while
the API vendors from the platform), which no repository can see from inside itself.

Runtime needs are equally implicit. A service's environment schema ([EC-0020](../../engineering-conventions/definitions/conventions/environment/env-schema.md))
declares every variable it reads, including the ones that reach another service or a database, but not what those
variables reach. The platform derives "the console needs the API" from a naming pattern, `*_API_BASE_URL`.

An external report proposed a single `component.yaml` descriptor per component, with its artifacts, the interfaces it
provides and consumes, its runtime needs and its verification profile. Its principles hold: each fact has one owner,
native formats are referenced and never restated, build edges must be acyclic while runtime edges may form cycles,
generated contracts need a drift gate, and declared requirements, release records, environment bindings and evidence
are four different things. Its descriptor does not fit here. `component.yaml` is already a customer-facing document
format that `musher-dev/specifications` owns ([the charter](0000-charter.md)). A single file would also mix facts
written by different hands at different rates: identity by a person once, offers by the producer at each release,
pins by a bot every week. The declarations under `.repo/` already separate those facts, and this decision completes
them rather than replacing them.

## Decision

We will model what a repository offers, what it needs and what it reaches as follows. Each fact has one owner.

| Fact | Owner | Written by |
| --- | --- | --- |
| What is delivered: an image, bundle, library, command-line tool, site or machine image | `[[outputs]]` in `.repo/outputs.toml` | a person |
| An **interface**: one surface another repository builds or runs against | `[[interfaces]]` in `.repo/outputs.toml`, `schema_version = 2` | a person |
| The interface's definition | files under `<product>/contracts/` | usually generated from code |
| An interface's version | the release of the output that delivers it; a `versioned` interface also carries `.vN.` in each file name | derived |
| A **dependency** on another repository's vendored interfaces, with its pin | `[[dependencies]]` in `.repo/dependencies.toml` | a person, then a bot |
| A dependency through a native manifest: mise, npm, uv, cargo | that manifest | never restated |
| A runtime edge to another Musher service | the environment binding that reaches it: `target = "<repository>#<interface>"` | a person |
| A runtime **capability**: PostgreSQL, object storage, payments | the environment binding that reaches it: `capability`, optionally `provider` | a person |
| The resource that satisfies a capability in an environment | environment configuration | infrastructure, not declared here |
| A **release record**: what a release delivered, byte for byte | `release.json` at the root of the delivering bundle | the release workflow |
| A **vendored copy** | `<product>/contracts/vendor/<repository>/<output>/`, holding the producer's `release.json` unchanged | copied, never edited |
| Verification evidence | check runs, `SHA256SUMS`, registry provenance | not declared |

In detail:

- **An interface is a surface another repository builds or runs against.** Files only the producer reads are not
  interfaces and do not go in `contracts/`. Each interface names its `format` (a registered term), its `definitions`
  (paths or globs), the output that `delivered_by` it, and its `compatibility`:
  - `gated`: a breaking change fails validation unless it ships as a major release;
  - `versioned`: a published `.vN.` file never changes, and a break is a new `.vN+1.` file;
  - `lockstep`: no compatibility promise, so only consumers released in the same composition may use it.
- **The `contract` output kind is retired.** Its term is removed, OUT-07 becomes a tombstone replaced by the
  interfaces declaration, and `schema_version = 1` declarations stay valid for this release series with the
  `contract` kind reported by OUT-03. This amends [decision 0010](0010-outputs-declaration.md).
- **A dependency declaration holds only what no manifest holds.** Every vendored interface is declared with its exact
  release version, which replaces `config/*.ref` files and hand-written lock files; that version is the only copy of
  the pin. Edges through mise, npm, uv and cargo are read from those manifests, never listed again, and must pin an
  exact version. No pin is a commit SHA, branch or range.
- **A vendored copy is verified offline.** The producer's `release.json` lists each interface's files with their
  SHA-256. The consumer keeps it unchanged beside the files it vendored, so the copy carries its own lock, and a check
  that can read no other repository can still prove the bytes are the release's.
- **Runtime edges live on bindings.** A binding names at most one of `target` or `capability`. Capabilities are
  terminology, like output kinds, so a new capability is a new term. A binding names the capability, never the
  cluster, bucket or account.
- **Each convention carries its own CI.** The convention that asks for an interface also asks for the tasks and
  workflow steps that keep it honest: `contracts:check` and `contracts:breaking` in validation, and `contracts:bundle`
  in the release. The convention that asks for a dependency asks for `deps:check` in validation and `deps:sync` in a
  scheduled `maintain-dependencies.yml`. These are presence checks: this repository runs nothing for others.
- **The runner hashes vendored files.** It reads `.repo/dependencies.toml` and each vendored `release.json`, and adds
  a `digests` map to the inventory with the SHA-256 of each file under `contracts/vendor/`. This amends
  [decision 0015](0015-the-runner-reads-what-conftest-cannot-select.md): one more thing the runner reads, selected by
  a fixed pattern, never by what a declaration says.
- **The org-wide graph is computed from the declarations, by a reader outside this repository.** Build edges must form
  a DAG and runtime edges may form cycles, but no single repository can see either. This repository will ship the
  graph logic in its command-line tool in a later release. `musher-dev/platform` runs it for now, and a dedicated
  service may replace that later. Decision 0010's rule that aggregation is not done here still holds: the logic is
  published here and runs elsewhere, like every other check.

The conventions are [EC-0030](../../engineering-conventions/definitions/conventions/interfaces/interfaces-declaration.md)
and [EC-0031](../../engineering-conventions/definitions/conventions/interfaces/publishing-interfaces.md) (family `IFACE`),
[EC-0032](../../engineering-conventions/definitions/conventions/dependencies/dependencies-declaration.md) and
[EC-0033](../../engineering-conventions/definitions/conventions/dependencies/keeping-dependencies-current.md) (family
`DEPS`), and ENVS-16 to ENVS-19 in EC-0020. The schemas are `outputs.schema.json` (version 2),
`dependencies.schema.json` and `release-record.schema.json`.

## Consequences

### Positive

- One question, one file: what a repository delivers and offers (`outputs.toml`), what it vendors
  (`dependencies.toml`), and what it reaches at runtime (`env.schema.yaml`).
- Each surface of a server is addressable as `<repository>#<interface>`, so a consumer depends on the public API, not
  on "the API".
- A pin has one place and one form, and a vendored copy proves its own bytes without the network.
- The graph can be computed from files every repository already keeps, by any reader.

### Negative

- A breaking release: the `contract` kind and its term are removed, so a declaration that uses it gets a finding.
- Repositories migrate: `.ref` files, `config/vendor/` copies and commit-SHA pins all move, and producers that publish
  nothing yet (the telemetry registry) must cut releases before their consumers can pin them.
- The runner hashes every vendored file on every check.

### Neutral

- Existing requirement IDs keep their meaning. OUT-07 stays as a tombstone.
- Pact-style contract tests, artifact attestations for private repositories and deploy-time admission checks are left
  for later: none of them is in the current stack, and GitHub Team offers no attestations for private repositories.

## Enforcement

- IFACE-01 to IFACE-08 and DEPS-01 to DEPS-07 are conftest checks with fixture repositories, over
  `.repo/outputs.toml`, `.repo/dependencies.toml`, the inventory and its digests.
- IFACE-11 to IFACE-13 and DEPS-08 to DEPS-10 check that the Taskfile defines the tasks and the workflows run them.
- ENVS-16 to ENVS-18 check `target`, `capability` and `provider` on bindings. ENVS-19 is `review-only`: a reviewer
  checks that a binding reaching another service or a capability names it.
- IFACE-09, IFACE-10 and IFACE-14 are `review-only`: a reviewer checks that references resolve inside the delivered
  files, that a breaking change follows its interface's compatibility, and that the release record is complete.
- `outputs.schema.json`, `dependencies.schema.json` and `release-record.schema.json` are embedded in `index.json` and
  applied by OUT-02, DEPS-02 and DEPS-05.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| A `component.yaml` descriptor | One file per component with every fact | rejected: the name is a customer document owned by `musher-dev/specifications`, and one file mixes facts with different writers |
| Backstage `catalog-info.yaml` as the source | A known format | rejected again ([decision 0013](0013-identity-declaration.md)): it stays a generated view |
| Each surface a `contract` output | No schema change | rejected: a surface is not something delivered, and one bundle delivers many surfaces |
| List every edge, native ones included | One complete file | rejected: the edge would be written twice, and the copies drift; `conventions describe` gives the full picture instead |
| Keep `.ref` files and point at them | Less migration | rejected: two files for one pin, and a SHA pin names no release |
| Runtime edges in `dependencies.toml` | All edges in one file | rejected: the binding already exists because the edge does, so the edge belongs on it |
| Interfaces and dependencies as above | Complete the `.repo/` split | **chosen** |

## References

- [Decision 0000: Charter](0000-charter.md)
- [Decision 0010: Outputs declaration](0010-outputs-declaration.md)
- [Decision 0015: The runner reads what conftest cannot select](0015-the-runner-reads-what-conftest-cannot-select.md)
- [oasdiff: breaking changes](https://github.com/oasdiff/oasdiff/blob/main/docs/BREAKING-CHANGES.md)
- [Buf: breaking change detection](https://buf.build/docs/breaking/)
- [OpenTelemetry Weaver](https://github.com/open-telemetry/weaver)
