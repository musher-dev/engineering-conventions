# Engineering conventions — agent-facing notes

@README.md

Agent-facing contract for `musher-dev/engineering-conventions`. The imported
README carries the orientation: what a convention is, how a consumer pins a
release, and the commands. This file carries only what constrains a change.

Two levels ([LAYOUT.md](LAYOUT.md)): the repository root builds, checks and
releases the product; `engineering-conventions/` is the product a consumer
pins. The policies for each part live in `.claude/rules/` and load when you
read a file they govern: `conventions.md`, `terminology.md`, `rego.md`,
`github-workflows.md`, `toolchain-pins.md`.

## Hard lines

- **Requirement and convention IDs are permanent.** A frontmatter ID (`GHA-07`,
  `EC-0002`) is never renumbered, reused or deleted. A retired requirement stays
  as a tombstone; a legacy name goes in `aliases`. Consumers' waivers and every
  printed diagnostic resolve against these IDs.
- **Generated files are never hand-edited.** `checks/data/index.json`,
  `checks/vale/MusherConventions/**` and `conventions/README.md` are written by
  `task generate` from the frontmatter and `terminology/`. Edit the source and
  regenerate; `task generate:check` fails on drift.
- **Every conftest requirement ships a fixture.** A fixture repo under
  `engineering-conventions/tests/fixtures/repos/` whose `expected.json` names
  the requirement. A check that no fixture proves is not done.
- **The commit type is the release.** Pick it from the one change-classification
  table in [decision 0005](docs/decisions/0005-status-severity-and-versioning.md#change-classification);
  do not restate or improvise it. A `docs:` commit cuts no release, so anything
  a consumer must be able to pin (what a requirement checks, a message, a term)
  is never `docs`.
- **This repository passes its own conventions.** `task conventions:self`
  reports zero findings, warnings included.
- **Everything published here is public.** No secrets, internal hostnames or
  unreleased plans, in prose, fixtures or commit messages.

## Things to avoid

- **No restated upstream definitions.** A term or rule another repository
  owns gets an `authority` pointer, not a copy
  ([the charter](docs/decisions/0000-charter.md)).
- **No inline lint suppressions.** A rule that is wrong here is turned off in
  its `.config/` file with the reason beside it.
- **No tool installed outside `.devcontainer/mise.toml`.** CI installs through
  `.github/actions/setup-tools` from that same file.

## Verification

`task check` runs every gate CI runs except the dev container build.
`task --list` enumerates the rest.

## Commits

Conventional Commits, enforced at commit-msg and on the PR title. Types and
scopes are in [`.github/conventional-commits.yaml`](.github/conventional-commits.yaml)
and nowhere else.

**Agents open PRs; humans merge.** Never run `gh pr merge`, enable auto-merge,
approve a PR, or push to `main`. Enforced by `permissions.deny` plus the
`.claude/hooks/no-merge-guard.sh` PreToolUse hook.
