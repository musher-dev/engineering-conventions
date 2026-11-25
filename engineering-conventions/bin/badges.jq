# The currency badges `conventions dependencies badges` writes (EC-0033,
# decision 0042), from what currency.jq reports. A badge is a self-contained
# SVG in the shields.io "flat" style, measured with a static table of Verdana
# 11px advance widths, so it renders the same with no network and no font.
#
#   input             what currency.jq writes
#   --arg part        "svg" for one badge, "readme" for the branch's README.md
#   --argjson at      with "svg", the index of the pin to render

def escape:
  gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;") | gsub("\""; "&quot;") | gsub("'"; "&apos;");

# Verdana's advance widths in its 2048-unit em, for printable ASCII from the
# space (32) to the tilde (126). Anything else, such as the arrow, is
# measured as a wide symbol.
def advances: [
  720, 823, 1067, 1876, 1303, 2220, 1495, 563, 913, 913, 1303, 1876, 745, 924, 745, 1303,
  1303, 1303, 1303, 1303, 1303, 1303, 1303, 1303, 1303, 1303, 913, 913, 1876, 1876, 1876, 1117,
  2048, 1401, 1405, 1430, 1577, 1294, 1178, 1587, 1540, 862, 920, 1424, 1141, 1726, 1532, 1612,
  1235, 1612, 1423, 1401, 1243, 1500, 1401, 2025, 1403, 1235, 1403, 913, 1303, 913, 1876, 1303,
  1303, 1229, 1276, 1067, 1276, 1220, 720, 1276, 1296, 562, 705, 1212, 562, 1992, 1296, 1243,
  1276, 1276, 874, 1067, 807, 1296, 1212, 1675, 1212, 1212, 1051, 1300, 913, 1300, 1876
];

def width:
  advances as $advances
  | [explode[] | if . >= 32 and . <= 126 then $advances[. - 32] else 1876 end]
  | add // 0
  | . * 11 / 2048
  | ceil;

def colour:
  {"current": "#4c1", "behind-minor": "#dfb317", "behind-major": "#fe7d37"}[.state] // "#9f9f9f";

# A behind pin names the newest release, so a newer major is never hidden
# behind a newer patch of the pinned one (decision 0043).
def message:
  if .state == "behind-minor" or .state == "behind-major" then "\(.pinned) → \(.latest)"
  else .pinned // "unknown" end;

def text($x; $length; $content):
  "<text aria-hidden=\"true\" x=\"\($x)\" y=\"150\" fill=\"#010101\" fill-opacity=\".3\" transform=\"scale(.1)\" textLength=\"\($length)\">\($content)</text>"
  + "<text x=\"\($x)\" y=\"140\" transform=\"scale(.1)\" fill=\"#fff\" textLength=\"\($length)\">\($content)</text>";

def svg:
  .label as $label
  | message as $message
  | ($label | width) as $label_text
  | ($message | width) as $message_text
  | ($label_text + 10) as $left
  | ($message_text + 10) as $right
  | ($left + $right) as $total
  | "\($label): \($message)" as $title
  | [
      "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\($total)\" height=\"20\" role=\"img\" aria-label=\"\($title | escape)\">",
      "<title>\($title | escape)</title>",
      "<linearGradient id=\"s\" x2=\"0\" y2=\"100%\"><stop offset=\"0\" stop-color=\"#bbb\" stop-opacity=\".1\"/><stop offset=\"1\" stop-opacity=\".1\"/></linearGradient>",
      "<clipPath id=\"r\"><rect width=\"\($total)\" height=\"20\" rx=\"3\" fill=\"#fff\"/></clipPath>",
      "<g clip-path=\"url(#r)\"><rect width=\"\($left)\" height=\"20\" fill=\"#555\"/><rect x=\"\($left)\" width=\"\($right)\" height=\"20\" fill=\"\(colour)\"/><rect width=\"\($total)\" height=\"20\" fill=\"url(#s)\"/></g>",
      "<g fill=\"#fff\" text-anchor=\"middle\" font-family=\"Verdana,Geneva,DejaVu Sans,sans-serif\" text-rendering=\"geometricPrecision\" font-size=\"110\">",
      text($left * 5; $label_text * 10; $label | escape),
      text($left * 10 + $right * 5; $message_text * 10; $message | escape),
      "</g></svg>"
    ]
  | join("");

def cell: if . == null then "–" else tostring | gsub("\\|"; "\\|") end;

def readme:
  [
    "# Dependency badges",
    "",
    "Written by `conventions dependencies badges`: each pin of another Musher release against its producer's",
    "published releases. `index.json` holds the same status as data.",
    "",
    "| Pin | Badge | Pinned | Latest | Latest in its major | State |",
    "| --- | --- | --- | --- | --- | --- |",
    (.[] | "| \(.label | cell) | ![\(.label | cell)](\(.badge)) | \(.pinned | cell) | \(.latest | cell) | \(.latestInMajor | cell) | \(.state) |")
  ]
  | join("\n");

if $part == "svg" then .[$at] | svg
elif $part == "readme" then readme
else error("unknown part \($part)") end
