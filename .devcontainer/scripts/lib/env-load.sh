#!/usr/bin/env bash
# env-load.sh — Library: export .devcontainer/.env into the current shell.
#
# This is a library file meant to be sourced, not executed directly.
# Usage: source "path/to/env-load.sh" [env-file]
#
# Why it exists: `runArgs --env-file` reads .env once, at `docker run` time, so
# every value a developer changes afterwards stays stale until a rebuild. Post-
# create wires this into the shell profile, so a new terminal sees the current
# file instead.
#
# Why it does not `source` the file: dotenv is not shell. `docker run
# --env-file` treats the whole right-hand side literally, so `FOO=a b` is one
# value there and a command execution to a shell. This parses instead.
#
# Exposes:
#   env_load [file] — export every KEY=VALUE in a dotenv file

# Exports each assignment in a dotenv file into the current shell.
#
# Arguments:
#   $1 — path to the env file (default: ../.env relative to this library)
# Outputs:
#   None
# Returns:
#   0 always — a missing file is not an error, it is a fresh clone
env_load() {
  local file="${1:-${BASH_SOURCE[0]%/*}/../.env}"
  [[ -f "${file}" ]] || return 0

  local line key value
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ "${line}" =~ ^[[:space:]]*# ]] && continue
    [[ "${line}" =~ ^([A-Z][A-Z0-9_]*)=(.*)$ ]] || continue
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    export "${key}=${value}"
  done < "${file}"
}
