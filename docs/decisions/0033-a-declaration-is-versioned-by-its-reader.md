---
title: A declaration carries a format version only when a reader outside its release reads it, and contracts stay with the product
date: 2026-10-13
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
amends: ["0022"]
---

# 0033 — A declaration carries a format version only when a reader outside its release reads it, and contracts stay with the product

## Context

Every `.repo/` declaration began with `schema_version = 1`. A format version exists so that a reader can tell which
shape it was handed when it may be handed more than one. That is true of two declarations and false of the other two:

| Declaration | Who reads it | Pinned to |
| --- | --- | --- |
| `.repo/conventions.toml` | `conventions check` | the release the repository pins |
| `.repo/dependencies.toml` | `conventions check` | the release the repository pins |
| `.repo/outputs.toml` | `conventions check`, and the org graph built from every repository's declarations | any release; version 1 and 2 coexist in this series |
| `.repo/repository.toml` | `conventions check`, and `musher-dev/infra-github` | infra-github pins its own vocabulary |

The conventions declaration and the dependencies declaration are read only by the conventions tool of the release
the repository pins. That pin already says which shape the file has, so the field adds nothing; nothing in `src/`,
`bin/` or the Rego policies reads it beyond schema validation. It is one more line every adopter copies, and a second
version number beside the pin that could suggest the two move independently.

The same review asked whether `<product>/contracts/` belongs in `.repo/` with the other declarations.

## Decision

**A declaration carries `schema_version` only when a reader outside the release that defines it reads it.**

- `.repo/conventions.toml` and `.repo/dependencies.toml` drop `schema_version`. Their schemas no longer require it;
  they still accept `1`, described as deprecated and ignored, and a later breaking release rejects the key. Any other
  value is still reported, by ADOPT-02 and DEPS-02. Every example, fixture and this repository's own declaration
  leave it out. This amends [decision 0022](0022-interfaces-and-dependencies.md), whose dependencies declaration
  carried it.
- `.repo/outputs.toml` and `.repo/repository.toml` keep it: the org graph and `musher-dev/infra-github` read them
  with tools pinned to other releases, and version 2 of the outputs declaration is the case the field exists for.

**An interface's files stay in `<product>/contracts/` (IFACE-08), not in `.repo/`.** The two directories hold
different things for different reviewers:

- `.repo/` holds declarations *about* the repository: what it is, what it publishes, what it vendors, which
  conventions it meets. Tooling reads them, and one CODEOWNERS entry gives them to the governance owners.
- `contracts/` holds the product's public interface files: the documents code is generated from and checked against,
  that ship in the bundles the product publishes, and that the product's owners review. They live beside the product
  for the same reason its source does.

Moving `contracts/` into `.repo/` would hide product files in a tooling directory, mix two review domains under one
owner, break IFACE-08 for every adopter, and give no check anything it cannot already see.

## Consequences

### Positive

- A conventions declaration with nothing to say is empty, and a dependencies declaration is its list of dependencies.
- The pin is the only version of the conventions and dependencies formats, so there is one number to raise.

### Negative

- The deprecated key is accepted for a while, so old and new declarations both validate until the breaking release
  that rejects it.

### Neutral

- Relaxing the schemas is a `feat`; rejecting the key later is a `feat!`
  ([decision 0005](0005-status-severity-and-versioning.md#change-classification)).

## Enforcement

- `conventions-declaration.schema.json` and `dependencies.schema.json` accept a declaration without `schema_version`
  and reject any value other than `1`; ADOPT-02 and DEPS-02 report the schema's findings. The fixtures
  `adopt-02-passes-without-schema-version`, `adopt-02-passes-deprecated-schema-version` and
  `deps-02-passes-deprecated-schema-version` hold it.
- IFACE-08 reports an interface whose definitions are outside `<product>/contracts/`.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Keep `schema_version` everywhere | One rule for every declaration | rejected: two of the four have no reader that needs it |
| Drop it everywhere | No format versions | rejected: the outputs and identity declarations are read by tools on other releases |
| Drop it where only the pinned release reads the file | The reader decides | **chosen** |
| Move `contracts/` into `.repo/` | Every declared file in one place | rejected: product files in a tooling directory, two review domains, breaks IFACE-08 |

## References

- [Decision 0011: The .repo/ declarations are TOML](0011-declarations-are-toml.md)
- [Decision 0022: Interfaces and dependencies](0022-interfaces-and-dependencies.md)
- [EC-0001 Conventions declaration](../../engineering-conventions/definitions/conventions/adoption/conventions-declaration.md)
- [EC-0032 Dependencies declaration](../../engineering-conventions/definitions/conventions/dependencies/dependencies-declaration.md)
- [EC-0030 Interfaces declaration](../../engineering-conventions/definitions/conventions/interfaces/interfaces-declaration.md)
