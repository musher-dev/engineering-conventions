---
id: EC-0045
title: Derived status
summary: >-
  A resource's health, readiness and status text are derived from current
  facts by one owning function, reported as conditions, never persisted as
  free text and never re-aggregated by a client. Code that maps a state to
  a health value handles every state, with no default that reports
  success, and pyright's exhaustiveness check stays on. A response that
  makes several claims about a resource takes them from one snapshot and
  says when it was observed. A fact only the observed system knows arrives
  as a level-triggered, fenced, timestamped observation that explains a
  condition and never decides it.
status: draft
topic: source-code
applies_to:
  paths:
    - "**/*.py"
    - "**/*.ts"
    - "**/*.tsx"
    - "**/*.rs"
    - "**/*.go"
    - "**/pyproject.toml"
    - "**/pyrightconfig.json"
created: 2026-11-17
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "Kubernetes API conventions: typical status properties"
    url: https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md#typical-status-properties
  - title: "Kubernetes API conventions: spec and status"
    url: https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md#spec-and-status
  - title: "Python: typing.assert_never"
    url: https://docs.python.org/3/library/typing.html#typing.assert_never
  - title: "Pyright: Configuration"
    url: https://microsoft.github.io/pyright/#/configuration
  - title: "TypeScript: exhaustiveness checking"
    url: https://www.typescriptlang.org/docs/handbook/2/narrowing.html#exhaustiveness-checking
  - title: "The Rust Reference: match expressions"
    url: https://doc.rust-lang.org/reference/expressions/match-expr.html
  - title: "Kubernetes API: VolumeAttachment status"
    url: https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/volume-attachment-v1/
requirements:
  - id: STATUS-01
    title: One owning function derives each resource's status from current facts
    status: proposed
    severity: warning
    since: 0.9.6
    validation:
      engine: review
  - id: STATUS-02
    title: Derived status is not persisted as free-form text
    status: proposed
    severity: warning
    since: 0.9.6
    validation:
      engine: review
  - id: STATUS-03
    title: Status is reported as conditions, with Unknown when the facts are missing
    status: proposed
    severity: warning
    since: 0.9.6
    validation:
      engine: review
  - id: STATUS-04
    title: A client shows the status its owner derived and does not re-aggregate it
    status: proposed
    severity: warning
    since: 0.9.6
    validation:
      engine: review
  - id: STATUS-05
    title: Code that maps a state to a health value handles every state, with no default that reports success
    status: proposed
    severity: warning
    since: 0.9.6
    validation:
      engine: review
  - id: STATUS-06
    title: pyright's match exhaustiveness check is not turned off
    status: proposed
    severity: warning
    since: 0.9.6
    validation:
      engine: conftest
      package: conventions.checks.source_code.derived_status
  - id: STATUS-07
    title: A response's claims about one resource come from one snapshot that states when it was observed
    status: proposed
    severity: warning
    since: 0.9.6
    validation:
      engine: review
  - id: STATUS-08
    title: A fact only the observed system knows is reported as an observation that explains but never decides
    status: proposed
    severity: warning
    since: 0.9.6
    validation:
      engine: review
---

# Derived status

A status page that reports "all replicas healthy" beside "0 of 1 ready", for a service nobody can reach, is not one
bug. It is several places each deciding what healthy means: one function that falls through to success for a state it
did not expect, an explanation written once and never refreshed, and a client that counts for itself from a different
endpoint. Each answer was plausible on its own; together they contradicted each other, and the one a reader trusted was
wrong. This convention gives status one owner and one derivation, so every surface that shows it shows the same answer,
and an unexpected state shows as unknown rather than as healthy.

## Scope

This convention covers code that reports the health, readiness or status of a resource: a deployment, a job, a
replica, a connection, an integration, anything a reader or another system asks "is it working?" about. It covers the
function that derives the answer, where the answer is kept, how it reaches a client, and the code that maps a resource's
state to a health value. Retries and waits, which decide how long a resource stays in a state before it fails, are
[EC-0046](bounded-retries.md).

