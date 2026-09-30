# syntax=docker/dockerfile:1
# Dev container image for musher-dev/engineering-conventions.
#
# The image bakes exactly one tool, mise, because mise cannot pin itself.
# Every other CLI is pinned in .config/mise/config.toml (docs/repository.md →
# "Toolchain").
#
# Pinned to the LTS tag: a floating `:ubuntu` rolls to interim releases. The
# digest (of the multi-platform index) fixes the bytes the tag names; Dependabot
# raises it (.github/dependabot.yml).
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04@sha256:d94c97dd9cacf183d0a6fd12a8e87b526e9e928307674ae9c94139139c0c6eae

# Without pipefail a failing command early in a pipeline is masked by the
# exit status of the last one.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Lockstep with the mise version in .github/actions/setup-tools/action.yml
# (.claude/rules/toolchain-pins.md). verify-toolchain.sh reads it back to
# assert the built container matches.
ARG MISE_VERSION=v2026.9.12

# The linux-x64 and linux-arm64 mise binaries of MISE_VERSION, from the
# release's SHASUMS256.txt (`./mise-<version>-linux-<arch>`). Bump them with
# MISE_VERSION, and with sha256: in .github/actions/setup-tools/action.yml.
ARG MISE_SHA256_AMD64=e79ae57945034903aee8aa2ea66b4c7ca9cd4f4edd5a8a78a589cbae6d0f428a
ARG MISE_SHA256_ARM64=f344c6961190ed2f68e595ed7cb4f03c36c17812bd608886bec799a3082180ff

# Set by BuildKit; dpkg answers for a builder that does not set it.
ARG TARGETARCH

# The release binary itself, not the mise.run installer, checked against the
# pinned checksum before it is installed. --retry-all-errors: GitHub's release
# downloads fail transiently on shared CI egress, and one failed fetch would
# otherwise fail the whole build.
RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "${arch}" in \
      amd64) asset=linux-x64; sha256="${MISE_SHA256_AMD64}" ;; \
      arm64) asset=linux-arm64; sha256="${MISE_SHA256_ARM64}" ;; \
      *) echo "no pinned mise checksum for architecture ${arch}" >&2; exit 1 ;; \
    esac; \
    curl --retry 5 --retry-all-errors --retry-delay 3 -fsSL -o /tmp/mise \
      "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/mise-${MISE_VERSION}-${asset}"; \
    echo "${sha256}  /tmp/mise" | sha256sum --check --strict -; \
    install -m 0755 /tmp/mise /usr/local/bin/mise; \
    rm -f /tmp/mise; \
    # Presence-only: executing a binary in the layer that installed it is a
    # BuildKit hazard. The version check lives in verify-toolchain.sh.
    test -x /usr/local/bin/mise

# No USER: Features install after this stage and updateRemoteUserUID expects
# root at build time. devcontainer.json's remoteUser owns runtime identity.
