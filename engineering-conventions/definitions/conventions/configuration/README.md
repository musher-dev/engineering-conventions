# Configuration

These conventions govern a repository's tool configuration: where the files that configure its linters, formatters,
scanners and hooks live, how each tool is pointed at its file, and how a scanner's suppressions are kept honest.

The governing rule, in one sentence:

> **Keep each tool's configuration in `.config/<concern>/<tool>.<ext>`, pass that path from every caller, and give
> every suppression a reason and an end date.**

## Status

Both conventions are **drafts**, owned by this repository, and every requirement is `proposed` at severity `warning`.
They adopt the CFG checks of `musher-dev/platform` and `musher-dev/development-container`; each requirement lists the
check it replaces in `aliases`, so a waiver or a habit that names `CFG-03` still finds `CONF-03`.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0011 Tool configuration](tool-configuration.md) | CONF-01 – CONF-09 | Where configuration lives, the `.config/` index, callers, and what `.config/` may hold |
| [EC-0012 Suppressions](suppressions.md) | CONF-10 – CONF-12 | Reasons and expiry dates in Trivy's and gitleaks' ignore files |

## Quick reference

| Put | Where |
| --- | --- |
| A linter's, formatter's or scanner's configuration | `.config/<concern>/<tool>.<ext>`, no leading dot |
| lefthook's configuration | `.config/lefthook.yml` |
| mise's configuration and lockfile | `.config/mise/config.toml`, `.config/mise/mise.lock` |
| The index of all of them | `.config/README.md`, one row per file |
| Trivy's ignore file | `.config/security/trivyignore.yaml`, every entry with `statement` and `expired_at` |
| A file its tool reads only from the root | The root: `Taskfile.yml`, `.gitignore`, `.gitattributes`, `.dockerignore` |
