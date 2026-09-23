# Convention profiles

A convention profile is the set of requirements that applies to one kind of
repository, and the severity each is reported at. A consuming repository
names its profile in `.repo/conventions.yaml`; without a declaration the
checks use `base-repo`.

| Profile | For |
| --- | --- |
| [`base-repo`](base-repo.yml) | Every repository |

Profiles are validated against
[`profile.schema.json`](../checks/schemas/profile.schema.json).

## How a profile resolves

`conventions generate` resolves every profile into `checks/data/index.json`,
so the checks never evaluate inheritance themselves:

1. **Selection.** A requirement is selected when its family, its convention
   or its ID is listed under `include`.
2. **Inheritance.** `inherits` merges the selectors, excludes and severity
   overrides of every inherited profile with the profile's own. A cycle is
   an error.
3. **Exclusion.** A requirement listed under `exclude.requirements` anywhere
   in the chain is removed.
4. **Status.** Retired requirements never apply. Proposed requirements apply
   only when `include_proposed` is true; when a profile does not set it, it
   inherits `true` if any inherited profile resolves to `true`.
5. **Severity.** Each requirement is reported at its own severity unless
   `severity` raises it. A profile may raise `warning` to `error`, never
   lower a severity, and may only set one for a requirement it selects.

## Adding a profile

Add `profiles/<id>.yml` whose `id` matches the filename, usually inheriting
`base-repo` and raising or adding requirements. How a profile change is
released is the change-classification table in
[decision 0005](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0005-status-severity-and-versioning.md#change-classification).
