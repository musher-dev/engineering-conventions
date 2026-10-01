---
id: EC-0036
title: Community files
summary: >-
  The files GitHub reads to route people to a repository are where GitHub
  reads them and in the form it honours: issue and discussion forms valid
  against GitHub's form schemas, a template chooser that decides blank
  issues, FUNDING.yml in .github/, one CODEOWNERS at .github/CODEOWNERS in
  syntax GitHub does not skip, and a security policy that says how to report
  a vulnerability and passes OpenSSF Scorecard's Security-Policy check.
status: draft
topic: community-files
applies_to:
  paths:
    - .github/ISSUE_TEMPLATE/*
    - .github/DISCUSSION_TEMPLATE/*
    - .github/FUNDING.yml
    - .github/CODEOWNERS
    - CODEOWNERS
    - docs/CODEOWNERS
    - SECURITY.md
    - .github/SECURITY.md
    - docs/SECURITY.md
created: 2026-10-01
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "GitHub Docs: Syntax for issue forms"
    url: https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms
  - title: "GitHub Docs: Configuring the template chooser"
    url: https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/configuring-issue-templates-for-your-repository#configuring-the-template-chooser
  - title: "GitHub Docs: Displaying a sponsor button in your repository"
    url: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/displaying-a-sponsor-button-in-your-repository
  - title: "GitHub Docs: Creating discussion category forms"
    url: https://docs.github.com/en/discussions/managing-discussions-for-your-community/creating-discussion-category-forms
  - title: "GitHub Docs: About code owners"
    url: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners
  - title: "GitHub Docs: Adding a security policy to your repository"
    url: https://docs.github.com/en/code-security/getting-started/adding-a-security-policy-to-your-repository
  - title: "OpenSSF Scorecard: Security-Policy"
    url: https://github.com/ossf/scorecard/blob/main/docs/checks.md#security-policy
  - title: SchemaStore
    url: https://github.com/SchemaStore/schemastore
requirements:
  - id: COMM-01
    title: An issue template is a .yml issue form valid against GitHub's issue-forms schema
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.community_files.community_files
  - id: COMM-02
    title: Issue forms come with a template chooser that is valid and sets blank_issues_enabled
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.community_files.community_files
  - id: COMM-03
    title: FUNDING.yml is in .github/ and valid against GitHub's funding schema
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.community_files.community_files
  - id: COMM-04
    title: A repository has one CODEOWNERS, at .github/CODEOWNERS
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.community_files.community_files
  - id: COMM-05
    title: CODEOWNERS uses only syntax GitHub honours, names well-formed owners and repeats no pattern
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.community_files.community_files
  - id: COMM-06
    title: A security policy GitHub recognises has a heading on reporting a vulnerability
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.community_files.community_files
  - id: COMM-07
    title: The security policy scores 10 on OpenSSF Scorecard's Security-Policy check
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: delegated
      tool: scorecard
      check: "scorecard --local . --checks Security-Policy --format json"
  - id: COMM-08
    title: A discussion category form is a .yml file valid against GitHub's discussion-forms schema
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.community_files.community_files
---

# Community files

GitHub reads a handful of files to route people who arrive at a repository: the forms a reporter fills in, the
Sponsor button, who is asked to review a change, and where to report a vulnerability. Every one of them fails quietly.
A form that does not match GitHub's syntax is left out of the chooser, a CODEOWNERS line GitHub cannot parse is
skipped, and a security policy in the wrong place is never shown. Nothing in the repository's own build notices. This
convention puts each file where GitHub reads it, in the form GitHub honours, and checks it the way GitHub would.

## Scope

This convention covers, in any repository checked against a release of `musher-dev/engineering-conventions`:

- the issue forms and the template chooser in `.github/ISSUE_TEMPLATE/`, and the legacy single issue template;
- the discussion category forms in `.github/DISCUSSION_TEMPLATE/`;
- `FUNDING.yml`;
- `CODEOWNERS`, wherever GitHub looks for it: `.github/`, the root or `docs/`;
- the security policy, `SECURITY.md` (or `.markdown`, `.adoc`, `.rst`) at the root, in `.github/` or in `docs/`.

What the files say is the repository's business: which forms it offers, who owns which paths, how it handles a
report. A form, a funding file or a discussion form is checked only where the repository has one. Every repository is
asked for a CODEOWNERS and a security policy.

The pull request template, the README, CONTRIBUTING and the changelog are not covered. GitHub gives them no syntax to
get wrong, and what makes them good is a review matter.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). It turns the checkable parts of
`musher-dev/platform`'s guidance on GitHub configuration and security policies into requirements, so that guidance can
be retired. Its requirements are `proposed` at severity `warning`, like every requirement in the 0.x series.

Where an industry schema or tool already defines the rule, this convention delegates to it rather than restating it:

| What | Defined by | Used here |
| --- | --- | --- |
| Issue forms, the template chooser, FUNDING.yml, discussion forms | [SchemaStore](https://github.com/SchemaStore/schemastore)'s schemas (Apache-2.0) | Vendored unmodified under `checks/schemas/vendor/schemastore/`, and validated in Rego |
| What makes a security policy useful | [OpenSSF Scorecard](https://github.com/ossf/scorecard)'s Security-Policy check | Delegated: the repository runs it (COMM-07) |
| CODEOWNERS syntax | GitHub's documentation | Checked in Rego (COMM-04, COMM-05): no maintained offline validator exists |

## Requirements

### COMM-01

**An issue template is a .yml issue form valid against GitHub's issue-forms schema.**

A Markdown issue template opens as a pre-filled text box: the reporter can delete every heading and submit, and nothing
is required. An issue form has typed fields that GitHub can make required, so a bug report arrives with the version
and the steps. GitHub leaves a form that does not match its syntax out of the chooser, and shows the error only on the
file's own page, so the form is validated against SchemaStore's issue-forms schema, the one editors already use. The
check reports:

- a `.md` file in `.github/ISSUE_TEMPLATE/`, or the single legacy template `ISSUE_TEMPLATE.md` at the root, in
  `.github/` or in `docs/`;
- a `.yaml` file there: GitHub reads the template chooser only as `config.yml`, so the directory uses `.yml`
  throughout;
- a `.yml` form, other than `config.yml`, that does not match the schema.

**Correct:**

```yaml
# .github/ISSUE_TEMPLATE/bug-report.yml
name: Bug report
description: Something does not work as documented.
labels: [bug]
body:
  - type: textarea
    id: what-happened
    attributes:
      label: What happened?
    validations:
      required: true
```

**Incorrect:**

```markdown
<!-- .github/ISSUE_TEMPLATE/bug-report.md: nothing here is required -->
## What happened?
```

```yaml
# .github/ISSUE_TEMPLATE/bug-report.yml: no description, and a textarea with no label
name: Bug report
body:
  - type: textarea
    attributes: {}
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### COMM-02

**Issue forms come with a template chooser that is valid and sets `blank_issues_enabled`.**

GitHub allows blank issues unless `.github/ISSUE_TEMPLATE/config.yml` turns them off, and the chooser then offers
"Open a blank issue" beside the forms, which skips every required field. Whether that is wanted is a decision, so a
repository with issue forms states it: `config.yml` exists, matches SchemaStore's issue-config schema (GitHub ignores
a chooser it cannot read), and sets `blank_issues_enabled` to `false` or `true`. The chooser is also where a contact
link sends a vulnerability report to a private channel instead of a public issue.

**Correct:**

```yaml
# .github/ISSUE_TEMPLATE/config.yml
blank_issues_enabled: false
contact_links:
  - name: Report a security vulnerability
    url: https://github.com/your-org/your-repo/security/advisories/new
    about: Report privately. Do not open a public issue for a vulnerability.
```

**Incorrect:**

```yaml
# .github/ISSUE_TEMPLATE/config.yml: blank issues left to the default, and a link with no about
contact_links:
  - name: Discussions
    url: https://github.com/your-org/your-repo/discussions
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### COMM-03

**`FUNDING.yml` is in `.github/` and valid against GitHub's funding schema.**

GitHub shows the Sponsor button only from `.github/FUNDING.yml` on the default branch; a `FUNDING.yml` at the root or
in `docs/`, or a `.github/FUNDING.yaml`, is never read. A file GitHub cannot read (an unknown platform, a list where a
single account is expected) shows no button and no error. The file is optional; where it exists, it is checked against
SchemaStore's funding schema.

**Correct:**

```yaml
# .github/FUNDING.yml
github: [your-org]
custom: ["https://example.com/sponsor"]
```

**Incorrect:**

```yaml
# FUNDING.yml at the root: GitHub never reads it
github: your-org
paypal: your-org   # not a platform GitHub supports
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### COMM-04

**A repository has one CODEOWNERS, at `.github/CODEOWNERS`.**

CODEOWNERS decides who is asked to review a change, and with a ruleset that requires code-owner review, who can
approve it. GitHub looks for it in `.github/`, then the root, then `docs/`, and reads only the first it finds, so a
second CODEOWNERS is silently ignored and its rules apply nowhere. One file in one place, beside the rest of GitHub's
configuration, is the one a reviewer edits. Every repository has one, even if it owns nothing yet: a path listed with
no owner is the documented way to leave it explicitly unowned. A catch-all `*` rule is not required; a repository that
wants review only on some paths lists only those.

**Correct:**

```text
.github/CODEOWNERS
```

**Incorrect:**

```text
CODEOWNERS               # at the root: move it to .github/
.github/CODEOWNERS
docs/CODEOWNERS          # ignored: GitHub reads .github/CODEOWNERS first
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### COMM-05

**CODEOWNERS uses only syntax GitHub honours, names well-formed owners and repeats no pattern.**

CODEOWNERS looks like a `.gitignore` but is not one. GitHub skips a line it cannot parse and reports the error only on
the file's page, so the paths that line was meant to protect lose their reviewers without a failing check. The check
reports, with the line number:

- a pattern that starts with `!`: negation is not supported;
- a pattern with a `[ ]` character range: not supported;
- a pattern that starts with `\#`: escaping a leading `#` is not supported;
- an owner that is not `@user`, `@org/team` or an email address, such as a bare name or a trailing comma;
- a pattern written on two lines: the later line wins and replaces the earlier one's owners entirely, so the owners
  on the first line are silently dropped.

Whether an owner exists and has write access needs GitHub's API, and stays a review matter.

**Correct:**

```text
# Last match wins, so broad patterns come first.
/docs/                 @your-org/docs
/src/api/              @your-org/api @alice
/src/api/generated/
```

**Incorrect:**

```text
/src/api/              @your-org/api
/src/api/              @alice              # replaces the line above: @your-org/api is dropped
!/src/api/generated/   @your-org/api       # negation: skipped
/src/[ab]*/            alice               # a range, and an owner without @: skipped
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### COMM-06

