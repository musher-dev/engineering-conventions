# Example staged consumer

The [example consumer](../consumer/README.md) part-way through adopting the conventions. Its build enforces four
families and reports the rest without failing, and it holds one waiver. Copy the declaration from it when your
repository adopts a release one family at a time
([decision 0019](../../../docs/decisions/0019-staged-adoption.md)).

It differs from the example consumer in three files:

| File | Shows |
| --- | --- |
| [`.repo/conventions.toml`](.repo/conventions.toml) | A staged adoption: `[adoption]` enforces `ADOPT`, `REPO`, `OUT` and `GHA` until a date, with a tracking issue (ADOPT-10, ADOPT-11). And a waiver of one requirement on one path, in an enforced family ([EC-0001](../../definitions/conventions/adoption/conventions-declaration.md)) |
| [`Taskfile.yml`](Taskfile.yml) | The `dev` task has no `desc`, a TASK-05 finding. TASK is not enforced yet, so it is reported as `not enforced` and does not fail the build |
| [`.github/workflows/validate.yml`](.github/workflows/validate.yml) | The `workflows` job runs on `ubuntu-latest`, a GHA-39 finding the waiver covers |

## Checking the example

From a checkout of this repository:

```sh
engineering-conventions/bin/conventions check -C engineering-conventions/examples/staged-consumer --fail-on warning
```

It reports one finding, `TASK-05  warning (not enforced)`, and exits 0. Once `TASK` is added to `enforce`, the same
command fails until the `dev` task has a `desc`. The adoption and the waiver expire on 2027-03-20; after that date
every family is enforced again, and the command fails.
