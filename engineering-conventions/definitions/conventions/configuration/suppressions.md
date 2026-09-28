---
id: EC-0012
title: Suppressions
summary: >-
  Every entry in a security scanner's ignore file states why the finding is
  acceptable and, where the scanner can expire it, a date within 180 days on
  which it stops being ignored: Trivy's trivyignore.yaml and .trivyignore,
  and gitleaks' .gitleaksignore.
status: draft
topic: configuration
applies_to:
  paths:
    - .config/**/trivyignore.yaml
    - .config/**/trivyignore
    - .config/**/gitleaksignore
    - "**/.trivyignore"
    - "**/.gitleaksignore"
created: 2026-09-28
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
implementations:
  - repo: musher-dev/platform
    check: CFG-09
    mode: blocking
references:
  - title: "Trivy: Filtering"
    url: https://trivy.dev/latest/docs/configuration/filtering/
  - title: "gitleaks: README"
    url: https://github.com/gitleaks/gitleaks#readme
requirements:
  - id: CONF-10
    title: Every entry in a trivyignore.yaml has a statement and an expiry within the term
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.configuration.suppressions
    aliases: ["platform:CFG-09"]
  - id: CONF-11
    title: Every entry in a .trivyignore has an expiry within the term and a rationale above it
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.configuration.suppressions
  - id: CONF-12
    title: Every entry in a .gitleaksignore has a rationale above it
    status: proposed
    severity: warning
    since: 0.6.0
    validation:
      engine: conftest
      package: conventions.checks.configuration.suppressions
---

# Suppressions

A scanner's ignore file turns a finding off. An entry without a reason cannot be reviewed, and an entry without an end
date suppresses the finding for as long as the file exists, long after anyone remembers why. This convention holds a
security scanner's suppressions to the same standard as a waiver of a requirement
([ADOPT-03 and ADOPT-05](../adoption/conventions-declaration.md#adopt-05)): each says why, and each ends.

## Scope

This convention covers the ignore files of Trivy (`trivyignore.yaml` and `.trivyignore`) and gitleaks
(`.gitleaksignore`), wherever they are: at the root, or under `.config/` without their leading dot
([EC-0011](tool-configuration.md)). The check reads `trivyignore.yaml` only at `.config/security/trivyignore.yaml`.
Whether an entry's reason is true is for review; these requirements prove only that a reason and an end are there.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). CONF-10 adopts `musher-dev/platform`'s
CFG-09, which retires there once a release carries it
([decision 0016](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0016-adopted-rules-get-new-families.md)).
CONF-11 and CONF-12 are new. Every requirement is `proposed` at severity `warning`.

### Differences from platform CFG-09

| platform CFG-09 | CONF-10 | Why |
| --- | --- | --- |
| Reads `vulnerabilities` only | Reads `vulnerabilities`, `misconfigurations`, `secrets` and `licenses` | Trivy honours an entry in any of them |
| Accepts any date, including a past one | The date is in the future and at most 180 days ahead | A suppression is a waiver of a finding, and gets a waiver's term |
| Reports an `expired_at` written as a quoted string | Does not tell a quoted date from an unquoted one | conftest reads both as the same string |

## The term

An expiry is at most **180 days** after the check runs, the same term as a waiver
([ADOPT-05](../adoption/conventions-declaration.md#adopt-05)). A date in the past is reported too: the scanner has
already stopped honouring the entry, so either the finding is fixed and the entry is dead weight, or it is not and the
scan fails. Renewing an entry means writing a new date and a statement that is still true.

## Requirements

### CONF-10

**Every entry in a `trivyignore.yaml` has a statement and an expiry within the term.**

Trivy accepts an entry that is only an ID and then ignores that finding forever. `statement` says why the finding is
acceptable, `expired_at` says when that stops being true, and Trivy reports the finding again after that date. The
check reads every entry under `vulnerabilities`, `misconfigurations`, `secrets` and `licenses`, and reports one
finding per entry naming everything it lacks.

**Correct:**

```yaml
vulnerabilities:
  - id: CVE-2026-0001
    statement: The vulnerable parser is only reached by the admin import, which this image does not ship.
    expired_at: 2026-12-01
```

**Incorrect:**

```yaml
vulnerabilities:
  - id: CVE-2026-0001
```

Checked by: conftest · Severity: warning · Since: 0.6.0 · Formerly: platform CFG-09

### CONF-11

**Every entry in a `.trivyignore` has an expiry within the term and a rationale above it.**

The plain ignore file has no statement field, so the rationale is a `#` comment directly above the entry. Entries
listed together under one comment share it; a blank line ends the group. The expiry is Trivy's own `exp:` suffix,
which it honours the same way as `expired_at`.

**Correct:**

```text
# The vulnerable parser is only reached by the admin import, which this image does not ship.
CVE-2026-0001 exp:2026-12-01
```

**Incorrect:**

```text
CVE-2026-0001
```

Checked by: conftest · Severity: warning · Since: 0.6.0

### CONF-12

**Every entry in a `.gitleaksignore` has a rationale above it.**

An entry in `.gitleaksignore` is a finding's fingerprint: a commit, a file, a rule and a line. It records that
something looked like a secret, not why it is not one, and a reader cannot tell a test key from a real credential
someone chose to ignore. A `#` comment directly above the entry says which it is; entries listed together share it.
gitleaks has no expiry for an entry, so none is required.

**Correct:**

```text
# The example key from the vendor's documentation, not a credential.
3f2a91c:docs/setup.md:generic-api-key:42
```

**Incorrect:**

```text
3f2a91c:docs/setup.md:generic-api-key:42
```

Checked by: conftest · Severity: warning · Since: 0.6.0

## Rationale

The failure every requirement here prevents is the same: a suppression nobody can account for. A reason makes an
entry reviewable when it is added. An end date makes it reviewed again, by the scan itself, instead of relying on
someone to remember. The term matches a waiver's so that the organization has one answer to "how long may we ignore
this".

## References

- [Trivy: Filtering](https://trivy.dev/latest/docs/configuration/filtering/), the `trivyignore.yaml` fields and the
  `exp:` suffix
- [gitleaks](https://github.com/gitleaks/gitleaks#readme), the `.gitleaksignore` fingerprint format
