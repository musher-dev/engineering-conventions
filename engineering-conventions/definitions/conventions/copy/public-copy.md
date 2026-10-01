---
id: EC-0038
title: Public copy
summary: >-
  A repository that publishes a site lints the site's copy with Vale through a
  config that installs this release's MusherProse package by its pinned URL
  and applies MusherCopy, proselint and write-good to the site's sources.
  MusherCopy holds one rule the adopted Vale packages lack: no placeholder in
  public copy. Voice and vocabulary belong to the site's owner.
status: draft
topic: copy
applies_to:
  paths:
    - .config/**/vale.ini
    - .vale.ini
    - _vale.ini
    - vale.ini
    - .repo/outputs.toml
    - .repo/repository.toml
created: 2026-10-01
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "Vale: Configuration"
    url: https://vale.sh/docs/topics/config
  - title: "Vale: Packages"
    url: https://vale.sh/docs/topics/packages
  - title: "Vale: Styles and rule types"
    url: https://vale.sh/docs/topics/styles
  - title: "vale-cli/proselint"
    url: https://github.com/vale-cli/proselint
  - title: "vale-cli/write-good"
    url: https://github.com/vale-cli/write-good
  - title: "Google developer documentation style guide: Excessive claims"
    url: https://developers.google.com/style/excessive-claims
  - title: "Vale: Microsoft style"
    url: https://github.com/vale-cli/Microsoft
requirements:
  - id: COPY-01
    title: A repository that publishes a site has a Vale config
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.copy.vale_config
  - id: COPY-02
    title: The Vale config installs the MusherProse package from the release the repository pins, and no package by a bare name
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.copy.vale_config
  - id: COPY-03
    title: The Vale config applies MusherCopy and the adopted packages, and maps each template extension under [formats]
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.copy.vale_config
  - id: COPY-04
    title: Public copy holds no placeholder
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: vale
      style: MusherCopy.Placeholders
---

# Public copy

A site is read by people deciding whether to trust what it describes. Copy full of clichés, weasel words and
unverifiable claims tells them nothing they can check, and copy that still says "coming soon" tells them the page was
never finished. This convention makes sure a site's copy is linted at all: with Vale, using published packages for
general writing problems, and one rule of its own for what those packages do not cover.

## Scope

This convention covers the copy of every site a repository publishes: a `site` output in `.repo/outputs.toml`
([EC-0007](../outputs/outputs-declaration.md)), or a repository whose identity declaration says `kind = "website"` or
`kind = "documentation"` ([EC-0009](../repository/identity-declaration.md)). Copy is the prose a visitor reads: page
text, headings and the text in a site's components, whatever file it is written in. Code, identifiers and generated
reference text are out of scope.

This convention verifies the mechanism, not the voice. Which words a site avoids, which claims it may make, its tone
and how long its sentences run are the site owner's decisions: positioning and product vocabulary are owned by
`musher-dev/platform` and `musher-dev/company` ([the charter](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0000-charter.md)).
A site that wants such rules writes them as a Vale style in its own repository and applies it beside MusherProse, in
the same `BasedOnStyles`.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`), and every requirement is `proposed` at
severity `warning`, like every requirement in the 0.x series. Why the copy checks adopt published Vale packages and
author only what they lack is [decision 0024](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0024-copy-rules-adopt-vale-packages.md).

## What runs

Each release attaches a Vale package, `MusherProse.zip`. Its `.vale.ini` installs four published packages, each
pinned to one release, and sets which of their rules apply. Its own styles are `MusherCopy` (the checks below) and
`MusherConventions` (the terminology this repository's prose uses).

| Style | Applied | What it catches |
| --- | --- | --- |
| `MusherCopy` | Whole | Placeholders left in a page (COPY-04) |
| `proselint` 0.3.4 | Whole | Clichés, redundancy, hedging, typography and common usage errors |
| `write-good` 0.4.1 | Whole, without `E-Prime`, `Passive` and `TooWordy` | Weasel words, "there is" openings, sentences starting with "so" |
| `Microsoft` 0.15.1 | `Wordiness` only | Wordy phrases with a shorter replacement |
| `Google` 0.7.1 | `ExcessiveClaims` only | Claims nobody can verify |

The package's toggles sit in a section for the extensions copy is written in (Markdown, HTML and the component
templates below), so `Microsoft.Wordiness` and `Google.ExcessiveClaims` apply to every such file the consuming config
lints, whichever section applies the styles. Keep that config for public copy.

A consumer's config looks like this, with the release in the URL equal to the release its mise configuration pins:

```ini
# .config/markdown/vale.ini
StylesPath = ../../.vale
MinAlertLevel = warning
Packages = https://github.com/musher-dev/engineering-conventions/releases/download/v0.7.1/MusherProse.zip

[formats]
svelte = html

[apps/marketing/src/**/*.{md,svelte}]
BasedOnStyles = MusherCopy, proselint, write-good
```

and its Taskfile installs the packages before it lints. Vale writes them under `StylesPath`, relative to the config,
which must exist: without it, `vale sync` installs into a directory in the user's home instead. So it points outside
`.config/`, which holds no downloads, at a directory the repository ignores, and the task creates it. Vale matches a
section's glob against the path it is given, so the task runs from the repository root:

```yaml
lint:copy:
  desc: Lint the site's copy with Vale.
  cmds:
    - mkdir -p .vale
    - vale --config .config/markdown/vale.ini sync
    - vale --config .config/markdown/vale.ini apps/marketing/src
