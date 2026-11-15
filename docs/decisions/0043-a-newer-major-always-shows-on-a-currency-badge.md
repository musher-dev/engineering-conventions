---
title: A newer major always shows on a currency badge, and the badge workflow reads with either App
date: 2026-11-15
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
amends: ["0042"]
---

# 0043 — A newer major always shows on a currency badge, and the badge workflow reads with either App

## Context

[Decision 0042](0042-dependency-currency-is-shown-not-proposed.md) made each pin's currency a README badge, and 0.9.4
shipped it. Under 0042 a badge turned orange only when the pin was the newest release of its own major and a newer
major existed. A pin that was also behind inside its major showed yellow, and the number after the arrow was the
newest release of the pinned major. Run against consumers' `main` on 2026-11-15, several badges read yellow
`N.0.0 → N.8.0` while a release four majors newer was out. A reader takes the number after the arrow as the newest
release, and a yellow badge as a small move, so both were wrong. 0.9.4 had two smaller gaps. It compared majors even
below 1.0.0, where the minor is the breaking part (decision 0005), so `0.9.4 → 0.10.0` read yellow. And a pin newer
than every release, such as a typo, read green.

The reusable workflow minted its token only from the musher-release App, through `vars.RELEASE_APP_CLIENT_ID` and the
`release-app-private-key` secret. Some repositories hold the musher-automation App's pair instead, so every private
producer's pin in them would read grey. GHA-52 asks that a token step name one App's client ID and key. An input that
let a caller pass any client ID would break it.

0.9.4's example callers also pinned the reusable workflow at v0.9.3's commit, which does not have the file.

## Decision

**The newest release in the line decides the colour and the number after the arrow. Below 1.0.0, a minor counts as a
major. The badge workflow takes either App's key.**

- A pin's breaking series is its major, or `0.<minor>` below 1.0.0. A pin is `behind-major`, orange, whenever the
  newest release in its tag line is in a later series, wherever the pin stands in its own. It is `behind-minor`,
  yellow, when a newer release exists in its series. A behind badge reads `<pinned> → <newest>`. `latestInMajor` stays
  in `index.json` and the branch's README, for a reader who stays in a series on purpose.
- A pin newer than every release in its line is `unknown`, grey, not `current`.
- `reusable-maintain-dependency-badges.yml` takes an optional `automation-app-private-key` secret. It is read with
  `vars.AUTOMATION_APP_CLIENT_ID` in a token step of its own, so each step names one App (GHA-52). The release App's
  token is used when both work. A key without its client-ID variable, or a token that cannot be minted, is a warning,
  and the private producers' pins read grey; the run does not fail.
- The documented caller and the examples also run on a push to `main` that changes `.repo/dependencies.toml` or
  `.config/mise/config.toml`, so a merged pin change turns its badge at once. The examples pin the workflow at
  v0.9.4's commit.

## Consequences

### Positive

- A badge never understates how far behind a pin is, and an arrow always points at the newest release.
- Repositories that hold the automation App's pair get working badges with no new secret.
- A misconfigured App key degrades to grey badges and a warning, instead of a failed scheduled run that emails someone.

### Negative

- A repository that stays on an old major on purpose shows orange. That is accurate, and its README can say why.
- Two token steps in the reusable workflow instead of one, each in the form GHA-52 asks for.
- How a badge is judged follows the `conventions` release the caller's mise configuration pins. A caller gets these
  states when it raises that pin to 0.9.5, whatever SHA it calls the workflow at.

### Neutral

- No requirement changes. DEPS-15, DEPS-16 and DEPS-17 read as before.

## Enforcement

- `tests/test_dependencies.py` holds the states: a pin behind in its major with a newer major out, the `0.<minor>`
  series, and a pin ahead of every release. It also holds an orange badge rendered end to end from the producers'
  releases, whose arrow names the newest release.
- GHA-52 and actionlint check the two token steps. actionlint's `config-variables` lists `AUTOMATION_APP_CLIENT_ID`.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Keep 0042's colours | Yellow names the newest of the pinned major | rejected: hides a newer major, and the arrow points at a release that is not the newest |
| Show both numbers | `N.0.0 → N.8.0 · M.0.0` | rejected: too long for a badge; `index.json` and the branch README carry both |
| A client-ID input | The caller passes any client ID | rejected: breaks GHA-52's one App per token step |
| Hold the release App's pair in more repositories | Distribute its key wherever a badge is rendered | rejected: widens where that key is held, when those repositories already hold the automation App's |
| The newest release decides, `0.<minor>` is a series, either App reads | This decision | **chosen** |

## References

- [Decision 0042](0042-dependency-currency-is-shown-not-proposed.md)
- [Decision 0005](0005-status-severity-and-versioning.md)
- [EC-0033 Keeping dependencies current](../../engineering-conventions/definitions/conventions/dependencies/keeping-dependencies-current.md)
- [GHA-52](../../engineering-conventions/definitions/conventions/github-actions/releases-and-deployments.md#gha-52)
