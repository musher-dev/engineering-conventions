---
title: A convention names its authority, and ownership moves in one change
date: 2026-09-23
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0002 — Authority and migration

## Context

The first conventions in this repository are not new. GitHub Actions naming was designed in `musher-dev/platform`
(issue [#2892](https://github.com/musher-dev/platform/issues/2892)), where checks CI-14 to CI-19 already block merges.
Moving such a rule here raises a question the rule itself cannot answer: while it exists in both places, which one is
right?

Two live authorities for one rule is the failure this repository exists to end. If the platform changes its grammar
and this repository does not, or the reverse, every consumer is checked against a rule its neighbor does not follow,
and both sides can point to a document that says they are correct.

## Decision

Every convention declares where its authority lives, who already implements it, and how far its migration has gone.
These are fields of the convention's frontmatter:

| Field | Values | Meaning |
| --- | --- | --- |
| `authority` | `self`, or `{repo, ref}` | Which repository decides what the convention says. `self` means this one; `{repo, ref}` names the upstream repository and the issue or document that holds the authoritative text |
| `implementations` | a list of `{repo, check, mode}` | Checks elsewhere that enforce the same requirements, such as `{repo: musher-dev/platform, check: CI-14, mode: blocking}` |
| `migration` | `proposed`, `mirrored`, `authoritative` | `proposed`: published here for comment, the upstream rule governs. `mirrored`: tracked here and kept in step with upstream. `authoritative`: this repository governs, and upstream checks follow it |

**Ownership moves in a single change.** A convention whose authority is another repository becomes authoritative here
only through one pull request in that repository which, at once:

1. replaces its local rule text with a link to the convention here;
2. pins a release of this repository in its conventions declaration;
3. retires or re-points its local checks, keeping their IDs as `aliases` on the requirements here.

The same release of this repository then sets `authority: self` and `migration: authoritative`. Before that change the
upstream rule governs and the convention here is `proposed`; after it, this repository governs. There is never a
period with two live authorities.

**Applied to the first conventions:**

- **GitHub Actions (EC-0002 to EC-0006)** name `musher-dev/platform` issue #2892 as their authority, list CI-06 and
  CI-14 to CI-19 as implementations, and are `migration: proposed`. Their requirements are derived from CI-14 to
  CI-19 rather than a pure mirror of them: where they differ, each convention lists the difference in its Status
  section, and those differences are proposals the platform adopts at the handoff. The handoff is a platform pull
  request after #2892 lands. Until then the platform's checks govern, and a change to the shared grammar is made in
  the platform first.
- **Rules local to another repository** are not claimed in advance. A local rule that proves useful to more than one
  repository is authored here as a new requirement, with its old ID recorded in `aliases`, and the local copy is
  retired ([the charter](0000-charter.md)).

## Consequences

### Positive

- A reader can always tell which text governs: the frontmatter says so.
- Existing check IDs survive a migration as aliases, so a platform engineer who knows `CI-14` finds `GHA-01`.
- Upstream owners are not asked to give up a working check before its replacement is proven.

### Negative

- During the `proposed` period a change must be made twice, upstream first. That cost is accepted as the price of
  having one authority.
- Proposed differences from the upstream checks are visible to consumers before the upstream has adopted them. Each
  is listed where it applies, so nobody mistakes a proposal for the platform's current behavior.
- Links to a private upstream repository in `authority.ref` do not open for readers outside the organization
  ([decision 0003](0003-public-visibility-and-consumption.md)).

### Neutral

- `proposed` requirements are reported only by profiles that opt in to them (`include_proposed: true`), at `warning`.

## Enforcement

- The convention frontmatter schema requires `authority` and `migration` on every convention and validates
  `implementations`; `task schemas:validate` fails otherwise.
- `conventions invariants` fails when a requirement ID or alias is removed.
- Whether a handoff pull request did all three steps at once is `review-only`: the reviewer of the upstream change
  checks that no local rule text survives beside the link.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Copy now, reconcile later | Declare the rules authoritative here immediately | rejected: two live authorities from day one |
| Wait until upstream is ready, then publish | Publish nothing until the handoff | rejected: consumers could not see or comment on the rules they will be held to |
| Declared authority with a single-change handoff | Publish as `proposed`, move ownership in one upstream pull request | **chosen** |

## References

- [platform #2892: Organize GitHub Actions workflows by responsibility](https://github.com/musher-dev/platform/issues/2892)
- [Decision 0004: Identifiers and diagnostic URLs](0004-identifiers-and-diagnostic-urls.md)
- [Decision 0005: Status, severity and versioning](0005-status-severity-and-versioning.md)
