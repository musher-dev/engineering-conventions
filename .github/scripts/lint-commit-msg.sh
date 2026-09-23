#!/usr/bin/env bash
# Validates a Conventional Commit subject against .github/conventional-commits.yaml.
#
# Usage:
#   .github/scripts/lint-commit-msg.sh <path-to-commit-msg-file>   # lefthook commit-msg
#   .github/scripts/lint-commit-msg.sh --title "feat(agent): foo"  # ad-hoc title check
#
# Pure bash; no external dependencies. Must run in <100ms (commit-msg budget).

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
manifest="$repo_root/.github/conventional-commits.yaml"

if [[ ! -f "$manifest" ]]; then
  echo "lint-commit-msg.sh: manifest not found at $manifest" >&2
  exit 2
fi

# Tiny YAML extractor for "key:\n  - value\n  - value\n" sections.
# Restricted to flat string lists at indent level 2 — sufficient for the
# manifest shape and not a general YAML parser.
extract_list() {
  local key="$1"
  awk -v key="^${key}:" '
    $0 ~ key { in_list = 1; next }
    in_list && /^[^[:space:]]/ { in_list = 0 }
    in_list && /^  - / { sub(/^  - /, ""); print }
  ' "$manifest"
}

types_alt="$(extract_list types | tr '\n' '|' | sed 's/|$//')"
scopes_alt="$(extract_list scopes | tr '\n' '|' | sed 's/|$//')"

if [[ -z "$types_alt" || -z "$scopes_alt" ]]; then
  echo "lint-commit-msg.sh: failed to extract types/scopes from $manifest" >&2
  exit 2
fi

if [[ "${1:-}" == "--title" ]]; then
  msg="${2:-}"
  if [[ -z "$msg" ]]; then
    echo "lint-commit-msg.sh: --title requires a non-empty value" >&2
    exit 2
  fi
else
  path="${1:?usage: $0 <path-to-commit-msg-file> | $0 --title <string>}"
  msg="$(head -1 "$path")"
fi

# Allow auto-generated messages through (Merge, Revert, fixup!, squash!, amend!)
if [[ "$msg" =~ ^(Merge\ |Revert\ |fixup!\ |squash!\ |amend!\ ) ]]; then
  exit 0
fi

regex="^(${types_alt})\((${scopes_alt})\)(!)?:[[:space:]][a-z].*[^.]$"
if echo "$msg" | grep -Eq "$regex"; then
  exit 0
fi

cat >&2 <<EOF

Commit message does not match Conventional Commits format.
Expected: type(scope): description
  Types:  $(extract_list types | paste -sd '|' -)
  Scopes: $(extract_list scopes | paste -sd '|' -)
  Rules:  start lowercase, no trailing period, breaking change via !
Got: $msg

Manifest: .github/conventional-commits.yaml
EOF
exit 1
