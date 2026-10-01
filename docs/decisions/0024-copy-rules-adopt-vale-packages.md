---
title: Copy rules adopt published Vale packages, leave voice to the site's owner, and ship as a Vale config package
date: 2026-10-01
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0024 — Copy rules adopt published Vale packages, leave voice to the site's owner, and ship as a Vale config package

## Context

A site's copy changes in every pull request that touches a page, and nobody re-reads a whole site in review. Some
mistakes are the same on every site: clichés, hedging, weasel words, redundancy, wordy phrases, claims nobody can
verify, and placeholders such as "coming soon" left in a page. Vale already has published packages for most of them,
maintained by their authors: `proselint` and `write-good` cover the general problems with few false positives once
three `write-good` rules are turned off (`E-Prime`, `Passive`, `TooWordy`), and `Microsoft.Wordiness` and
`Google.ExcessiveClaims` each catch one class the others miss. The rest of the Microsoft and Google styles, `alex`,
`Joblint` and `Readability` encode other companies' house styles: their capitalization, their jargon lists, their
reading-grade targets. None of the packages reports a placeholder.

Other copy rules are voice: which marketing words a brand avoids, which claims it allows, its tone, how long its
sentences run. Those are positioning decisions. The charter ([decision 0000](0000-charter.md)) places positioning and
product vocabulary with `musher-dev/platform` and `musher-dev/company`, not here, and a rule this repository shipped
would make every site exempt it wherever its owner disagreed.

A consumer also needs one pin for all of it. [Decision 0004](0004-identifiers-and-diagnostic-urls.md) makes a
release's text immutable, and [EC-0017](../../engineering-conventions/definitions/conventions/toolchain/tool-pins.md)
pins every tool once. A Vale `Packages` entry given by name resolves to the latest release when `vale sync` runs, so a
consumer listing five packages by name would be checked against rules nobody pinned.

## Decision

We will check that public copy is linted with Vale through a new convention,
[EC-0038 Public copy](../../engineering-conventions/definitions/conventions/copy/public-copy.md), family `COPY`, topic
`copy`. The convention verifies the mechanism; it does not author a voice.

- **Adopt, then author.** The copy rules adopt `proselint` 0.3.4 and `write-good` 0.4.1 whole (less `E-Prime`,
  `Passive` and `TooWordy`), and `Microsoft.Wordiness` (0.15.1) and `Google.ExcessiveClaims` (0.7.1) alone. Each is
  pinned to a release URL, and is used as published: nothing here copies or restates a rule of theirs.
- **Author only what holds for every site,** as the `MusherCopy` style. Today that is one rule, `Placeholders`
  (COPY-04), reported at level `warning`, the requirement's severity. The style is generated, like
  `MusherConventions` ([decision 0007](0007-terminology-and-generated-artifacts.md)), from one source,
  `definitions/copy/style.yml`, validated by `checks/schemas/copy-style.schema.json`. The same source lists the
  adopted packages and their toggles, and generates the package's `.vale.ini` and the `copy` block of `index.json`
  that the checks read.
- **Leave voice to the site's owner.** Banned words, claims, tone and sentence length are not rules here. A site's
  owner that wants them writes a Vale style in its own repository and applies it beside the package, in the same
  `BasedOnStyles`.
