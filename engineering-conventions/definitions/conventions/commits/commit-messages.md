---
id: EC-0035
title: Commit messages
summary: >-
  Every commit and every pull request title passes committed against the
  repository's .config/commits/committed.toml, which is the one list of the
  commit types and scopes it accepts. committed is pinned in mise, runs in
  lefthook's commit-msg hook, and checks the pull request title, beside
  action-semantic-pull-request for the scope and the lowercase start
  committed cannot require.
status: draft
topic: commits
applies_to:
  paths:
    - .config/commits/committed.toml
    - .config/mise/config.toml
    - .config/lefthook.yml
    - .github/workflows/*.yml
    - .github/conventional-commits.yaml
created: 2026-10-01
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: Conventional Commits 1.0.0
    url: https://www.conventionalcommits.org/en/v1.0.0/
  - title: "committed: reference"
    url: https://github.com/crate-ci/committed/blob/main/docs/reference.md
  - title: amannn/action-semantic-pull-request
    url: https://github.com/amannn/action-semantic-pull-request
  - title: "Lefthook: commit-msg arguments"
    url: https://lefthook.dev/configuration/run.html
requirements:
  - id: COMMIT-01
    title: .config/commits/committed.toml states the repository's commit rules
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.commits.messages
  - id: COMMIT-02
    title: committed is pinned in mise
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.commits.messages
  - id: COMMIT-03
    title: Lefthook's commit-msg hook runs committed on the message being written
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.commits.messages
  - id: COMMIT-04
    title: A pull request workflow checks the title with committed and requires a scope
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.commits.messages
  - id: COMMIT-05
    title: Every commit message and pull request title passes committed
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: delegated
      tool: committed
      check: "committed --config .config/commits/committed.toml"
  - id: COMMIT-06
    title: No .github/conventional-commits.yaml keeps a second list of types and scopes
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.commits.messages
---

# Commit messages

A commit message is read long after it is written: by release-please, which chooses the next version from its type
and writes the changelog from its subject; by `git log` and `git blame`; and by whoever reviews the pull request it
squashes into. A message that is not a Conventional Commit cuts the wrong release or none, and a scope nobody
declared sorts a change into a changelog section that does not exist.

The rules are checked by [committed](https://github.com/crate-ci/committed), a single binary that reads them from one
file. These requirements say where that file is, what it must hold, and the two places it runs: on the contributor's
machine before a commit exists, and on the pull request title before it becomes the squash commit.

## Scope

Every repository. A repository's commit history is its release history, whatever it holds.

The types and scopes are the repository's own. Which type a change takes is the repository's change classification
(this repository's is [decision 0005](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0005-status-severity-and-versioning.md#change-classification));
this convention requires only that the list exists, in one place, and is enforced. What the format means is
[Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/), which this convention does not restate.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`), and every requirement is `proposed` at
severity `warning`. It replaces the hand-written commit-message scripts and the `.github/conventional-commits.yaml`
lists that each repository kept ([decision 0025](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0025-commit-messages-delegate-to-committed.md)).

## Requirements

### COMMIT-01

**`.config/commits/committed.toml` states the repository's commit rules.**

committed reads its rules from the file `--config` names. That file is the one list of the repository's commit types
and scopes: the hook, the pull request check and release-please's configuration all follow it, and nothing else may
keep a copy that can drift from it. It sits under `.config/` like every other tool's configuration
([EC-0011](../configuration/tool-configuration.md)), so every caller passes its path.

The check reads each setting's effective value, which is committed's default where the key is absent, and reports a
file that is missing, or that does not set:

| Key | Value | Why |
| --- | --- | --- |
| `style` | `"conventional"` | The type and scope are what release-please reads |
| `allowed_types` | a list, not empty | committed's default list leaves out `ci` and `build`, and accepts types the repository may not release on |
| `allowed_scopes` | a list, not empty | Without one, any scope passes, and a typo becomes a changelog entry |
| `subject_length` | 1 to 72 (default 50) | The header fits a terminal and GitHub's commit list; `0` turns the limit off |
| `subject_not_punctuated` | `true` (default) | The subject is a title, not a sentence |
| `imperative_subject` | `true` (default) | A subject completes "this commit will …" |
| `no_wip` | `true` (default) | A work-in-progress commit never reaches the default branch |

**Correct:**

```toml
# .config/commits/committed.toml
style = "conventional"
subject_length = 72
line_length = 0
subject_capitalized = false
subject_not_punctuated = true
imperative_subject = true
no_fixup = false
no_wip = true
allowed_types = ["feat", "fix", "docs", "chore", "refactor", "test", "ci", "build"]
allowed_scopes = [
  "api",     # api/**
  "release", # release-please pull requests
  "repo",    # Taskfile, lefthook, .config/
]
```

**Incorrect:**

```toml
# committed.toml at the root: found by committed's own search, not passed by path
style = "conventional"
subject_length = 0            # no limit on the header
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### COMMIT-02

**committed is pinned in mise.**

The hook and the pull request check must run the same committed, at the version the configuration was written for,
or a rule passes on one and fails on the other. Pin it in the mise configuration with an exact version, like every
other tool ([EC-0017](../toolchain/tool-pins.md)). Its releases carry a Linux arm64 build that aqua's registry entry
does not list, so the `github:` backend installs it on every platform. The check applies to a repository that keeps a
mise configuration, and accepts committed under any backend.

**Correct:**

```toml
# .config/mise/config.toml
[tools]
"github:crate-ci/committed" = "1.1.11"
```

**Incorrect:**

```yaml
# a workflow step: installs whatever cargo resolves today
- run: cargo install committed
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### COMMIT-03

**Lefthook's commit-msg hook runs committed on the message being written.**

The hook is the cheapest place to catch a bad message: before the commit exists, while the author still has the
editor open. lefthook passes the message file as `{1}`; without `--commit-file {1}`, committed checks `HEAD`, which is
the previous commit, so the hook passes or fails on the wrong message. Without `--config`, it reads a root
`committed.toml`, or nothing. Skip merges and rebases: a merge commit's generated message is not a Conventional
Commit, and a rebase replays messages that were checked when they were written. The check applies to a repository
that runs its hooks with lefthook ([EC-0014](../git-hooks/lefthook.md)).

**Correct:**

```yaml
# .config/lefthook.yml
commit-msg:
  skip:
    - merge
    - rebase
  jobs:
    - name: committed
      run: committed --config .config/commits/committed.toml --commit-file {1}
      fail_text: "The message must pass .config/commits/committed.toml. Run 'committed --commit-file .git/COMMIT_EDITMSG'."
```

**Incorrect:**

```yaml
commit-msg:
  jobs:
    - name: committed
      run: committed --config .config/commits/committed.toml   # checks HEAD, not this message
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### COMMIT-04

**A pull request workflow checks the title with committed and requires a scope.**

The title becomes the squash commit, so it is the message release-please reads, and a hook on a contributor's machine
never sees it. A workflow triggered by `pull_request` runs committed on the title, passed on standard input
(`--commit-file -`) through an environment variable so the title never reaches the shell as code. committed cannot
require a scope or a lowercase first letter, so the same job also runs `amannn/action-semantic-pull-request` with
`requireScope: true`, and with `subjectPattern: ^[a-z].+$`, its `types` and `scopes` read from
`.config/commits/committed.toml`. The check applies to a repository with workflows, and reports a missing committed
step and a missing `requireScope` separately.

**Correct:**

```yaml
- name: Read the allowed types and scopes
  id: allowed
  run: |
    {
      echo "types<<EOF"; yq -p toml -o yaml '.allowed_types[]' .config/commits/committed.toml; echo "EOF"
      echo "scopes<<EOF"; yq -p toml -o yaml '.allowed_scopes[]' .config/commits/committed.toml; echo "EOF"
    } >> "$GITHUB_OUTPUT"
- name: Check the title passes committed
  env:
    TITLE: ${{ github.event.pull_request.title }}
  run: printf '%s\n' "$TITLE" | committed --config .config/commits/committed.toml --commit-file -
- name: Check the title has a scope and a lowercase subject
  uses: amannn/action-semantic-pull-request@48f256284bd46cdaab1048c3721360e808335d50  # v6.1.1
  env:
    GITHUB_TOKEN: ${{ github.token }}
  with:
    types: ${{ steps.allowed.outputs.types }}
    scopes: ${{ steps.allowed.outputs.scopes }}
    requireScope: true
    subjectPattern: ^[a-z].+$
```

**Incorrect:**

```yaml
- name: Check the title
  run: echo "${{ github.event.pull_request.title }}" | grep -Eq '^(feat|fix)(\(.+\))?: '
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### COMMIT-05

**Every commit message and pull request title passes committed.**

COMMIT-01 to COMMIT-04 make sure committed runs; this requirement is what it checks. Each rule exists because
something downstream reads the message:

| Rule | committed setting | Why |
| --- | --- | --- |
| The header is `type(scope): subject`, with `!` before the colon for a breaking change | `style = "conventional"` | release-please reads the type and the `!` to choose the version |
| The type is one the repository lists | `allowed_types` | A type outside the list lands in no changelog section |
| The scope is one the repository lists | `allowed_scopes`; required on a title by `requireScope` | The scope says which part of the repository changed |
| The header fits in 72 columns; committed lets its last word run over | `subject_length = 72` | It fits `git log --oneline` and GitHub's commit list |
| The subject is in the imperative mood | `imperative_subject = true` | It reads as "this commit will add …", like git's own messages |
| The subject does not end in punctuation | `subject_not_punctuated = true` | It is a title |
| The subject starts in lowercase | `subjectPattern` on the title | One style in every changelog |
| A blank line separates the header from a body | `style = "conventional"` | Tools split the header from the body at the first blank line |
| No work-in-progress commits | `no_wip = true` | A `WIP` commit is not a change anyone can release |

`fixup!` commits are allowed (`no_fixup = false`): they are squashed by `git rebase --autosquash` before a merge. A
`git revert` writes `Revert "…"`, which is not a Conventional Commit; reword it as `revert: …` with a type the
repository lists. The conventions runner does not run committed itself; a finding appears in the commit-msg hook and
in the pull request workflow, not in `conventions check` output.

**Correct:**

```text
feat(api): add a cursor to the deployment list

The list returned every deployment at once, which timed out for large
projects.
```

```text
fix(release)!: tag releases with a v prefix
```

**Incorrect:**

```text
Added cursor pagination to the deployment list.
```

```text
feat(apis): add a cursor
```

```text
WIP feat(api): add a cursor
```

Checked by: committed (delegated) · Severity: warning · Since: 0.7.1

### COMMIT-06

**No `.github/conventional-commits.yaml` keeps a second list of types and scopes.**

Before committed, each repository listed its types and scopes in `.github/conventional-commits.yaml` and read it with a
script of its own. Once `.config/commits/committed.toml` holds the list, the old file is a copy that nothing enforces,
and the next type added to one and not the other is accepted by one check and refused by the other. Move its types and
scopes, with their comments, into `allowed_types` and `allowed_scopes`, point every reader at the new file, and delete
it, with the script that read it.

**Correct:**

```text
.config/commits/committed.toml
```

**Incorrect:**

```text
.config/commits/committed.toml
.github/conventional-commits.yaml
```

Checked by: conftest · Severity: warning · Since: 0.7.1

## References

- [Decision 0025: Commit messages are checked by committed](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0025-commit-messages-delegate-to-committed.md)
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)
- [committed: reference](https://github.com/crate-ci/committed/blob/main/docs/reference.md)
- [amannn/action-semantic-pull-request](https://github.com/amannn/action-semantic-pull-request)
- [EC-0011 Tool configuration](../configuration/tool-configuration.md)
- [EC-0014 Lefthook configuration](../git-hooks/lefthook.md)
- [EC-0017 Tool pins](../toolchain/tool-pins.md)
