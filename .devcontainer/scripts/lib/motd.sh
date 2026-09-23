#!/usr/bin/env bash
# motd.sh — Renders a startup MOTD summarizing the dev container state.
#
# This is a library file meant to be sourced, not executed directly.
# Requires common.sh (has_cmd, log) to be sourced first.
#
# Usage: source "path/to/motd.sh"; show_motd "/path/to/stacks/compose.yaml" "/path/to/.devcontainer"

if [[ -z "${_MOTD_SH_LOADED:-}" ]]; then
readonly _MOTD_SH_LOADED=1

# --- Color setup ---

_motd_setup_colors() {
  if [[ -t 1 ]] && has_cmd tput; then
    _BOLD="$(tput bold)"
    _DIM="$(tput dim)"
    _GREEN="$(tput setaf 2)"
    _YELLOW="$(tput setaf 3)"
    _RED="$(tput setaf 1)"
    _CYAN="$(tput setaf 6)"
    _RESET="$(tput sgr0)"
  else
    _BOLD="" _DIM="" _GREEN="" _YELLOW="" _RED="" _CYAN="" _RESET=""
  fi
}

# --- Sub-functions ---

_motd_header() {
  local line
  line="$(printf '═%.0s' {1..58})"
  echo "${_BOLD}${line}${_RESET}"
  echo "${_BOLD}  Musher Dev Container${_RESET}"
  echo "${_BOLD}${line}${_RESET}"
}

# Prints a detected runtime version, or skips if not found.
#
# Arguments:
#   $1 — command name
#   $2 — display label
#   $3 — version extraction command (eval'd)
_motd_runtime_entry() {
  local cmd="$1" label="$2" version_cmd="$3"
  if has_cmd "$cmd"; then
    local ver
    ver="$(eval "$version_cmd" 2>/dev/null || echo "?")"
    printf "  ${_CYAN}%-9s${_RESET} %-14s" "$label" "$ver"
  else
    printf "  %-9s %-14s" "" ""
  fi
}

_motd_runtimes() {
  local sep
  sep="$(printf '─%.0s' {1..54})"
  echo ""
  echo "  ${_BOLD}Runtimes${_RESET}"
  echo "  ${_DIM}${sep}${_RESET}"

  _motd_runtime_entry node "node" "node -v"
  _motd_runtime_entry python3 "python" "python3 -c 'import platform; print(platform.python_version())'"
  echo ""

  _motd_runtime_entry go "go" "go version | grep -oP '\\d+\\.\\d+\\.\\d+'"
  _motd_runtime_entry java "java" "java -version 2>&1 | head -1 | grep -oP '\\d+[\\d.]+'"
  echo ""

  _motd_runtime_entry deno "deno" "deno -v | head -1 | awk '{print \$2}'"
  _motd_runtime_entry bun "bun" "bun -v"
  echo ""
}

_motd_services() {
  local compose_file="$1"
  local env_file="${2:-}"
  if [[ -z "$compose_file" ]] || [[ ! -f "$compose_file" ]] || ! has_cmd docker; then
    return 0
  fi

  # Name the env file explicitly for the same reason startup.sh does: the
  # compose file lives under stacks/ and is no longer a sibling of .env.
  local -a env_args=()
  [[ -n "$env_file" && -f "$env_file" ]] && env_args=(--env-file "$env_file")

  local output
  output="$(docker compose "${env_args[@]}" -f "$compose_file" ps --format json 2>/dev/null || true)"
  if [[ -z "$output" ]]; then
    return 0
  fi

  local sep
  sep="$(printf '─%.0s' {1..54})"
  echo ""
  printf "  ${_BOLD}%-35s %s${_RESET}\n" "Services" "Status"
  echo "  ${_DIM}${sep}${_RESET}"

  echo "$output" | while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    local name state health ports
    name="$(echo "$line" | grep -oP '"Name"\s*:\s*"\K[^"]+' | head -1)"
    state="$(echo "$line" | grep -oP '"State"\s*:\s*"\K[^"]+' | head -1)"
    health="$(echo "$line" | grep -oP '"Health"\s*:\s*"\K[^"]+' | head -1)"

    ports="$(echo "$line" | grep -oP '"PublishedPort"\s*:\s*\K\d+' | head -1)"

    [[ -z "$name" ]] && continue

    local display_name="$name"
    if [[ -n "$ports" ]] && [[ "$ports" != "0" ]]; then
      display_name="${name} (${ports})"
    fi

    local status_label color
    if [[ -n "$health" ]] && [[ "$health" != "" ]]; then
      status_label="$health"
    else
      status_label="$state"
    fi

    case "$status_label" in
      healthy)  color="${_GREEN}" ;;
      starting) color="${_YELLOW}" ;;
      *)        color="${_RED}" ;;
    esac

    printf "  %-35s ${color}%s${_RESET}\n" "$display_name" "$status_label"
  done
}

