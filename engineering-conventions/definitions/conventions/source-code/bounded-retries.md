---
id: EC-0046
title: Bounded retries and waits
summary: >-
  Every retry loop counts failures by class against a budget that resets
  after a stated healthy period, is paced by one jittered backoff, and
  retries at one layer. Exhaustion is always surfaced as a condition and an
  alertable signal, and stops the loop only when no retry can succeed
  without new inputs. Every wait has a deadline from measured latency that
  fits inside the deadline containing it, a client never retries sooner
  than Retry-After asks, and an action that overrides a safety hold needs
  a fence.
status: draft
topic: source-code
applies_to:
  paths:
    - "**/*.py"
    - "**/*.ts"
    - "**/*.tsx"
    - "**/*.rs"
    - "**/*.go"
created: 2026-11-17
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "Amazon Builders' Library: Timeouts, retries and backoff with jitter"
    url: https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/
  - title: "AWS Architecture Blog: Exponential Backoff and Jitter"
    url: https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/
  - title: "Site Reliability Engineering: Handling Overload"
    url: https://sre.google/sre-book/handling-overload/
  - title: "Site Reliability Engineering: Addressing Cascading Failures"
    url: https://sre.google/sre-book/addressing-cascading-failures/
  - title: "Kubernetes: Pod lifecycle, container restarts"
    url: https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#restart-policy
  - title: "Amazon ECS: deployment circuit breaker"
    url: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-circuit-breaker.html
  - title: "Nomad: reschedule block"
    url: https://developer.hashicorp.com/nomad/docs/job-specification/reschedule
  - title: "RFC 9110, section 10.2.3: Retry-After"
    url: https://www.rfc-editor.org/rfc/rfc9110#section-10.2.3
  - title: "gRPC: Retry"
    url: https://grpc.io/docs/guides/retry/
  - title: "KEP-2268: Non-graceful node shutdown"
    url: https://github.com/kubernetes/enhancements/tree/master/keps/sig-storage/2268-non-graceful-shutdown
  - title: "Kubernetes API conventions: typical status properties"
    url: https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md#typical-status-properties
requirements:
  - id: RETRY-01
    title: A retry loop counts failures by class against a budget, paced by one jittered backoff at one layer
    status: proposed
    severity: warning
    since: 0.9.6
    validation:
      engine: review
  - id: RETRY-02
    title: An exhausted retry budget is surfaced, and stops the loop only when no retry can succeed without new inputs
    status: proposed
    severity: warning
    since: 0.9.6
    validation:
      engine: review
  - id: RETRY-03
    title: Every wait has a deadline from measured latency that fits inside the deadline containing it
    status: proposed
    severity: warning
    since: 0.9.6
    validation:
      engine: review
  - id: RETRY-04
    title: A client never retries sooner than Retry-After asks
    status: proposed
    severity: warning
    since: 0.9.6
    validation:
      engine: review
  - id: RETRY-05
    title: An action that overrides a safety hold requires a fence proving the previous holder can no longer act
    status: proposed
    severity: warning
    since: 0.9.6
    validation:
      engine: review
---

# Bounded retries and waits

A retry loop with no budget does not recover from a failure that will not go away; it hides it. A unit that is
recreated each time it fails looks busy rather than broken, the status reports it as starting, and the only evidence
is a log line repeated until someone reads it. A wait with no deadline does the same to whatever is waiting, and two
layers that each retry, or each time the same wait, multiply the load or race each other to a wrong answer. This
convention makes every retry and every wait finite and single-owned, makes the moment it gives up something a reader
and an alert can see, and keeps a retry from overriding a safety hold it cannot prove is safe to override.

## Scope

This convention covers code that retries an operation, recreates or restarts something that failed, waits for an
external dependency (a network call, a database or queue becoming reachable, a job finishing, a resource reaching a
state), or overrides a hold another holder placed. It applies whether the loop is written by hand or configured in a
library, a framework or a scheduler; the configuration is where the budget and the deadline are declared. How the
resulting state is reported is [EC-0045](derived-status.md).

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirements are `proposed` at
severity `warning`, like every requirement in the 0.x series, and are judged in review: a retry is written in too many
forms, across too many libraries, for a portable check. A repository may hold itself to a stricter local check that
cites the requirement it implements ([decision 0044](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0044-source-code-behaviour-is-a-topic-of-its-own.md)).

