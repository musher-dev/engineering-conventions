---
id: EC-0029
title: OpenTofu state keys
summary: >-
  An OpenTofu root keeps its state in the shared state bucket under the key
  tfstate/<repository>/<root>/terraform.tfstate, where <repository> is the
  repository's name and <root> is the root's directory name; a
  root split by environment adds the environment before the file. A used
  key is never edited, it is migrated.
status: draft
topic: opentofu
applies_to:
  paths:
    - Taskfile.yml
    - "*/Taskfile.yml"
    - "*/*/Taskfile.yml"
    - "**/taskfiles/*.yml"
    - terraform/**/Taskfile.yml
    - "*/terraform/**/Taskfile.yml"
    - tofu/**/Taskfile.yml
    - "*/tofu/**/Taskfile.yml"
    - opentofu/**/Taskfile.yml
    - "*/opentofu/**/Taskfile.yml"
    - .repo/repository.toml
created: 2026-09-30
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "OpenTofu: backend configuration, partial configuration"
    url: https://opentofu.org/docs/language/settings/backends/configuration/#partial-configuration
  - title: "OpenTofu: the s3 backend"
    url: https://opentofu.org/docs/language/settings/backends/s3/
requirements:
  - id: TOFU-01
    title: An OpenTofu root's state key is tfstate/<repository>/<root>/terraform.tfstate
    status: proposed
    severity: warning
    since: 0.6.5
    validation:
      engine: conftest
      package: conventions.checks.opentofu.state
---

# OpenTofu state keys

Every OpenTofu root in the organization keeps its state in one shared bucket, each under its own key. The key is the
only thing that keeps two roots' state apart, and the only record of which repository writes it. This convention
gives the key one form that holds both: the repository, then the root.

## Scope

This convention covers the state key of every OpenTofu root in a repository checked against a release of
`musher-dev/engineering-conventions` with the `infrastructure` profile. A root is a directory OpenTofu is run in, with
its own backend and state, such as `terraform/network/`. How a root is laid out, what it manages and which bucket it
uses are the owning repository's business.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`), and TOFU-01 is `proposed` at severity
`warning`, like every requirement in the 0.x series.

It extends `musher-dev/foundation-bootstrap`'s state-key rule, which pairs a root's directory with its key inside one
repository; this one adds the repository, so the pairing holds across the organization. It does not replace that rule,
and it does not restate the procedure for moving a key, which stays foundation-bootstrap's migration runbook.

## Where the key is stated

Roots use a partial backend configuration: the `backend "s3" {}` block in the root is empty, the bucket and endpoint
come from a shared backend file, and the key is passed at init:

```sh
tofu init -backend-config=../backend.hcl -backend-config="key={{.TOFU_STATE_KEY}}"
```

The key itself is a Taskfile variable, `TOFU_STATE_KEY`, set either in the Taskfile that runs the root or in the
`vars` of the include that loads a shared Taskfile for it. A Taskfile that drives several roots names each one's key
`<ROOT>_STATE_KEY` beside its directory `<ROOT>_DIR`. The check reads exactly these variables.

## Frozen keys and migration

**A used key is never edited. It is migrated.** Changing the string in place points the backend at an empty key, and
the next plan offers to recreate everything the root manages. A key moves only by foundation-bootstrap's migration
runbook, one root at a time, when its owner chooses to.

Keys that predate this convention stay where they are until then. A repository records each one as a waiver in
`.repo/conventions.toml` ([EC-0001](../adoption/conventions-declaration.md)), naming the Taskfile that holds it and
the issue that tracks its migration:

```toml
[[waivers]]
requirement = "TOFU-01"
paths = ["terraform/network/Taskfile.yml"]
reason = "The network key is in use and frozen until it is migrated by the state-key migration runbook."
tracking = "https://github.com/your-org/your-repo/issues/1"
expires = "2026-12-31"
```

A waiver expires, so a frozen key comes back to its owner for a decision at least every 180 days: migrate it, or renew
the waiver with the reason it still stands.

## Requirements

### TOFU-01

**An OpenTofu root's state key is `tfstate/<repository>/<root>/terraform.tfstate`.**

`<repository>` is the repository's name, and `<root>` is the name of the root's directory. A root split by environment
puts the environment before the file: `tfstate/<repository>/<root>/<env>/terraform.tfstate`.

For the repository's name, the check takes the actual name when the runner knows it (from `--repository`,
`GITHUB_REPOSITORY` or the origin remote), and otherwise the `name` declared in `.repo/repository.toml`
([EC-0009](../repository/identity-declaration.md)). When it knows neither, it does not check the repository segment.

Each part prevents a failure:

- **The repository segment.** Without it, keys are unique only because no two repositories have used the same root
  name yet. A second repository that claims `tfstate/network/` reads and locks the first one's state on its first
  `tofu init`. And a key that does not name its repository can only be traced to an owner by searching every
  repository, and where access to a shared bucket is granted per bucket rather than per prefix, no credential says
  who writes where.
- **The root segment.** A key with only the repository in it has no room for the repository's second root.
- **The tfstate/ prefix.** Retention rules and tools that scan `tfstate/` match keys under that prefix. A key outside
  it is missed by both.

The check reads each Taskfile variable whose name ends in `STATE_KEY` and whose value is a string. It requires the
`tfstate/` prefix, the repository's name as the next segment (when a name is known), a root segment, at most an
environment after it, and `terraform.tfstate` as the file. Where the Taskfile says which directory the key belongs to,
through `<ROOT>_DIR` beside `<ROOT>_STATE_KEY` or through `TOFU_DIR: .` in a Taskfile kept in the root, the root
segment must be that directory's name. A segment built from a template (`{{.ENV}}`, `${ENV}`) matches anything, and a
key that starts with a template is built at run time and not judged.

The runner passes Taskfiles up to two directories deep, as it does for the Tasks conventions, and also every Taskfile
under a `terraform/`, `tofu/` or `opentofu/` directory at the top of the repository or one level down, where a root
keeps its own Taskfile.

**Correct:**

```yaml
# Repository platform-network, taskfiles/tofu.Taskfile.yml
vars:
  TOFU_DIR: terraform/network
  TOFU_STATE_KEY: tfstate/platform-network/network/terraform.tfstate
```

```yaml
# Repository platform-network, terraform/app/Taskfile.yml: one key per environment, such as terraform/app/staging
includes:
  tofu:
    taskfile: ../../taskfiles/layer.yml
    vars:
      TOFU_DIR: .
      TOFU_STATE_KEY: tfstate/platform-network/app/{{.ENV}}/terraform.tfstate
```

**Incorrect:**

```yaml
- tfstate/network/terraform.tfstate                   # no repository: unique only by luck, owner unknown
- platform-network/network/terraform.tfstate          # outside tfstate/: missed by retention rules and scans
- tfstate/platform-network/terraform.tfstate          # no root: nowhere for a second root to go
```

Checked by: conftest · Severity: warning · Since: 0.6.5

## References

- [OpenTofu: backend configuration, partial configuration](https://opentofu.org/docs/language/settings/backends/configuration/#partial-configuration)
- [OpenTofu: the s3 backend](https://opentofu.org/docs/language/settings/backends/s3/)
