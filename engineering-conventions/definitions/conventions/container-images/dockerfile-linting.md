---
id: EC-0040
title: Dockerfile linting
summary: >-
  Every Dockerfile, a dev container's included, passes hadolint with the
  repository's configuration at .config/docker/hadolint.yaml. hadolint is
  pinned in mise, lefthook runs it on the Dockerfiles a commit stages, and a
  validate workflow runs it on every Dockerfile.
status: draft
topic: container-images
applies_to:
  paths:
    - "**/Dockerfile"
    - "**/*.Dockerfile"
    - .config/docker/hadolint.yaml
    - .config/docker/hadolint.yml
    - .config/mise/config.toml
    - .config/lefthook.yml
    - Taskfile.yml
    - .github/workflows/*.yml
    - .github/workflows/*.yaml
created: 2026-10-03
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "hadolint"
    url: https://github.com/hadolint/hadolint
  - title: "hadolint: Configure"
    url: https://github.com/hadolint/hadolint#configure
  - title: "Docker: Building best practices"
    url: https://docs.docker.com/build/building/best-practices/
requirements:
  - id: IMAGE-06
    title: Every Dockerfile passes hadolint with the repository's configuration
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: delegated
      tool: hadolint
      check: conventions hadolint
  - id: IMAGE-07
    title: A repository with a Dockerfile configures hadolint at .config/docker/hadolint.yaml
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.container_images.hadolint
  - id: IMAGE-08
    title: A repository with a Dockerfile pins hadolint in mise
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.container_images.hadolint
  - id: IMAGE-09
    title: Lefthook's pre-commit hook runs hadolint with the repository's configuration on every staged Dockerfile
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.container_images.hadolint
  - id: IMAGE-10
    title: A validate workflow runs hadolint with the repository's configuration
    status: proposed
    severity: warning
    since: 0.8.0
    validation:
      engine: conftest
      package: conventions.checks.container_images.hadolint
---

# Dockerfile linting

A Dockerfile's mistakes are mechanical and repeat from one image to the next: a base image with no tag, a package
installed at whatever version the mirror has today, a `cd` in a `RUN` that the next `RUN` forgets, a shell script with
an unquoted variable. [hadolint](https://github.com/hadolint/hadolint) checks for them, and runs shellcheck on every
`RUN`. This convention asks each repository with a Dockerfile to run it the same way: pinned, configured in one file,
on every commit and in validation, and checks that it does.

## Scope

This convention covers every Dockerfile a repository holds, a dev container's included, except those under a `tests/`
or `fixtures/` directory, which are test input. A repository with no Dockerfile meets every requirement. It sets no
rules of its own: which hadolint rules a repository turns off, and the registries it trusts, are its own decisions,
made in its configuration with the reason beside each.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirements are `proposed` at severity
`warning`, like every requirement in the 0.x series. The rules belong to hadolint, at the release each repository
pins. The reasons are in [decision
0030](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0030-container-images-live-in-docker-directories.md).

## How it fits together

```text
.config/mise/config.toml       "aqua:hadolint/hadolint" = "2.15.1"                    IMAGE-08
.config/docker/hadolint.yaml   failure-threshold, rules turned off with their reasons IMAGE-07
.config/lefthook.yml           pre-commit: hadolint on the staged Dockerfiles          IMAGE-09
Taskfile.yml                   lint:docker, run by lint and check                      IMAGE-10
.github/workflows/validate.yml task check                                               IMAGE-10, IMAGE-06
```

The configuration is ordinary hadolint:

```yaml
# .config/docker/hadolint.yaml
failure-threshold: warning
ignored:
  # Alpine's package index keeps one version of each package, so a pin breaks the build when it moves.
  - DL3018
```

A rule is turned off under `ignored`, with the reason beside it, as for any suppression
([EC-0012](../configuration/suppressions.md)); an inline `# hadolint ignore=` comment is a suppression in code, which
the repository's own rules may forbid.

`conventions hadolint` is a convenience: it runs the hadolint release this one pins with `.config/docker/hadolint.yaml`
over every Dockerfile in the repository, or over the files it is given. A repository may run hadolint itself instead.

## Requirements

### IMAGE-06

**Every Dockerfile passes hadolint with the repository's configuration.**

hadolint parses each instruction, checks it against Docker's build practices (pinned base images and packages, one
`apt-get update` with its `install`, `COPY` rather than `ADD`, a `USER` other than root, `WORKDIR` rather than `cd`),
and runs shellcheck on the shell in every `RUN`. A Dockerfile passes when hadolint exits 0 at the configuration's
`failure-threshold`.

The conventions runner does not run hadolint: the repository's validation does (IMAGE-10).

Checked by: hadolint (delegated) · Severity: warning · Since: 0.8.0

### IMAGE-07

**A repository with a Dockerfile configures hadolint at `.config/docker/hadolint.yaml`.**

hadolint reads its configuration from the working directory, the repository's `.config/`, or the home directory, and
falls back to its defaults when it finds none, so a hook, a task and a developer's own run can each judge a Dockerfile
differently. One file, named on every command line, keeps them the same, and is where the repository says which rules
it turns off and why. It sits with the other tools' configuration ([EC-0011](../configuration/tool-configuration.md)),
in the `docker` concern directory.

**Correct:**

```text
.config/docker/hadolint.yaml
```

**Incorrect:**

```text
.hadolint.yaml                 # at the root; CONF-01 reports it too
```

Checked by: conftest · Severity: warning · Since: 0.8.0

### IMAGE-08

**A repository with a Dockerfile pins hadolint in mise.**

hadolint's rules change between releases. Pinned in `.config/mise/config.toml`, the hook, the task and CI run the same
release, and a new one arrives in a reviewed pull request ([EC-0017](../toolchain/tool-pins.md)). The check applies when
the repository has a mise configuration.

**Correct:**

```toml
[tools]
"aqua:hadolint/hadolint" = "2.15.1"
```

**Incorrect:**

```sh
# .devcontainer/scripts/tools.sh
curl -fsSL "https://github.com/hadolint/hadolint/releases/download/v2.15.1/hadolint-Linux-x86_64" -o /usr/local/bin/hadolint
```

Checked by: conftest · Severity: warning · Since: 0.8.0

### IMAGE-09

**Lefthook's pre-commit hook runs hadolint with the repository's configuration on every staged Dockerfile.**

A finding is cheapest on the commit that adds it. A repository that runs lefthook has a pre-commit job that runs
hadolint with `--config .config/docker/hadolint.yaml`, or `conventions hadolint`, or a task that runs either. If the
job has a `glob`, it matches both `Dockerfile` and `<name>.Dockerfile` at any depth: `**/{Dockerfile,*.Dockerfile}`
does, and matches a file in every repository that has a Dockerfile ([HOOKS-11](../git-hooks/lefthook.md#hooks-11)).

**Correct:**

```yaml
# .config/lefthook.yml
pre-commit:
  jobs:
    - name: dockerfile
      glob: "**/{Dockerfile,*.Dockerfile}"
      run: hadolint --config .config/docker/hadolint.yaml {staged_files}
      fail_text: "hadolint found a problem in a staged Dockerfile. Run 'task lint:docker'."
