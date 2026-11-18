# Source code

These conventions govern what source code does, wherever it runs: code that reports whether something is working,
code that retries, waits or overrides a hold until it is, and code that receives input from a party the platform does
not trust. They cover how a resource's health, readiness and status are derived and shown, how every retry and wait is
bounded and ends in a state a reader can see, and where a control signal is stripped.

The governing rule, in one sentence:

> **Derive status from current facts in one place, give every retry a budget and every wait a deadline that end in a
> surfaced state, override a hold only behind a fence, and strip control signals where untrusted input enters.**

The topic is named for its surface, the source files, like every other topic; its families are named for the concern
each holds ([decision 0044](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0044-source-code-behaviour-is-a-topic-of-its-own.md)).

## Status

The three conventions are **drafts**, owned by this repository, and every requirement is `proposed` at severity
`warning`. The shape of a condition is the Kubernetes API conventions'; EC-0045 points at them rather than restating
them. All but STATUS-06 are judged in review: code is written in too many forms for a portable check. A repository
may hold itself to a stricter local check, under a prefix of its own, that cites the requirement it implements.

## Who is checked

The `base-repo` profile selects all three families, so every kind of repository is checked: a library retries and
honours `Retry-After` as much as a service does, and a command-line tool shows a derived status. Only STATUS-06 has a
machine check, and it reports only a pyright or basedpyright configuration that turns the match exhaustiveness check
off; the rest apply wherever a repository has code that reports status, retries, waits or receives untrusted input,
and a reviewer holds them.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0045 Derived status](derived-status.md) | STATUS-01 – STATUS-08 | One owning derivation, facts stored and status derived, conditions, clients that do not re-aggregate, exhaustive state mapping, one snapshot per response, observations that explain but never decide |
| [EC-0046 Bounded retries and waits](bounded-retries.md) | RETRY-01 – RETRY-05 | Budgets counted by failure class with a healthy reset, one jittered backoff at one layer, surfaced exhaustion, nested deadlines from measured latency, `Retry-After`, fences before overriding a hold |
| [EC-0047 Trust boundaries](trust-boundaries.md) | TRUST-01 | Control signals stripped at the first hop that receives untrusted input |

Related requirements in other families:

- pyright and basedpyright check types at `strict` or above (CONF-18), which turns on the exhaustiveness check
  STATUS-06 keeps on.

## Quick reference

| Write | Not |
| --- | --- |
| One `derive_status(facts)` every surface calls | A health check per endpoint, dashboard and alert |
| Facts with `observed_at`; status computed on read | A `health_message` column |
| Conditions with `type`, `status`, `reason`, `message`, `lastTransitionTime`, `observedGeneration` | A lone `phase: Healthy` |
| `Unknown` when the facts are missing or unrecognised | A default branch that returns healthy |
| `match` plus `assert_never`, `never`, or a Rust `match` with no wildcard | `else: return True`, `_ => Healthy` |
| Counts and conditions from one snapshot, with `observedAt` | A client that counts replicas from another endpoint |
| A host's report as a fenced, renewed observation filling `reason` | An agent's event that marks a volume detached |
| Failures counted per class, reset after ten healthy minutes | A count keyed on the error message |
| One full-jitter backoff, at one layer | A backoff, a cooldown, and a retrying client inside a retrying job |
| `RetriesExhausted` as a condition and a counter; stop only for a cause in the inputs | A log line that says "giving up" |
| An attempt timeout from p99.9, inside the caller's remaining deadline | A call with the library's default of no timeout |
| The next attempt no sooner than `Retry-After`, scheduled if too far to sleep | A capped sleep that retries early |
| A force-detach behind a fence | A force-detach after five silent minutes |
| Control headers stripped and set again at the edge | A handler that trusts a header any client can send |
