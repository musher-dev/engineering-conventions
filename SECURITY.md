# Security Policy

## Reporting a vulnerability

If you believe you have found a security vulnerability in
`musher-dev/engineering-conventions`, report it privately through GitHub's
[private vulnerability reporting](https://github.com/musher-dev/engineering-conventions/security/advisories/new),
or email [security@musher.dev](mailto:security@musher.dev). Do **not** open a
public issue for a security report.

We aim to acknowledge a report within **2 business days** and to ship a fix or
workaround for a confirmed vulnerability within **30 days** of that
acknowledgement, depending on severity and complexity. Disclosure timelines are
agreed case by case.

## Scope

In scope:

- **The checks**: the Rego policies, JSON Schemas and Vale style under
  `engineering-conventions/checks/`, where a flaw would let a consumer's
  repository pass a check it should fail, or make the checks unsafe to run on
  untrusted input (a pull request's workflow files, for example).
- **The release bundle**: the tarball, the Vale package, `manifest.json` and
  `SHA256SUMS` attached to each GitHub Release, and the workflows that build
  and publish them.

Out of scope: the repositories that consume these conventions (report those to
the same address and say which repository), and the upstream tools the checks
run on (conftest, OPA, Vale), which have their own security policies.

## Supply chain

- Every third-party action in `.github/workflows/` and `.github/actions/` is
  pinned to a full commit SHA with a version comment, and Dependabot updates
  those pins after a seven-day cooldown.
- `task lint:actions:security` runs [zizmor](https://docs.zizmor.sh) on every
  workflow, composite action and the Dependabot config, and actionlint runs
  beside it. Both are required checks through `Validate / Required`.
- `task secrets:scan` runs [gitleaks](https://github.com/gitleaks/gitleaks) over
  the history on every change, and the pre-commit hook scans each staged change.
- Every CLI the gates run is pinned once, in `.devcontainer/mise.toml`, and CI
  installs from that file. The exceptions are mise itself (pinned in the
  Dockerfile and the setup-tools action, in lockstep), the dev container CLI
  (`@devcontainers/cli`, an exact version in the Dev Container job), and the
  Claude Code installer, which the dev container runs only outside CI.
- The release bundle is reproducible from its tag: `task bundle:build` produces
  the same bytes from the same commit with the same GNU tar, gzip and zip, which
  come from the runner image and are not pinned.
- Each release publishes `SHA256SUMS` and a GitHub build-provenance attestation
  for the bundle and the Vale package. Verify a download with:

  ```bash
  sha256sum -c SHA256SUMS
  gh attestation verify engineering-conventions-<version>.tar.gz \
    --repo musher-dev/engineering-conventions \
    --signer-workflow musher-dev/engineering-conventions/.github/workflows/publish.yml \
    --source-ref refs/tags/v<version>
  ```

- Release tags are immutable: the `Release Tags` ruleset
  (`.github/rulesets/release-tags.json`) blocks creating, updating or deleting
  a `v*` tag for everyone but the release automation.
