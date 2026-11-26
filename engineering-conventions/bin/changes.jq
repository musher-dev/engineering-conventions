# The change manifest `conventions release changes` writes (decision 0045):
# every pull request one release carries, with when its work began, when it
# opened and merged and whether the release's changelog section lists it,
# and the release pull request that cut the release, valid against
# checks/schemas/change-manifest.schema.json. The launcher asks GitHub with
# gh and hands each answer here as a named argument; every part runs with -n,
# and an argument a part does not read may be left out.
#
#   --arg part   which step to run:
#
#   package    the release-please package --arg tag releases, from
#              --slurpfile config (.github/release-please/config.json at the
#              tag): its path, changelog, tag prefix, version and
#              bootstrap-sha, one per line
#   previous   the highest earlier tag of the package, from --slurpfile refs
#              (the git/matching-refs pages), --arg prefix and --arg version:
#              its name, object type and object sha, one per line; nothing
#              for the package's first release
#   since      the earliest date among the commits of --slurpfile compare
#   range      every commit the release covers, oldest first, as a JSON array
#              of {sha, message, touches}: with --arg mode compare, those of
#              --slurpfile compare, and with --arg mode history, those of
#              --slurpfile history; touches is whether --slurpfile touching,
#              the history of --arg path, lists it, or the path is .
#   release    the number of the pull request that merged as --arg commit,
#              from --slurpfile associations (the ChangeCommit answers)
#   paged      each pull request the release carries whose commits fill more
#              than one page, from --slurpfile associations and range, --arg
#              path and --arg commit
#   manifest   the manifest itself, from --slurpfile range, associations,
#              pages (PullRequestCommits) and refreshes (ReleaseRefreshes),
#              --rawfile changelog, and --arg repository, path, version, tag,
#              previous ("" for none), commit, changelog_path and generator

def semver: type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$");

def key: split(".") | map(tonumber);

# The values of a JSON stream of arrays, such as gh's pages of a list.
def items: .[] | if type == "array" then .[] else empty end;

# One value per line, as the launcher reads them back.
def lines:
  .[]
  | tostring
  | if test("\n") then error("a value holds a line break, which the launcher cannot read back: \(tojson)") else . end;

