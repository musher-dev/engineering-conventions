---
id: EC-0028
title: Dev container stacks
summary: >-
  The compose stacks a dev container starts beside it, in compose files under
  .devcontainer/, run images that move only with a commit, publish their
  ports on the loopback address only, and publish them from the reserved
  range 15432-15460.
status: draft
topic: dev-containers
applies_to:
  paths:
    - .devcontainer/**/compose.yaml
    - .devcontainer/**/compose.yml
    - .devcontainer/**/docker-compose.yaml
    - .devcontainer/**/docker-compose.yml
created: 2026-09-29
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
implementations:
  - repo: musher-dev/development-container
    check: PORT-05
    mode: blocking
references:
  - title: "Compose file reference: ports"
    url: https://docs.docker.com/reference/compose-file/services/#ports
  - title: "Compose file reference: image"
    url: https://docs.docker.com/reference/compose-file/services/#image
requirements:
  - id: DEVC-11
    title: A dev container stack's service runs an image with a fixed tag or a digest
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.stacks
  - id: DEVC-12
    title: A dev container stack publishes its ports on the loopback address only
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.stacks
  - id: DEVC-13
    title: A dev container stack publishes its host ports from the reserved range 15432-15460
    status: proposed
    severity: warning
    since: 0.6.2
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.stacks
    aliases: ["development-container:PORT-05a"]
---

# Dev container stacks

A dev container often starts services beside it, such as a database, a cache or an observability stack, from compose
files under `.devcontainer/`. They run on the developer's machine, publish ports on it, and are rebuilt whenever
anyone rebuilds the container. These requirements keep them reproducible and keep them off the network.

## Scope

A compose file under `.devcontainer/`, at any depth, named `compose.yaml`, `docker-compose.yaml`, or either with a
suffix such as `compose.override.yaml`. Compose files elsewhere describe the product, not the dev environment, and are
not checked here. A value written with a variable is left alone.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`), and every requirement is `proposed` at
severity `warning`. DEVC-13 adopts the compose half of `musher-dev/development-container`'s PORT-05. Its other port
checks compare the port table in its documentation with its stacks, which is particular to that scaffold, and stay
there.

## Requirements

### DEVC-11

**A dev container stack's service runs an image with a fixed tag or a digest.**

A service image without a tag, or tagged `latest`, `main` or another moving name, is a different database or
collector on each machine that pulls it, and a stack that worked yesterday fails today with no change to review. A
digest fixes any tag, including a moving one.

**Correct:**

```yaml
services:
  postgres:
    image: pgvector/pgvector:0.8.5-pg17
  azimutt:
    image: ghcr.io/azimuttapp/azimutt:main@sha256:f5a8a650b6d4199ae09b796b2b414b3830e215f09861c5d49e887cb8a4a7d9e6
```

**Incorrect:**

```yaml
services:
  postgres:
    image: pgvector/pgvector:latest
```

Checked by: conftest · Severity: warning · Since: 0.6.2

### DEVC-12

**A dev container stack publishes its ports on the loopback address only.**

Compose publishes a port on every network interface unless it names an address. A development database with its
default password, published on `0.0.0.0`, is open to everyone on the same café or office network. Binding to
`127.0.0.1` keeps it reachable from the machine and its dev container, and nowhere else. A port with only a container
side (`"5432"`) is published on a random host port on every interface, and is reported too.

**Correct:**

```yaml
ports:
  - "127.0.0.1:15432:5432"
```

**Incorrect:**

```yaml
ports:
  - "15432:5432"
```

Checked by: conftest · Severity: warning · Since: 0.6.2

### DEVC-13

**A dev container stack publishes its host ports from the reserved range 15432-15460.**

A stack that publishes on a service's usual port collides with the same service running on the host, such as a local
PostgreSQL on 5432 or a web server on 3000, and with the ports a product's own dev server takes. Publishing from one
reserved block, 15432 to 15460, keeps the stacks clear of both, and gives each stack a number a reader recognises as
the dev environment's. The container side keeps its usual port.

**Correct:**

```yaml
ports:
  - "127.0.0.1:15432:5432"
```

**Incorrect:**

```yaml
ports:
  - "127.0.0.1:5432:5432"
```

Checked by: conftest · Severity: warning · Since: 0.6.2 · Formerly: development-container PORT-05 (in part)