**A security policy GitHub recognises has a heading on reporting a vulnerability.**

Someone who finds a vulnerability looks for the security policy before opening an issue. Without one, the only visible
channel is a public issue, which discloses the vulnerability to everyone before it is fixed. GitHub links the policy
from the Security tab and the issue chooser only when it is `SECURITY.md` (or `.markdown`, `.adoc`, `.rst`) at the root,
in `.github/` or in `docs/`. The policy needs a heading on reporting a vulnerability, such as `Reporting a
vulnerability`, so the reader finds the channel in one look. A policy inherited from the organization's `.github`
repository does not count: a clone, a fork and the checks never see it. A supported-versions table is not required:
many repositories release only from `main`.

**Correct:**

```markdown
# Security policy

## Reporting a vulnerability

Report it privately through a GitHub security advisory:
https://github.com/your-org/your-repo/security/advisories/new. We reply within three working days.
```

**Incorrect:**

```markdown
# Security

Please be careful with secrets.
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### COMM-07

**The security policy scores 10 on OpenSSF Scorecard's Security-Policy check.**

[OpenSSF Scorecard](https://github.com/ossf/scorecard) judges a security policy by what it holds: a way to reach
someone (an email address or a link), enough text to describe a process, and words about disclosure and
vulnerabilities. It is the measure security tools and package indexes already show for a repository, so this
requirement delegates to it rather than restating its rules. Scorecard reads the local checkout and needs no token for
this check. Pin `aqua:ossf/scorecard` in `.config/mise/config.toml` and run it in the repository's own validation:

```sh
scorecard --local . --checks Security-Policy --format json
```

The policy passes when the check's `score` is 10. The conventions runner does not run Scorecard itself, so a finding
appears in the repository's own validation, not in `conventions check` output. COMM-06 checks what can be checked
without it: that the policy exists where GitHub reads it and has a reporting heading.

Checked by: scorecard (delegated) · Severity: warning · Since: 0.7.1

### COMM-08

**A discussion category form is a .yml file valid against GitHub's discussion-forms schema.**

A discussion category form is read from `.github/DISCUSSION_TEMPLATE/<category-slug>.yml` and nowhere else; a `.yaml`
or `.md` file there is never offered. Like an issue form, a form GitHub cannot parse is left out of the category, so
each one is validated against SchemaStore's discussion-forms schema. A repository without discussion forms has
nothing to check.

**Correct:**

```yaml
# .github/DISCUSSION_TEMPLATE/ideas.yml
labels: [idea]
body:
  - type: textarea
    id: idea
    attributes:
      label: What would you like to see?
    validations:
      required: true
```

**Incorrect:**

```yaml
# .github/DISCUSSION_TEMPLATE/ideas.yml: no body
title: "[Idea] "
labels: [idea]
```

Checked by: conftest · Severity: warning · Since: 0.7.1

## References

- [GitHub Docs: Syntax for issue forms](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms)
- [GitHub Docs: Configuring the template chooser](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/configuring-issue-templates-for-your-repository#configuring-the-template-chooser)
- [GitHub Docs: Displaying a sponsor button in your repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/displaying-a-sponsor-button-in-your-repository)
- [GitHub Docs: Creating discussion category forms](https://docs.github.com/en/discussions/managing-discussions-for-your-community/creating-discussion-category-forms)
- [GitHub Docs: About code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- [GitHub Docs: Adding a security policy to your repository](https://docs.github.com/en/code-security/getting-started/adding-a-security-policy-to-your-repository)
- [OpenSSF Scorecard: Security-Policy](https://github.com/ossf/scorecard/blob/main/docs/checks.md#security-policy)
- [SchemaStore](https://github.com/SchemaStore/schemastore), and `checks/schemas/vendor/schemastore/README.md` for the
  vendored copies
