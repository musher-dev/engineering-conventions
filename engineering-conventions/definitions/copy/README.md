# Copy

The source of the copy rules ([EC-0038](../conventions/copy/public-copy.md)). One file, so the rules a consumer's Vale
runs, the convention that explains them and the checks that read a consumer's config cannot disagree.

| File | What it holds |
| --- | --- |
| [`style.yml`](style.yml) | The `MusherCopy` rule, and the Vale packages the `MusherProse` package adopts, with their toggles |

It is validated against [`copy-style.schema.json`](../../checks/schemas/copy-style.schema.json). `task generate`
writes from it:

| Generated | Read by |
| --- | --- |
| `checks/vale/MusherCopy/<name>.yml` | Vale: one rule per entry in `rules`, its `link` the requirement whose `validation.style` names it |
| `checks/vale/MusherProse.ini` | Vale: the `.vale.ini` of the `MusherProse` package, with the adopted packages' URLs and toggles |
| The `copy` block of `checks/data/index.json` | The COPY checks: the package's name, the styles a config applies, the template formats |

## Adding a rule

A rule belongs here only if it holds for every site's copy, whoever owns the site. Voice and vocabulary, such as
banned marketing words, claims, tone or sentence length, belong to the site's owner, in a Vale style in its own
repository ([decision 0024](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0024-copy-rules-adopt-vale-packages.md)).

Check the adopted packages first: `proselint`, `write-good`, and the Microsoft and Google styles. A rule one of them
ships is adopted with a toggle, not written again. A new rule needs a requirement in
[EC-0038](../conventions/copy/public-copy.md) with `engine: vale` and `style: MusherCopy.<name>`, and its `level`
matches that requirement's severity; `task generate` fails without the requirement. A word added to `Placeholders` is
a new finding for a consumer, so it is classified by
[decision 0005](https://github.com/musher-dev/engineering-conventions/blob/main/docs/decisions/0005-status-severity-and-versioning.md#change-classification).

## Moving an adopted package

Change its `version` and `package` URL together, run `task generate`, and lint a site's copy with the new release
before merging: a package's new release can add rules.
