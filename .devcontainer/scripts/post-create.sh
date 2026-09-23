#!/usr/bin/env bash
# post-create.sh — DevContainer post-create command hook.
#
# Runs once after the container is created. Sets up environment files,
# invokes the base setup orchestrator, and configures shell customization.
#
# Usage: Called automatically by devcontainer.json postCreateCommand.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

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

# Brings .devcontainer/.env up to date with the schema, and wires the shell
# profiles to load it.
#
# `repo env sync` only adds bindings the schema has gained and mints local
# secrets -- it never overwrites a live value, so it is safe on every create.
# The profile line is what makes an edited .env reach new terminals without a
# rebuild; see lib/env-load.sh for why it parses rather than sources.
#
# Globals:
#   SCRIPT_DIR — read
# Outputs:
#   Writes progress to stderr via log()
setup_env_file() {
  local loader="${SCRIPT_DIR}/lib/env-load.sh"
  local marker="# musher devcontainer env (post-create)"

  if has_cmd repo; then
    log "Syncing .devcontainer/.env with the schema..."
    (cd "${SCRIPT_DIR}/../.." && repo env sync) || log "WARNING: repo env sync failed"
  fi

  local rc
  for rc in "${HOME}/.zshrc" "${HOME}/.bashrc"; do
    [[ -f "${rc}" ]] || continue
    grep -qF "${marker}" "${rc}" && continue
    {
      echo ""
      echo "${marker}"
      echo "[ -f \"${loader}\" ] && . \"${loader}\" && env_load"
    } >> "${rc}"
  done
}

# Installs lefthook git hooks for this repo. Best-effort: silently
# skips if lefthook isn't on PATH yet or no lefthook.yml exists.
#
# Outputs:
#   Writes progress to stderr via log()
install_lefthook_hooks() {
  command -v lefthook >/dev/null 2>&1 || return 0
  [[ -f "${SCRIPT_DIR}/../../lefthook.yml" ]] || return 0
  log "Installing lefthook git hooks..."
  (cd "${SCRIPT_DIR}/../.." && lefthook install >/dev/null 2>&1) || true
}

# Entry point: runs the full post-create setup sequence.
#
# Arguments:
#   $@ — passed through (unused, reserved for future use)
# Outputs:
#   Writes progress to stderr via log()
main() {
  log "Starting post-create setup..."
  base_setup
  setup_env_file
  install_lefthook_hooks
  # --- Add repo-specific setup below ---
  log "Post-create setup completed"
}

main "$@"
