# Tool configuration

| File | Tool | Configures | Caller |
| --- | --- | --- | --- |
| `commits/committed.toml` | committed | Commit message and pull request title rules | `Validate Pull Request / Title` |
| `sql/sqlfluff.cfg` | SQLFluff | SQL lint | `task lint` |
| `markdown/lychee.toml` | lychee | Link checking | `task lint` |
| `prose/vale.ini` | Vale | Prose style | `task lint` |
