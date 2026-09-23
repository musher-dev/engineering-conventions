#!/usr/bin/env bash
# PreToolUse(Bash) guardrail: AI agents open PRs; only humans merge
# (musher-dev/platform ADR 0134; copied from platform .claude/hooks/).
#
# Contract (code.claude.com/docs/en/hooks): stdin carries the tool-call JSON;
# exit 2 blocks the call BEFORE permission rules are evaluated — it overrides
# any allow rule in any settings scope — and stderr becomes the reason the
# agent sees. Exit 0 makes no decision; the normal permission flow applies.
#
# This is the load-bearing layer behind the permissions.deny rules in
# .claude/settings.json: deny rules match command verbs reliably, but the
# official docs call argument-shaped patterns fragile (quoting, flag order,
# variables, extra spaces), so this hook normalizes the whole command string
# and pattern-checks every merge surface: gh pr merge, the REST merge
# endpoint, GraphQL merge mutations, PR self-approval, and pushes to
# protected branches in any spelling.
set -uo pipefail

PROTECTED_RE='(main|master)'

# jq ships in the devcontainer. If it is genuinely absent, fail open with a
# loud note rather than bricking every Bash call — the deny rules still stand.
if ! command -v jq >/dev/null 2>&1; then
  echo "no-merge-guard: jq not found; hook cannot inspect commands" >&2
  exit 0
fi

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
[[ -z "$cmd" ]] && exit 0

block() {
  printf 'BLOCKED by .claude/hooks/no-merge-guard.sh: %s Merging is a human action on this repo (musher-dev/platform ADR 0134).\n' "$1" >&2
  exit 2
}

# Normalize: strip quotes and backslashes (defeats gh "pr" merge), collapse
# whitespace (defeats gh  pr   merge), lowercase.
norm=$(printf '%s' "$cmd" | tr -d "\"'\\\\" | tr '\n\t' '  ' | tr -s ' ' | tr '[:upper:]' '[:lower:]')

# 1. gh pr merge (any flags: --auto, --admin, -s/-r/-m) and merge queues.
grep -Eq '(^|[;&|(]|[[:space:]])gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)' <<<"$norm" \
  && block "'gh pr merge' is not permitted — open the PR and hand the link to a human."
grep -Eq '(^|[;&|(]|[[:space:]])gh[[:space:]]+merge-queue([[:space:]]|$)' <<<"$norm" \
  && block "merge-queue operations are not permitted."

# 2. The REST merge endpoint, via gh api or any HTTP client (curl, wget, httpie).
grep -Eq 'pulls/[0-9]+/merge' <<<"$norm" \
  && block "the pull-request merge REST endpoint is not permitted."
if grep -Eq '(^|[;&|(]|[[:space:]])gh[[:space:]]+api([[:space:]]|$)' <<<"$norm" \
  && grep -Eq '(--method|[[:space:]]-x)[[:space:]]*(put|post|patch|delete)' <<<"$norm" \
  && grep -Eq 'pulls' <<<"$norm"; then
  block "write calls to the pulls API are not permitted."
fi

# 3. GraphQL merge / auto-merge / queue mutations, however transported.
grep -Eq 'mergepullrequest|enablepullrequestautomerge|enqueuepullrequest|mergebranch' <<<"$norm" \
  && block "GraphQL merge mutations are not permitted."

# 4. PR approvals — a merge precondition the agent must not self-satisfy.
grep -Eq '(^|[;&|(]|[[:space:]])gh[[:space:]]+pr[[:space:]]+review([[:space:]][^;&|]*)?(--approve|[[:space:]]-a)([[:space:]]|$)' <<<"$norm" \
  && block "approving pull requests is not permitted."

# 5. git push targeting a protected branch, in any spelling.
if grep -Eq '(^|[;&|(]|[[:space:]])git[[:space:]]+([^;&|]*[[:space:]])?push([[:space:]]|$)' <<<"$norm"; then
  push_args=${norm#*push}

  # Explicit refspec: origin main | HEAD:main | +main | refs/heads/main | :main
  if grep -Eq "([[:space:]]|:|\+)(refs/heads/)?${PROTECTED_RE}([[:space:]]|$|:)" <<<"$push_args"; then
    block "pushing to a protected branch is not permitted — push a feature branch and open a PR."
  fi
  # Force push anywhere.
  if grep -Eq '(--force|--force-with-lease|--force-if-includes|[[:space:]]-[a-z]*f)([[:space:]=]|$)' <<<"$push_args"; then
    block "force pushing is not permitted."
  fi
  # Implicit push (no refspec): block when HEAD is on a protected branch.
  if ! grep -Eq '[^[:space:]-][^[:space:]]*[[:space:]]+[^[:space:]-]' <<<"$push_args"; then
    branch=$(git -C "${cwd:-.}" branch --show-current 2>/dev/null || echo "")
    if grep -Eq "^${PROTECTED_RE}$" <<<"$branch"; then
      block "the current branch '$branch' is protected; a bare 'git push' would push to it."
    fi
  fi
fi

# 6. Local merge into a protected branch (checkout main && merge feature).
if grep -Eq '(^|[;&|(]|[[:space:]])git[[:space:]]+(checkout|switch)[[:space:]]+'"${PROTECTED_RE}"'([[:space:];&|]|$)' <<<"$norm" \
  && grep -Eq '(^|[;&|(]|[[:space:]])git[[:space:]]+(merge|rebase|cherry-pick)([[:space:]]|$)' <<<"$norm"; then
  block "merging into a protected branch locally is not permitted."
fi

exit 0
