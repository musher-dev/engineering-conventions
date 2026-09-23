#!/usr/bin/env bash
# post-create.sh — DevContainer post-create command hook.
#
# Runs once after the container is created: installs the pinned toolchain,
# then the git hooks.
#
# Usage: Called automatically by devcontainer.json postCreateCommand.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly REPO_ROOT

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/base-setup.sh
source "${SCRIPT_DIR}/lib/base-setup.sh"

# Logs the failing command and line number on ERR.
#
# Arguments:
#   $1 — line number
#   $2 — failed command string
# Outputs:
#   Writes error details to stderr via log()
on_error() {
  local line="${1}"
  local cmd="${2}"
  log "ERROR: command '${cmd}' failed at line ${line}"
}
trap 'on_error ${LINENO} "${BASH_COMMAND}"' ERR

# Installs the lefthook git hooks.
#
# The config is .config/lefthook.yml, which lefthook discovers on its own. The
# template this repo came from tested for a root lefthook.yml instead, found
# none, and silently installed no hooks at all; this checks the real path and
# fails loudly, because a container without hooks passes every local commit
# that CI then rejects.
#
# Globals:
#   REPO_ROOT — read
# Outputs:
#   Writes progress to stderr via log()
# Returns:
#   0 on success, 1 if lefthook is missing or the install fails
install_lefthook_hooks() {
  if [[ ! -f "${REPO_ROOT}/.config/lefthook.yml" ]]; then
    log "No .config/lefthook.yml; skipping git hooks"
    return 0
  fi
  if ! has_cmd lefthook; then
    log "ERROR: lefthook is not on PATH; run 'task tools:install', then 'task hooks:install'"
    return 1
  fi
  log "Installing lefthook git hooks..."
  (cd "${REPO_ROOT}" && lefthook install)
}

# Entry point: runs the full post-create setup sequence.
#
# Outputs:
#   Writes progress to stderr via log()
main() {
  log "Starting post-create setup..."
  base_setup
  install_lefthook_hooks
  log "Post-create setup completed"
}

main "$@"