```

`conventions prose` also runs `MusherCopy` from the bundle, offline, over every section of the repository's Vale
config that applies it. The adopted packages run where the repository runs Vale itself, after `vale sync`.

## Requirements

### COPY-01

**A repository that publishes a site has a Vale config.**

A site's copy changes in every pull request that touches a page, and nobody re-reads the whole site each time. Without
a linter, a cliché or a "coming soon" reaches production unnoticed and stays there.

A repository publishes a site when `.repo/outputs.toml` declares an output with `kind = "site"`, or when
`.repo/repository.toml` says `kind = "website"` or `kind = "documentation"`. Its Vale config is a `vale.ini` under
`.config/`, the home [EC-0011](../configuration/tool-configuration.md) gives a tool's configuration, or a `.vale.ini`,
`_vale.ini` or `vale.ini` at the root, which Vale finds by itself and CONF-01 reports as misplaced.

**Correct:**

```text
.repo/outputs.toml           [[outputs]] kind = "site"
.config/markdown/vale.ini
```

**Incorrect:**

```text
.repo/outputs.toml           [[outputs]] kind = "site"
                             and no Vale config anywhere
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### COPY-02

**The Vale config installs the MusherProse package from the release the repository pins, and no package by a bare name.**

`Packages` takes a package's name or a URL. A name resolves to the latest release when `vale sync` runs, so the rules
a pull request is checked against change with no commit to show it, and two machines that synced a day apart
disagree. The URL of a release asset names its version, so the rules move only when the URL does.

The MusherProse URL names the same release as the `github:musher-dev/engineering-conventions` pin in the mise
configuration, or, without one, `conventions.version` in `.repo/conventions.toml`. The checks, the terminology and the
copy rules then move together, in the pull request that raises the pin. Every other entry in `Packages` is a URL or a
path too.

The check reads the config that applies `MusherCopy` or names `MusherProse`, or every Vale config when none does.

**Correct:**

```ini
Packages = https://github.com/musher-dev/engineering-conventions/releases/download/v0.7.1/MusherProse.zip
```

**Incorrect:**

```ini
Packages = MusherProse, Google
# Both resolve to whatever is latest when vale sync runs.

Packages = https://github.com/musher-dev/engineering-conventions/releases/download/v0.6.0/MusherProse.zip
# The repository pins 0.7.1: the copy rules lag the checks.
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### COPY-03

**The Vale config applies MusherCopy and the adopted packages, and maps each template extension under [formats].**

Installing a package applies nothing: Vale lints a file only with the styles in `BasedOnStyles` of a section whose
glob matches it. A section that names `MusherCopy` alone leaves out the adopted packages this convention relies on for
everything `MusherCopy` does not check. `Microsoft.Wordiness` and `Google.ExcessiveClaims` need no entry: the
package's own `.vale.ini` turns each on, alone, for every copy extension.

Vale reads Markdown, HTML, reStructuredText, AsciiDoc and source code comments, and skips a file whose format it does
not know. A component template such as a Svelte, Vue or Astro file is mostly HTML, and Vale reads it once
`[formats]` maps its extension to `html`. Without the mapping, the section's glob matches every component and Vale
lints none of them, which looks exactly like a site with clean copy.

The check reads the same config as COPY-02. It needs one section whose `BasedOnStyles` names `MusherCopy`,
`proselint` and `write-good`, and for every section that names `MusherCopy`, a `[formats]` entry for each extension
in its glob that is `svelte`, `vue`, `astro`, `njk`, `liquid`, `hbs`, `ejs`, `erb`, `twig`, `jinja` or `mdoc`.

**Correct:**

```ini
[formats]
svelte = html

[apps/marketing/src/**/*.{md,svelte}]
BasedOnStyles = MusherCopy, proselint, write-good
```

**Incorrect:**

```ini
[apps/marketing/src/**/*.{md,svelte}]
BasedOnStyles = MusherCopy
# proselint and write-good never run, and no .svelte file is read.
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### COPY-04

**Public copy holds no placeholder.**

"TBD", "TBC", "coming soon" and "lorem ipsum" are notes to the author that reached the reader. A section that is not
ready is removed and tracked in an issue; it ships when it is written. `TODO`, `FIXME` and `XXX` are reported by
`proselint.Annotations`.

Vale reports them at level `warning`, the requirement's severity. A consumer whose `MinAlertLevel` is `warning` sees
them, and one that runs Vale with a failing level of its own decides whether they fail its build.

**Correct:** The section is absent, and an issue tracks it.

**Incorrect:** Pricing: coming soon.

Checked by: vale · Severity: warning · Since: 0.7.1

## References

- [Vale: Configuration](https://vale.sh/docs/topics/config)
- [Vale: Packages](https://vale.sh/docs/topics/packages)
- [Vale: Styles and rule types](https://vale.sh/docs/topics/styles)
- [vale-cli/proselint](https://github.com/vale-cli/proselint)
- [vale-cli/write-good](https://github.com/vale-cli/write-good)
- [Google developer documentation style guide: Excessive claims](https://developers.google.com/style/excessive-claims)
- [Vale: Microsoft style](https://github.com/vale-cli/Microsoft)
- [Decision 0024: Copy rules adopt published Vale packages](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0024-copy-rules-adopt-vale-packages.md)
