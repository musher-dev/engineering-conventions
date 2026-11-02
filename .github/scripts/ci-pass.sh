#!/usr/bin/env bash
# Pass markers for Validate (decision 0040): a job whose inputs are identical
# to those of a run in which it already passed may skip, on proof.
#
#   ci-pass.sh key <job>  Print the job's input key: a sha256 over the git
#                         object IDs of every path the job reads, at HEAD.
#   ci-pass.sh lookup     Print the ci-pass- cache entries of this pull
#                         request's ref and of main, as "<key>\t<ref>" lines.
#   ci-pass.sh prove      Print, as a JSON array, the eligible jobs that a
#                         marker proves already passed on these inputs.
#
# `key` runs in each eligible job (through .github/actions/sync-pass-marker) and in
# detect, against the same commit. `lookup` and `prove` run in detect only, on
# a same-repository pull_request, and need GH_TOKEN with `actions: read`, plus
# GITHUB_REPOSITORY, GITHUB_REF, GITHUB_HEAD_REF and PR_HEAD_SHA. A marker that
# cannot be read or proved is refused with a warning and its job runs: `prove`
# fails only on a usage error, never because the API did.
set -euo pipefail

# The one table of eligible jobs. Each row is the job ID, its display name
# (what the jobs API reports), and every path its tasks read, a directory
# standing for everything below it and `.` for the whole tree. Widen a row
# when a job's tasks start reading more: a path missing here lets the job skip
# a change it would have failed. A path that does not exist hashes as absent,
# so a row can name a file a later change adds.
JOBS=(
  'repository_lint|Repository / Lint|.'
  'checks|Checks|.config engineering-conventions/checks engineering-conventions/tests/fixtures/openapi'
  'content|Content|.config .github .repo docs engineering-conventions README.md CONTRIBUTING.md SECURITY.md AGENTS.md'
  'conventions|Conventions / Self|.'
  'bundle|Bundle|engineering-conventions version.txt'
)

# What every job reads whatever its row says: the tool pins, the workflow and
# its actions and scripts, and the task definitions.
SHARED_INPUTS=(
  .config/mise
  .github/workflows/validate.yml
  .github/actions
  .github/scripts
  Taskfile.yml
  taskfiles
)

# Bump to orphan every marker written under an older key layout.
KEY_VERSION=v1
WORKFLOW=.github/workflows/validate.yml
MAIN_REF=refs/heads/main

die() {
  echo "ci-pass: $*" >&2
  exit 2
}

warn() {
  echo "::warning title=ci-pass::$*" >&2
}

# The table row for a job, or nothing.
row() {
  local entry
  for entry in "${JOBS[@]}"; do
    if [[ "${entry%%|*}" == "$1" ]]; then
      printf '%s\n' "${entry}"
      return 0
    fi
  done
  return 1
}

# key <job>: the sha256 over the key version, the job, the runner OS and the
# object ID of each input at HEAD. git's object IDs are content hashes, so an
# edit anywhere below a listed directory changes the key.
key() {
  local job="$1" entry paths path spec oid
  entry="$(row "${job}")" || die "'${job}' is not an eligible job"
  read -r -a paths <<<"${entry##*|}"
  {
    printf '%s\n' "${KEY_VERSION}" "job ${job}" "os ${RUNNER_OS:-$(uname -s)}"
    for path in "${paths[@]}" "${SHARED_INPUTS[@]}"; do
      if [[ "${path}" == "." ]]; then
        spec='HEAD^{tree}'
      else
        spec="HEAD:${path}"
      fi
      oid="$(git rev-parse --verify --quiet "${spec}")" || oid=absent
      printf '%s %s\n' "${path}" "${oid}"
    done
  } | sha256sum | cut -d' ' -f1
}

require_env() {
  local name
  for name in "$@"; do
    [[ -n "${!name:-}" ]] || die "${name} is not set"
  done
}

# lookup: every ci-pass- cache entry on this pull request's ref and on main,
# newest first within each ref. The caches API lists keys, never contents,
# which is why a marker's run ID and attempt are in its key.
lookup() {
  require_env GITHUB_REPOSITORY GITHUB_REF
  local ref
  for ref in "${GITHUB_REF}" "${MAIN_REF}"; do
    gh api --paginate --method GET "repos/${GITHUB_REPOSITORY}/actions/caches" \
      -f key=ci-pass- -f ref="${ref}" -f sort=created_at -f direction=desc -F per_page=100 \
      --jq '.actions_caches[] | [.key, .ref] | @tsv'
  done
}

# The `.github/workflows` and `.github/actions` tree IDs at a commit, read
# through the API, because a run's head may be a commit this clone lacks.
remote_trees() {
  gh api "repos/${GITHUB_REPOSITORY}/contents/.github?ref=$1" \
    --jq '[.[] | select(.type == "dir" and (.name == "workflows" or .name == "actions")) | "\(.name)=\(.sha)"]
      | sort | join(" ")'
}

local_trees() {
  local name oid out=()
  for name in actions workflows; do
    oid="$(git rev-parse --verify --quiet "$1:.github/${name}")" || continue
    out+=("${name}=${oid}")
  done
  printf '%s\n' "${out[*]}"
}

