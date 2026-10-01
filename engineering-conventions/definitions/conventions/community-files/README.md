# Community files

These conventions govern the files GitHub reads to route people to a repository: the issue and discussion forms, the
template chooser, `CODEOWNERS` and the security policy.

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

The `base-repo` profile selects the family, so every repository is checked. Each file is checked only where the
repository has one; a repository without its own security policy relies on its organization's, which Scorecard judges
(COMM-06).

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0036 Community files](community-files.md) | COMM-01 – COMM-07 | Issue forms and the template chooser, CODEOWNERS, the security policy, discussion forms |

## Quick reference

| File | Where GitHub reads it | Checked against |
| --- | --- | --- |
| Issue forms | `.github/ISSUE_TEMPLATE/*.yml` | SchemaStore `github-issue-forms.json` (COMM-01) |
| Template chooser | `.github/ISSUE_TEMPLATE/config.yml`, setting `blank_issues_enabled` | SchemaStore `github-issue-config.json` (COMM-02) |
| Code owners | `.github/CODEOWNERS`, the only copy, where there is one | GitHub's documented syntax (COMM-03, COMM-04) |
| Security policy | `SECURITY.md` at the root, in `.github/` or in `docs/`, else the organization's | A reporting heading (COMM-05); Scorecard Security-Policy at 10 (COMM-06) |
| Discussion forms | `.github/DISCUSSION_TEMPLATE/<category-slug>.yml` | SchemaStore `github-discussion.json` (COMM-07) |
