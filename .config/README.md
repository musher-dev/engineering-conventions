# Tool configuration

Every file here configures one tool this repository runs. Where a file goes, how its caller names it and why nothing
is suppressed inline are set in [How this repository is organized](../docs/repository.md#where-configuration-goes);
this page only indexes what is here. A new file adds a row.

| File | Tool | Configures | Caller |
| --- | --- | --- | --- |
| `lefthook.yml` | lefthook | The pre-commit and commit-msg hooks | lefthook, which discovers it (`task hooks:install`) |
| `actions/actionlint.yaml` | actionlint | Workflow and composite-action lint | `task lint:actions` |
| `actions/zizmor.yml` | zizmor | Workflow security audit | `task lint:actions:security` |
| `commits/committed.toml` | committed | Commit message and pull request title rules: the types and scopes | the commit-msg hook, `Validate Pull Request / Title` |
| `markdown/markdownlint.jsonc` | markdownlint-cli2 | Markdown style | `task lint:md`, the pre-commit hook |
| `markdown/vale.ini` | Vale | Prose style and terminology | `task prose:lint`, the pre-commit hook |
| `mise/config.toml` | mise | The pinned version of every CLI | mise, which discovers it (`task tools:install`, `setup-tools`, post-create) |
| `mise/mise.lock` | mise | Each pinned tool's download URL and checksum per platform | `mise install --locked`; written by `task tools:lock` |
| `mise/locks/` | mise | The npm and pipx tools' dependency locks, referenced from `mise.lock` | `mise install --locked`; written by `task tools:lock` |
| `rego/regal.yaml` | Regal | Rego lint | `task checks:lint` |
| `security/gitleaks.toml` | gitleaks | Secret scanning | `task secrets:scan`, the pre-commit hook |
| `spelling/typos.toml` | typos | Spelling | `task lint:spelling`, the pre-commit hook |
| `toml/taplo.toml` | Taplo | TOML formatting | `task lint:toml`, the pre-commit hook, the editor |
| `yaml/yamllint.yaml` | yamllint | YAML lint | `task lint:yaml`, the pre-commit hook |
