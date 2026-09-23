# Consuming the conventions

How to check a repository against a release of these conventions. A consumer needs `conftest`, optionally `vale` and a
JSON Schema validator, and the release bundle. No Python is required.

## 1. Declare the conventions

Create `.repo/conventions.yaml` at the root of the repository:

```yaml
schema_version: 1
conventions:
  version: "0.1.0"
profile: base-repo
waivers: []
```

`conventions.version` is the release the repository is checked against. `profile` selects which requirements apply;
`base-repo` is the default for every repository. The full format, including repository-specific display forms and
waivers, is [EC-0001](../engineering-conventions/conventions/adoption/conventions-declaration.md).

A repository without a declaration is still checked, against `base-repo`, and gets an ADOPT-01 finding.

## 2. Download and verify the bundle

Each release attaches a tarball, a Vale package, a manifest and `SHA256SUMS`. Download them for the pinned version,
check the checksums, and verify that the assets were built by this repository's `Publish` workflow:

```sh
version=0.1.0
mkdir -p .conventions && cd .conventions

gh release download "v${version}" -R musher-dev/engineering-conventions
sha256sum -c SHA256SUMS

for asset in "engineering-conventions-${version}.tar.gz" MusherConventions.zip; do
  gh attestation verify "$asset" -R musher-dev/engineering-conventions \
    --signer-workflow musher-dev/engineering-conventions/.github/workflows/publish.yml \
    --source-ref "refs/tags/v${version}"
done

tar -xzf "engineering-conventions-${version}.tar.gz"
```

`sha256sum -c` catches a corrupted or truncated download. `gh attestation verify` checks the signed provenance: that
the file was built by this repository's `publish.yml` from the `v<version>` tag, not uploaded by hand or built from
another ref. Pinning `--source-ref` also rejects an older release's `MusherConventions.zip`, whose name carries no
version. Keep `.conventions/` out of
version control (add it to `.gitignore`), or commit the extracted tree if the repository prefers vendored files.

The extracted tree is `.conventions/engineering-conventions/`, with `checks/rego/`, `checks/data/index.json`,
`checks/data/release.json`, `checks/schemas/`, the conventions, and a worked example in `examples/consumer/`.

## 3. Run the structural checks

The Rego checks read the workflow, action, ruleset and declaration files together, plus an inventory of every file in
the repository (so they can see files that were not passed, such as a missing declaration). Run from the repository
root:

```sh
bundle=.conventions/engineering-conventions

git ls-files | jq -R . | jq -s '{conventions_inventory: {files: .}}' > "${RUNNER_TEMP:-/tmp}/inventory.json"

shopt -s nullglob globstar
files=(
  .github/workflows/*.yml .github/workflows/*.yaml
  .github/actions/**/action.yml .github/actions/**/action.yaml
  .github/rulesets/*.json
)
[ -f .repo/conventions.yaml ] && files+=(.repo/conventions.yaml)

conftest test --combine \
  -p "${bundle}/checks/rego" \
  -d "${bundle}/checks/data/index.json" \
  -d "${bundle}/checks/data/release.json" \
  "${files[@]}" "${RUNNER_TEMP:-/tmp}/inventory.json"
```

| Option | Why |
| --- | --- |
| `--combine` | Every file is evaluated in one query, so checks can relate files to each other (a ruleset to the jobs that emit its contexts) |
| `-p checks/rego` | The checks and the router |
| `-d checks/data/index.json` | Requirements, profiles and vocabulary, generated from the conventions |
| `-d checks/data/release.json` | The release version, so diagnostic links point at the immutable tag, and ADOPT-08 can confirm it is the version the declaration pins |

Findings at severity `error` are reported as failures and make `conftest` exit nonzero. Findings at `warning` are
reported as warnings; add `--fail-on-warn` to fail on them too. In the 0.x series every requirement is a warning.

The date used to decide whether a waiver has expired is the current time. To pin it (in a test, say), pass one more
data file: `-d runtime.json` containing `{"conventions": {"runtime": {"now": "2026-09-23T00:00:00Z"}}}`.

## 4. Validate the declaration

ADOPT-02 is a JSON Schema check. Any draft-07 validator works:

```sh
check-jsonschema \
  --schemafile .conventions/engineering-conventions/checks/schemas/conventions-declaration.schema.json \
  .repo/conventions.yaml
```

