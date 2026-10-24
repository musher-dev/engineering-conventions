---
id: EC-0036
title: Community files
summary: >-
  The files GitHub reads to route people to a repository are where GitHub
  reads them and in the form it honours: issue and discussion forms valid
  against GitHub's form schemas, a template chooser that decides blank
  issues, at most one CODEOWNERS, at .github/CODEOWNERS, in syntax GitHub
  does not skip, owning selected paths and never every path, and naming
  only paths that exist, and a security policy that says how to report a
  vulnerability and passes OpenSSF Scorecard's Security-Policy check.
status: draft
topic: community-files
applies_to:
  paths:
    - .github/ISSUE_TEMPLATE/*
    - .github/DISCUSSION_TEMPLATE/*
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
    title: An issue form is a .yml file valid against GitHub's issue-forms schema
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
    title: A repository with a CODEOWNERS has exactly one, at .github/CODEOWNERS
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.community_files.community_files
  - id: COMM-04
    title: CODEOWNERS uses only syntax GitHub honours, names well-formed owners and repeats no pattern
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.community_files.community_files
  - id: COMM-05
    title: A repository's own security policy has a heading on reporting a vulnerability
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.community_files.community_files
  - id: COMM-06
    title: The security policy scores 10 on OpenSSF Scorecard's Security-Policy check
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: delegated
      tool: scorecard
      check: "scorecard --local . --checks Security-Policy --format json"
  - id: COMM-07
    title: A discussion category form is a .yml file valid against GitHub's discussion-forms schema
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.community_files.community_files
  - id: COMM-08
    title: Every repository has a CODEOWNERS
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.community_files.community_files
  - id: COMM-09
    title: CODEOWNERS has no catch-all rule that owns every path
    status: proposed
    severity: warning
    since: 0.9.2
    validation:
      engine: conftest
      package: conventions.checks.community_files.community_files
    waivable: false
  - id: COMM-10
    title: Every root-anchored literal path in CODEOWNERS names a file or directory that exists
    status: proposed
    severity: warning
    since: 0.9.2
    validation:
      engine: conftest
      package: conventions.checks.community_files.community_files
---

# Community files

GitHub reads a handful of files to route people who arrive at a repository: the forms a reporter fills in, who is
asked to review a change, and where to report a vulnerability. Every one of them fails quietly.
A form that does not match GitHub's syntax is left out of the chooser, a CODEOWNERS line GitHub cannot parse is
skipped, and a security policy in the wrong place is never shown. Nothing in the repository's own build notices. This
convention puts each file where GitHub reads it, in the form GitHub honours, and checks it the way GitHub would.

## Scope

This convention covers, in any repository checked against a release of `musher-dev/engineering-conventions`:

- the issue forms and the template chooser in `.github/ISSUE_TEMPLATE/`, and the legacy single issue template;
- the discussion category forms in `.github/DISCUSSION_TEMPLATE/`;
- `CODEOWNERS`, wherever GitHub looks for it: `.github/`, the root or `docs/`;
- the security policy, `SECURITY.md` (or `.markdown`, `.adoc`, `.rst`) at the root, in `.github/` or in `docs/`.

What the files say is the repository's business: which forms it offers, who owns which paths, how it handles a
report. Each file is checked only where the repository has one, except CODEOWNERS, which every repository has
(COMM-08). A repository without its own security policy relies
on the one its organization publishes, which GitHub shows in its place, and Scorecard judges that one (COMM-06).

The pull request template, the README, CONTRIBUTING and the changelog are not covered. GitHub gives them no syntax to
get wrong, and what makes them good is a review matter.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). It checks what GitHub's documentation,
SchemaStore and OpenSSF Scorecard already define for these files, and adds no content of its own. Its requirements are
`proposed` at severity `warning`, like every requirement in the 0.x series.

Where an industry schema or tool already defines the rule, this convention delegates to it rather than restating it:

| What | Defined by | Used here |
| --- | --- | --- |
| Issue forms, the template chooser, discussion forms | [SchemaStore](https://github.com/SchemaStore/schemastore)'s schemas (Apache-2.0) | Vendored unmodified under `checks/schemas/vendor/schemastore/`, and validated in Rego |
| What makes a security policy useful | [OpenSSF Scorecard](https://github.com/ossf/scorecard)'s Security-Policy check | Delegated: the repository runs it (COMM-06) |
| CODEOWNERS syntax | GitHub's documentation | Checked in Rego (COMM-03, COMM-04, COMM-10): no maintained offline validator exists |
| CODEOWNERS as a selective gate | The standard `musher-dev/platform` set, which it, `musher-dev/platform-api` and `musher-dev/specifications` follow | Checked in Rego (COMM-09), and never waived |

## Requirements

### COMM-01

**An issue form is a .yml file valid against GitHub's issue-forms schema.**

An issue form has typed fields that GitHub can make required, so a bug report arrives with the version and the steps.
GitHub leaves a form that does not match its syntax out of the chooser, and shows the error only on the file's own
page, so the form is validated against SchemaStore's issue-forms schema, the one editors already use. Whether a
repository offers forms, Markdown templates or neither is its own choice; a Markdown template is not checked. The
check reports:

- a `.yaml` file in `.github/ISSUE_TEMPLATE/`: GitHub reads the template chooser only as `config.yml`, so the
  directory uses `.yml` throughout;
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

**A repository with a CODEOWNERS has exactly one, at `.github/CODEOWNERS`.**

CODEOWNERS decides who is asked to review a change, and with a ruleset that requires code-owner review, who can
approve it. GitHub looks for it in `.github/`, then the root, then `docs/`, and reads only the first it finds, so a
second CODEOWNERS is silently ignored and its rules apply nowhere. One file in one place, beside the rest of GitHub's
configuration, is the one a reviewer edits. Every repository has one ([COMM-08](#comm-08)), and it lists only the
paths that need a code owner's review, never a catch-all ([COMM-09](#comm-09)).

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

### COMM-04

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

Whether an owner exists and has write access needs GitHub's API, and is not checked offline.

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

### COMM-05

**A repository's own security policy has a heading on reporting a vulnerability.**

Someone who finds a vulnerability looks for the security policy before opening an issue, and without one the only
visible channel is a public issue. GitHub links the policy from the Security tab and the issue chooser when it is
`SECURITY.md` (or `.markdown`, `.adoc`, `.rst`) at the root, in `.github/` or in `docs/`, and otherwise shows the
policy of the organization's `.github` repository. A repository that keeps its own policy in one of those places
needs a heading on reporting a vulnerability, such as `Reporting a vulnerability`, so the reader finds the channel in
one look. A repository without its own relies on the organization's, and COMM-06 judges whichever applies. A
supported-versions table is not required: many repositories release only from `main`.

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

### COMM-06

**The security policy scores 10 on OpenSSF Scorecard's Security-Policy check.**

[OpenSSF Scorecard](https://github.com/ossf/scorecard) judges a security policy by what it holds: a way to reach
someone (an email address or a link), enough text to describe a process, and words about disclosure and
vulnerabilities. It is the measure security tools and package indexes already show for a repository, so this
requirement delegates to it rather than restating its rules. Scorecard reads the local checkout and needs no token for
this check. Pin `aqua:ossf/scorecard` in `.config/mise/config.toml` and run it in the repository's own validation:

```sh
scorecard --local . --checks Security-Policy --format json
```

The policy passes when the check's `score` is 10. `--local` reads only the checkout, so a repository that relies on
its organization's policy runs the check against itself on GitHub instead, `scorecard --repo github.com/<owner>/<repo>
--checks Security-Policy`, which also looks in the organization's `.github` repository and needs a token. The
conventions runner does not run Scorecard itself, so a finding
appears in the repository's own validation, not in `conventions check` output. COMM-05 checks what can be checked
without it: that a policy the repository keeps itself has a reporting heading.

Checked by: scorecard (delegated) · Severity: warning · Since: 0.7.1

### COMM-07

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

### COMM-08

**Every repository has a CODEOWNERS.**

A repository without a CODEOWNERS asks no one in particular to review a change: a pull request waits until someone
happens to look, and a ruleset cannot require a code owner's approval ([BRANCH-03](../branch-protection/default-branch-protection.md#branch-03)).
CODEOWNERS is also where a reader finds who owns the repository's paths, which the identity declaration's `owner`
names only for the whole ([EC-0009](../repository/identity-declaration.md)). The check reports a repository with
no CODEOWNERS in any place GitHub reads one; [COMM-03](#comm-03) says which place.

**Correct:**

```text
# .github/CODEOWNERS
/.github/    @musher-dev/platform
/.repo/      @musher-dev/platform
```

**Incorrect:** no CODEOWNERS in `.github/`, at the root or in `docs/`.

Checked by: conftest · Severity: warning · Since: 0.8.0

### COMM-09

**CODEOWNERS has no catch-all rule that owns every path.**

CODEOWNERS names the gate: the few paths whose change carries trust or a wide blast radius, and who must approve a
change to them. A `*` line names everything, so it gates nothing in particular. With a ruleset that requires a code
owner's review ([BRANCH-03](../branch-protection/default-branch-protection.md#branch-03)), every pull request waits for
the same person, a bot's pin bump, a lock file and a typo fix included, and that person learns to approve without
reading. The paths that matter are then reviewed no more carefully than the rest. So a catch-all is banned outright:
**COMM-09 cannot be waived**, and a waiver that names it is itself reported ([ADOPT-06](../adoption/conventions-declaration.md#adopt-06)).

The selective gate is the standard `musher-dev/platform` set for every repository. CODEOWNERS owns the gate itself,
`/.github/` and `/.repo/` where it exists, plus a short list of paths whose change carries trust or a wide blast
radius, such as authentication, the release machinery or a published interface. Pin, lock and vendored files stay
unowned, so a bot's pull request merges on green checks. The ruleset pairs `required_approving_review_count: 0` with
`require_code_owner_review: true`, so a pull request that touches no owned path needs no review.

A repository that wants every change reviewed by someone says so where review is configured, not in CODEOWNERS: it
raises `required_approving_review_count` in the default branch's ruleset, and lets GitHub's review assignment for a
team spread the requests. That asks for a review on every pull request without making one person the owner of every
path.

The check reports, with the line number, a rule whose pattern is `*`, `**` or `/**` and names an owner. A narrower
glob, such as `*.md` or `/docs/**`, is a selection, not a catch-all, and a catch-all with no owner leaves every path
explicitly unowned. Whether each owner exists and has write access needs GitHub's API, and is not checked offline.

**Correct:**

```text
# .github/CODEOWNERS: the gate, and the paths with real blast radius
/.github/              @your-org/maintainers
/.repo/                @your-org/maintainers
/src/auth/             @your-org/security
```

**Incorrect:**

```text
# .github/CODEOWNERS: every pull request, a lock-file bump included, waits for review
*                      @your-org/maintainers
```

Checked by: conftest · Severity: warning · Since: 0.9.2 · Waivable: no

### COMM-10

**Every root-anchored literal path in CODEOWNERS names a file or directory that exists.**

A CODEOWNERS line names paths, not files, so nothing breaks when the path it names is renamed or deleted: the line
stays, matches nothing, and the code it was written to protect moves out from under it unowned. A selective gate
([COMM-09](#comm-09)) makes this worse, since an unowned path merges on green checks. A path that starts with `/` and
has no wildcard (`*`, `?`), range or escape names exactly one place in the repository, so the check can tell whether
it is there. A pattern ending in `/` must name a directory; one without it, a file or a directory. A relative pattern,
such as `docs/`, and a glob may match anywhere and are not judged. The check reports each such line, with its number.

**Correct:**

```text
/.github/              @your-org/maintainers
/src/auth/             @your-org/security
```

**Incorrect:**

```text
/src/authentication/   @your-org/security    # renamed to src/auth/: this line protects nothing
```

Checked by: conftest · Severity: warning · Since: 0.9.2

## References

- [GitHub Docs: Syntax for issue forms](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms)
- [GitHub Docs: Configuring the template chooser](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/configuring-issue-templates-for-your-repository#configuring-the-template-chooser)
- [GitHub Docs: Creating discussion category forms](https://docs.github.com/en/discussions/managing-discussions-for-your-community/creating-discussion-category-forms)
- [GitHub Docs: About code owners](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
- [GitHub Docs: Adding a security policy to your repository](https://docs.github.com/en/code-security/getting-started/adding-a-security-policy-to-your-repository)
- [OpenSSF Scorecard: Security-Policy](https://github.com/ossf/scorecard/blob/main/docs/checks.md#security-policy)
- [SchemaStore](https://github.com/SchemaStore/schemastore), and `checks/schemas/vendor/schemastore/README.md` for the
  vendored copies