## What a retry declares

| Declared | Means | Example |
| --- | --- | --- |
| Budget | When the loop is exhausted: consecutive failures of one class, a total time, or both | 5 image-pull failures in a row, or 2 minutes |
| Healthy reset | How long the unit must run healthy before its count returns to zero | 10 minutes |
| Backoff | The one thing that paces the loop: growing, capped and jittered | full jitter from 1 s, capped at 5 minutes |
| Layer | Which layer retries; the others fail fast | the job runner, not the HTTP client inside it |
| Deadline | When a wait lapses, from measured latency, inside its caller's | p99.9 of 850 ms plus margin: 1 s per attempt |
| Surfaced state | What a reader and an alert see on exhaustion | condition `Ready=False`, reason `RetriesExhausted`; a counter |

## Requirements

### RETRY-01

**A retry loop counts failures by class against a budget, paced by one jittered backoff at one layer.**

A loop that retries until it succeeds turns a permanent failure into unbounded work, and one that retries at once, or
at a fixed interval, turns one failure into load on the thing that is failing. Bound every loop by a budget of
attempts, total time, or both, and hold it to these rules:

- **Count by class.** A loop that recreates a unit which ran (a replica, a job, a connection) counts consecutive
  failures per class: a classified reason such as `ImagePullFailed` or `OutOfMemory`. Never key the count on the error
  message, which carries an address, a time or an ID and makes every failure look like the first.
- **Reset after a healthy period.** The count returns to zero only after the unit has been healthy for a stated period,
  as the kubelet resets a container's restart backoff after ten minutes of running and Amazon ECS's deployment circuit
  breaker resets its count on a healthy task (`resetOnHealthyTask`). A unit that starts, passes one probe and crashes
  never completes the period, so its count keeps growing.
- **One pacer.** The backoff alone decides when the next attempt starts, as Nomad's `reschedule` block declares delay,
  delay function and maximum delay in one place. A second limiter beside it, such as a cooldown, a rate limit or a
  minimum interval enforced elsewhere, makes the slower of the two the real policy, and nobody declared it.
- **One layer.** Retry at one layer of the stack, the one that can judge whether another attempt is worth making; the
  layers below it fail fast and report the failure's class. Three layers that each try three times make 27 attempts on
  a dependency that is already struggling.
- **Full or decorrelated jitter.** Prefer full jitter, a random wait between zero and the capped exponential, or
  decorrelated jitter, a random wait between the base and three times the previous wait, capped. Clients that failed
  together then do not retry together; a fixed or un-jittered backoff keeps them in step.

**Correct:**

```python
@dataclass(frozen=True)
class RecoveryPolicy:
    budget: int  # consecutive failures of one class
    healthy_reset: timedelta  # running this long returns the count to zero
    backoff: FullJitter  # the only thing that paces the loop


POLICIES = {
    FailureClass.IMAGE_PULL: RecoveryPolicy(5, timedelta(minutes=10), FullJitter(base=1, cap=300)),
    FailureClass.OUT_OF_MEMORY: RecoveryPolicy(
        3, timedelta(minutes=10), FullJitter(base=5, cap=600)
    ),
}
```

**Incorrect:**

```python
failures[str(error)] += 1  # every message is new, so the budget is never reached
if failures[str(error)] < 5 and not cooldown.active(unit):
    time.sleep(2**attempt)  # no jitter, and a second limiter beside it
    recreate(unit)
```

Checked by: review · Severity: warning · Since: 0.9.6

### RETRY-02

**An exhausted retry budget is surfaced, and stops the loop only when no retry can succeed without new inputs.**

When a budget is spent, the operation has failed, and the resource it was for has to say so, always: set a condition
the status derivation reads, `status: False` with a reason such as `RetriesExhausted`
([EC-0045](derived-status.md)), and emit a signal an alert can fire on, such as a counter or an event. A log line is
evidence for whoever is already looking; it is not a state, and it is not an alert.

What the loop does next depends on whether another attempt can succeed:

