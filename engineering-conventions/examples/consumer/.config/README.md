# Tool configuration

Every file here configures one tool the repository runs (CONF-02, CONF-03).

| File | Tool | Configures | Caller |
| --- | --- | --- | --- |
| `commits/committed.toml` | committed | The commit types, scopes and message rules | `Validate Pull Request / Title` |
| `docker/hadolint.yaml` | hadolint | Dockerfile lint: the failure threshold and any rule turned off | `task lint`, the Validate workflow |
| `mise/config.toml` | mise | The pinned version of every CLI | mise, which discovers it |
| `mise/mise.lock` | mise | Each pinned tool's download URL and checksum | `mise install --locked` |
