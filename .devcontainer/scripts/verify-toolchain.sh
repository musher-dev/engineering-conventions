#!/usr/bin/env bash
# verify-toolchain.sh — Asserts the image-baked tools report their pinned versions.
#
# The Dockerfile's own assertions are presence-only (`test -x`): executing a
# binary in the same layer that installed it is a known BuildKit hazard, and the
# pinned download URLs already guarantee the version -- a wrong one 404s. This
# script is the runtime half of that split, run against the built container.
#
# The expected versions are read back out of .devcontainer/Dockerfile so the
# ARGs stay the single source of truth. `repo toolchain check` separately
# asserts those ARGs are concrete pins rather than floating tags.
#
# Usage: bash .devcontainer/scripts/verify-toolchain.sh
#        (CI runs it as the devcontainers/ci `runCmd`.)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
DOCKERFILE="${SCRIPT_DIR}/../Dockerfile"
readonly DOCKERFILE

# Reads a pinned ARG default out of the Dockerfile.
#
# Arguments:
#   $1 — the ARG name, e.g. BUN_VERSION
# Outputs:
#   The pinned value on stdout
# Returns:
#   0 on success, 1 if the ARG is absent or has no default
arg_pin() {
  local name="${1}"
  local value
  value="$(sed -n "s/^ARG ${name}=\\(.*\\)$/\\1/p" "${DOCKERFILE}" | head -1)"
  if [[ -z "${value}" ]]; then
    echo "ERROR: no 'ARG ${name}=<pin>' in ${DOCKERFILE}" >&2
    return 1
  fi
  printf '%s\n' "${value}"
}

# Asserts `<tool> --version` reports the expected version.
#
# Arguments:
#   $1 — the binary name, which is also the human-readable tool name
#   $2 — expected version (no leading 'v')
# Outputs:
#   Writes a pass/fail line to stdout
# Returns:
#   0 on match, 1 on mismatch or missing binary
assert_version() {
  local tool="${1}" expected="${2}"
  local actual
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "  FAIL ${tool}: not on PATH"
    return 1
  fi
  # Tools disagree on output shape (`task` prints "Task version: v3.52.0", uv
  # prints "uv 0.11.28"), so match the expected string anywhere in the first
  # line rather than parsing four different formats.
  actual="$("${tool}" --version 2>&1 | head -1)"
  if [[ "${actual}" != *"${expected}"* ]]; then
    echo "  FAIL ${tool}: expected ${expected}, got '${actual}'"
    return 1
  fi
  echo "  ok   ${tool} ${expected}"
}

# Entry point: checks every image-baked tool against its Dockerfile pin.
#
# Outputs:
#   Writes per-tool results to stdout
# Returns:
#   0 if all tools match, 1 otherwise
main() {
  echo "Verifying image-baked toolchain against ${DOCKERFILE}..."

  local bun_v uv_v task_v mise_v
  bun_v="$(arg_pin BUN_VERSION)"
  uv_v="$(arg_pin UV_VERSION)"
  task_v="$(arg_pin TASK_VERSION)"
  # MISE_VERSION is pinned with a leading 'v'; `mise --version` prints without.
  mise_v="$(arg_pin MISE_VERSION)"
  mise_v="${mise_v#v}"

  local failed=0
  assert_version bun  "${bun_v}"  || failed=1
  assert_version uv   "${uv_v}"   || failed=1
  assert_version task "${task_v}" || failed=1
  assert_version mise "${mise_v}" || failed=1

  # bunx is a symlink to bun; assert it survived rather than being overwritten.
  if [[ ! -x /usr/local/bin/bunx ]]; then
    echo "  FAIL bunx: /usr/local/bin/bunx missing or not executable"
    failed=1
  else
    echo "  ok   bunx"
  fi

  if ((failed)); then
    echo "Toolchain verification FAILED" >&2
    return 1
  fi
  echo "Toolchain verification passed"
}

main "$@"