The shape of a condition is the Kubernetes API conventions'. This convention points at them and does not restate them:
a repository's conditions follow those conventions whether or not the resource lives in Kubernetes.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirements are `proposed` at
severity `warning`, like every requirement in the 0.x series. Every requirement but STATUS-06 is judged in review: the
code it describes is too varied for a portable check, and STATUS-06 keeps on the one machine check that already exists
for the commonest case. A repository may hold itself to a stricter local check that cites the requirement it implements
([decision 0044](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0044-source-code-behaviour-is-a-topic-of-its-own.md)).

## Facts and status

| Kind | Examples | Stored | Derived |
| --- | --- | --- | --- |
| Fact | the desired replica count, a replica's last probe result and its time, an exit code, the generation a controller last acted on | yes | |
| Status | healthy, ready, degraded, the explanation a reader sees | | yes, by one function, each time it is read |

A fact is what was observed or requested, with when. Status is a judgement over facts. Store the facts; derive the
status.

## Requirements

### STATUS-01

**One owning function derives each resource's status from current facts.**

When the API, the dashboard, the command-line tool and the alert each decide what healthy means, they decide it
differently, and the differences surface exactly when something is wrong. Give each kind of resource one function that
takes its current facts and returns its conditions, and have every surface call it. A second derivation, even a
"simpler" one for a summary, is a second opinion that will disagree.

**Correct:**

```python
def derive_status(facts: DeploymentFacts) -> list[Condition]:
    """The only place a deployment's conditions are decided."""
    ...


# API handler, CLI and alert rule all call derive_status(facts).
```

**Incorrect:**

```python
def is_healthy(deployment) -> bool:  # used by the API
    return deployment.ready_replicas == deployment.replicas


def summary_ok(deployment) -> bool:  # used by the dashboard
    return deployment.state != "failed"
```

Checked by: review · Severity: warning · Since: 0.9.6

### STATUS-02

**Derived status is not persisted as free-form text.**

A health flag or an explanation string written to a column is true when it is written and stale from then on: nothing
rewrites it when a replica dies or a dependency recovers, and it outlives the facts it described. Persist facts with
their observation time and generation, and compute the status and its message when they are read. A cache of a derived
value is acceptable only when it records the facts' generation it was derived from and is discarded when they change;
it is never the source of truth.

**Correct:**

```sql
CREATE TABLE replica_probe (
  replica_id   text        NOT NULL,
  probe        text        NOT NULL,
  succeeded    boolean     NOT NULL,
  observed_at  timestamptz NOT NULL
);
```

**Incorrect:**

```sql
ALTER TABLE deployment ADD COLUMN health_message text;  -- "All replicas healthy", forever
```

Checked by: review · Severity: warning · Since: 0.9.6

### STATUS-03

**Status is reported as conditions, with `Unknown` when the facts are missing.**

