# The errors GitHub reports in a repository's CODEOWNERS (COMM-11), as the
# conftest results bin/report.jq renders, so `conventions codeowners` prints
# the same report, and the same --output json, as `conventions check`.
#
#   input             GET /repos/{owner}/{repo}/codeowners/errors: {errors: [...]},
#                     each with the line, the path and GitHub's message
#   --slurpfile index checks/data/index.json
#   --arg ref         the bundle's tag, or main in a checkout: the diagnostic
#                     URL points at the text that produced it (lib/findings.rego)

$index[0].conventions.index as $index
| $index.requirements["COMM-11"] as $requirement
| "\($index.repository)/blob/\($ref)/\($index.product_dir)/\($requirement.path)#\($requirement.anchor)" as $url

# GitHub's message is "Unknown owner on line 3: make sure @mona exists and has
# write access to the repository", then the line and a caret; the finding
# keeps the first line, with the line number where every finding puts it.
| def message:
    (.message // .kind // "an error" | tostring | split("\n")[0] | sub(" on line [0-9]+"; "")) as $text
    | "line \(.line // "?"): \($text[0:1] | ascii_downcase)\($text[1:])"
      + (if (.suggestion | type) == "string" and .suggestion != "" then "; \(.suggestion)" else "" end);

[
  (.errors // [])[]
  | {
      convention: $requirement.convention,
      enforced: true,
      id: "COMM-11",
      message: message,
      path: (.path // ".github/CODEOWNERS"),
      severity: $requirement.severity,
      url: $url
    }
]
| [{
    filename: "",
    namespace: "main",
    successes: 0,
    failures: [.[] | select(.severity == "error") | {msg: .message, metadata: .}],
    warnings: [.[] | select(.severity != "error") | {msg: .message, metadata: .}]
  }]
