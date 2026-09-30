---
title: The runner reads what conftest cannot select
date: 2026-09-28
status: accepted
deciders: ["@justinmerrell"]
supersedes: []
amended_by: ["0022"]
---

# 0015 — The runner reads what conftest cannot select

## Context

The conventions moving here from `musher-dev/platform` and `musher-dev/development-container` check files the
runner could not give to conftest:

- **JSON with comments.** `.devcontainer/devcontainer.json` allows comments and trailing commas, and conftest's
  `json` parser rejects both.
- **Dockerfiles by any name.** conftest chooses a parser from a file's name. It reads `Dockerfile` and
  `Dockerfile.*`, but takes `build.Dockerfile` or `Containerfile` for an unknown extension.
- **Markdown and one-line files.** Agent context (`CLAUDE.md`, `.claude/rules/*.md`), decision records, the
  `.config/` index, `.trivyignore` and `.nvmrc` have no conftest parser at all.

conftest parses every file in a combined run with one parser each, and **aborts the whole run** on the first file
it cannot parse. So these files cannot simply be added to the list the runner passes. Decision 0001 also keeps
consumers free of any runtime beyond the pinned conftest, jq and Vale, so the answer cannot be a new tool.

## Decision

The runner (`bin/conventions`, and `src/conventions_tools/run.py` identically) adds three things to the inventory
it already passes to conftest:

| Field | Holds | How the runner makes it |
| --- | --- | --- |
| `parsed` | `devcontainer.json` files and Dockerfiles, as `{path, contents}` | `conftest parse --combine --parser jsonnet` or `--parser dockerfile`, file by file |
| `unparsed` | A file of those that did not parse, with conftest's reason | the same call, when it fails |
| `texts` | The raw text of agent context, decision records, the `.config/` index and the ignore and version files, up to 256 KiB each | `jq --rawfile` |
| `sizes` | The size in bytes of every Markdown file | `wc -c` |

`lib/files.rego` merges `parsed` into the documents every check reads, so a check sees a pre-parsed file exactly as
it sees one conftest parsed itself. `lib/text.rego` reads frontmatter (through `yaml.unmarshal`), headings and
`@imports` from `texts`, ignoring fenced code. A file in `unparsed` is reported by the runner as a `PARSE` error,
as a workflow that does not parse already is.

**One list of files.** The patterns that choose each set (`INPUTS`, `JSONNET`, `DOCKERFILES`, `TEXTS`, `SIZES`,
`TEXT_LIMIT`) are defined once, in `bin/conventions`. The Python runner reads them from that file, so the two
runners cannot select different files.

**Fixtures are set apart.** A repository that keeps sample repositories or deliberately broken files for its tests
declares their directories under `[paths] fixtures` in `.repo/conventions.toml`. The checks do not count those
files as part of the repository. This is not a waiver: it does not expire, so the schema describes it as for
fixtures only, and a reviewer rejects any other use. This repository declares its fixture repositories and its
example consumer.

## Consequences

### Positive

- Conventions about the dev container, Dockerfiles, agent context, decision records and suppression files can be
  checked by the engines consumers already run.
- A pre-parsed file that does not parse is reported and skipped. It no longer aborts the check.
- jq writes the inventory, so any file name or text is escaped correctly. The launcher previously escaped paths with
  `sed`.

### Negative

- The runner does more work: one conftest process per pre-parsed file, and one `wc` per Markdown file.
- jsonnet is a superset of JSON. It accepts comments and trailing commas, which is the point, but it also evaluates
  expressions. A `devcontainer.json` that is valid jsonnet but not JSONC is read, not rejected. That is a check
  that is too lenient, never a check that is wrong.
- A text over 256 KiB is not embedded, so a check that needs it sees nothing and stays silent.

### Neutral

- Rego still sees only data. Frontmatter is parsed in Rego, and no check reads the filesystem.

## Enforcement

- `tests/test_launcher.py` runs both runners on the same repositories and requires the same findings, including a
  `PARSE` error for a pre-parsed file that does not parse.
- `tests/test_run.py::test_selection_is_read_from_the_launcher` fails if the launcher stops defining a pattern set.
- `lib/files_test.rego` and `lib/text_test.rego` cover the merge, the fixture exclusion, frontmatter, headings and
  imports.
- Keeping `[paths] fixtures` to fixtures is `review-only`: a reviewer rejects a glob over code the repository ships.

## Considered options

| Option | Summary | Outcome |
| --- | --- | --- |
| Add the files to conftest's inputs | Pass them in the combined run | rejected: one Markdown file aborts the whole check |
| A second conftest run per parser | Run conftest once more with `--parser jsonnet` over those files | rejected: its findings could not see the rest of the repository, which cross-file checks need |
| A Python or Go pre-processor | Parse everything in a program shipped with the bundle | rejected: consumers would need a runtime beyond conftest, jq and Vale (decision 0001) |
| Pre-parse with conftest, embed text with jq | This decision | **chosen** |

## References

- [Decision 0001: Validation engines](0001-validation-engines.md)
- [conftest parsers](https://www.conftest.dev/options/#parser)
- `engineering-conventions/bin/conventions`, `engineering-conventions/bin/inventory.jq`
