# OpenTofu

These conventions govern a repository's OpenTofu roots: for now, the key each root keeps its state under in the
shared state bucket.

The governing rule, in one sentence:

> **A root's state key names its repository and its root, under `tfstate/`, and once used it is migrated, never
> edited.**

## Status

The convention is a **draft**, owned by this repository, and its requirement is `proposed` at severity `warning`. It
extends `musher-dev/foundation-bootstrap`'s rule "A state key mirrors its root directory" with the repository's name.

## Who is checked

The `infrastructure` profile selects the family, so a repository whose identity declaration says
`kind = "infrastructure"`, or whose conventions declaration names that profile, is checked. Only a repository whose
Taskfiles state a state key has anything to find.

## Reading order

| Convention | Requirements | Covers |
| --- | --- | --- |
| [EC-0029 OpenTofu state keys](state-keys.md) | TOFU-01 | The form of a root's state key, where it is stated, and how a frozen key is waived until it is migrated |

## Quick reference

| Root | State key |
| --- | --- |
| `terraform/<root>/` | `tfstate/<repository>/<root>/terraform.tfstate` |
| `terraform/<root>/`, split by environment | `tfstate/<repository>/<root>/<env>/terraform.tfstate` |
| A key already in use in another form | Unchanged until migrated; a waiver on TOFU-01 meanwhile |
