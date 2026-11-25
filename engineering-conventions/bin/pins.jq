# The pins `conventions dependencies` compares with their producers' releases
# (EC-0033, decision 0042): each [[dependencies]] entry of
# .repo/dependencies.toml, and the engineering-conventions release that
# .config/mise/config.toml pins. One object per pin:
#
#   {repository, output, pinned, prefix, label, badge}
#
# `prefix` is the pin's tag line: the vendored release record's tag with the
# version stripped (`schemas/v1.6.0` is `schemas/v`), else `<family>/v` for a
# `<family>-release` output, `musher-v` for the platform repository, and `v`
# for anything else.
#
#   --slurpfile dependencies   conftest parse of .repo/dependencies.toml, or {}
#   --slurpfile mise           conftest parse of .config/mise/config.toml, or {}
#   named arguments            "record:PATH" (--slurpfile, a vendored release.json)

def records:
  $ARGS.named
  | to_entries
  | map(select(.key | startswith("record:")) | {path: .key[7:], record: .value[0]});

def text: if type == "string" then . elif type == "number" then tostring else null end;

# The tag with the version cut from its end, or null when it does not end so.
def tag_line($tag; $version):
  if ($tag | type) == "string" and ($version | type) == "string" and $version != ""
    and ($tag | endswith($version)) and ($tag | length) > ($version | length)
  then $tag[0:(($tag | length) - ($version | length))]
  else null end;

def fallback_line($repository; $output):
  if $output | endswith("-release") then ($output | sub("-release$"; "")) + "/v"
  elif $repository == "platform" then "musher-v"
  else "v" end;

# The record vendored for one dependency, at <dir>/contracts/vendor/<repository>/<output>/release.json.
def record_of($repository; $output):
  ("contracts/vendor/\($repository)/\($output)/release.json") as $tail
  | [records[] | select(.path == $tail or (.path | endswith("/" + $tail))) | .record]
  | first // null;

# mise's three forms: "1.2.3", ["1.2.3", ...] and {version = "1.2.3"}.
def mise_version:
  if type == "string" then .
  elif type == "array" then (map(mise_version) | map(select(. != null)) | first // null)
  elif type == "object" then (.version | text)
  else null end;

(($dependencies[0].dependencies // []) | if type == "array" then . else [] end
  | map(select(type == "object" and (.repository | type) == "string" and (.output | type) == "string"))
  | map(
      . as $dependency
      | ($dependency.version | text) as $pinned
      | record_of($dependency.repository; $dependency.output) as $record
      | {
          repository: $dependency.repository,
          output: $dependency.output,
          pinned: $pinned,
          prefix: (tag_line($record.tag // null; $record.version // $pinned)
            // fallback_line($dependency.repository; $dependency.output)),
          label: "\($dependency.repository) \($dependency.output)",
          badge: "\($dependency.repository)-\($dependency.output).svg"
        }
    ))
+ ((($mise[0].tools // {})["github:musher-dev/engineering-conventions"] // null | mise_version) as $pinned
  | if $pinned == null then []
    else [{
      repository: "engineering-conventions",
      output: null,
      pinned: $pinned,
      prefix: "v",
      label: "engineering-conventions",
      badge: "engineering-conventions.svg"
    }]
    end)
