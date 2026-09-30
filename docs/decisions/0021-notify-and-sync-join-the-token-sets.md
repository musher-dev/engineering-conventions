---
title: A notification workflow is notify, a syncing action is sync, and action synonyms are terminology
date: 2026-09-30
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
amends: ["0006"]
---

# 0021 — A notification workflow is notify, a syncing action is sync, and action synonyms are terminology

## Context

[Decision 0006](0006-github-actions-naming-vocabulary.md) closed the GitHub Actions token sets and left two kinds of
automation without a token. The first is a workflow that only sends a message: company's weekly chat digest fits no
responsibility. The second is an action that changes external state to keep it in step with the repository: infra's
bootstrap sync fits no action token. Each repository that met one of them could only record a waiver
([#11](https://github.com/musher-dev/engineering-conventions/issues/11)).

The closest existing tokens don't fit, because their definitions say what the unit changes. A notification changes
nothing, so it is neither `repository` nor `maintain`. A sync changes what it finds, so it is not `check`, which is
defined as changing nothing.

GHA-20 also suggests a token for a directory that starts with a common stand-in (`auth`, `validate`, `verify`). That
map was a literal in its Rego, the one piece of GitHub Actions vocabulary outside the terminology.

## Decision

We will add two provisional terms to `definitions/terminology/global.yml` and move the synonym map into it:

- `gha.responsibility.notify`, token `notify`: a workflow that only sends a message and changes nothing, in the
  repository or elsewhere.
- `gha.action.sync`, token `sync`: an action that changes external state to match what the repository declares. It
  is the counterpart of `check`.
- The stand-ins GHA-20 maps to an action token become aliases of the action terms, with the scope `action-token`.
  `task generate` projects them into `vocabulary.action_synonyms` in `checks/data/index.json`, and the check reads
  them from there. The scope reaches no other generated list, so `validate` and `verify` stay valid workflow tokens.

The sets stay closed: no other token changes, and the terminology is now the single source of every word the checks
read.

## Consequences

### Positive

- The two repositories waiting on a token can name their units without a waiver.
- Every GitHub Actions word a check reads comes from the terminology, so adding a synonym is a terminology change
  with its own change class.

### Negative

- Two more tokens to learn. Each has a "not this" row in its convention to keep it apart from its neighbours.

### Neutral

- Both terms are `provisional`, so a 0.x release may still rename them.
- GHA-02, GHA-04 and GHA-20 messages now list the new tokens among the valid ones.

## Enforcement

GHA-02 accepts `notify` as a responsibility and GHA-20 accepts `sync` as an action token. The near-miss fixtures
`gha-02-passes-notify` and `gha-20-passes-sync` prove both. `task generate:check` fails if
`vocabulary.action_synonyms` drifts from the terminology. A test in `tests/test_generate.py` fails if an
`action-token` alias reaches a banned-token list or the Vale style.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| A | Widen `repository` or `monitor` to cover notifications, and `setup` to cover syncing | rejected: each token's definition says what it changes; widening it makes the name say less |
| B | Keep waivers until more cases appear | rejected: two repositories already carry them, and the waivers expire |
| C | Add `notify` and `sync`, and move the synonyms into the terminology | **chosen** |

## References

- [Decision 0006](0006-github-actions-naming-vocabulary.md), which this amends
- [EC-0002 Workflow files](../../engineering-conventions/definitions/conventions/github-actions/workflow-files.md)
- [EC-0004 Composite actions](../../engineering-conventions/definitions/conventions/github-actions/composite-actions.md)
- [#11](https://github.com/musher-dev/engineering-conventions/issues/11)
