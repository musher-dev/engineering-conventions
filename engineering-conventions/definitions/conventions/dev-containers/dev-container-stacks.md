---
id: EC-0028
title: Dev container stacks
summary: >-
  The compose stacks a dev container starts beside it, in compose files under
  .devcontainer/, run images that move only with a commit, publish their
  ports on the loopback address only, publish them from the reserved
  range 15432-15460, are forwarded by the dev container, which names the
  same ports in forwardPorts and portsAttributes and forwards none outside
  that range, and, when they label the capability they provide, run a
  version the product's environment schema accepts.
status: draft
topic: dev-containers
applies_to:
  paths:
    - .devcontainer/**/compose.yaml
    - .devcontainer/**/compose.yml
    - .devcontainer/**/docker-compose.yaml
    - .devcontainer/**/docker-compose.yml
    - .devcontainer/devcontainer.json
    - .devcontainer/*/devcontainer.json
created: 2026-09-29
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "Compose file reference: ports"
    url: https://docs.docker.com/reference/compose-file/services/#ports
  - title: "Compose file reference: labels"
    url: https://docs.docker.com/reference/compose-file/services/#labels
  - title: "Compose file reference: image"
    url: https://docs.docker.com/reference/compose-file/services/#image
  - title: "Dev Container metadata reference: forwardPorts and portsAttributes"
    url: https://containers.dev/implementors/json_reference/
requirements:
  - id: DEVC-11
    title: A dev container stack's service runs an image with a fixed tag or a digest
    status: proposed
    severity: warning
    since: 0.6.3
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.stacks
  - id: DEVC-12
    title: A dev container stack publishes its ports on the loopback address only
    status: proposed
    severity: warning
    since: 0.6.3
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.stacks
  - id: DEVC-13
    title: A dev container stack publishes its host ports from the reserved range 15432-15460
    status: proposed
    severity: warning
    since: 0.6.3
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.stacks
    aliases: ["development-container:PORT-05a"]
  - id: DEVC-16
    title: A dev container stack that labels the capability it provides runs a version every environment schema accepts
    status: proposed
    severity: warning
    since: 0.7.1
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.stacks
  - id: DEVC-19
    title: A dev container configuration's forwardPorts and portsAttributes name the same ports
    status: proposed
    severity: warning
    since: 0.10.0
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.stacks
    aliases: ["development-container:PORT-01"]
  - id: DEVC-20
    title: A dev container forwards every host port its stacks publish
    status: proposed
    severity: warning
    since: 0.10.0
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.stacks
    aliases: ["development-container:PORT-02"]
  - id: DEVC-21
    title: A dev container forwards ports from the reserved range 15432-15460 only
    status: proposed
    severity: warning
    since: 0.10.0
    validation:
      engine: conftest
      package: conventions.checks.dev_containers.stacks
    aliases: ["development-container:PORT-05b"]
---

# Dev container stacks

A dev container often starts services beside it, such as a database, a cache or an observability stack, from compose
files under `.devcontainer/`. They run on the developer's machine, publish ports on it, and are rebuilt whenever
anyone rebuilds the container. These requirements keep them reproducible and keep them off the network.

## Scope

A compose file under `.devcontainer/`, at any depth, named `compose.yaml`, `docker-compose.yaml`, or either with a
suffix such as `compose.override.yaml`. Compose files elsewhere describe the product, not the dev environment, and are
not checked here. A value written with a variable is left alone. DEVC-16 also reads the `requires` of every
environment schema the repository holds ([EC-0020](../environment/env-schema.md#runtime-requirements)).

DEVC-19 to DEVC-21 also read each dev container configuration a stack runs beside, at `.devcontainer/devcontainer.json`
or `.devcontainer/<name>/devcontainer.json` ([EC-0027](dev-container-configuration.md#devc-01)). A compose file under
`.devcontainer/<name>/` pairs with the configuration in that directory when there is one, and otherwise with the
configuration at `.devcontainer/devcontainer.json`. When the repository holds only named configurations and none
sits in the stack's directory, the stack pairs with all of them, and a port any one of them forwards counts as
forwarded. A repository without a configuration has nothing to compare a stack with.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`), and every requirement is `proposed` at
severity `warning`. DEVC-13, DEVC-19, DEVC-20 and DEVC-21 adopt `musher-dev/development-container`'s PORT-05, PORT-01
and PORT-02. Only its comparison of the port table in its documentation with its configuration is particular to that
scaffold, and stays there.

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

Checked by: conftest · Severity: warning · Since: 0.6.3

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

Checked by: conftest · Severity: warning · Since: 0.6.3

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

Checked by: conftest · Severity: warning · Since: 0.6.3 · Formerly: development-container PORT-05 (in part)

### DEVC-16

**A dev container stack that labels the capability it provides runs a version every environment schema accepts.**

A product's environment schema declares the range of versions its code works with for each runtime it needs
([EC-0020](../environment/env-schema.md#runtime-requirements)). A stack that runs an older engine than that range
lets code pass locally that fails in every environment, or fails locally for a reason nobody can see. A compose
service says what it provides with two labels: `dev.musher.capability`, a registered runtime capability, and
`dev.musher.capability-version`, the version of the engine its image runs. The check compares that version with the
range of every `requires` entry with the same capability, in every environment schema the repository holds, and
reports a version outside a range, or one that is not dot-separated integers. Labels may be written as a map or a
list. A service without the labels is not compared: adding them is how a stack opts in. The version label repeats
the image's tag, so the two move in the same commit.

**Correct:**

```yaml
# .devcontainer/stacks/cache/compose.yaml; platform-api/env.schema.yaml requires valkey ">=9, <10"
services:
  valkey:
    image: valkey/valkey:9.0.1
    labels:
      dev.musher.capability: valkey
      dev.musher.capability-version: "9.0.1"
```

**Incorrect:**

```yaml
services:
  valkey:
    image: valkey/valkey:8.1.3
    labels:
      - dev.musher.capability=valkey
      - dev.musher.capability-version=8.1.3   # outside >=9, <10
```

Checked by: conftest · Severity: warning · Since: 0.7.1

### DEVC-19

**A dev container configuration's forwardPorts and portsAttributes name the same ports.**

`forwardPorts` makes a port reachable from the developer's machine, and `portsAttributes` gives it the label the
editor shows and says what happens when it is forwarded. A port forwarded without attributes shows up as a bare
number nobody can place, and auto-forward notifications fire for it; attributes left for a port no longer forwarded
describe a service that is gone. The check reports each port on one side only. A `forwardPorts` entry written as a
numeric string, which the specification's schema rejects (DEVC-17), is still compared as its number. A
`"service:port"` entry in `forwardPorts`, which forwards a compose service's port, is not compared, and neither is a
`portsAttributes` key written as a range, such as `"40000-55000"`, or a regular expression, though a forwarded port
inside such a range counts as described.

**Correct:**

```jsonc
"forwardPorts": [15432, 15433],
"portsAttributes": {
  "15432": { "label": "PostgreSQL", "onAutoForward": "silent" },
  "15433": { "label": "Redis", "onAutoForward": "silent" }
}
```

**Incorrect:**

```jsonc
"forwardPorts": [15432, 15433],         // 15433 has no attributes
"portsAttributes": {
  "15432": { "label": "PostgreSQL" },
  "15434": { "label": "MinIO API" }    // 15434 is not forwarded
}
```

Checked by: conftest · Severity: warning · Since: 0.10.0 · Formerly: development-container PORT-01

### DEVC-20

**A dev container forwards every host port its stacks publish.**

A stack publishes its ports on the loopback address of the machine that runs Docker (DEVC-12). When that machine is
not the developer's, as in a codespace or on a remote Docker host, a port the dev container does not forward cannot
be reached from the developer's browser or database client, and the service looks down when it is running. Listing
every published port in `forwardPorts` also keeps one place that says which ports the environment takes. Each host
port is compared, the ports of a range one by one, with the `forwardPorts` of the configuration the stack pairs with
(see [Scope](#scope)); a port written with a variable is left alone.

**Correct:**

```yaml
# .devcontainer/stacks/postgres/compose.yaml; .devcontainer/devcontainer.json forwards [15432]
services:
  postgres:
    ports:
      - "127.0.0.1:15432:5432"
```

**Incorrect:**

```yaml
# .devcontainer/stacks/redis/compose.yaml; .devcontainer/devcontainer.json forwards [15432]
services:
  redis:
    ports:
      - "127.0.0.1:15433:6379"
```

Checked by: conftest · Severity: warning · Since: 0.10.0 · Formerly: development-container PORT-02

### DEVC-21

**A dev container forwards ports from the reserved range 15432-15460 only.**

The reserved range keeps the dev environment's ports clear of the services already on the developer's machine
(DEVC-13). Forwarding a port outside it, such as 5432, takes that port on the developer's machine, where a local
PostgreSQL or another project's container is likely to hold it already, and the forward silently moves to another
number or fails. A forwarded port in the range is one a stack publishes, under the number a reader recognises. A
`"service:port"` entry is not compared.

**Correct:**

```jsonc
"forwardPorts": [15432, 15460]
```

**Incorrect:**

```jsonc
"forwardPorts": [5432, 3000]
```

Checked by: conftest · Severity: warning · Since: 0.10.0 · Formerly: development-container PORT-05 (in part)
