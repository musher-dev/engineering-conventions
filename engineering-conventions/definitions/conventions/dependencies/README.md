# Dependencies

These conventions govern how a repository depends on another Musher repository's release: where it pins the version,
how it keeps a copy of the interfaces it builds against, how that copy proves it is exactly what was released, and
how it is kept current; and what keeps every other dependency current: the updater that watches its actions, images
and packages.

The governing rule, in one sentence:

> **Pin every release in one place and one form, vendor only released bytes with their release record, and let a
> scheduled workflow, Renovate or Dependabot propose each update.**

Every dependency has exactly one written pin:

| Dependency | The pin lives in | Declared in `.repo/dependencies.toml` |
| --- | --- | --- |
| Another repository's interfaces, vendored | `.repo/dependencies.toml` | yes |
| A package another repository publishes (npm, PyPI, crates) | the package manifest | no: read from the manifest |
| A tool another repository publishes | `.config/mise/config.toml` | no: read from the mise configuration |
| Another service at runtime | nowhere: the binding in `env.schema.yaml` names it with `target` | no |

## Status

The conventions are **drafts**, owned by this repository, and every requirement is `proposed` at severity `warning`.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0032 Dependencies declaration](dependencies-declaration.md) | DEPS-01 – DEPS-07 | The file, exact pins, the vendored copy and its release record |
| [EC-0033 Keeping dependencies current](keeping-dependencies-current.md) | DEPS-08 – DEPS-10 | The `deps:*` tasks, validation, the scheduled update |
| [EC-0042 Automated dependency updates](automated-updates.md) | DEPS-11 – DEPS-13 | Renovate or Dependabot for the actions, the Dockerfiles and the product's manifest |

What a producer declares and ships is the [interfaces](../interfaces/README.md) topic. Runtime edges and capabilities
are fields of an environment binding ([EC-0020](../environment/env-schema.md)). The reasoning is recorded in
[decision 0022](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0022-interfaces-and-dependencies.md).

## Quick reference

```toml
# .repo/dependencies.toml
schema_version = 1

[[dependencies]]
repository = "platform-api"
output = "contracts"
interfaces = ["public-http"]
version = "0.36.1"
```

```text
web/contracts/vendor/platform-api/contracts/
├── release.json              the producer's release record, unchanged
└── openapi/public.json       the interface's files, byte for byte
```

| Task | Does |
| --- | --- |
| `deps:check` | Verifies every vendored copy against its release record, offline, and that code generated from it is current |
| `deps:sync` | Fetches each pinned release, verifies it against the release's `SHA256SUMS`, and replaces the copy |
