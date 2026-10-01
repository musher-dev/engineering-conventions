# Copy

The source of the copy rules ([EC-0038](../conventions/copy/public-copy.md)). One file, so the rules a consumer's Vale
runs, the convention that explains them and the checks that read a consumer's config cannot disagree.

| File | What it holds |
| --- | --- |
| [`style.yml`](style.yml) | The `MusherCopy` rules, and the Vale packages the `MusherProse` package adopts, with their toggles |

It is validated against [`copy-style.schema.json`](../../checks/schemas/copy-style.schema.json). `task generate`
writes from it:

| Generated | Read by |
| --- | --- |
| `checks/vale/MusherCopy/<name>.yml` | Vale: one rule per entry in `rules`, its `link` the requirement whose `validation.style` names it |
| `checks/vale/MusherProse.ini` | Vale: the `.vale.ini` of the `MusherProse` package, with the adopted packages' URLs and toggles |
| The `copy` block of `checks/data/index.json` | The COPY checks: the package's name, the styles a config applies, the rules it may not turn off |

## Adding a rule

Check the adopted packages first: `proselint`, `write-good`, and the Microsoft and Google styles. A rule one of them
ships is adopted with a toggle, not written again. A new rule needs a requirement in
[EC-0038](../conventions/copy/public-copy.md) with `engine: vale` and `style: MusherCopy.<name>`; `task generate`
fails without one. A word added to `Banned` or `Placeholders` can fail a consumer's build, so it is classified like a
banned prose alias in [decision 0005](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0005-status-severity-and-versioning.md#change-classification).

## Moving an adopted package

Change its `version` and `package` URL together, run `task generate`, and lint a site's copy with the new release
before merging: a package's new release can add rules.
