---
id: EC-0047
title: Trust boundaries
summary: >-
  A control signal, a header or field a component acts on rather than
  passes through, is stripped or ignored where untrusted input enters, at
  the hop closest to the untrusted party, and set again there from what
  that hop verified.
status: draft
topic: source-code
applies_to:
  paths:
    - "**/*.py"
    - "**/*.ts"
    - "**/*.tsx"
    - "**/*.rs"
    - "**/*.go"
created: 2026-11-18
owners:
  - "@justinmerrell"
authority: self
migration: authoritative
references:
  - title: "CWE-501: Trust Boundary Violation"
    url: https://cwe.mitre.org/data/definitions/501.html
  - title: "Envoy: HTTP header sanitizing"
    url: https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/header_sanitizing
requirements:
  - id: TRUST-01
    title: A control signal is stripped or ignored where untrusted input enters, at the hop closest to the untrusted party
    status: proposed
    severity: warning
    since: 0.9.6
    validation:
      engine: review
---

# Trust boundaries

A service behind a gateway trusts the identity header the gateway sets, and a worker trusts the priority field the
scheduler wrote. Both are right to, until a request from outside arrives carrying the same header or field, set by
whoever sent it, and some path forwards it unchanged. The component that acts on it cannot tell the two apart. This
convention puts the decision about what may cross a trust boundary at the boundary itself.

## Scope

This convention covers code and configuration that receive input from a party the platform does not control (an
edge proxy, an API gateway, a request handler, a webhook receiver, a consumer of a queue fed from outside) and pass it
on to components that act on it. Which parties are trusted is each system's own decision; this convention only says
where the line is enforced.

## Status and authority

This convention is a **draft** owned by this repository (`authority: self`). Its requirement is `proposed` at severity
`warning`, like every requirement in the 0.x series, and is judged in review: a boundary is drawn in proxy
configuration, middleware and handlers alike, too many forms for a portable check.

## Requirements

### TRUST-01

**A control signal is stripped or ignored where untrusted input enters, at the hop closest to the untrusted party.**

A control signal is a header or field a component acts on rather than passes through: an identity or tenant a gateway
asserts, a priority, a routing or debug flag, a deadline, a retry hint. Inside the platform a component trusts it
because another component set it; when an outside party can set it too, that party is making the platform's decision
for it ([CWE-501](https://cwe.mitre.org/data/definitions/501.html)). Remove or overwrite every control signal at the
first hop that receives untrusted input, and set it again there from what that hop verified. Do it at that hop rather
than in the component that acts on the signal: every hop in between would otherwise trust and forward it, and a new
path that reaches a second component skips the one check that existed. A component that cannot strip a field it
receives ignores it and reads the verified value from where the boundary put it.

**Correct:**

```python
CONTROL_HEADERS = {"x-authenticated-user", "x-tenant-id", "x-priority"}


def from_client(request: Request) -> dict[str, str]:
    """The edge: the first hop that sees a client's request."""
    headers = {k: v for k, v in request.headers.items() if k.lower() not in CONTROL_HEADERS}
    headers["x-authenticated-user"] = verify_session(request).user_id
    return headers
```

**Incorrect:**

```python
def handler(request: Request) -> Response:
    """Three hops in: the edge forwarded every header it was sent."""
    user = request.headers["x-authenticated-user"]  # set by whoever sent the request
    return load_account(user)
```

Checked by: review · Severity: warning · Since: 0.9.6

## Rationale

A trust boundary violation is rarely one mistake: each hop forwards what it was given because the hop before it
should have checked, and the component that acts on the signal assumes the same. Enforcing the line at the first hop
that sees untrusted input makes one place responsible, and every path through the system inherits it. Proxies that
own an edge, such as Envoy, sanitize their own internal headers there for the same reason.

## References

- [CWE-501: Trust Boundary Violation](https://cwe.mitre.org/data/definitions/501.html)
- [Envoy: HTTP header sanitizing](https://www.envoyproxy.io/docs/envoy/latest/configuration/http/http_conn_man/header_sanitizing),
  internal headers removed from requests at the edge