# The tag release-please gives a package, less its version: the component and
# the separator, unless include-component-in-tag is false or there is no
# component, then the v, unless include-v-in-tag is false (decision 0017). A
# package without a component takes its package-name, less an npm scope, as
# release-please does.
def tag_prefix:
  ((.component // .["package-name"] // "") | tostring | sub("^@[^/]+/"; "")) as $component
  | (if .["include-component-in-tag"] == false or $component == "" then ""
     else $component + (.["tag-separator"] // "-") end)
  + (if .["include-v-in-tag"] == false then "" else "v" end);

# A release-please configuration's packages, each with its path, tag prefix,
# changelog and bootstrap-sha. The top-level options are every package's
# defaults; the changelog path is relative to the package's.
def packages:
  (.[0] // {}) as $config
  | ($config | del(.packages)) as $defaults
  | ($config.packages // {})
  | if type == "object" then to_entries else [] end
  | map(.key as $path | ($defaults + (.value // {})) as $options | {
      path: $path,
      prefix: ($options | tag_prefix),
      changelog: ((($options["changelog-path"] // "CHANGELOG.md") | ltrimstr("./")) as $file
        | if $path == "." then $file else "\($path | rtrimstr("/"))/\($file)" end),
      bootstrap: ($options["bootstrap-sha"] // "")
    });

# The Conventional Commits header of a squash commit: its type, and whether
# it is breaking, by a ! before the colon or a BREAKING CHANGE footer.
def conventional:
  split("\n") as $lines
  | ([$lines[0] | capture("^(?<type>[A-Za-z]+)(\\([^()\\n]*\\))?(?<bang>!?): ")] | first) as $header
  | {
      type: ($header.type // null),
      breaking: (($header.bang // "") == "!" or any($lines[1:][]; test("^BREAKING[ -]CHANGE: ")))
    };

# Who opened a pull request, by kind, never by login. The coding agents' Apps
# are the one list to extend when another agent opens pull requests: the
# feature agent, the hotfix agent and the read-only investigator.
def agents: ["musher-dagger", "musher-balto", "musher-larry"];
def dependency_bots: ["dependabot", "renovate"];

def author_kind:
  ((.login // "") | ascii_downcase | sub("\\[bot\\]$"; "")) as $login
  | if .__typename != "Bot" then "human"
    elif $login | IN(agents[]) then "agent"
    elif $login | IN(dependency_bots[]) then "dependency-bot"
    else "automation" end;

# A changelog section's entries: each bullet with the lines that continue it,
# and whether it stands under the ⚠ BREAKING CHANGES heading.
def entries:
  reduce .[] as $line ({breaking: false, open: false, entries: []};
    if $line | test("^#{1,6} ") then .breaking = ($line | test("BREAKING CHANGE")) | .open = false
    elif $line | test("^ {0,3}[*+-] ") then .entries += [{breaking: .breaking, text: $line}] | .open = true
    elif .open and ($line | test("\\S")) then .entries[(.entries | length) - 1].text += " " + $line
    else .open = false end)
  | .entries;

# The pull requests a section's entries list. An entry's commit links name
# squash commits, and a pull request is listed when one is its merge commit.
# An entry whose links resolve to none falls back to its last #N that is a
# pull request in the release, since a title can name an issue before the
# pull request. A breaking-change note without a commit link only repeats an
# entry the section lists with one, so it is skipped.
def listed($numbers; $by_merge):
  [entries[]
    | [.text | match("/commit/([0-9a-f]{40})(?![0-9a-f])"; "g") | .captures[0].string] as $links
    | [$links[] | $by_merge[.] // empty] as $linked
    | if ($linked | length) > 0 then $linked[]
      elif .breaking and ($links | length) == 0 then empty
      else [.text | match("#([0-9]+)"; "g") | .captures[0].string | select($numbers[.])] | last // empty | tonumber
      end]
  | unique;

$ARGS.named as $in
| ($in.tag // "") as $tag
| ($in.version // "") as $version
| ($in.commit // "") as $commit
| ($in.associations // []) as $associations

# Every merged pull request the ChangeCommit answers name, once each: a pull
# request whose merge commit is the asked-about commit is the change that
# commit brought.
| def merged:
    [$associations[]
      | .data.repository.object // empty
      | .oid as $oid
      | .associatedPullRequests.nodes[]?
      | select(.mergeCommit.oid == $oid)]
    | group_by(.number)
    | map(.[0]);

  def release_pull_request:
    merged
    | map(select(.mergeCommit.oid == $commit))
    | first
    // error("\($commit), the commit \($tag) names, is no pull request's merge commit: a release-please release is cut by merging its release pull request");

  # The changelog section that names the version: from its heading to the
  # next heading of the same level or above.
  def section:
    split("\n") as $lines
    | ($version | gsub("\\."; "\\.")) as $pattern
    | ($lines | map(test("^#{1,6} +\\[?v?" + $pattern + "\\]?([ (]|$)")) | index(true)) as $at
    | if $at == null then error("\($in.changelog_path) at \($tag) has no section for \($version)") else . end
    | ($lines[$at] | capture("^(?<hashes>#+)").hashes | length) as $level
    | $lines[($at + 1):]
    | (map(test("^#{1,\($level)} ")) | index(true)) as $end
    | if $end == null then . else .[:$end] end;

  def package:
    ($in.config // [] | packages) as $packages
    | [$packages[] | .prefix as $prefix | select($tag | startswith($prefix)) | . + {version: $tag[($prefix | length):]}
        | select(.version | semver)]
    | if length == 1 then .[0] | [.path, .changelog, .prefix, .version, .bootstrap] | lines
      elif length == 0 then
        error("no package in .github/release-please/config.json at \($tag) is released as \($tag): "
          + ([$packages[] | "\(.path) is released as \(.prefix)X.Y.Z"] | join(", ")
             | if . == "" then "it has no packages" else . end))
      else error("packages \(map(.path) | join(" and ")) are each released as \($tag)") end;

  def previous:
    ($in.prefix // "") as $prefix
    | [$in.refs // [] | items
        | select((.ref | type) == "string" and (.ref | startswith("refs/tags/" + $prefix)))
        | {tag: .ref[10:], version: .ref[(10 + ($prefix | length)):], type: .object.type, sha: .object.sha}
        | select((.version | semver) and (.version | key) < ($version | key))]
    | max_by(.version | key) // empty
    | [.tag, .type, .sha]
    | lines;

  def since:
    [$in.compare // [] | .[] | .commits[]? | .commit.author.date, .commit.committer.date | strings] | min // empty;

  # Every commit the release covers, oldest first, and whether it changes the
  # package's path itself.
  def range:
    ([$in.touching // [] | items | {key: .sha, value: true}] | from_entries) as $touches
    | if $in.mode == "history" then [$in.history // [] | items] | reverse
      else [$in.compare // [] | .[] | .commits[]?] end
    | map({sha, message: (.commit.message // ""), touches: ($in.path == "." or $touches[.sha] == true)});

  # The pull requests the release carries: each whose merge commit the
  # release covers and the package owns, as release-please decides it. A
  # commit a pull request merged as is judged by the pull request's files,
  # unless GitHub lists more than a page of them; any other commit, by its
  # own. It belongs to the package when one of those files is under the
  # package's path, or when there are none, since release-please counts an
  # empty change in every package. A pull request whose changes reached the
  # branch before it merged changes no file, and neither does its squash
  # commit, which its own files would leave out.
  def carried:
    ($in.range[0] // [] | map({key: .sha, value: .}) | from_entries) as $commits
    | merged
    | map(select(.mergeCommit.oid != $commit and $commits[.mergeCommit.oid] != null)
        | select(
            $in.path == "."
            or (if .files.pageInfo.hasNextPage == false
                then (.files.nodes // []) as $files
                  | ($files | length) == 0 or any($files[]; .path | startswith($in.path + "/"))
                else $commits[.mergeCommit.oid].touches end)
          ));

  def manifest:
    ($in.range[0] // []) as $range
    | ($range | map({key: .sha, value: .message}) | from_entries) as $messages
    | release_pull_request as $release
    | ([$in.refreshes // [] | .[] | .data.repository.pullRequest.timelineItems.nodes[]? | .createdAt? // empty]
        | sort) as $refreshed
    | ([$in.pages // [] | .[] | .data.repository.pullRequest // empty]
        | group_by(.number)
        | map({key: (.[0].number | tostring), value: {totalCount: .[0].commits.totalCount, nodes: [.[].commits.nodes[]]}})
        | from_entries) as $paged
    | carried as $changes
    | ($changes | map({key: (.number | tostring), value: true}) | from_entries) as $numbers
    | ($changes | map({key: .mergeCommit.oid, value: .number}) | from_entries) as $by_merge
    | ($in.changelog // "" | section | listed($numbers; $by_merge)) as $listed
    # The release pull request first carried a change when it opened, or was
    # refreshed, after the change merged. A change it was never refreshed
    # after, such as an unlisted one that rewrote no notes, counts from its
    # own merge.
    | def opened_after($merged):
        ([$release.createdAt] + $refreshed | map(select(. >= $merged)) | min)
        // ([$release.createdAt, $merged] | max);
    {
      schema_version: 1,
      repository: $in.repository,
      path: $in.path,
      version: $version,
      tag: $tag,
      previous_tag: (if ($in.previous // "") == "" then null else $in.previous end),
      commit: $commit,
      generated_at: (now | floor | todate),
      generator: $in.generator,
      release_pull_request: {
        number: $release.number,
        url: $release.url,
        title: $release.title,
        created_at: $release.createdAt,
        merged_at: $release.mergedAt,
        merge_commit: $release.mergeCommit.oid,
        refreshed_at: $refreshed
      },
      changes: (
        [$changes[]
          | . as $pull
          | ($messages[$pull.mergeCommit.oid] | conventional) as $header
          | ($paged[$pull.number | tostring] // $pull.commits) as $commits
          | ($commits.nodes | map(.commit) | sort_by(.authoredDate, .oid) | first
              // error("pull request #\($pull.number) lists no commits")) as $first
          | {
              listed: ($pull.number | IN($listed[])),
              pull_request: {
                number: $pull.number,
                url: $pull.url,
                title: $pull.title,
                type: $header.type,
                breaking: $header.breaking,
                author_kind: ($pull.author | author_kind),
                created_at: $pull.createdAt,
                merged_at: $pull.mergedAt,
                merge_commit: $pull.mergeCommit.oid
              },
              first_commit: {
                sha: $first.oid,
                authored_at: $first.authoredDate,
                at: ([$first.authoredDate, $pull.createdAt] | min),
                rewritten: ($first.authoredDate > $pull.createdAt),
                # GitHub lists at most 250 of a pull request's commits.
                truncated: ($commits.totalCount > ($commits.nodes | length))
              },
              release_pull_request_opened_at: opened_after($pull.mergedAt)
            }]
        # Newest merge first; the lower number first within a second.
        | sort_by(.pull_request.merged_at, 0 - .pull_request.number)
        | reverse
      )
    };

  if $part == "package" then package
  elif $part == "previous" then previous
  elif $part == "since" then since
  elif $part == "range" then range
  elif $part == "release" then release_pull_request | .number
  elif $part == "paged" then carried | map(select(.commits.pageInfo.hasNextPage) | .number) | .[]
  elif $part == "manifest" then manifest
  else error("no part \($part)") end