A single phase or enum (`running`, `healthy`) cannot say that a resource is running but not ready, or ready but
degraded, so each consumer infers the rest and infers it differently. Report a list of conditions, each with `type`,
`status` (`True`, `False` or `Unknown`), `reason`, `message`, its own `lastTransitionTime` and the `observedGeneration`
it was derived from, as the [Kubernetes API conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md#typical-status-properties)
define them; a phase, if one is kept, is derived from the conditions and never the other way round. When the facts a
condition needs are missing, stale or in a state the code does not recognise, its status is `Unknown`, never `True`.

**Correct:**

```json
{
  "observedGeneration": 7,
  "conditions": [
    {
      "type": "Ready",
      "status": "False",
      "reason": "ReplicasUnavailable",
      "message": "0 of 1 replicas ready",
      "lastTransitionTime": "2026-11-17T09:12:44Z",
      "observedGeneration": 7
    }
  ]
}
```

**Incorrect:**

```json
{ "phase": "Healthy", "message": "All replicas healthy" }
```

Checked by: review · Severity: warning · Since: 0.9.6

### STATUS-04

**A client shows the status its owner derived and does not re-aggregate it.**

A client that counts ready replicas itself, from a list endpoint, reads different facts at a different moment from
the endpoint that reported the conditions, and the two numbers on one screen disagree. Display the conditions and the
counts the owning function returned in the same response. When a client needs a number the response lacks, add it to
the derivation (STATUS-01), not to the client.

**Correct:**

```ts
const { conditions, readyReplicas, replicas } = await api.getDeploymentStatus(id);
```

**Incorrect:**

```ts
const status = await api.getDeploymentStatus(id);
const replicas = await api.listReplicas(id);
const ready = replicas.filter((r) => r.state === "running").length;
```

Checked by: review · Severity: warning · Since: 0.9.6

### STATUS-05

**Code that maps a state to a health value handles every state, with no default that reports success.**

A `default`, `else` or `_` branch that returns healthy turns every state added later, and every state still in
progress, into success. Handle each member of the state enum by name, and end with the language's exhaustiveness
guard so a new member fails the type check until someone decides what it means: Python's `match` with
`typing.assert_never`, TypeScript's assignment to `never`, Rust's `match` with no wildcard arm. Where a fallback is
unavoidable, as for a value from the network that may hold a state this build does not know, it yields `Unknown` or
failure, never success.

**Correct:**

```python
from typing import assert_never


def ready(state: ReplicaState) -> ConditionStatus:
    match state:
        case ReplicaState.RUNNING:
            return ConditionStatus.TRUE
        case ReplicaState.CRASHED | ReplicaState.STOPPED:
            return ConditionStatus.FALSE
        case ReplicaState.STARTING | ReplicaState.UNKNOWN:
            return ConditionStatus.UNKNOWN
        case _:
            assert_never(state)
```

```ts
function ready(state: ReplicaState): ConditionStatus {
  switch (state) {
    case "running":
      return "True";
    case "crashed":
    case "stopped":
      return "False";
    case "starting":
      return "Unknown";
    default: {
      const unhandled: never = state;
      throw new Error(`unhandled replica state: ${String(unhandled)}`);
    }
  }
}
```

```rust
fn ready(state: ReplicaState) -> ConditionStatus {
    match state {
        ReplicaState::Running => ConditionStatus::True,
        ReplicaState::Crashed | ReplicaState::Stopped => ConditionStatus::False,
        ReplicaState::Starting => ConditionStatus::Unknown,
    }
}
```

**Incorrect:**

```python
def healthy(state: ReplicaState) -> bool:
    if state in (ReplicaState.CRASHED, ReplicaState.STOPPED):
        return False
    return True  # STARTING, and every state added later, is healthy
```

```rust
match state {
    ReplicaState::Crashed => ConditionStatus::False,
    _ => ConditionStatus::True,
}
```

Checked by: review · Severity: warning · Since: 0.9.6

### STATUS-06

**pyright's match exhaustiveness check is not turned off.**

`reportMatchNotExhaustive` is the check that makes STATUS-05's Python form hold: it reports a `match` over an enum or a
union that misses a member. pyright's `strict` mode and basedpyright's `recommended` and `all` turn it on, which
[CONF-18](../configuration/tool-strictness.md#conf-18) already asks for, so this requirement only reports a
configuration that turns it back off: `false`, `"none"`, `"information"` or `"hint"` in `[tool.pyright]`,
`[tool.basedpyright]` or a `pyrightconfig.json`. `"warning"` stays, because a tool's warnings fail its gate
([CONF-22](../configuration/tool-strictness.md#conf-22)). The check reads the same files CONF-18 does.

**Correct:**

```toml
[tool.basedpyright]
typeCheckingMode = "strict"
```

**Incorrect:**

```toml
[tool.basedpyright]
typeCheckingMode = "strict"
reportMatchNotExhaustive = false
```

Checked by: conftest · Severity: warning · Since: 0.9.6

### STATUS-07

**A response's claims about one resource come from one snapshot that states when it was observed.**

A response that reads the replica count, the conditions and the explanation in three queries can return three
moments, and a reader sees "ready" beside a count that says otherwise. Read the facts a response makes claims from in
one consistent read (one transaction, one cached snapshot, one call to the owning function), and include when that
snapshot was observed, so a reader can tell current from stale. A response that must combine sources observed at
different times says so per source.

**Correct:**

```json
{
  "observedAt": "2026-11-17T09:12:44Z",
  "replicas": 1,
  "readyReplicas": 0,
  "conditions": [{ "type": "Ready", "status": "False", "reason": "ReplicasUnavailable" }]
}
```

**Incorrect:**

```python
return {
    "replicas": db.count_replicas(id),  # read now
    "conditions": cache.get_conditions(id),  # read a minute ago
    "message": deployment.health_message,  # written last week
}
```

Checked by: review · Severity: warning · Since: 0.9.6

### STATUS-08

**A fact only the observed system knows is reported as an observation that explains but never decides.**

Some facts are known only to the system being watched: why a volume failed to detach on its host, what a process
printed before it exited. The owner cannot establish them itself, so the observed system reports them, and a report can
be lost, reordered, late, or sent by a holder that has since been replaced. Report each such fact as an observation
that is:

- **level-triggered**: it states the current situation, not an event, and is sent again while it holds, replacing the
  last one, so a missed or reordered report is corrected by the next; one that is not renewed expires;
- **fenced**: it carries the generation, lease or attempt it was observed under, and the owner discards one from an
  earlier generation or from a holder that no longer holds the lease;
- **timestamped**: it says when it was observed, so a reader can tell current from stale (STATUS-07).

An observation explains: it fills a condition's `reason` and `message`, as a Kubernetes VolumeAttachment's
`detachError` says why a volume is still attached. It does not decide: the condition's `status`, and any action taken
on the resource, come from facts the owner established, so an observation that is wrong, stale or forged can mislead a
reader for a while but cannot move a resource.

**Correct:**

```python
@dataclass(frozen=True)
class DetachObservation:
    attempt: int  # the detach attempt it belongs to: older attempts are discarded
    observed_at: datetime  # re-sent while the error holds; expires when not renewed
    error: str | None  # explains; never read by the decision below


def detached(facts: VolumeFacts) -> ConditionStatus:
    return ConditionStatus.TRUE if facts.unmount_confirmed else ConditionStatus.FALSE
```

**Incorrect:**

```python
def on_agent_event(event: dict) -> None:
    if event.get("detach_error") is None:  # one edge event, unfenced, decides the state
        volume.mark_detached()
```

Checked by: review · Severity: warning · Since: 0.9.6

## Rationale

Status that contradicts itself is worse than no status: a reader trusts the wrong half and acts on it. The
contradiction comes from multiplicity: several derivations, a copy that went stale, a client that counts for itself,
reads taken at different moments. One owner, deriving from current facts each time it is asked, with every state
handled by name and the unknown reported as unknown, leaves one answer to be right or wrong, and makes it easy to find
when it is wrong. The Kubernetes conditions shape is adopted rather than invented because it already separates the
claims a phase conflates, records when each one changed, and is already familiar to anyone who has read a Kubernetes
object's status.

## References

- [Kubernetes API conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md),
  "Spec and Status" and "Typical status properties", the authority for conditions
- [Python: `typing.assert_never`](https://docs.python.org/3/library/typing.html#typing.assert_never)
- [Pyright: Configuration](https://microsoft.github.io/pyright/#/configuration), `reportMatchNotExhaustive`
- [TypeScript: exhaustiveness checking](https://www.typescriptlang.org/docs/handbook/2/narrowing.html#exhaustiveness-checking)
- [The Rust Reference: match expressions](https://doc.rust-lang.org/reference/expressions/match-expr.html)
- [Kubernetes API: VolumeAttachment](https://kubernetes.io/docs/reference/kubernetes-api/config-and-storage-resources/volume-attachment-v1/),
  `detachError`, an observation that explains a status it does not decide
