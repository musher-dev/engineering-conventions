# Tool configuration

| File | Tool | Configures | Caller |
| --- | --- | --- | --- |
| `commits/committed.toml` | committed | Commit message and pull request title rules | `Validate Pull Request / Title` |
| `prose/vale.ini` | Vale | Prose style | `task lint` |
| `actions/zizmor.yml` | zizmor | Workflow security audit | `task lint` |
| `docker/hadolint.yaml` | hadolint | Dockerfile lint | `task lint` |
| `spelling/_typos.toml` | typos | Spelling | `task lint` |
