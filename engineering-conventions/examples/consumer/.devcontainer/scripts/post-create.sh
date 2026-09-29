#!/usr/bin/env bash
# Runs once the workspace is mounted. A real repository installs its tools
# and git hooks here; the example only confirms the Feature installed gh.
set -euo pipefail

gh --version
