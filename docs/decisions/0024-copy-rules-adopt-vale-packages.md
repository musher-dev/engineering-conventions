---
title: Copy rules adopt published Vale packages, author only what they lack, and ship as a Vale config package
date: 2026-10-01
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0024 — Copy rules adopt published Vale packages, author only what they lack, and ship as a Vale config package

## Context

Musher's sites need their copy checked: banned marketing words, claims without proof, filler and placeholders reach
production when nobody re-reads a whole site in review. The platform's reviewers work from a list of those words and
check it by hand.

Vale already has published packages for most general writing problems. Run against the platform's marketing site and
customer docs, `proselint` and `write-good` caught clichés, hedging, weasel words and redundancy with few false
positives once three `write-good` rules were turned off (`E-Prime`, `Passive`, `TooWordy`). `Microsoft.Wordiness`
and `Google.ExcessiveClaims` each caught one class the others missed. The whole Microsoft and Google styles, `alex`,
`Joblint` and `Readability` were mostly noise on the same corpus: product names flagged as jargon, headings judged by
another company's capitalization rules, reading-grade scores on reference tables. None of the packages knows the
marketing words the list bans, or a placeholder left in a page.

A consumer also needs one pin for all of it. [Decision 0004](0004-identifiers-and-diagnostic-urls.md) makes a
release's text immutable, and [EC-0017](../../engineering-conventions/definitions/conventions/toolchain/tool-pins.md)
pins every tool once. A Vale `Packages` entry given by name resolves to the latest release when `vale sync` runs, so a
consumer listing five packages by name would be checked against rules nobody pinned.

## Decision

We will lint public copy with Vale through a new convention, [EC-0038 Public copy](../../engineering-conventions/definitions/conventions/copy/public-copy.md),
family `COPY`, topic `copy`.

- **Adopt, then author.** The copy rules adopt `proselint` 0.3.4 and `write-good` 0.4.1 whole (less `E-Prime`,
  `Passive` and `TooWordy`), and `Microsoft.Wordiness` (0.15.1) and `Google.ExcessiveClaims` (0.7.1) alone. Each is
  pinned to a release URL, and is used as published: nothing here copies or restates a rule of theirs.
- **Author only the gaps,** as the `MusherCopy` style: `Banned`, `Placeholders`, `Generic`, `GenericContext`,
  `Hyperbole`, `Filler`, `SentenceAverage` and `ParagraphSentences`, one requirement each (COPY-05 to COPY-12), as
  the frontmatter schema's `<Style>.<Rule>` form for a `vale` requirement asks. The style is generated, like
  `MusherConventions` ([decision 0007](0007-terminology-and-generated-artifacts.md)), from one source,
  `definitions/copy/style.yml`, validated by `checks/schemas/copy-style.schema.json`. The same source lists the
  adopted packages and their toggles, and generates the package's `.vale.ini` and the `copy` block of `index.json`
  that the checks read.
- **Ship a Vale config package.** Each release attaches `MusherProse.zip`: `MusherProse/.vale.ini`, whose `Packages`
  names the four adopted release URLs and whose one section, for the extensions copy is written in, holds the
  toggles, and `MusherProse/styles/` with `MusherCopy` and `MusherConventions`. A consumer names it once, at the URL
  of the release its mise configuration pins, and `vale sync` installs everything. The name follows the
  `conventions prose` command, and the package is a new asset: `MusherConventions.zip` is unchanged, because
  [Consuming the conventions](../consuming.md#without-mise) documents it for repositories that run Vale themselves.
- **Check the consumer's config with conftest.** COPY-01 to COPY-04 read the Vale config's raw text with a small INI
  reader, `checks/rego/lib/ini.rego`, because `conftest parse --parser ini` drops the keys before the first section,
  where `Packages` lives. The runner already embeds `.config/**/*.ini`; it now embeds a root `.vale.ini`, `_vale.ini`
  or `vale.ini` too ([decision 0015](0015-the-runner-reads-what-conftest-cannot-select.md)).
- **Offline from the bundle.** `conventions prose` runs `MusherCopy` from the bundle over the sections of the
  repository's Vale config that apply it, with that config's `[formats]` and `MusherCopy` toggles. It does not run the
  adopted packages, which need `vale sync`; they run where the repository runs Vale itself.

## Consequences

### Positive

- Most of the copy checking is maintained by the packages' authors. This repository owns eight rules, and a ninth is
  added only after checking that no adopted package has it.
- A consumer pins one URL, and the copy rules move with the conventions release in the pull request that raises it.
- The banned-word list is data with one source, so the style, the convention and the checks cannot disagree on it.

### Negative

- `vale sync` needs network access to GitHub's release downloads. A repository that lints offline gets `MusherCopy`
  alone, through `conventions prose`.
- A config package cannot know the consumer's paths, so its toggles sit in a section for every copy extension:
  `Microsoft.Wordiness` and `Google.ExcessiveClaims` apply to every Markdown, HTML or template file the consuming
  config lints. A config that also lints internal prose gets them there. The section names no code extension, so they
  never reach a code file's comments.
- Vale reports `MusherCopy.Banned` and `MusherCopy.Placeholders` at level `error`. A word added to either list later
  can fail a build that passed, so it is a `feat!` change under
  [decision 0005](0005-status-severity-and-versioning.md#change-classification), like a banned prose alias.
- Raising an adopted package's version is a change here, made by editing `definitions/copy/style.yml` and
  regenerating. Renovate does not see it.

### Neutral

- COPY-05 to COPY-12 are `warning` like every requirement in the 0.x series. The Vale level of each rule is what
  Vale reports, and a consumer's `MinAlertLevel` decides what fails its run.
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
- COPY-01 to COPY-04 are conftest checks with fixture repositories and near-misses under
  `engineering-conventions/tests/fixtures/repos/copy-*`.
- Whether a new word belongs in `MusherCopy` or in an adopted package is `review-only`: a reviewer checks the adopted
  packages first.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Author every rule in one Musher style | Rewrite the useful parts of proselint and write-good | rejected: restates rules other people maintain, and the copy drifts from theirs |
| Adopt whole packages, Microsoft and Google included | Base the copy on five published styles | rejected: most of their findings on Musher's copy were noise |
| Vendor the adopted packages into the bundle | Copy the four packages' rules into `MusherProse.zip` | rejected: redistributes other projects' rules and licenses, and every upgrade is a copy to review |
| Consumers list each package themselves | Document the five `Packages` entries | rejected: five pins per consumer, and a name instead of a URL floats |
| Adopt packages by pinned URL in a config package, author only the gaps | This decision | **chosen** |

## References

- [EC-0038 Public copy](../../engineering-conventions/definitions/conventions/copy/public-copy.md)
- [Vale: Packages](https://vale.sh/docs/topics/packages)
- [Vale: Configuration](https://vale.sh/docs/topics/config)
- [Decision 0007: Terminology model and committed generated artifacts](0007-terminology-and-generated-artifacts.md)
- [Decision 0015: The runner reads what conftest cannot select](0015-the-runner-reads-what-conftest-cannot-select.md)
