---
id: EC-0001
title: Conventions declaration
summary: >-
  Every consuming repository pins the release it is checked against, and
  declares in an optional .repo/conventions.toml any convention profile other
  than the default and every time-boxed waiver it holds.
status: active
topic: adoption
applies_to:
  paths:
    - .repo/conventions.toml
created: 2026-09-23
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
requirements:
  - id: ADOPT-01
    title: A repository declares its conventions in .repo/conventions.toml
    status: retired
    severity: warning
    since: 0.1.0
    replaced_by: [ADOPT-09]
    validation:
      engine: conftest
      package: conventions.checks.adoption.declaration
  - id: ADOPT-02
    title: The conventions declaration is valid against its schema
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.adoption.declaration
  - id: ADOPT-03
    title: An expired waiver no longer suppresses its finding
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.adoption.declaration
  - id: ADOPT-04
    title: A waiver names a requirement that exists and is not retired
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.adoption.declaration
  - id: ADOPT-05
    title: A waiver expires within 180 days
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.adoption.declaration
  - id: ADOPT-06
    title: A waiver that suppresses nothing is removed
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.adoption.declaration
  - id: ADOPT-07
    title: The declaration names a profile the release defines
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.adoption.declaration
  - id: ADOPT-08
    title: The declared version is the version of the bundle being run
    status: proposed
    severity: warning
    since: 0.1.0
    validation:
      engine: conftest
      package: conventions.checks.adoption.declaration
  - id: ADOPT-09
    title: A repository pins the conventions release it is checked against
    status: proposed
    severity: warning
    since: 0.2.0
    validation:
      engine: conftest
      package: conventions.checks.adoption.declaration
---

# Conventions declaration

A repository that adopts these conventions pins the release it is checked against, usually as one line in its mise
configuration, `.config/mise/config.toml` (ADOPT-09). Anything else it needs to say goes in an optional
`.repo/conventions.toml`: a convention profile other than the one its kind selects, repository-specific vocabulary,
and every waiver it holds. The declaration makes a repository's position explicit and reviewable. A deviation is a
dated, tracked line in a file, not a silent gap in a check.

## Scope

This convention covers `.repo/conventions.toml` in every repository checked against a release of
`musher-dev/engineering-conventions`. It defines the file's format, how the profile is selected, and how waivers
behave over time.

## Status and authority

This convention is **active** and owned by this repository (`authority: self`). The declaration is this repository's
own interface, so no other repository is its authority. Its requirements are `proposed` at severity `warning` in the
0.x series, like every other requirement. The two statuses answer different questions: the convention is `active`
because the file format it defines is in use and governed here now; each requirement is `proposed` because no
consumer has yet seen its findings long enough for it to be enforced
([decision 0005](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0005-status-severity-and-versioning.md)).

The `ADOPT` family cannot be waived. A waiver exists to record a deviation from a requirement, and the requirements
that make waivers trustworthy (that they expire, name something real and are removed when unused) cannot themselves be
waived without making every waiver meaningless.

## The declaration file

```toml
# .repo/conventions.toml
schema_version = 1

# Optional: the convention profile that applies, overriding the one the kind in
# .repo/repository.toml selects.
profile = "base-repo"

# Optional: the release this repository is checked against, without the leading v.
# Leave it out when mise pins the release (github:musher-dev/engineering-conventions).
[conventions]
version = "0.1.0"

# Optional: display forms for this repository's own filename tokens. They add to
# the release's display forms and can never redefine one it ships.
[vocabulary.display_forms]
grpc = "gRPC"
sbom = "SBOM"

# Optional: time-boxed deviations, one [[waivers]] table each. Leave them out
# when there are none.
[[waivers]]
requirement = "GHA-32"
paths = [".github/workflows/validate-docs.yml"]
reason = """\
  The docs workflow is paths-filtered until its jobs move into validate-repository.yml; \
  its check is not yet required."""
tracking = "https://github.com/your-org/your-repo/issues/1"
expires = "2026-12-31" # quoted: a bare TOML date is not a string (ADOPT-02)
```

The file is TOML ([decision 0011](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0011-declarations-are-toml.md)).
Keys at the top level come before the first `[table]` header, since everything after a header belongs to that table.
Dates are quoted strings: an unquoted `expires = 2026-12-31` is a TOML date, which the checks read as a timestamp and
ADOPT-02 reports.

