# Tool configuration

| File | Tool | Configures | Caller |
| --- | --- | --- | --- |
| `commits/committed.toml` | committed | Commit message and pull request title rules | `Validate Pull Request / Title` |
| `python/scripts-pyright.json` | Pyright | Type checking of the scripts | `Validate Scripts`, by the paths filter `.config/python/scripts-*` |
| `python/scripts-ruff.toml` | Ruff | Linting of the scripts | `Validate Scripts`, by the paths filter `.config/python/scripts-*` |
