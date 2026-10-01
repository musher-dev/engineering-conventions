# The OpenAPI documents `conventions openapi` lints when it is given none: the
# files each `format = "openapi"` interface in .repo/outputs.toml covers
# (EC-0037). A definition is matched as lib/contracts.rego matches it: a
# directory with a trailing /, a doublestar glob, a file, or else a directory.
# Only JSON and YAML files are documents, so a README beside them is skipped.
#
#   stdin (-Rn)       every repository path, one per line
#   --slurpfile outputs   conftest parse of .repo/outputs.toml

# A doublestar glob as an anchored regex: **/ spans any depth (none
# included), * and ? stay within one segment, {a,b} is either.
def glob_regex:
  gsub("(?<c>[.+^$()|\\\\])"; "\\\(.c)")
  | gsub("\\*\\*/"; "\u0001")
  | gsub("\\*\\*"; "\u0002")
  | gsub("\\*"; "[^/]*")
  | gsub("\\?"; "[^/]")
  | gsub("\u0001"; "(.*/)?")
  | gsub("\u0002"; ".*")
  | gsub("\\{(?<alts>[^}]*)\\}"; "(" + (.alts | gsub(","; "|")) + ")")
  | "^" + . + "$";

def covers($files):
  . as $pattern
  | if endswith("/") then $files[] | select(startswith($pattern))
    elif test("[*?\\[{]") then ($pattern | glob_regex) as $regex | $files[] | select(test($regex))
    elif any($files[]; . == $pattern) then $pattern
    else $files[] | select(startswith($pattern + "/"))
    end;

[inputs | select(. != "")] as $files
| [
    ($outputs[0].interfaces // [])[]
    | select(type == "object" and .format == "openapi")
    | (.definitions // [])[]
    | select(type == "string")
    | covers($files)
    | select(test("\\.(json|ya?ml)$"; "i"))
  ]
| unique[]