# verify <job name> <ref> <run id> <attempt>: succeed when the marker's run is
# one whose pass this run may rely on, else print why not and fail.
verify() {
  local name="$1" ref="$2" run_id="$3" attempt="$4" run problem jobs conclusions theirs ours
  if [[ "${ref}" != "${GITHUB_REF}" && "${ref}" != "${MAIN_REF}" ]]; then
    echo "the marker is scoped to ${ref}"
    return 1
  fi
  run="$(gh api "repos/${GITHUB_REPOSITORY}/actions/runs/${run_id}")" || {
    echo "run ${run_id} could not be read"
    return 1
  }
  # A marker on this pull request's ref must come from a same-repository
  # pull_request run for this branch; one on main, from a push to main.
  problem="$(jq -r --arg repo "${GITHUB_REPOSITORY}" --arg workflow "${WORKFLOW}" \
    --arg ref "${ref}" --arg main "${MAIN_REF}" --arg branch "${GITHUB_HEAD_REF}" \
    --argjson attempt "${attempt}" '
      if (.path // "" | startswith($workflow)) | not then "it is a run of \(.path), not \($workflow)"
      elif .repository.full_name != $repo then "it belongs to \(.repository.full_name)"
      elif .head_repository.full_name != $repo then "its head is in \(.head_repository.full_name)"
      elif $ref == $main and (.event != "push" or .head_branch != "main") then
        "it is a \(.event) run on \(.head_branch), not a push to main"
      elif $ref != $main and (.event != "pull_request" or .head_branch != $branch) then
        "it is a \(.event) run on \(.head_branch), not a pull_request run on \($branch)"
      elif (.run_attempt // 0) < $attempt then "it has no attempt \($attempt)"
      else empty end' <<<"${run}")" || {
    echo "run ${run_id} is not a run object"
    return 1
  }
  if [[ -n "${problem}" ]]; then
    echo "run ${run_id}: ${problem}"
    return 1
  fi
  jobs="$(gh api --paginate \
    "repos/${GITHUB_REPOSITORY}/actions/runs/${run_id}/attempts/${attempt}/jobs?per_page=100")" || {
    echo "the jobs of run ${run_id} attempt ${attempt} could not be read"
    return 1
  }
  conclusions="$(jq -r --arg name "${name}" '.jobs[] | select(.name == $name) | .conclusion' <<<"${jobs}")" || {
    echo "the jobs of run ${run_id} attempt ${attempt} are not job objects"
    return 1
  }
  if [[ -z "${conclusions}" ]] || grep -qvx success <<<"${conclusions}"; then
    echo "'${name}' did not succeed in run ${run_id} attempt ${attempt}: ${conclusions:-no such job}"
    return 1
  fi
  # A workflow edited to write a marker for a later tree, then reverted,
  # cannot vouch for the revert: its head's workflows differ from this one's.
  theirs="$(remote_trees "$(jq -r .head_sha <<<"${run}")")" || {
    echo "the .github trees of run ${run_id} could not be read"
    return 1
  }
  ours="$(local_trees "${PR_HEAD_SHA}")"
  if [[ -z "${ours}" || "${theirs}" != "${ours}" ]]; then
    echo "run ${run_id}'s .github/workflows or .github/actions differ from this head's"
    return 1
  fi
}

prove() {
  require_env GITHUB_REPOSITORY GITHUB_REF GITHUB_HEAD_REF PR_HEAD_SHA
  local entries entry job name job_key marker ref suffix run_id attempt reason passed=()
  if ! entries="$(lookup)"; then
    warn "the ci-pass- caches could not be listed; every job runs"
    printf '[]\n'
    return 0
  fi
  for entry in "${JOBS[@]}"; do
    job="${entry%%|*}"
    name="${entry#*|}"
    name="${name%%|*}"
    job_key="ci-pass-$(key "${job}")"
    while IFS=$'\t' read -r marker ref; do
      [[ "${marker}" == "${job_key}-"* ]] || continue
      suffix="${marker#"${job_key}-"}"
      [[ "${suffix}" =~ ^([0-9]+)-([0-9]+)$ ]] || continue
      run_id="${BASH_REMATCH[1]}"
      attempt="${BASH_REMATCH[2]}"
      if reason="$(verify "${name}" "${ref}" "${run_id}" "${attempt}")"; then
        echo "${job}: inputs identical to run ${run_id} attempt ${attempt}, where it passed" >&2
        passed+=("${job}")
        break
      fi
      warn "${job}: marker refused: ${reason}"
    done <<<"${entries}"
  done
  if ((${#passed[@]} == 0)); then
    printf '[]\n'
  else
    printf '%s\n' "${passed[@]}" | jq -R . | jq -cs .
  fi
}

case "${1:-}" in
  key)
    [[ $# -eq 2 ]] || die "usage: ci-pass.sh key <job>"
    key "$2"
    ;;
  lookup)
    lookup
    ;;
  prove)
    prove
    ;;
  *)
    die "usage: ci-pass.sh key <job> | lookup | prove"
    ;;
esac