| Field | Required | Meaning |
| --- | --- | --- |
| `schema_version` | yes | The file format version. Always `1`. |
| `conventions.version` | no | The release pinned, such as `0.1.0`, for a repository that does not pin it in mise. Upgrade by changing this value and the downloaded bundle together; ADOPT-08 reports a mismatch. |
| `profile` | no | The convention profile that selects which requirements apply and at what severity. It overrides the profile of the repository's kind ([EC-0009](../repository/identity-declaration.md)); without either, `base-repo` applies. It must be one the pinned release defines (ADOPT-07). |
| `vocabulary.display_forms` | no | Extra display forms, keyed by lowercase token. They add to the release's display forms and cannot change one the release defines. |
| `decisions` | no | Where the repository keeps its decision records, when not in `docs/decisions/` as one `NNNN-slug.md` file each: `path`, `form` and `page`, described in [EC-0021](../decisions/decision-records.md#where-the-records-are). |
| `waivers` | no | A list of waivers, described below. |

The authoritative shape is `checks/schemas/conventions-declaration.schema.json`, and ADOPT-02 checks the file against
it.

### Waivers

A waiver suppresses the findings of one requirement, optionally only on some paths, until a date.

| Field | Required | Meaning |
| --- | --- | --- |
| `requirement` | yes | The requirement ID, such as `GHA-32`. Never an `ADOPT` requirement. |
| `paths` | no | Repository-relative globs. The waiver applies only to findings on matching paths. Omit to waive the requirement everywhere. |
| `reason` | yes | Why the deviation is needed, at least 20 characters. Written for the reviewer who will be asked to extend it. |
| `tracking` | yes | The URL of the issue that tracks removing the waiver. |
| `expires` | yes | The last day the waiver applies, as a quoted `"YYYY-MM-DD"` string, at most 180 days after the day the check runs. |

A waiver is a promise to fix something, with a date on it. When the date passes, the waived findings return and the
declaration itself reports the lapse (ADOPT-03). Extending a waiver is a new review: change `expires`, and say in the
pull request why the fix slipped.

### Profile selection

The profile decides which requirements apply and at which severity. A profile can include
requirements by family, by convention or by ID, exclude requirements, inherit from other profiles, and **raise** a
requirement's severity from `warning` to `error`. A profile can never lower a severity.

| Situation | Profile used |
| --- | --- |
| The declaration names a profile the release defines | That profile |
| The declaration names a profile the release does not define | The kind's profile, else `base-repo`, plus an ADOPT-07 finding |
| No declaration, or no `profile` in it, and `.repo/repository.toml` declares a registered `kind` | The profile named for the kind |
| Neither | `base-repo` |

`profile` is an override: most repositories leave it out and let their kind select the profile. An unknown profile
falls back to the kind's profile or `base-repo` rather than to nothing, so a typo in `profile` never switches every
check off.

The shipped profiles, and the families and requirements each includes, are documented in
[the profiles README](../../profiles/README.md). In the 0.x series `base-repo` reports proposed requirements, so a
repository sees every finding it would face before any of them can fail its build, and every kind's profile inherits
it.

## Requirements

### ADOPT-01

**A repository declares its conventions in `.repo/conventions.toml`.**

Retired in 0.2.0 and replaced by [ADOPT-09](#adopt-09). The declaration became optional when the release pin moved
to `mise.toml`, so a repository without one is no longer a finding; what adoption needs is a pin, not a file. The
declaration was a YAML file when this requirement was retired; the title names the file as it is today.

Checked by: nothing (retired) · Severity: warning · Since: 0.1.0

### ADOPT-02

**The conventions declaration is valid against its schema.**

The declaration is read by a policy engine, so a typo in a key is not an error the engine would notice by itself: an
unknown key is ignored, and a misspelled `waivers` waives nothing. Validating the file against
`conventions-declaration.schema.json`, which the release carries in its index, turns those mistakes into findings.
The schema rejects unknown keys, a `reason` under 20 characters, a `tracking` value that is not an `https` URL, a
malformed or unquoted date, and any waiver of an `ADOPT` requirement. A display form that redefines one the release
ships is reported here too.

**Correct:**

```toml
schema_version = 1
profile = "base-repo"

[conventions]
version = "0.1.0"
```

**Incorrect:**

```toml
schema_version = 1
profile = "base-repo"

[conventions]
version = "v0.1.0"            # no leading v

[[waiver]]                    # unknown key; should be waivers
requirement = "GHA-07"
expires = 2026-12-01          # unquoted: a TOML date, not a string
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### ADOPT-03

**An expired waiver no longer suppresses its finding.**

After `expires`, the waiver stops applying: the findings it suppressed are reported again at their normal severity,
and the declaration gets an ADOPT-03 finding naming the lapsed waiver. Both are reported so the reader sees the
original problem and the broken promise together. The waiver is removed once the fix lands, or extended in a reviewed
change that says why.

**Correct:**

```toml
[[waivers]]
requirement = "GHA-06"
reason = "Two workflows keep .yaml until the release tooling that globs for it is updated."
tracking = "https://github.com/your-org/your-repo/issues/1"
expires = "2026-11-30"        # still in the future on the day the check runs
```

**Incorrect:**

```toml
[[waivers]]
requirement = "GHA-06"
reason = "Two workflows keep .yaml until the release tooling that globs for it is updated."
tracking = "https://github.com/your-org/your-repo/issues/1"
expires = "2026-06-30"        # in the past: GHA-06 findings return, plus ADOPT-03
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### ADOPT-04

**A waiver names a requirement that exists and is not retired.**

A waiver for an ID the pinned release does not define suppresses nothing, and usually means a typo (`GHA-7` for
`GHA-07`) or a requirement that was retired and replaced. Either way the waiver no longer says what the repository
thinks it says. When a requirement is retired, its tombstone names the requirement that replaced it; move the waiver
there if it still applies.

**Correct:**

```toml
[[waivers]]
requirement = "GHA-24"
# ...
```

**Incorrect:**

```toml
[[waivers]]
requirement = "GHA-99"        # not defined in the pinned release
# ...
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### ADOPT-05

**A waiver expires within 180 days.**

A waiver with a distant expiry is a permanent deviation with a date attached. The 180-day ceiling, measured from the
day the check runs, forces a waiver to be looked at at least twice a year. A requirement that a repository will never
meet is a case for changing the requirement or the profile, which is a proposal to this repository, not a long
waiver.

**Correct:**

```toml
expires = "2027-01-31"        # within 180 days of a run on 2026-09-23
```

**Incorrect:**

```toml
expires = "2028-01-01"        # more than 180 days out
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### ADOPT-06

**A waiver that suppresses nothing is removed.**

A waiver that matches no finding is stale: the problem was fixed, the path moved, or the waiver was scoped wrongly
from the start. Left in place, a stale waiver would silently suppress the next unrelated finding on that path. The
check reports each waiver that matched no finding in the run.

**Correct:**

```toml
waivers = []                  # the GHA-32 fix landed, and the waiver went with it
```

**Incorrect:**

```toml
[[waivers]]
requirement = "GHA-32"
paths = [".github/workflows/validate-docs.yml"]   # file no longer exists
# ...
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### ADOPT-07

**The declaration names a profile the release defines.**

The profile decides which requirements apply, so a profile name the pinned release does not define leaves the repository
checked against something it did not choose. It usually means a typo (`base_repo` for `base-repo`), or a profile that a
newer release adds and this one lacks. The check falls back to the profile of the repository's kind, or to `base-repo`,
so the repository is still checked, and reports the unknown name so it can be corrected. The profiles a release defines
are listed in `definitions/profiles/README.md`.

**Correct:**

```toml
profile = "base-repo"
```

**Incorrect:**

```toml
profile = "base_repo"         # not a profile the release defines; the kind's is used, plus ADOPT-07
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### ADOPT-08

**The declared version is the version of the bundle being run.**

`conventions.version` says which release the repository meets, and the diagnostic links point at that release's
text. If the bundle actually run is a different version, the findings come from one release and the declaration
claims another: an upgrade that changed the pinned version but not the downloaded bundle (or the reverse) checks the
repository against rules nobody reviewed. The check compares the declared version with the version the bundle carries
in `checks/data/release.json`.

It only fires when the run has release data, which means when the checks run from a downloaded release bundle. A run
from a checkout of this repository has no release version to compare against, and reports nothing for ADOPT-08.

**Correct:**

```toml
[conventions]
version = "0.2.0"             # and CI downloads engineering-conventions-0.2.0.tar.gz
```

**Incorrect:**

```toml
[conventions]
version = "0.1.0"             # while CI downloads and runs the 0.2.0 bundle
```

Checked by: conftest · Severity: warning · Since: 0.1.0

### ADOPT-09

**A repository pins the conventions release it is checked against.**

A repository that runs whatever release is newest is checked against rules nobody reviewed, and an upgrade happens
to it rather than through a pull request. A pin makes the release a line in a diff that Renovate can raise and a
reviewer can read. The usual pin is the tool entry that installs the release through mise; for a repository that
does not use mise, `conventions.version` in the declaration is the pin. The check reads `mise.toml`, `.mise.toml`,
`.config/mise.toml`, `.config/mise/config.toml`, `mise/config.toml` and `.devcontainer/mise.toml`. The finding is
reported on `.config/mise/config.toml`, the file to add the pin to, and the one mise configuration
[EC-0017](../toolchain/tool-pins.md) allows.

**Correct:**

```toml
# .config/mise/config.toml
[tools]
"github:musher-dev/engineering-conventions" = "X.Y.Z"
```

**Incorrect:**

```sh
# no pin: each run checks against whichever release is newest
mise exec github:musher-dev/engineering-conventions@latest -- conventions check
```

Checked by: conftest · Severity: warning · Since: 0.2.0

## References

- [Consuming the conventions](https://github.com/musher-dev/engineering-conventions/blob/main/docs/consuming.md)
- [Decision 0005: Status, severity and versioning](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0005-status-severity-and-versioning.md)
- `checks/schemas/conventions-declaration.schema.json`
- `definitions/profiles/README.md`
