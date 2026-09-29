---
title: A repository may adopt the conventions one family at a time, for a limited time
date: 2026-09-29
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0019 — A repository may adopt the conventions one family at a time, for a limited time

## Context

A repository that adopts a release sees every finding from every family its profile selects. Two established
repositories dry-running the conventions got about seventy findings each, across a dozen families. Some of those
findings replace a check the repository already runs; others are hygiene it has not reached yet.

[Decision 0016](0016-adopted-rules-get-new-families.md) has an upstream repository retire its local checks one family
at a time. When a local check is deleted, the family that replaces it must block in CI straight away, or the rule
stops being enforced anywhere. The other families should keep reporting, but must not fail the build yet.

None of the existing tools gives that split:

- `--fail-on warning` fails on every family, and `--fail-on error` fails on none while every requirement is a
  warning.
- A profile is defined by the release, not the repository. It cannot lower a severity
  ([EC-0001](../../engineering-conventions/definitions/conventions/adoption/conventions-declaration.md#profile-selection)),
  and excluding a family hides its findings.
- Waiving every finding of the families not yet adopted suppresses them rather than reporting them. The waivers need
  renewing, and each one that stops matching becomes an ADOPT-06 finding.
- A command-line filter would hide findings, is not reviewed in the repository, and lets local and CI runs differ.

## Decision

- **`.repo/conventions.toml` gains an optional `[adoption]` table**: `enforce`, a list of requirement families such as
  `["ADOPT", "REPO", "OUT", "GHA"]`, plus `tracking` (an `https://` issue URL) and `expires` (a quoted
  `"YYYY-MM-DD"`).
- **While the table is in force,** only findings in the listed families, and always the `ADOPT` family and `PARSE`
  errors, count toward `--fail-on`. Every other finding is still reported, marked `not enforced`, at its usual
  severity.
- **Without the table, or once it expires,** every family is enforced, exactly as before.
- **It includes rather than excludes.** A family that a later release adds arrives advisory during staging, rather
  than failing a build no one prepared.
- **It is time-boxed like a waiver.**
  - **ADOPT-11** reports an adoption that has expired, or that expires more than 180 days after the day the check
    runs.
  - **ADOPT-10** reports a listed family this release does not define.
- **The mark shows in every output.**
  - In JSON output, each finding carries `enforced`.
  - The text report marks a requirement's block `(not enforced)`, and the summary counts those findings.
  - Formats passed through to conftest carry the same mark in each finding's message.
- **The exit status is the same for every output format:** it counts enforced findings only.

## Consequences

### Positive

- A repository can make its CI gate blocking on the day it adopts, for the families it has cleaned up, and see
  everything else in the same report.
- Retiring a local check and enforcing its replacement happen in one pull request that edits one list.
- Nothing is hidden. The unenforced findings are still in the report, and the table's expiry forces the rest of the
  work to be scheduled.

### Negative

- Every finding carries one more field, and the text and conftest messages gain a marker while a staged adoption is
  in force.
- Formats passed through to conftest are now evaluated twice: once for the output, and once for the exit status.
- Families are coarse: a repository cannot enforce part of a family. A requirement that must stay advisory inside an
  enforced family still needs a waiver.

### Neutral

- A repository without the table is unaffected. Its JSON findings gain `enforced: true`.
- `--fail-on` still decides which severities fail; the table decides which families count.

## Enforcement

- **ADOPT-10 and ADOPT-11** in `checks/rego/adoption/declaration.rego`, with the fixtures `adopt-10-unknown-family`
  and `adopt-11-adoption-expired`.
- **`lib/enforcement.rego`** decides `enforced` for every finding, and `lib/findings.rego` puts it in each result.
- **`bin/report.jq`** and `src/conventions_tools/run.py` count only enforced findings toward `--fail-on`. The fixture
  `adoption-enforce-subset` expects an unenforced finding; `tests/test_launcher.py` checks the exit status for the
  text, JSON and passed-through formats.
- **`examples/staged-consumer/`** is a tested example of a staged adoption.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| A time-boxed `[adoption] enforce` list | Listed families fail the build; the rest report as not enforced | **chosen** |
| A command-line `--only` filter | Run only some families | rejected: hides findings, is not reviewed in the repository, lets local and CI runs differ |
| Consumer-defined profiles | The repository selects its own requirements | rejected: a profile cannot lower severity, and excluding a family hides it |
| Waive every finding of the families not yet adopted | Use the existing mechanism | rejected: suppresses rather than reports, and churns ADOPT-06 as findings are fixed |
| An exclude list | List the families not enforced | rejected: a family a later release adds would fail builds on upgrade |

## References

- [Decision 0016: Rules adopted from other repositories get new families](0016-adopted-rules-get-new-families.md)
- [EC-0001 Conventions declaration](../../engineering-conventions/definitions/conventions/adoption/conventions-declaration.md)
- [Consuming the conventions: Adopt in stages](../consuming.md#adopt-in-stages)