| Cause | After exhaustion | Resumes on |
| --- | --- | --- |
| Inside the unit's inputs: an image that does not exist, a configuration the unit rejects, an error classified permanent | Stop | A change to the unit's inputs: a new specification, generation or request |
| Outside the unit, and may clear: a dependency that is down, a host out of capacity, a quota | Keep retrying at the capped interval, with the condition still set | A change to the awaited dependency, observed, which also resets the backoff |

A loop that stops for a cause that may clear waits for a person to notice and restart it; a loop that keeps retrying a
cause that cannot clear spends the dependency's capacity on attempts that will fail.

**Correct:**

```python
except RetryError as error:
    failure = classify(error.last_attempt.exception())
    facts.record_exhausted(failure_class=failure.cls, reason="RetriesExhausted")
    retries_exhausted_total.labels(operation="fetch_manifest", failure_class=failure.cls).inc()
    if failure.needs_new_inputs:
        return Park(until=InputsChanged(generation=facts.generation))
    return RetryAt(policy.backoff.cap)   # outside cause: keep trying, still surfaced
```

**Incorrect:**

```python
except RetryError:
    logger.warning("giving up on manifest fetch")   # no state, no alert, and never resumes
```

Checked by: review · Severity: warning · Since: 0.9.6

### RETRY-03

**Every wait has a deadline from measured latency that fits inside the deadline containing it.**

A wait with no deadline, on a socket, a lock, a job or a resource becoming ready, holds whatever is waiting for as
long as the dependency stays away, and nothing reports that it is stuck. A library's default of no timeout is a wait
without a deadline. Give every wait a deadline, and:

- **Measure it.** Set an attempt's timeout from the dependency's measured latency, a high percentile such as p99.9 plus
  a margin, so a false timeout is rare and a real one is not waited out. A round number chosen once is either too short
  under load or long enough to hide an outage.
