#!/usr/bin/env bash
# Lists the repository's files matching git pathspecs, NUL-separated: tracked
# files plus untracked ones that are not gitignored, and only those that exist.
#
# The lint tasks take their file lists from here rather than from a tool's own
# directory walk, because each walker disagrees on .gitignore and on dot
# directories (.github/, .claude/), and the gates must see the same set. The
# existence filter drops a tracked file deleted in the working tree, which
# `git ls-files --cached` still lists.
#
# Pathspecs use glob semantics (GIT_GLOB_PATHSPECS): `*` stays within one
# directory and `**/` spans any depth, root included, as in .config/lefthook.yml.
#
# Usage: .github/scripts/list-files.sh '**/*.md' ':!:CHANGELOG.md' | xargs -0 -r <tool>
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
GIT_GLOB_PATHSPECS=1 git ls-files -z --cached --others --exclude-standard --deduplicate -- "$@" |
  while IFS= read -r -d '' file; do
    if [[ -f "${file}" ]]; then
      printf '%s\0' "${file}"
    fi
  done
