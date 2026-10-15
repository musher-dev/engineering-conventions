# The files an environment schema's bindings are mirrored_in (ENVS-34), one
# per line, from the repository root. bin/conventions embeds their text so
# the check can compare each with the binding's local_default.
#
#   input        the schema as conftest parse reads it
#   --arg dir    the schema's directory, "." at the root
#
# Each path is resolved against the schema's directory with . and empty
# segments dropped; one that is absolute or has a .. segment is left out, as
# checks/rego/environment/env_stacks.rego and src/conventions_tools/run.py
# resolve them.

.bindings? // {}
| objects
| .[]
| objects
| .mirrored_in? // []
| arrays
| .[]
| strings
| select(startswith("/") | not)
| split("/")
| select(any(.[]; . == "..") | not)
| ($dir | split("/")) + .
| map(select(. != "" and . != "."))
| join("/")
