# syntax=docker/dockerfile:1
# Musher dev container base image.
#
# bun, uv and task are installed here rather than as Features: their Features
# resolve release assets through an unauthenticated api.github.com call, which
# the shared egress IPs used by Codespaces and CI rate-limit, failing the whole
# build. mise is here because it was otherwise the one unpinned tool.
#
# Full rationale: CONFIGURATION.md → "Runtimes & Tools"
# Enforced by:    repo toolchain check (TC-01..TC-03)
#
# Pinned to the LTS tag: floating `:ubuntu` rolls to interim releases that
# docker-in-docker does not support.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Without pipefail a truncated `curl | bash` reports bash's exit status, giving
# a successful build and an image with no tool in it.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The single source of truth for what this image bakes. verify-toolchain.sh
# reads them back to assert the built container matches.
ARG BUN_VERSION=1.3.14
ARG UV_VERSION=0.11.28
ARG TASK_VERSION=3.52.0
ARG MISE_VERSION=v2026.8.6

RUN set -eux; \
    command -v unzip >/dev/null 2>&1 || { echo "unzip missing from the base image; bun's installer requires it" >&2; exit 1; }; \
    \
    # --- bun -> /usr/local/bin/{bun,bunx}
    # HOME is a scratch dir because the installer appends PATH exports to
    # ~/.bashrc and ~/.zshrc whenever they are writable.
    mkdir -p /tmp/bun-home; \
    HOME=/tmp/bun-home BUN_INSTALL=/usr/local bash -c \
      "curl --retry 5 --retry-all-errors --retry-delay 3 -fsSL https://bun.sh/install \
       | bash -s bun-v${BUN_VERSION}"; \
    rm -rf /tmp/bun-home; \
    # Never write to /usr/local/bin/bunx: it is a symlink to bun, so doing so
    # overwrites the binary and every `bun` call then recurses into itself.
    \
    # --- uv -> /usr/local/bin/{uv,uvx}
    curl --retry 5 --retry-all-errors --retry-delay 3 -LsSf \
      "https://astral.sh/uv/${UV_VERSION}/install.sh" \
      | env UV_INSTALL_DIR=/usr/local/bin INSTALLER_NO_MODIFY_PATH=1 sh; \
    \
    # --- task -> /usr/local/bin/task
    curl --retry 5 --retry-all-errors --retry-delay 3 -fsSL https://taskfile.dev/install.sh \
      | sh -s -- -b /usr/local/bin "v${TASK_VERSION}"; \
    \
    # --- mise -> /usr/local/bin/mise
    # System-wide; base-setup.sh still runs `mise reshim` to build the per-user
    # shim dir that remoteEnv's PATH expects.
    MISE_VERSION="${MISE_VERSION}" MISE_INSTALL_PATH=/usr/local/bin/mise \
      bash -c 'curl --retry 5 --retry-all-errors --retry-delay 3 -fsSL https://mise.run | sh'; \
    \
    # Presence-only: the runtime version check lives in verify-toolchain.sh.
    test -x /usr/local/bin/bun; \
    test -x /usr/local/bin/bunx; \
    test -x /usr/local/bin/uv; \
    test -x /usr/local/bin/uvx; \
    test -x /usr/local/bin/task; \
    test -x /usr/local/bin/mise

# No USER: Features install after this stage and updateRemoteUserUID expects
# root at build time. devcontainer.json's remoteUser owns runtime identity.