## 5. Check prose with Vale (optional)

The `MusherConventions` Vale style flags banned and discouraged terms in Markdown. Extract the verified package into
the repository's Vale styles directory and enable it:

```sh
mkdir -p .vale/styles
unzip -o .conventions/MusherConventions.zip -d .vale/styles
```

```ini
# .vale.ini
StylesPath = .vale/styles

[*.md]
BasedOnStyles = MusherConventions
```

```sh
vale .
```

Vale can also download the package itself (`Packages = https://github.com/musher-dev/engineering-conventions/releases/download/v0.1.0/MusherConventions.zip`
and `vale sync`), but that skips the checksum and attestation verification above.

## 6. Delegated checks

GHA-33 is delegated to actionlint and zizmor, which the bundle does not run. Run them in the repository's own
validation:

```sh
actionlint
zizmor --min-severity medium --persona regular .github/
```

## Reading a diagnostic

Each finding is one line:

```text
warning [GHA-07] .github/workflows/ci.yml — name "CI" should be "Validate Code": a workflow's name is its filename stem in Title Case. https://github.com/musher-dev/engineering-conventions/blob/v0.1.0/engineering-conventions/conventions/github-actions/workflow-files.md#gha-07
```

| Part | Meaning |
| --- | --- |
| `warning` | The effective severity under the repository's profile |
| `[GHA-07]` | The requirement ID; search for it, or waive it by this ID |
| `.github/workflows/ci.yml` | The file to change, relative to the repository root |
| message | What to change. It is enough to act on without the link |
| URL | The requirement's section in the pinned release, with the reasoning and examples |

`conftest` prints the line after its own prefix (`WARN - Combined - main - ...`). With `--output json`, each result
also carries `id`, `path`, `severity`, `url` and `convention` under `metadata`.

**A file that does not parse.** A workflow, action or ruleset that is not valid YAML or JSON cannot be checked at all.
The conventions runner reports it with the pseudo-ID `PARSE` and exits with status 2, whatever `--fail-on` says:

```text
error [PARSE] .github/workflows/validate.yml — <what the parser rejected, and where>
```

Fix the syntax and run again. Run with `conftest` directly, the same file makes `conftest` itself fail with a parse
error.

**Fix filenames before names.** A workflow's `name:` (GHA-07), the workflow prefix of a required-check job (GHA-12) and
an action's `name:` (GHA-22) are derived from a filename or directory. While GHA-01, GHA-05, GHA-20 or GHA-21 asks for a
file to be renamed, the derived-name checks wait, so a first run can show fewer name findings than the second. Rename
files first, then fix the names the next run reports.

**No rulesets, no required-check findings.** GHA-15, GHA-16 and GHA-32 compare the workflows with the required
status checks in `.github/rulesets/*.json`. A repository that does not commit its rulesets there gets no findings from
them. That is not a pass: export the rulesets from the repository settings and commit them to have them checked.

## Waivers

When a repository cannot meet a requirement yet, it records a waiver in its declaration rather than ignoring the
finding:

```yaml
waivers:
  - requirement: GHA-32
    paths:
      - .github/workflows/validate-docs.yml
    reason: >-
      The docs workflow keeps its paths filter until its jobs move into validate-repository.yml.
    tracking: https://github.com/your-org/your-repo/issues/1
    expires: 2026-12-31
```

A waiver needs a reason of at least 20 characters, a tracking issue URL and an expiry at most 180 days away. It
suppresses matching findings until the expiry date; after that, the findings return along with an ADOPT-03 finding.
A waiver that matches nothing is reported as stale (ADOPT-06). `ADOPT` requirements cannot be waived. The full rules
are in [EC-0001](../engineering-conventions/conventions/adoption/conventions-declaration.md).

## In CI

[`examples/consumer`](../engineering-conventions/examples/consumer/) is a complete, conforming consumer: a declaration,
a `Validate` workflow that runs the steps above as a `Conventions` job, a pull-request-title workflow, and a ruleset
that requires only the aggregate and the single-job title workflow.

## Upgrading

Change `conventions.version` in the declaration and the version you download, together, in one pull request; ADOPT-08
reports a declaration that names a different version from the bundle being run. Read the release notes: what each
kind of release can change is in [versioning](versioning.md).
