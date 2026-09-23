#!/usr/bin/env bash
# base-setup.sh — Reusable setup orchestrator for musher dev containers.
#
# This file is intended to be sourced, not executed directly.
# Source it and call base_setup, or call individual functions to customize.
#
# Usage:
#   source "path/to/base-setup.sh"
#   base_setup
set -euo pipefail

# Guard against direct execution — this file must be sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Error: source this file, don't execute it" >&2
  exit 1
fi

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly _LIB_DIR
readonly _HOME="/home/${REMOTE_USER:-vscode}"

# shellcheck source=common.sh
source "${_LIB_DIR}/common.sh"

# --- Config directories ---

# Creates standard config directories for dev tools.
#
# Globals:
#   _HOME — read, user home directory
# Outputs:
#   Writes progress to stderr via log()
base_setup_config_dirs() {
  setup_config_dirs \
    "gh config:${_HOME}/.config/gh" \
    "claude:${_HOME}/.claude" \
    "codex:${_HOME}/.codex"
}

# --- Cache directories ---

# Creates cache directories for all dev tools so caches land
# under a single tree instead of scattering across the filesystem.
#
# Globals:
#   _HOME — read, user home directory
# Outputs:
#   Writes progress to stderr via log()
base_setup_cache_dirs() {
  setup_config_dirs \
    "xdg cache:${_HOME}/.cache" \
    "uv cache:${_HOME}/.cache/uv" \
    "npm cache:${_HOME}/.cache/npm"
}

# --- mise (installs every CLI pinned in .devcontainer/mise.toml) ---

readonly _MISE_SHIMS="${_HOME}/.local/share/mise/shims"

# Puts the mise shims and ~/.local/bin on PATH for the rest of this script, so
# mise-managed CLIs and Claude are visible to base_verify_tools (lifecycle
# hooks don't always inherit devcontainer.json remoteEnv).
#
# Globals:
#   PATH — modified (export)
base_setup_path() {
  export PATH="${_MISE_SHIMS}:${_HOME}/.local/bin:${PATH}"
}

# Installs the CLIs pinned in .devcontainer/mise.toml, then regenerates shims.
#
# mise itself is baked into the image (ARG MISE_VERSION in the Dockerfile).
# There is deliberately no fallback installer: an unpinned mise would resolve
# the pins with a different mise than CI uses, which is the drift the single
# anchor exists to prevent. A missing mise means the image build is wrong.
#
# Globals:
#   MISE_GLOBAL_CONFIG_FILE — read, path to the tool manifest
# Outputs:
#   Writes progress to stderr via log()
# Returns:
#   0 on success, non-zero on failure
base_install_tools() {
  if ! has_cmd mise; then
    log "ERROR: mise is not on PATH; rebuild the container (it is baked by .devcontainer/Dockerfile)"
    return 1
  fi
  local config="${MISE_GLOBAL_CONFIG_FILE:-${_LIB_DIR}/../../mise.toml}"
  log "Installing pinned CLIs from ${config}..."
  mise trust "${config}" >/dev/null 2>&1 || true
  retry 3 5 mise install
  mise reshim >/dev/null 2>&1 || true
}

# --- Claude Code ---

# Installs Claude Code via the native installer if not already present.
#
# Best-effort: nothing in the gates needs it, and the Dev Container CI job runs
# this script with no network credentials, so a failed download is a warning
# rather than a failed container.
#
# Outputs:
#   Writes progress to stderr via log()
# Returns:
#   0 always
base_install_claude() {
  if has_cmd claude; then
    log "Claude Code already installed, skipping"
    return 0
  fi
  # CI builds the container only to prove the toolchain; it has no use for an
  # unpinned installer running with the job's token in the environment.
  if [[ -n "${CI:-}" ]]; then
    log "CI is set; skipping the Claude Code install"
    return 0
  fi
  log "Installing Claude Code (native installer)..."
  if ! retry 3 5 bash -c 'curl -fsSL https://claude.ai/install.sh | bash'; then
    log "WARNING: Claude Code install failed; re-run the installer by hand when online"
  fi
}

# --- Verify ---

# Verifies the CLIs the gates depend on are on PATH. Exact versions are
# asserted by verify-toolchain.sh; this only catches a failed install early.
#
# Outputs:
#   Writes tool status to stderr via log()
# Returns:
#   0 if all tools found, 1 if any are missing
base_verify_tools() {
  verify_tools gh task lefthook conftest opa vale uv
}

# --- Orchestrator ---

# Runs the complete base setup sequence.
#
# Outputs:
#   Writes progress to stderr via log()
base_setup() {
  log "Running base setup..."
  base_setup_config_dirs
  base_setup_cache_dirs
  base_setup_path
  base_install_tools
  base_install_claude
  base_verify_tools
  log "Base setup complete"
}
