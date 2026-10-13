# The waivers `conventions waivers` lists: one tab-separated row per waiver
# in .repo/conventions.toml, in the order written, as requirement, expiry,
# how far away it is, tracking URL and the paths it covers. Nothing here is
# checked: `conventions check` holds the waivers to EC-0001.
#
#   input         conftest parse of .repo/conventions.toml
#   --arg today   the current date, YYYY-MM-DD (UTC)

def text: if type == "string" then . else tojson end;

def day: strptime("%Y-%m-%d") | mktime / 86400 | floor;

def plural($n; $unit): "\($n) \($unit)\(if $n == 1 then "" else "s" end)";

def remaining($expires):
  ($expires | try day catch null) as $last
  | if $last == null then "no valid expiry"
    else ($last - ($today | day)) as $days
    | if $days > 0 then "expires in \(plural($days; "day"))"
      elif $days == 0 then "expires today"
      else "expired \(plural(-$days; "day")) ago"
      end
    end;

def paths: if (.paths | type) == "array" and (.paths | length) > 0 then .paths | map(text) | join(", ") else "everywhere" end;

(if type == "object" then .waivers else null end) as $waivers
| if ($waivers | type) != "array" then empty else
    $waivers[]
    | select(type == "object")
    | [(.requirement // "?" | text), (.expires // "" | text), remaining(.expires // "" | text), (.tracking // "" | text), paths]
    | map(gsub("[\t\n]"; " "))
    | join("\t")
  end
