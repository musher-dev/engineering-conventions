# Each pin's currency, for `conventions dependencies status` (EC-0033,
# decision 0042): the pin against the producer's published releases in the
# same tag line.
#
#   input            what pins.jq writes
#   named arguments  "tags:REPOSITORY" (--slurpfile, the tag of each published
#                    release that is neither a draft nor a prerelease); a
#                    producer whose releases could not be read has none
#
# One object per pin, in the order given:
#
#   {repository, output, pinned, latest, latestInMajor, state, label, badge}
#
# state is
#   current        no newer release in the line
#   behind-minor   a newer release exists in the pinned major
#   behind-major   the pin is the newest of its major, and a newer major exists
#   unknown        the releases could not be read, or the pin is not X.Y.Z

# A version as a sortable key, [major, minor, patch, 1 for a release or 0 for
# a prerelease], or null when it is not semantic.
def key:
  (ltrimstr("v")
  | capture("^(?<a>0|[1-9][0-9]*)\\.(?<b>0|[1-9][0-9]*)\\.(?<c>0|[1-9][0-9]*)(?<pre>-[0-9A-Za-z.-]+)?(\\+[0-9A-Za-z.-]+)?$")
  | [(.a | tonumber), (.b | tonumber), (.c | tonumber), (if .pre then 0 else 1 end)])
  // null;

def releases_of($repository):
  $ARGS.named["tags:" + $repository] as $tags
  | if $tags == null then null else ($tags[0] // []) end;

# The releases in a tag line, as [{version, key}], prereleases left out.
def line($tags; $prefix):
  [$tags[]
    | select(type == "string" and startswith($prefix))
    | .[($prefix | length):] as $version
    | ($version | key) as $key
    | select($key != null and $key[3] == 1)
    | {version: $version, key: $key}];

def newest: if length == 0 then null else max_by(.key) end;

map(
  . as $pin
  | releases_of($pin.repository) as $tags
  | (($pin.pinned // "") | key) as $pinned
  | (if $tags == null or $pinned == null then [] else line($tags; $pin.prefix) end) as $line
  | ($line | newest) as $latest
  | ($line | map(select(.key[0] == $pinned[0])) | newest) as $in_major
  | {
      repository: $pin.repository,
      output: $pin.output,
      pinned: $pin.pinned,
      latest: $latest.version,
      latestInMajor: $in_major.version,
      state: (
        if $tags == null or $pinned == null or $latest == null then "unknown"
        elif $in_major != null and $in_major.key > $pinned then "behind-minor"
        elif $latest.key[0] > $pinned[0] then "behind-major"
        else "current" end
      ),
      label: $pin.label,
      badge: $pin.badge
    }
)
