# METADATA
# title: Relative paths
# description: >-
#   Resolves a path written relative to a file, as an @import in a CLAUDE.md
#   is, into a repository path: `.` segments dropped and each `..` folded
#   into the segment before it.
package conventions.lib.paths

# The directory part of a path, with its trailing slash; "" at the root.
directory(path) := regex.replace(path, `[^/]*$`, "")

# The repository path that `target`, written in the file at `from`, names.
# A result that starts with `../` lies outside the repository.
resolve(from, target) := trim_suffix(collapsed, "/") if {
	joined := concat("", [directory(from), target])
	segments := [segment | some segment in split(joined, "/"); segment != "."; segment != ""]
	collapsed := fold(fold(fold(fold(fold(fold(fold(fold(concat("/", segments)))))))))
}

# A segment other than `..`, followed by `..`: both cancel. Eight passes fold
# any path eight directories deep, more than an import ever climbs.
parent_pattern := `(^|/)(?:[^/.][^/]*|\.[^/.][^/]*|\.\.[^/]+)/\.\.(/|$)`

fold(path) := regex.replace(path, parent_pattern, "$1")

outside("..")

outside(path) if startswith(path, "../")
