# syntax=docker/dockerfile:1
# Dev container image for musher-dev/engineering-conventions.
#
# The image bakes exactly one tool, mise. Every other CLI (task, lefthook, the
# rule engines, the linters, uv) is pinned in .devcontainer/mise.toml and
# installed from it at post-create, from the same file CI installs from, so a
# version lives in one place. mise cannot pin itself from that file, which is
# why it alone is an ARG here.
#
# Full rationale: CONFIGURATION.md → "Runtimes & Tools"
#
# Pinned to the LTS tag: a floating `:ubuntu` rolls to interim releases.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Without pipefail a truncated `curl | sh` reports sh's exit status, giving a
# successful build and an image with no mise in it.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Lockstep with the mise version in .github/actions/setup-tools/action.yml
# (.claude/rules/toolchain-pins.md). verify-toolchain.sh reads it back to
# assert the built container matches.
ARG MISE_VERSION=v2026.9.12

# --retry-all-errors: the installer comes from a CDN that fails transiently on
# shared CI egress, and one failed fetch would otherwise fail the whole build.
RUN set -eux; \
    MISE_VERSION="${MISE_VERSION}" MISE_INSTALL_PATH=/usr/local/bin/mise \
      bash -c 'curl --retry 5 --retry-all-errors --retry-delay 3 -fsSL https://mise.run | sh'; \
    # Presence-only: executing a binary in the layer that installed it is a
    # BuildKit hazard. The version check lives in verify-toolchain.sh.
    test -x /usr/local/bin/mise

# No USER: Features install after this stage and updateRemoteUserUID expects
# root at build time. devcontainer.json's remoteUser owns runtime identity.
