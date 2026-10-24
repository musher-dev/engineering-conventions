---
title: A .config/ concern names the files its tool reads, and every tool's configuration starts from its preset
date: 2026-10-24
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
---

# 0038 — A .config/ concern names the files its tool reads, and every tool's configuration starts from its preset

## Context

EC-0011 puts each tool's configuration in `.config/<concern>/<tool>.<ext>` and calls a concern "a coarse bucket",
with no rule for what a bucket is. Nothing checked the name: CONF-07 only keeps files off the top level. The
directories in use here and across the organization's repositories mix four keys. Some are file types (`markdown`,
`yaml`, `toml`), some are what a tool reads (`actions`, `docker`, `rego`), some are what a tool looks for
(`security`, `spelling`, `commits`), and one is a tool (`mise`). The mixture puts tools in the wrong place. Vale, a
prose linter that consumers point at Svelte and HTML, sat in `markdown/` because this repository first ran it on
Markdown. Other repositories have grown buckets keyed by team or purpose.

The boundary of `.config/` was not written down either. In practice it holds the repository-wide quality tooling,
while a product's language toolchain (ruff and basedpyright in `pyproject.toml`, `tsconfig.json`, Cargo's `[lints]`)
stays beside the code it checks. development-container's README states that boundary; EC-0011 did not.

Strictness had no convention. A configuration that starts from nothing and lists the rules it wants, or turns a
tool's preset off, freezes the rule set on the day it was written. A survey of the organization's repositories found
hand-picked rule sets with a reason on each exception, and none using a tool's "every rule" switch. Two settings in
this repository had no reason, and on inspection both restated or loosened the preset for no current cause.

## Decision

We will key every `.config/` concern on one thing: the files its tool reads. A tool that reads every file is keyed
on what it looks for (`prose`, `security`, `spelling`), and mise keeps `mise/`, where it looks by itself. The
registered concerns are one list in the check. CONF-14 reports a directory outside it, and CONF-15 reports a known
tool's configuration in a concern other than its own. EC-0011 states the boundary: `.config/` is repository-wide
quality configuration, and a product's language toolchain stays with the product. This repository moves
`.config/markdown/vale.ini` to `.config/prose/vale.ini`.

We will set a strictness floor in a new convention, EC-0044 Tool strictness. A tool's configuration starts from the
tool's own preset: yamllint extends `default` (CONF-16), markdownlint keeps `default` (CONF-17), pyright and
basedpyright check at `strict` or above (CONF-18), a `tsconfig.json` turns `strict` on (CONF-19), Biome keeps its
recommended rules (CONF-20) and a gitleaks `[extend]` keeps the default rules (CONF-21). Two rules apply to every
tool, by review: its warnings fail the gate that runs it (CONF-22), and every departure from its preset carries a
reason beside it (CONF-23). The floors already set for hadolint (IMAGE-07) and for actionlint and zizmor (GHA-33)
are referenced, not restated. No requirement asks for every rule a tool has.

The runner reads the configurations these checks need. conftest parses the YAML and TOML ones by name. The JSON with
comments ones (markdownlint, `tsconfig.json`, Biome, `pyrightconfig.json`) are parsed first with the jsonnet parser,
as `devcontainer.json` already is ([decision 0015](0015-the-runner-reads-what-conftest-cannot-select.md)).

## Consequences

### Positive

- A reader finds a tool's configuration from the files it judges, without the index.
- A tool upgrade makes a repository stricter, and each departure from the tool's judgment is visible with its reason.
- One vocabulary across repositories, so a migration issue can name the directory to move to.

### Negative

- Repositories with buckets outside the list (`comments/`, `positioning/`, a flat `.config/`) get warnings and must
  move files and update callers.
- A `tsconfig.json` or markdownlint file that jsonnet cannot parse, such as one with a duplicate key, is now reported
  as a parse error.
- CONF-23 is review-only until a check reads configuration text instead of parsed values.

### Neutral

- A concern the list lacks is added here, by a change to the check, rather than invented in a repository.
- A configuration that extends another file is judged only on what it sets itself.

## Enforcement

CONF-14 and CONF-15 in `checks/rego/configuration/tool_configuration.rego` fail on an unregistered concern and on a
known tool's file in the wrong concern. CONF-16 to CONF-21 in `checks/rego/configuration/tool_strictness.rego` fail on
a configuration below its tool's floor. Each has a fixture and a near-miss. CONF-22 and CONF-23 are `review-only`: a
reviewer looks for a tool run without its warnings failing (yamllint without `--strict`, Regal below
`--fail-level warning`, Vale passing on warnings), and for a setting that differs from the preset with no comment
above it.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Key concerns by tool | One directory per tool | rejected: two-file directories, and related tools scatter |
| Key concerns by file type alone | `markdown/vale.ini`, `yaml/zizmor.yml` | rejected: a tool that reads every file has no file type, and a tool's first input decides its home |
| Key concerns by the files a tool reads, or what an every-file tool looks for | This decision | **chosen** |
| Mandate every rule (`select = ["ALL"]`, basedpyright `all`) | The strictest switch each tool has | rejected: rules that contradict each other, and repositories spend their time on exceptions |
| Floor at each tool's preset, with reasons for departures | This decision | **chosen** |

## References

- [EC-0011 Tool configuration](../../engineering-conventions/definitions/conventions/configuration/tool-configuration.md)
- [EC-0044 Tool strictness](../../engineering-conventions/definitions/conventions/configuration/tool-strictness.md)
- [Decision 0015](0015-the-runner-reads-what-conftest-cannot-select.md)