```

**Incorrect:**

```yaml
      glob: "**/Dockerfile"          # misses build.Dockerfile
      run: hadolint {staged_files}   # and whatever configuration it finds
```

Checked by: conftest · Severity: warning · Since: 0.8.0

### IMAGE-10

**A validate workflow runs hadolint with the repository's configuration.**

A hook can be skipped; a check a pull request must pass cannot. A validate workflow runs `conventions hadolint`, or
hadolint with `--config` (or `-c`) naming the configuration, on a step, itself or through a task, directly or through
the tasks that task calls, such as the repository's `check` ([TASK-13](../tasks/task-interface.md#task-13)). The
configuration may be named by a task variable, such as `{{.HADOLINT_CONFIG}}`; the variable then names the file, so
the file has a caller ([CONF-04](../configuration/tool-configuration.md#conf-04)).

**Correct:**

```yaml
# taskfiles/lint.Taskfile.yml
  lint:docker:
    desc: Lint every Dockerfile with hadolint and .config/docker/hadolint.yaml.
    cmds:
      - git ls-files -z '*Dockerfile' | xargs -0 -r hadolint --config .config/docker/hadolint.yaml
```

```yaml
# .github/workflows/validate.yml
      - run: task check
```

**Incorrect:**

```yaml
# .github/workflows/validate.yml: nothing lints a Dockerfile before it merges
      - run: task test
```

Checked by: conftest · Severity: warning · Since: 0.8.0

## References

- [hadolint](https://github.com/hadolint/hadolint)
- [Docker: Building best practices](https://docs.docker.com/build/building/best-practices/)
- [EC-0039 Container image layout](image-layout.md)
- [EC-0012 Suppressions](../configuration/suppressions.md)
