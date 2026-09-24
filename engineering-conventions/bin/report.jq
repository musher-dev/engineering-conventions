# The report bin/conventions prints, from conftest's JSON results.
#
#   --arg format    json: the flat array of findings, the same shape
#                   `uv run conventions check --output json` prints;
#                   text: one block per requirement, then a summary;
#                   fails: whether a finding is at or above --fail-on.
#   --arg fail_on   error or warning.
#   --argjson colour  true to colour the text for a terminal.
#   --slurpfile index checks/data/index.json, for requirement titles.
#
# src/conventions_tools/run.py renders the same text, and
# tests/test_launcher.py holds the two to the same output.

def paint($code; $text): if $colour then "\u001b[\($code)m\($text)\u001b[0m" else $text end;

def plural($n; $word): "\($n) \($word)\(if $n == 1 then "" else "s" end)";

def rank: if .severity == "error" then 0 else 1 end;

def block:
  .[0] as $first
  | [
      "\(paint("1"; $first.id))  \(paint(if $first.severity == "error" then "31" else "33" end; $first.severity))  \(plural(length; "finding"))",
      ($index[0].conventions.index.requirements[$first.id].title // "" | select(. != "")),
      ($first.url | select(. != "") | paint("2"; .)),
      (sort_by([.path, .message]) | group_by(.path)[] | ("  " + .[0].path), (.[] | "    " + .message))
    ]
  | join("\n");

def summary:
  (map(select(.severity == "error")) | length) as $errors
  | "\(plural(length - $errors; "warning")), \(plural($errors; "error")) in \(plural(map(.id) | unique | length; "requirement"))."
    + if $fail_on == "error" and $errors == 0 then "\nWarnings do not fail the check; --fail-on warning makes them fail." else "" end;

[.[] | ((.failures // [])[], (.warnings // [])[]) | .metadata | {convention, id, message, path, severity, url}]
| sort_by([.path, .id, .message])
| if $format == "json" then .
  elif $format == "fails" then any(.[]; .severity == "error" or $fail_on == "warning")
  elif length == 0 then "No findings."
  else [(group_by(.id) | sort_by([(.[0] | rank), .[0].id])[] | block), summary] | join("\n\n")
  end
