# METADATA
# title: Doublestar globs
# description: >-
#   Brace expansion and doublestar matching, the glob semantics of tools such
#   as lefthook with glob_matcher doublestar: `*` stays within one path
#   segment and `**/` matches zero or more directories.
package conventions.lib.doublestar

brace_pattern := `\{[^{}]*\}`

# The alternatives of a pattern with its `{a,b}` groups expanded, so that each
# can be judged on its own: `*.{ts,md}` is `*.ts` and `*.md`. Groups nested
# inside a group are left as written.
expand(pattern) := {pattern} if not regex.match(brace_pattern, pattern)

expand(pattern) := {concat("", pieces(literals, options, choice)) |
	some choice in numbers.range(0, product([count(o) | some o in options]) - 1)
} if {
	groups := regex.find_n(brace_pattern, pattern, -1)
	count(groups) > 0
	literals := regex.split(brace_pattern, pattern)
	options := [split(trim_suffix(trim_prefix(group, "{"), "}"), ",") | some group in groups]
}

# The pieces of one expansion: literal, option, literal, ... The choice is a
# mixed-radix number with one digit per group.
pieces(literals, options, choice) := [piece |
	some i, literal in literals
	piece := concat("", [literal, option_at(options, choice, i)])
]

option_at(options, _, i) := "" if i >= count(options)

option_at(options, choice, i) := options[i][digit] if {
	i < count(options)
	radix := product([count(earlier) | some j, earlier in options; j < i])
	digit := floor(choice / radix) % count(options[i])
}

# Every way to read the `**/` segments of a pattern, each either present or
# dropped, so that gobwas (whose `**/` needs at least one directory) matches
# as doublestar does.
variants(pattern) := {concat("", [part_with(parts, mask, i) | some i, _ in parts]) |
	parts := split(pattern, "**/")
	gaps := count(parts) - 1
	some mask in numbers.range(0, bits.lsh(1, gaps) - 1)
}

part_with(parts, _, i) := parts[i] if i == count(parts) - 1

part_with(parts, mask, i) := concat("", [parts[i], "**/"]) if {
	i < count(parts) - 1
	bits.and(mask, bits.lsh(1, i)) != 0
}

part_with(parts, mask, i) := parts[i] if {
	i < count(parts) - 1
	bits.and(mask, bits.lsh(1, i)) == 0
}

# Whether a doublestar pattern matches a path.
match(pattern, path) if {
	some alternative in expand(pattern)
	some variant in variants(alternative)
	glob.match(variant, ["/"], path)
}

# Whether a pattern matches any of a set of paths.
matches_any(pattern, paths) if {
	some path in paths
	match(pattern, path)
}
