---
title: The dev container scaffold's general rules move here, and a stack is named by its directory
date: 2026-10-15
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
amends: ["0020"]
---

# 0037 — The dev container scaffold's general rules move here, and a stack is named by its directory

## Context

[Decision 0020](0020-dev-container-files-get-their-own-family.md) kept the dev container scaffold in
`musher-dev/development-container` and expected repositories to consume it by pinning a published image. That
repository has since stopped publishing an image (development-container#45): a repository now starts from the
template and keeps the copy. The copy includes the template's `.repo/governance/` policies, about a thousand lines
of Python, so every repository made from the template carries rules it cannot update.

Most of those rules are not about the scaffold. They state what any repository with a dev container, an env schema
or a declared product should satisfy, and each was filed here as its own issue:

- a glob in `.gitattributes`, a `dorny/paths-filter` filter or a `.claude/rules` `paths:` entry that matches nothing
  (#111);
- `forwardPorts`, `portsAttributes` and the ports the stacks publish disagreeing (#109);
- a compose `${VAR}`, a binding's `consumers` or its `mirrored_in` files disagreeing with the env schema (#107);
- a workspace mount outside the declared product, or an editor that is not pointed at it (#110).

Two of them need words this repository did not have. The env schema's `consumers` names *stacks*, but EC-0028
defined a stack only as a compose file. And two need file contents the inventory did not carry: `.gitattributes`,
and the files a binding's `mirrored_in` names.

## Decision

**A rule from the scaffold that holds for any repository is authored here, keeping the scaffold's code as an
alias; the scaffold keeps only rules about itself.** This amends decision 0020, whose premise of a published
scaffold image no longer holds. Its other parts stand: the scaffold stays in development-container, and no
template lives here.

- The ported requirements are AGENT-19, CONF-13, GHA-54, DEVC-19 to DEVC-23 and ENVS-32 to ENVS-34. Each carries
  the `development-container:` code it replaces in `aliases`.
- What stays in the scaffold: comparing forwarded ports with the port table in its own documentation, and its
  scripts' behaviour.
- **A stack's name is the name of the directory holding its compose file.**
  `.devcontainer/stacks/postgres/compose.yaml` is the stack `postgres`. EC-0028 states this, and an env binding's
  `consumers` names stacks this way.
- **The inventory carries two more texts.** It now carries the root `.gitattributes`, and every file an env
  schema's `mirrored_in` names that resolves inside the repository. Both are subject to the same size limit as the
  other texts.

## Consequences

### Positive

- A repository made from the template can delete the copied policies the conventions now cover. Fixes to those
  rules then reach it through its pin.
- The rules are written once in Rego, with fixtures, instead of once per copy in Python.

### Negative

- A repository that already meets the scaffold's rules sees new warnings wherever the two implementations differ.
  For example, compose ports written in long syntax are now read, where the scaffold's line pattern skipped them.

### Neutral

- Every ported requirement is `proposed` at `warning`, as the rest of the families are in 0.x.

## Enforcement

The requirements listed above, each with its conftest check and fixtures. That a scaffold rule ported here is
general, and not a description of how the template is built, is `review-only`, under the boundary decision 0020
sets.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Leave the rules in the scaffold | Each repository keeps its copy | rejected: a copy cannot be updated, and the rules are not about the scaffold |
| Publish the scaffold's policies as their own tool | development-container releases a checker that repositories pin | rejected: a second checker with its own pin, diagnostics and waivers, for rules of the same kind as the conventions |
| Port the general rules here | This decision | **chosen** |

## References

- [Decision 0020](0020-dev-container-files-get-their-own-family.md)
- musher-dev/development-container#45
- Issues #107, #109, #110, #111
