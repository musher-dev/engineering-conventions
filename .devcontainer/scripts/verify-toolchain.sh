#!/usr/bin/env bash
# verify-toolchain.sh — Asserts the container's toolchain matches its pins.
#
# Two halves. mise is the one image-baked tool, so its version is read back
# from the Dockerfile's ARG and compared with the binary. Every other CLI is
# pinned in .config/mise/config.toml, and `mise ls --current --missing` lists
# any pin that is not installed, so an empty listing means the container runs
# exactly the versions CI does.
#
# The Dockerfile's own assertion is presence-only (`test -x`): executing a
# binary in the same layer that installed it is a known BuildKit hazard. This
# script is the runtime half of that split, run against the built container.
#
# Usage: bash .devcontainer/scripts/verify-toolchain.sh
#        (`task tools:doctor` and the Dev Container CI job run it.)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
DOCKERFILE="${SCRIPT_DIR}/../Dockerfile"
readonly DOCKERFILE
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly REPO_ROOT
MISE_CONFIG="${REPO_ROOT}/.config/mise/config.toml"
readonly MISE_CONFIG

# Reads a pinned ARG default out of the Dockerfile.
#
# Arguments:
#   $1 — the ARG name, e.g. MISE_VERSION
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

# Asserts the running mise is the version the Dockerfile pins.
#
# Outputs:
#   Writes a pass/fail line to stdout
# Returns:
#   0 on match, 1 on mismatch or missing binary
assert_mise() {
  local expected actual
  # The ARG carries a leading 'v'; `mise --version` prints without one.
  expected="$(arg_pin MISE_VERSION)"
  expected="${expected#v}"
  if ! command -v mise >/dev/null 2>&1; then
    echo "  FAIL mise: not on PATH"
    return 1
  fi
  actual="$(mise --version 2>&1 | head -1)"
  if [[ "${actual}" != *"${expected}"* ]]; then
    echo "  FAIL mise: expected ${expected}, got '${actual}'"
    return 1
  fi
  echo "  ok   mise ${expected}"
}

# Asserts min_version in the mise config is the version the Dockerfile pins,
# so a mise older than the one CI and the container run refuses the config.
#
# Outputs:
#   Writes a pass/fail line to stdout
# Returns:
#   0 on match, 1 on mismatch or a missing min_version
assert_mise_min_version() {
  local expected actual
  expected="$(arg_pin MISE_VERSION)"
  expected="${expected#v}"
  actual="$(sed -n 's/^min_version = "\(.*\)"$/\1/p' "${MISE_CONFIG}" | head -1)"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "  FAIL config.toml: min_version is '${actual}', expected ${expected}"
    return 1
  fi
  echo "  ok   config.toml min_version ${expected}"
}

# Asserts every tool pinned in .config/mise/config.toml is installed at its
# pinned version. mise finds the config by walking up from the working
# directory, so this runs from the repository root.
#
# Outputs:
#   Writes a pass/fail line, and any missing pins, to stdout
# Returns:
#   0 when nothing is missing, 1 otherwise
assert_mise_pins() {
  local missing
  if ! missing="$(cd "${REPO_ROOT}" && mise ls --current --missing 2>&1)"; then
    echo "  FAIL config.toml: 'mise ls --current --missing' failed: ${missing}"
    return 1
  fi
  if [[ -n "${missing}" ]]; then
    echo "  FAIL config.toml: pinned tools not installed (run 'task tools:install'):"
    printf '%s\n' "${missing}" | sed 's/^/         /'
    return 1
  fi
  echo "  ok   every config.toml pin is installed"
}

# Entry point: checks the baked tool and every mise pin.
#
# Outputs:
#   Writes per-check results to stdout
# Returns:
#   0 if everything matches, 1 otherwise
main() {
  echo "Verifying the toolchain against ${DOCKERFILE} and ${MISE_CONFIG}..."
  local failed=0
  assert_mise || failed=1
  assert_mise_min_version || failed=1
  assert_mise_pins || failed=1
  if ((failed)); then
    echo "Toolchain verification FAILED" >&2
    return 1
  fi
  echo "Toolchain verification passed"
}

main "$@"
