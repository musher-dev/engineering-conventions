#!/usr/bin/env bash
# common.sh — Shared utility functions for dev container setup scripts.
#
# This is a library file meant to be sourced, not executed directly.
# Usage: source "path/to/common.sh"
#
# Provides logging, command helpers, directory setup and tool verification
# functions used by all setup scripts.
set -euo pipefail

# Logs a timestamped message to stderr.
#
# Arguments:
#   $@ — message text
# Outputs:
#   Writes timestamped message to stderr
log() {
  echo "[$(date '+%H:%M:%S')] $*" >&2
}

# --- Command helpers ---

# Checks whether a command exists on the PATH.
#
# Arguments:
#   $1 — command name
# Returns:
#   0 if found, 1 otherwise
has_cmd() {
  command -v "$1" &>/dev/null
}

# Runs a command with sudo if available, otherwise without.
#
# Arguments:
#   $@ — command and arguments
maybe_sudo() {
  if sudo -n true 2>/dev/null; then
    sudo "$@"
  else
    "$@"
  fi
}

# Retries a command with exponential back-off.
#
# Arguments:
#   $1 — max attempts
#   $2 — delay in seconds between attempts
#   $@ — command and arguments to execute
# Returns:
#   0 on success, 1 after exhausting all attempts
retry() {
  local attempts="${1:?usage: retry <attempts> <delay> <command...>}"
  local delay="${2:?}"
  shift 2
  local attempt=1
  while true; do
    if "$@"; then
      return 0
    fi
    if ((attempt >= attempts)); then
      log "FAIL: '$*' failed after ${attempts} attempts"
      return 1
    fi
    log "Attempt ${attempt}/${attempts} failed, retrying in ${delay}s..."
    sleep "$delay"
    ((attempt++))
  done
}

# --- Directory helpers ---

# Ensures a directory exists and is owned by the given user.
#
# Arguments:
#   $1 — directory path
#   $2 — owner (default: "vscode")
ensure_writable_dir() {
  local dir="${1:?usage: ensure_writable_dir <path>}"
  local owner="${2:-vscode}"
  if [[ ! -d "$dir" ]]; then
    maybe_sudo mkdir -p "$dir"
  fi
  maybe_sudo chown -R "${owner}:${owner}" "$dir"
}

# Creates config directories from "label:path" pairs.
#
# Globals:
#   REMOTE_USER — read, falls back to "vscode"
# Arguments:
#   $@ — entries in "label:path" format
# Outputs:
#   Writes progress to stderr via log()
setup_config_dirs() {
  local owner="${REMOTE_USER:-vscode}"
  for entry in "$@"; do
    local label="${entry%%:*}"
    local dir="${entry#*:}"
    log "Ensuring config dir: ${label} (${dir})"
    ensure_writable_dir "$dir" "$owner"
  done
}

# --- Verification ---

# Verifies that a list of commands are available on the PATH.
#
# Arguments:
#   $@ — command names to check
# Outputs:
#   Writes status of each tool to stderr via log()
# Returns:
#   0 if all tools found, 1 if any are missing
verify_tools() {
  log "Verifying installed tools..."
  local all_ok=true
  for cmd in "$@"; do
    if has_cmd "$cmd"; then
      log "  ✓ ${cmd}: $("$cmd" --version 2>/dev/null || echo 'installed')"
    else
      log "  ✗ ${cmd}: MISSING"
      all_ok=false
    fi
  done
  [[ "${all_ok}" == true ]]
}
