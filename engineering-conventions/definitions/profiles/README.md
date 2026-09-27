# Convention profiles

A convention profile is the set of requirements that applies to one kind of
repository, and the severity each is reported at. The checks use, in order:

1. the profile a repository names in `.repo/conventions.toml`
   ([EC-0001](../conventions/adoption/conventions-declaration.md)), an
   override most repositories leave out;
2. the profile named for the `kind` in `.repo/repository.toml`
   ([EC-0009](../conventions/repository/identity-declaration.md));
3. `base-repo`.

A name the release does not define is skipped, so a typo falls through to the
next choice rather than switching every check off.

| Profile | For |
| --- | --- |
| [`base-repo`](base-repo.yml) | Every repository |
| [`service`](service.yml) | `kind = "service"` |
| [`website`](website.yml) | `kind = "website"` |
| [`library`](library.yml) | `kind = "library"` |
| [`tool`](tool.yml) | `kind = "tool"` |
| [`infrastructure`](infrastructure.yml) | `kind = "infrastructure"` |
| [`specification`](specification.yml) | `kind = "specification"` |
| [`content`](content.yml) | `kind = "content"` |
| [`documentation`](documentation.yml) | `kind = "documentation"` |
| [`template`](template.yml) | `kind = "template"` |

Every registered kind has a profile of the same name, and `task invariants`
fails when one is missing. Each kind's profile inherits `base-repo` and, until
requirements specific to the kind exist, applies exactly what it does.

Profiles are validated against
[`profile.schema.json`](../../checks/schemas/profile.schema.json).

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

Add `definitions/profiles/<id>.yml` whose `id` matches the filename, usually
inheriting `base-repo` and raising or adding requirements. A new repository
kind is a term tagged `repository.kind` in `definitions/terminology/global.yml`
together with a profile of the same name. How a profile change is
released is the change-classification table in
[decision 0005](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0005-status-severity-and-versioning.md#change-classification).
