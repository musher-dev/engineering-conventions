# Copy

These conventions govern the copy of a repository's sites: the words a visitor reads, and the Vale config that lints
them.

The governing rule, in one sentence:

> **Lint a site's copy with the MusherProse Vale package at the release the repository pins, and leave its voice to
> the site's owner.**

A repository with no site meets every requirement; they apply once it publishes one.

## Status

The convention is a **draft**, owned by this repository, and every requirement is `proposed` at severity `warning`.

## Who is checked

`base-repo` selects the family, so every profile does. COPY-01 to COPY-03 apply to a repository that declares a
`site` output in `.repo/outputs.toml` or whose kind is `website` or `documentation`. COPY-04 is the `MusherCopy` Vale
style: it runs where the repository runs Vale with the package.

Banned words, claims, tone and sentence length are not checked here. They are the site owner's to decide, in a Vale
style of its own applied beside MusherProse.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0038 Public copy](public-copy.md) | COPY-01 – COPY-04 | The Vale config a site needs, the adopted packages, and the placeholder rule |

## Quick reference

| Write | Not |
| --- | --- |
| `Packages = https://github.com/musher-dev/engineering-conventions/releases/download/v<release>/MusherProse.zip` | `Packages = MusherProse` |
| `BasedOnStyles = MusherCopy, proselint, write-good` | `BasedOnStyles = MusherCopy` |
| `[formats]` with `svelte = html` beside a section matching `*.svelte` | A section matching `*.svelte` and no format |
| The section is absent until it is written | Coming soon |
