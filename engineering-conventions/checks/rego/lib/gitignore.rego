# METADATA
# title: Gitignore patterns
# description: >-
#   Whether a pattern in a .gitignore or .gitattributes matches a path, read
#   as git reads it: a pattern with no slash, or only a trailing one,
#   matches a name at any depth; a pattern with a slash is anchored to the
#   file's directory; a leading **/ matches at any depth.
package conventions.lib.gitignore

import data.conventions.lib.files

# Whether PATTERN matches RELATIVE, a path relative to the directory of the
# file that holds the pattern. A slash-free pattern matches any segment of
# the path, so a bare directory name matches every file beneath it.
matches(pattern, relative) if {
	clean := trim_suffix(pattern, "/")
	not contains(clean, "/")
	some name in split(relative, "/")
	glob.match(clean, [], name)
}

matches(pattern, relative) if {
	contains(trim_suffix(pattern, "/"), "/")
	clean := trim_prefix(trim_suffix(pattern, "/"), "/")
	glob.match(clean, ["/"], relative)
}

matches(pattern, relative) if {
	startswith(pattern, "**/")
	rest := substring(pattern, 3, -1)
	glob.match(rest, ["/"], files.basename(relative))
}
