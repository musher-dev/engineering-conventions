# Community files

These conventions govern the files GitHub reads to route people to a repository: the issue and discussion forms, the
template chooser, `FUNDING.yml`, `CODEOWNERS` and the security policy.

The governing rule, in one sentence:

> **Put each community file where GitHub reads it, in the form GitHub honours, and check it the way GitHub would.**

The topic is named for its files. GitHub calls most of them "community health files", but `CODEOWNERS` is not one of
those and governs the same surface: who is routed where when they arrive. `github` would claim all of `.github/`,
which the GitHub Actions and release conventions already govern.

## Status

The convention is a **draft**, owned by this repository, and every requirement is `proposed` at severity `warning`.
It delegates to industry definitions where they exist: SchemaStore's schemas for the forms, vendored under
`checks/schemas/vendor/schemastore/`, and OpenSSF Scorecard for what makes a security policy useful.

## Who is checked

The `base-repo` profile selects the family, so every repository is checked. Every repository is asked for a
`CODEOWNERS` and a security policy; the forms and `FUNDING.yml` are checked only where they exist.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0036 Community files](community-files.md) | COMM-01 – COMM-08 | Issue forms and the template chooser, FUNDING.yml, CODEOWNERS, the security policy, discussion forms |

## Quick reference

| File | Where GitHub reads it | Checked against |
| --- | --- | --- |
| Issue forms | `.github/ISSUE_TEMPLATE/*.yml` | SchemaStore `github-issue-forms.json` (COMM-01) |
| Template chooser | `.github/ISSUE_TEMPLATE/config.yml`, setting `blank_issues_enabled` | SchemaStore `github-issue-config.json` (COMM-02) |
| Sponsor button | `.github/FUNDING.yml` | SchemaStore `github-funding.json` (COMM-03) |
| Code owners | `.github/CODEOWNERS`, the only copy | GitHub's documented syntax (COMM-04, COMM-05) |
| Security policy | `SECURITY.md` at the root, in `.github/` or in `docs/` | A reporting heading (COMM-06); Scorecard Security-Policy at 10 (COMM-07) |
| Discussion forms | `.github/DISCUSSION_TEMPLATE/<category-slug>.yml` | SchemaStore `github-discussion.json` (COMM-08) |
