---
title: Dependency currency is shown as README badges, not proposed as a pull request per release
date: 2026-11-15
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
amends: ["0022", "0032"]
---

# 0042 — Dependency currency is shown as README badges, not proposed as a pull request per release

## Context

[Decision 0022](0022-interfaces-and-dependencies.md) asked every consumer of another Musher repository's release for
a scheduled `maintain-dependencies.yml` that runs `deps:sync` and opens a pull request for each new release (DEPS-10).
In practice those pull requests were not merged. A producer that releases often opened one in every consumer each
time, a consumer that was not ready to move closed or ignored them, and the next release opened another. The pull
request that carried a needed fix looked like every other one. The scheduled workflow had become noise that taught
people to ignore it.

Dependabot showed the same pattern at a larger scale. [Decision 0032](0032-every-dependency-ecosystem-has-an-updater.md)
asked that every ecosystem have an updater and left its schedule and grouping to the repository; most chose weekly,
ungrouped updates, so each repository received a pull request per dependency per week.

The question a pull request per release answered, "is this pin behind?", does not need a pull request. It needs to be
visible where people already look, and quiet until someone chooses to act.

## Decision

**Show each pin's currency as a README badge, and have a person open the pull request that moves it. Keep Dependabot,
but monthly and grouped.**

- DEPS-10 is retired and replaced by DEPS-16. A repository that pins another Musher release, in
  `.repo/dependencies.toml` or as the `github:musher-dev/engineering-conventions` pin in `.config/mise/config.toml`,
  shows a currency badge for each pin in its README (DEPS-15), rendered by a `maintain-dependency-badges.yml` that runs
  on a schedule and on a producer's `dependency-released` dispatch (DEPS-16).
- This repository ships the tooling: `conventions dependencies status` compares each pin with its producer's published
  releases in the same tag line, and `conventions dependencies badges` renders one self-contained SVG per pin, green
  when current, yellow when a newer release exists in the pinned major, orange when only a newer major does, grey when
  the releases cannot be read. The reusable workflow `reusable-maintain-dependency-badges.yml` runs them and keeps the
  badges as one commit on an orphan `badges` branch, pushed only when a badge changed.
- When a badge turns, a person runs `task deps:sync` and opens the pull request. A producer's optional
  `notify-release.yml` still sends `dependency-released`; it now refreshes a badge instead of opening a pull request.
- Dependabot stays for packages, actions and images (EC-0042), but every version update runs monthly or less often
  with one group whose `patterns` are `["*"]` (DEPS-17), so it opens at most one pull request per ecosystem a month.
  Security updates are not subject to the schedule or the cooldown and stay immediate; they are enabled in each
  repository's settings.
- GHA-52 accepts a private key read as `secrets.<purpose>-app-private-key` in a called workflow, the kebab-case name
  GHA-38 asks a `workflow_call` secret to have, as the same pair as `<PURPOSE>_APP_PRIVATE_KEY`. Without it, no
  reusable workflow could mint an App token and pass both checks.

## Consequences

### Positive

- No consumer receives a pull request it did not ask for when a producer releases; the README says how far behind
  each pin is, in the colour of the gap.
- A badge is current within minutes of a release when the producer notifies, and within a day when it does not.
- Dependabot opens a handful of pull requests a month per repository instead of several a week, and security fixes
  still arrive at once.

### Negative

- Nothing moves a pin by itself any more: a repository whose badges nobody reads falls behind silently, which is the
  failure DEPS-10 existed to prevent. The badge makes that visible; it does not prevent it.
- Every consumer adds a workflow, a GitHub App key for private producers, and a line per pin to its README.
- A badge served from a private repository renders only for viewers with read access to it.
- A version update that matters waits up to a month for Dependabot's next run, unless someone triggers it.

### Neutral

- `deps:sync` and `deps:check` are unchanged; only who runs `deps:sync`, and when, changes.
- A `maintain-dependencies.yml` that a repository keeps is not reported; nothing asks for it.

## Enforcement

- DEPS-15 and DEPS-16 in `checks/rego/dependencies/currency.rego`, with fixtures `deps-15-*` and `deps-16-*`, each with
  a near-miss; DEPS-10's fixtures moved to DEPS-16.
- DEPS-17 in `checks/rego/dependencies/updates.rego`, with fixtures `deps-17-*`.
- The GHA-52 kebab-case key in `checks/rego/github_actions/releases_and_deployments.rego` and its unit test.
- `tests/test_dependencies.py` holds the commands' states and the badges to SVG snapshots.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Keep a pull request per release | DEPS-10 as it was | rejected: the pull requests went unmerged and buried the ones that mattered |
| Batch releases into one weekly pull request | One scheduled pull request moving every pin | rejected: still a pull request nobody asked for, and one unready pin blocks the rest |
| An issue per pin that falls behind | The schedule opens or updates an issue | rejected: issues pile up like the pull requests did, and nobody reads the tracker for this |
| README badges, a person moves the pin | This decision | **chosen** |
| Turn Dependabot off | Rely on the badges and people | rejected: security updates must stay immediate, and packages have no badge |

## References

- [EC-0033 Keeping dependencies current](../../engineering-conventions/definitions/conventions/dependencies/keeping-dependencies-current.md)
- [EC-0042 Automated dependency updates](../../engineering-conventions/definitions/conventions/dependencies/automated-updates.md)
- [GitHub Docs: Dependabot options reference](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference)
- [shields.io badge specification](https://github.com/badges/shields/blob/master/spec/SPECIFICATION.md)
