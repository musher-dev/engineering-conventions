# Toolchain

These conventions govern the versions of the tools a repository runs: its runtimes, its CLIs and its package
managers, wherever they are installed.

The governing rule, in one sentence:

> **Pin every tool once, exactly, in `.config/mise/config.toml`, and make anything that pins a tool outside mise pin
> the same version.**

mise installs the tools for the dev container, a developer's shell and CI from that one file, and its lockfile
records what each install downloads. What mise cannot reach (an image tag, a Feature option, `packageManager`, a
setup action's input, a `.nvmrc`) is held equal to it by a check, so a version changes in one pull request.

## Status

The convention is a **draft**, owned by this repository, and every requirement is `proposed` at severity `warning`.
It replaces the toolchain lockstep checks of `musher-dev/platform` and `musher-dev/development-container`; each
requirement names the check it replaces in `aliases`.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0017 Tool pins](tool-pins.md) | TOOL-01 – TOOL-11 | The one mise configuration, its backends, versions, `min_version` and lockfile; and the pins outside mise that must equal it |

## Quick reference

| Where a version appears | Must be | Requirement |
| --- | --- | --- |
| `.config/mise/config.toml` `[tools]` | Exact, with a backend unless a core tool | TOOL-02, TOOL-03 |
| `min_version`, `jdx/mise-action` `version`, `ARG MISE_VERSION` | Equal | TOOL-04 |
| `.config/mise/mise.lock` | Committed | TOOL-05 |
| A Dockerfile `ARG *_VERSION` default | Exact | TOOL-06 |
| A `FROM` or `COPY --from` image of a pinned runtime | The mise pin | TOOL-07 |
| A dev container Feature of a pinned tool | The mise pin | TOOL-08 |
| `packageManager` in `package.json` | The mise pin | TOOL-09 |
| A `setup-*` action's version input | The mise pin, or replaced by `jdx/mise-action` | TOOL-10 |
| `.nvmrc`, `.node-version`, `.python-version` | The mise pin | TOOL-11 |
| `.tool-versions`, any other mise config file | Absent | TOOL-11, TOOL-01 |
