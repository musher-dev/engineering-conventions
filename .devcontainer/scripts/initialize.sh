#!/usr/bin/env bash
# initialize.sh — Host-side bootstrap for the dev container.
#
# Runs on the host via `initializeCommand`, before `docker run` — it has to,
# because `runArgs --env-file` is evaluated at `docker run` time, so .env must
# already exist. post-create.sh would be too late.
#
# The CRLF guard here is not redundant with .gitattributes. That normalizes
# every file Git checks out, which is why the old postCreate fix-crlf step
# could go; it cannot reach .env, which is gitignored, generated locally and
# hand-edited, so a Windows editor can reintroduce CR at any time. Docker
# rejects an --env-file containing CRLF.
#
# The env template is generated from .devcontainer/env.schema.yaml, but this
# hook stays pure bash: it runs on the host, where only bash is guaranteed --
# no Python, no yq. Everything schema-shaped happens in the container instead
# (`repo env sync` in post-create). See CONFIGURATION.md → "Environment
# Variables".
#
# Idempotent: safe to run on every container start.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly DEVCONTAINER_DIR="${SCRIPT_DIR}/.."
readonly ENV_FILE="${DEVCONTAINER_DIR}/.env"
readonly ENV_EXAMPLE="${DEVCONTAINER_DIR}/.env.example"

log() {
  echo "[initialize] $*" >&2
}

ensure_env_file() {
  if [[ -f "${ENV_FILE}" ]]; then
    return 0
  fi
  if [[ -f "${ENV_EXAMPLE}" ]]; then
    log "Creating .devcontainer/.env from .env.example"
    cp "${ENV_EXAMPLE}" "${ENV_FILE}"
  else
    log "No .env.example found; creating empty .devcontainer/.env"
    : > "${ENV_FILE}"
  fi
}

# Not redundant with .gitattributes: .env is gitignored, so Git never
# normalizes it. See the header note.
strip_crlf() {
  [[ -f "${ENV_FILE}" ]] || return 0
  if grep -q $'\r' "${ENV_FILE}" 2>/dev/null; then
    log "Stripping CRLF from .devcontainer/.env"
    sed -i 's/\r$//' "${ENV_FILE}"
  fi
}

# Fills keys the schema marks `source: host` from the host's environment.
#
# The generated template puts a `# @host` marker on the line before such a
# key, which is the whole interface: no YAML parsing on the host. Only empty
# keys are filled, so a value already in .env always wins.
#
# Globals:
#   ENV_FILE — modified
# Outputs:
#   Writes progress to stderr via log()
fill_from_host() {
  [[ -f "${ENV_FILE}" ]] || return 0
  grep -q '^# @host$' "${ENV_FILE}" || return 0

  local tmp marked=0 filled=0 key
  tmp="$(mktemp)"
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" == "# @host" ]]; then
      marked=1
      printf '%s\n' "${line}"
      continue
    fi
    if [[ ${marked} -eq 1 && "${line}" =~ ^([A-Z][A-Z0-9_]*)=$ ]]; then
      key="${BASH_REMATCH[1]}"
      if [[ -n "${!key-}" ]]; then
        printf '%s=%s\n' "${key}" "${!key}"
        filled=$((filled + 1))
        marked=0
        continue
      fi
    fi
    marked=0
    printf '%s\n' "${line}"
  done < "${ENV_FILE}" > "${tmp}"
  mv "${tmp}" "${ENV_FILE}"
  [[ ${filled} -gt 0 ]] && log "Filled ${filled} host-sourced value(s) into .devcontainer/.env"
  return 0
}

main() {
  ensure_env_file
  strip_crlf
  fill_from_host
}

main "$@"