_motd_quickref() {
  local sep
  sep="$(printf '─%.0s' {1..54})"
  echo ""
  echo "  ${_BOLD}Quick Reference${_RESET}"
  echo "  ${_DIM}${sep}${_RESET}"
  echo "  docker compose --env-file .devcontainer/.env \\"
  echo "    -f .devcontainer/stacks/compose.yaml up -d / down / logs -f"
  echo "  git status / log / diff"
  echo "  task                             Task runner"
  echo "  claude                           Claude Code AI"
}

# Warns when .env is missing a value the enabled stacks need, or has drifted
# from the schema. Silent when env is healthy.
#
# Requiredness is profile-aware -- `repo env doctor` only counts bindings whose
# consuming stack is actually enabled -- so this stays quiet about credentials
# for stacks nobody turned on.
#
# Globals:
#   _BOLD, _DIM, _YELLOW, _RESET — color codes set by _motd_setup_colors
# Arguments:
#   $1 — .devcontainer directory (unused; kept for call-site stability)
_motd_env_warnings() {
  has_cmd repo || return 0

  local summary
  summary="$(repo env doctor --motd 2>/dev/null)" && return 0
  [[ -n "${summary}" ]] || return 0

  local sep
  sep="$(printf '─%.0s' {1..54})"
  echo ""
  echo "  ${_BOLD}${_YELLOW}Environment${_RESET}"
  echo "  ${_DIM}${sep}${_RESET}"
  awk '{print "  '"${_YELLOW}"'" $0 "'"${_RESET}"'"}' <<< "${summary}"
  echo "  Run ${_BOLD}task env:setup${_RESET} to fill these in."
}

_motd_tips() {
  local sep
  sep="$(printf '─%.0s' {1..54})"
  echo ""
  echo "  ${_BOLD}Tips${_RESET}"
  echo "  ${_DIM}${sep}${_RESET}"
  echo "  * Enable services:         task env:setup"
  echo "  * Available profiles:      redis, minio, registry,"
  echo "                             azimutt, observability"
  echo "  * Tool versions:           CONFIGURATION.md (Runtimes & Tools)"
}

# Renders the full MOTD to stdout.
#
# Arguments:
#   $1 — path to stacks/compose.yaml (may be empty to skip services)
#   $2 — path to .devcontainer/ directory (may be empty to skip env warnings);
#        also supplies the --env-file the compose file needs
# Outputs:
#   MOTD text to stdout
show_motd() {
  local compose_file="${1:-}"
  local devcontainer_dir="${2:-}"
  _motd_setup_colors

  local border
  border="$(printf '═%.0s' {1..58})"

  echo ""
  _motd_header
  _motd_runtimes
  _motd_services "$compose_file" "${devcontainer_dir:+${devcontainer_dir}/.env}"
  _motd_env_warnings "$devcontainer_dir"
  _motd_quickref
  _motd_tips
  echo "${_BOLD}${border}${_RESET}"
  echo ""
}

fi
