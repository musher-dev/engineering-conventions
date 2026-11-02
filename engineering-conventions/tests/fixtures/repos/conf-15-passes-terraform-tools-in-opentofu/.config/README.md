# Tool configuration

| File | Tool | Configures | Caller |
| --- | --- | --- | --- |
| `commits/committed.toml` | committed | Commit message and pull request title rules | `Validate Pull Request / Title` |
| `opentofu/tflint.hcl` | tflint | Terraform lint | `task lint` |
| `opentofu/terraform-docs.yml` | terraform-docs | Module documentation | `task lint` |
