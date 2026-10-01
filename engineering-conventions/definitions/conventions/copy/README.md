# Copy

These conventions govern the copy of a repository's sites: the words a visitor reads, and the Vale config that lints
them.

The governing rule, in one sentence:

> **Lint a site's copy with the MusherProse Vale package at the release the repository pins, and show the behavior or
> the number instead of claiming a quality.**

A repository with no site meets every requirement; they apply once it publishes one.

## Status

The convention is a **draft**, owned by this repository, and every requirement is `proposed` at severity `warning`.

## Who is checked

`base-repo` selects the family, so every profile does. COPY-01 to COPY-03 apply to a repository that declares a
`site` output in `.repo/outputs.toml` or whose kind is `website` or `documentation`. COPY-04 applies to any Vale config.
COPY-05 to COPY-12 are the `MusherCopy` Vale style: they run where the repository runs Vale with the package.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0038 Public copy](public-copy.md) | COPY-01 – COPY-12 | The Vale config a site needs, the adopted packages, and the MusherCopy style |

## Quick reference

| Write | Not |
| --- | --- |
| Restarts a crashed agent within ten seconds | A robust, seamless runtime |
| Runs 200 agents on one host | Scalable and enterprise-grade |
| 99.95% uptime over twelve months, on the status page | Never goes down |
| The section is absent until it is written | Coming soon |
| `Packages = https://github.com/musher-dev/engineering-conventions/releases/download/v<release>/MusherProse.zip` | `Packages = MusherProse` |
| `BasedOnStyles = MusherCopy, proselint, write-good` | `MusherCopy.Banned = NO` |
