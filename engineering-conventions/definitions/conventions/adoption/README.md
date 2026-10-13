# Adoption

These conventions govern how a repository adopts the conventions: the release it pins, and the optional
`.repo/conventions.toml` in which it says anything else, from a profile other than its kind's to the waivers it
holds.

The governing rule, in one sentence:

> **Pin the release you are checked against, and write every deviation from it down as a dated, tracked line that
> lapses on its own.**

## Status

The convention is **active**, owned by this repository, and every requirement is `proposed` at severity `warning`.
The `ADOPT` family cannot be waived: it is what makes a waiver trustworthy.

## Who is checked

`base-repo` selects the family, so every repository is checked. A repository with no `.repo/conventions.toml` is
asked only to pin a release (ADOPT-09).

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0001 Conventions declaration](conventions-declaration.md) | ADOPT-01 – ADOPT-11 | The release pin, the declaration's format, profile selection, waivers and a staged adoption |

## Quick reference

```toml
# .config/mise/config.toml
[tools]
"github:musher-dev/engineering-conventions" = "0.1.0"   # ADOPT-09: the pinned release
```

```toml
# .repo/conventions.toml: optional, valid against its schema (ADOPT-02)
schema_version = 1
profile = "base-repo"              # ADOPT-07: a profile the release defines

[adoption]                         # a staged adoption
enforce = ["ADOPT", "REPO"]        # ADOPT-10: families the release defines
tracking = "https://github.com/your-org/your-repo/issues/2"
expires = "2027-01-31"             # ADOPT-11: within 180 days

[[waivers]]
requirement = "GHA-32"             # ADOPT-04: exists and is not retired
reason = "Paths-filtered until its jobs move into validate-repository.yml."
tracking = "https://github.com/your-org/your-repo/issues/1"
expires = "2026-12-31"             # ADOPT-05: within 180 days; ADOPT-03 once it passes
```

A waiver that suppresses nothing is removed (ADOPT-06). A `conventions.version`, for a repository that does not pin
the release in mise, must be the version of the bundle being run (ADOPT-08).