- **Ship a Vale config package.** Each release attaches `MusherProse.zip`: `MusherProse/.vale.ini`, whose `Packages`
  names the four adopted release URLs and whose one section, for the extensions copy is written in, holds the
  toggles, and `MusherProse/styles/` with `MusherCopy` and `MusherConventions`. A consumer names it once, at the URL
  of the release its mise configuration pins, and `vale sync` installs everything. The name follows the
  `conventions prose` command, and the package is a new asset: `MusherConventions.zip` is unchanged, because
  [Consuming the conventions](../consuming.md#without-mise) documents it for repositories that run Vale themselves.
- **Check the consumer's config with conftest.** COPY-01 to COPY-03 read the Vale config's raw text with a small INI
  reader, `checks/rego/lib/ini.rego`, because `conftest parse --parser ini` drops the keys before the first section,
  where `Packages` lives. The runner already embeds `.config/**/*.ini`; it now embeds a root `.vale.ini`, `_vale.ini`
  or `vale.ini` too ([decision 0015](0015-the-runner-reads-what-conftest-cannot-select.md)).
- **Offline from the bundle.** `conventions prose` runs `MusherCopy` from the bundle over the sections of the
  repository's Vale config that apply it, with that config's `[formats]` and `MusherCopy` toggles. It does not run the
  adopted packages, which need `vale sync`; they run where the repository runs Vale itself.

## Consequences

### Positive

- Nearly all of the copy checking is maintained by the packages' authors. This repository owns one rule, and another
  is added only when it holds for every site and no adopted package has it.
- A consumer pins one URL, and the copy rules move with the conventions release in the pull request that raises it.
- A site's voice is decided where its positioning is, and no site exempts another owner's word list.

### Negative

- `vale sync` needs network access to GitHub's release downloads. A repository that lints offline gets `MusherCopy`
  alone, through `conventions prose`.
- A config package cannot know the consumer's paths, so its toggles sit in a section for every copy extension:
  `Microsoft.Wordiness` and `Google.ExcessiveClaims` apply to every Markdown, HTML or template file the consuming
  config lints. A config that also lints internal prose gets them there. The section names no code extension, so they
  never reach a code file's comments.
- Raising an adopted package's version is a change here, made by editing `definitions/copy/style.yml` and
  regenerating. Renovate does not see it.

### Neutral

- COPY-01 to COPY-04 are `warning` like every requirement in the 0.x series, and the Vale level of each authored rule
  matches its requirement's severity. A consumer's `MinAlertLevel` and failing level decide what fails its run.
- Vale matches a section's glob against the path it is given, so a consumer runs Vale from the repository root with
  root-relative paths.

## Enforcement

- `task generate:check` fails when the generated `MusherCopy` rules, `MusherProse.ini` or the index's `copy` block
  differ from `definitions/copy/style.yml`, and when a generated style directory holds a file nothing generates.
- `conventions generate` fails when a `MusherCopy` rule has no requirement whose `validation.style` names it, and
  `task invariants` fails when a requirement names a `MusherCopy` rule the source does not define.
- `task bundle:verify` fails when `MusherProse.zip` is missing from `SHA256SUMS`, its root is not `MusherProse/`, its
  styles are not exactly `MusherConventions` and `MusherCopy`, or its `.vale.ini` names a package without a release
  URL.
- COPY-01 to COPY-03 are conftest checks with fixture repositories and near-misses under
  `engineering-conventions/tests/fixtures/repos/copy-*`.
- Whether a rule belongs in `MusherCopy`, in an adopted package or in a site owner's style is `review-only`.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Author a house style of banned words, claims and sentence limits | One voice for every site | rejected: voice is positioning, owned outside this repository, and every site would exempt what its owner disagreed with |
| Adopt whole packages, Microsoft and Google included | Base the copy on five published styles | rejected: they encode other companies' house styles |
| Vendor the adopted packages into the bundle | Copy the four packages' rules into `MusherProse.zip` | rejected: redistributes other projects' rules and licenses, and every upgrade is a copy to review |
| Consumers list each package themselves | Document the five `Packages` entries | rejected: five pins per consumer, and a name instead of a URL floats |
| Adopt packages by pinned URL in a config package, author only what holds for every site | This decision | **chosen** |

## References

- [Decision 0000: Charter](0000-charter.md)
- [EC-0038 Public copy](../../engineering-conventions/definitions/conventions/copy/public-copy.md)
- [Vale: Packages](https://vale.sh/docs/topics/packages)
- [Vale: Configuration](https://vale.sh/docs/topics/config)
- [Decision 0007: Terminology model and committed generated artifacts](0007-terminology-and-generated-artifacts.md)
- [Decision 0015: The runner reads what conftest cannot select](0015-the-runner-reads-what-conftest-cannot-select.md)