- **Nest it.** An inner timeout is shorter than the deadline that contains it, and the caller passes down what remains
  of its deadline (a context, a cancellation token, gRPC's `grpc-timeout`). No attempt starts that cannot finish before
  the outer deadline, and no work continues after its caller has given up.
- **One judge per wait.** When two layers watch the same wait, such as a controller waiting on an agent that is itself
  waiting on a volume to detach, the better-informed layer decides when it has failed. The other suspends its clock
  while it is told the wait is progressing, or keeps a longer deadline that acts only as a backstop when the informed
  layer stops reporting. Two equal clocks race, and the less-informed one wins half the time.
- **Only the outermost is terminal.** A lapsed attempt timeout is reported and retried under RETRY-01 and RETRY-02;
  only the outermost deadline, the one the requester set, ends the operation as failed.

**Correct:**

```go
// p99.9 of Fetch is 850ms: one second per attempt, never past the caller's deadline.
for attempt := 0; ; attempt++ {
    if d, ok := ctx.Deadline(); ok && time.Until(d) < time.Second {
        return fmt.Errorf("fetch: not enough of the deadline left for an attempt: %w", context.DeadlineExceeded)
    }
    attemptCtx, cancel := context.WithTimeout(ctx, time.Second)
    err := client.Fetch(attemptCtx)
    cancel()
    if err == nil || !retryable(err) {
        return err
    }
    sleep(ctx, backoff.Next(attempt))
}
```

**Incorrect:**

```python
response = requests.get(url)  # no timeout: waits as long as the server does
job.wait(timeout=600)  # inside a request whose own deadline is 30 seconds
```

Checked by: review · Severity: warning · Since: 0.9.6

### RETRY-04

**A client never retries sooner than `Retry-After` asks.**

A server that answers `429` or `503` with `Retry-After` ([RFC 9110, section 10.2.3](https://www.rfc-editor.org/rfc/rfc9110#section-10.2.3)),
or a gRPC status with retry pushback, is saying when a retry can succeed. Retrying sooner wastes the attempt and adds
to the load that caused the refusal. A client may cap how long it sleeps in line, so that one header cannot hold a
request handler or a worker for an hour, but the cap never brings the next attempt forward: when the asked time is
beyond the cap or the remaining budget, the client ends the attempt and schedules the next one no earlier than the
asked time. A value that cannot be parsed, is in the past, or is absurdly far ahead (beyond a stated maximum, such as a
day) is treated as absent, and the backoff alone applies.

**Correct:**

```ts
const asked = parseRetryAfter(response.headers.get("retry-after"), { maxMs: DAY_MS }); // null if absent or absurd
const delay = Math.max(asked ?? 0, backoff.next());
if (delay <= MAX_INLINE_SLEEP_MS && elapsed + delay <= budget.remainingMs()) {
  await sleep(delay);
} else {
  await queue.schedule(job, { notBefore: Date.now() + delay }); // later, never sooner
  return;
}
```

**Incorrect:**

```ts
if (response.status === 429) {
  await sleep(Math.min(retryAfterMs, 5_000)); // the server asked for 60 seconds; this retries in 5
}
```

Checked by: review · Severity: warning · Since: 0.9.6

### RETRY-05

**An action that overrides a safety hold requires a fence proving the previous holder can no longer act.**

A safety hold keeps two holders from acting on one thing at once: a volume attached to a node, a lease on a job, a
lock on a row. Overriding it, by force-detaching the volume, force-deleting the workload or taking the lease, is safe
only if the previous holder cannot still write. A holder that is slow, partitioned or paused looks exactly like one
that is gone, so a timeout or a missed heartbeat is not proof. Require a fence before the override:

- the holder's machine confirmed powered off or isolated, as Kubernetes' non-graceful node shutdown (KEP-2268) acts
  only once the node is marked out of service;
- a lease whose expiry the holder itself honours, stopping before it lapses; or
- a fencing token, a number that grows with each grant, which the protected resource checks so that it rejects a
  stale holder's writes.

Without a fence the override waits, and the wait is surfaced as RETRY-02 surfaces exhaustion.

**Correct:**

```python
def force_detach(volume: Volume, node: Node) -> None:
    fence = node.fence()  # out of service, powered off, or lease lapsed and honoured
    if fence is None:
        raise HoldNotFenced(volume.id, node.id)
    volume.detach(force=True, fence_token=fence.token)
```

**Incorrect:**

```python
if time.time() - node.last_heartbeat > 300:  # silent is not the same as stopped
    volume.detach(force=True)
```

Checked by: review · Severity: warning · Since: 0.9.6

## Rationale

A bounded retry fails at a known time, in a known way, and says so; an unbounded one fails silently and indefinitely,
and its cost lands on the dependency and on whoever eventually reads the log. The rules follow systems that have run
this loop at scale: the kubelet's and the ECS circuit breaker's healthy reset, Nomad's single declared reschedule
policy, the Amazon Builders' Library's timeouts from measured latency and retries at one layer, the Google SRE book's
retry budgets and deadline propagation, and HTTP's `Retry-After`. Each is cited, not restated. Declaring the budget,
the backoff and the deadline beside the call makes them reviewable; surfacing exhaustion makes the failure reach the
status and the alert a reader already watches; and a fence keeps the last resort, overriding a hold, from turning one
failure into two writers.

## References

- [Amazon Builders' Library: Timeouts, retries and backoff with jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/),
  timeouts from a latency percentile and retrying at one layer
- [AWS Architecture Blog: Exponential Backoff and Jitter](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/),
  full and decorrelated jitter
- [Site Reliability Engineering: Handling Overload](https://sre.google/sre-book/handling-overload/), retry budgets
- [Site Reliability Engineering: Addressing Cascading Failures](https://sre.google/sre-book/addressing-cascading-failures/),
  deadline propagation and retrying at one level
- [Kubernetes: Pod lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#restart-policy), the
  restart backoff that resets after ten minutes of running
- [Amazon ECS: deployment circuit breaker](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/deployment-circuit-breaker.html),
  `resetOnHealthyTask`
- [Nomad: `reschedule`](https://developer.hashicorp.com/nomad/docs/job-specification/reschedule), one declared delay
  policy
- [RFC 9110, section 10.2.3: Retry-After](https://www.rfc-editor.org/rfc/rfc9110#section-10.2.3)
- [gRPC: Retry](https://grpc.io/docs/guides/retry/), retry policies and server pushback
- [KEP-2268: Non-graceful node shutdown](https://github.com/kubernetes/enhancements/tree/master/keps/sig-storage/2268-non-graceful-shutdown),
  a fence before a force-detach
- [Kubernetes API conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md#typical-status-properties),
  the shape of the surfaced condition
