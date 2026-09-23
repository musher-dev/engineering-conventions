#!/usr/bin/env bash
# startup.sh — Starts compose services and waits for health checks.
#
# Executed on every container start to bring up supporting services
# (databases, caches, observability) defined in stacks/compose.yaml.
#
# Usage: Called automatically by devcontainer.json postStartCommand.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
DEVCONTAINER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly DEVCONTAINER_DIR
COMPOSE_FILE="${DEVCONTAINER_DIR}/stacks/compose.yaml"
readonly COMPOSE_FILE
# The compose file lives under stacks/, so it is no longer a sibling of .env and
# Compose's positional auto-discovery cannot find it. Name the env file
# explicitly on every invocation -- otherwise ${VAR:-default} silently wins and
# COMPOSE_PROFILES reads as empty, disabling every opt-in stack without an error.
ENV_FILE="${DEVCONTAINER_DIR}/.env"
readonly ENV_FILE

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/motd.sh
source "${SCRIPT_DIR}/lib/motd.sh"

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

# Polls compose services until all report healthy or timeout elapses.
#
# Globals:
#   COMPOSE_FILE — read, path to stacks/compose.yaml
#   ENV_FILE     — read, path to .env (passed to every compose invocation)
# Arguments:
#   $1 — timeout in seconds (default: 60)
# Outputs:
#   Writes progress/warnings to stderr via log()
# Returns:
#   0 when healthy or on timeout (non-fatal), 1 if services failed
wait_for_healthy() {
  local timeout="${1:-60}"
  log "Waiting up to ${timeout}s for services to be healthy..."
  local elapsed=0
  while ((elapsed < timeout)); do
    local output
    output="$(docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" ps --format json 2>/dev/null || true)"

    local failed=""
    failed="$(echo "$output" | grep -E '"(exited|dead|unhealthy)"' || true)"
    if [[ -n "$failed" ]]; then
      log "ERROR: Failing services detected:"
      echo "$output" | grep -E '"(exited|dead|unhealthy)"' | while IFS= read -r line; do
        local name
        name="$(echo "$line" | grep -o '"Name":"[^"]*"' | head -1 | cut -d'"' -f4)"
        local state
        state="$(echo "$line" | grep -o '"State":"[^"]*"' | head -1 | cut -d'"' -f4)"
        log "  ${name}: ${state}"
        docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" logs --tail=10 "$name" 2>/dev/null || true
      done
      return 1
    fi

    local starting
    starting="$(echo "$output" | grep -c '"starting"' || true)"
    if [[ "$starting" -eq 0 ]]; then
      log "All services healthy"
      return 0
    fi

    sleep 3
    ((elapsed += 3))
  done
  log "WARNING: Timed out waiting for healthy services"
  return 0
}

# Entry point: starts compose services and waits for health.
#
# Outputs:
#   Writes progress to stderr via log()
main() {
  if ! has_cmd docker; then
    log "Docker not available, skipping service startup"
    show_motd "" "${DEVCONTAINER_DIR}"
    return 0
  fi

  if [[ ! -f "${COMPOSE_FILE}" ]]; then
    log "No stacks/compose.yaml found, skipping service startup"
    show_motd "" "${DEVCONTAINER_DIR}"
    return 0
  fi

  # --env-file errors out on a missing path. initialize.sh creates .env on the
  # host before the container starts, so this only trips if that hook was
  # skipped -- say a bare `docker run` outside the devcontainer tooling.
  if [[ ! -f "${ENV_FILE}" ]]; then
    log "No .env found at ${ENV_FILE}; run scripts/initialize.sh first"
    show_motd "" "${DEVCONTAINER_DIR}"
    return 0
  fi

  # Which stacks can actually start, from .env rather than from this process's
  # environment: `runArgs --env-file` froze a copy at `docker run` time, and
  # Compose gives the shell environment precedence over --env-file, so a stale
  # COMPOSE_PROFILES would otherwise beat the file the developer just edited.
  # A stack missing a required value is skipped; the container is never blocked.
  if has_cmd repo; then
    COMPOSE_PROFILES="$(repo env doctor --compose-profiles 2>/dev/null || echo "${COMPOSE_PROFILES:-}")"
    export COMPOSE_PROFILES
    repo env doctor --quiet >/dev/null 2>&1 || log "Some values are missing -- run 'task env:setup' ($(repo env doctor --motd 2>/dev/null | head -1))"
  fi

  log "Starting compose services..."
  docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d --remove-orphans

  wait_for_healthy 60

  show_motd "${COMPOSE_FILE}" "${DEVCONTAINER_DIR}"
}

main "$@"
