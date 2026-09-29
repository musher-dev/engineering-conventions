# The report bin/conventions prints, from conftest's JSON results.
#
#   --arg format    json: the flat array of findings, the same shape
#                   `uv run conventions check --output json` prints;
#                   text: one block per requirement, then a summary;
#                   fails: whether an enforced finding is at or above
#                   --fail-on; a finding in a family a staged adoption
#                   does not enforce yet never fails (lib/enforcement.rego).
#   --arg fail_on   error or warning.
#   --argjson colour  true to colour the text for a terminal.
#   --slurpfile index checks/data/index.json, for requirement titles.
#   --slurpfile inventory the inventory bin/inventory.jq wrote, whose
#                   unparsed files are reported as PARSE errors.
#
# src/conventions_tools/run.py renders the same text, and
# tests/test_launcher.py holds the two to the same output.

def paint($code; $text): if $colour then "\u001b[\($code)m\($text)\u001b[0m" else $text end;

def plural($n; $word): "\($n) \($word)\(if $n == 1 then "" else "s" end)";

def rank: if .severity == "error" then 0 else 1 end;

def unenforced: .enforced == false;

def block:
  .[0] as $first
  | [
      "\(paint("1"; $first.id))  \(paint(if $first.severity == "error" then "31" else "33" end; $first.severity))\(if $first | unenforced then " (not enforced)" else "" end)  \(plural(length; "finding"))",
      (if $first.id == "PARSE" then "A file that does not parse cannot be checked"
       else $index[0].conventions.index.requirements[$first.id].title // "" end | select(. != "")),
      ($first.url | select(. != "") | paint("2"; .)),
      (sort_by([.path, .message]) | group_by(.path)[] | ("  " + .[0].path), (.[] | "    " + .message))
    ]
  | join("\n");

def summary:
  (map(select(.severity == "error")) | length) as $errors
  | "\(plural(length - $errors; "warning")), \(plural($errors; "error")) in \(plural(map(.id) | unique | length; "requirement"))."
    + if $fail_on == "error" and $errors == 0 then "\nWarnings do not fail the check; --fail-on warning makes them fail." else "" end
    + (map(select(unenforced)) as $rest
      | if ($rest | length) == 0 then ""
        else "\n\($rest | length) of them \(if ($rest | length) == 1 then "is" else "are" end) in families this repository does not enforce yet (\($rest | map(.id | split("-")[0]) | unique | join(", "))), so they do not fail the check."
        end);

[.[] | ((.failures // [])[], (.warnings // [])[]) | .metadata | {convention, enforced: (.enforced != false), id, message, path, severity, url}]
+ [$inventory[0].conventions_inventory.unparsed[]? | {convention: "", enforced: true, id: "PARSE", message: .reason, path, severity: "error", url: ""}]
| sort_by([.path, .id, .message])
| if $format == "json" then .
  elif $format == "fails" then any(.[]; (unenforced | not) and (.severity == "error" or $fail_on == "warning"))
  elif length == 0 then "No findings."
  else [(group_by(.id) | sort_by([(.[0] | rank), .[0].id])[] | block), summary] | join("\n\n")
  end
