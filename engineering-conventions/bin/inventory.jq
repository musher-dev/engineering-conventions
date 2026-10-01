# The inventory bin/conventions passes to conftest beside the files it parses
# (decision 0015).
#
#   stdin (-Rn)       every repository path, one per line
#   --arg name        the repository's actual name, or empty when unknown
#   named arguments   "text:PATH" (--rawfile, the file's text),
#                     "size:PATH" (--arg, its size in bytes),
#                     "digest:PATH" (--arg, its SHA-256 in lower-case hex),
#                     "parsed:PATH" (--slurpfile, conftest parse --combine output),
#                     "unparsed:PATH" (--rawfile, conftest parse's error),
#                     "derived:PATH" (--slurpfile, what bin/env-contract.jq derives
#                     from an environment schema: {contract, example})
#
# src/conventions_tools/run.py writes the same document; tests/test_launcher.py
# holds the two to the same findings.

def named($prefix):
  $ARGS.named
  | to_entries
  | map(select(.key | startswith($prefix)) | {key: .key[($prefix | length):], value});

# conftest's error, on one line and without the parts every error repeats.
def reason:
  gsub("\\s+"; " ")
  | sub("^ ?Error: "; "")
  | sub("^parse configurations: "; "")
  | sub(" ?, path: .*$"; "")
  | sub(" $"; "");

{
  conventions_inventory: (
    {files: [inputs | select(. != "")]}
    + (if $name == "" then {} else {repository: {name: $name}} end)
    + {
      texts: (named("text:") | from_entries),
      sizes: (named("size:") | map(.value |= tonumber) | from_entries),
      digests: (named("digest:") | from_entries),
      derived: (named("derived:") | map(.value |= .[0]) | from_entries),
      parsed: (named("parsed:") | map({path: .key, contents: .value[0][0].contents})),
      unparsed: (named("unparsed:") | map({path: .key, reason: ("conftest cannot parse it: " + (.value | reason))}))
    }
  )
}
