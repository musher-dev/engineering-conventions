# METADATA
# title: Version ranges
# description: >-
#   The range grammar of an environment schema's requires (EC-0020,
#   decision 0026): comparators separated by commas, all of which must
#   hold, with the operators >=, >, <=, < and == on dot-separated integers.
#   A missing component counts as 0, so <10 excludes 10.0.
package conventions.lib.versions

version_pattern := `^[0-9]+(\.[0-9]+)*$`

comparator_pattern := `^(>=|<=|==|>|<) *([0-9]+(\.[0-9]+)*)$`

# A version as its components, or undefined when it is not one.
parse(version) := [to_number(part) | some part in split(version, ".")] if {
	is_string(version)
	regex.match(version_pattern, version)
}

# The comparators of a range, as {op, version}, or undefined when any part
# is not a comparator.
comparators(range) := parsed if {
	is_string(range)
	parts := [trim_space(part) | some part in split(range, ",")]
	parsed := [{"op": match[1], "version": parse(match[2])} |
		some part in parts
		some match in regex.find_all_string_submatch_n(comparator_pattern, part, 1)
	]
	count(parsed) == count(parts)
}

valid_range(range) if comparators(range)

# -1, 0 or 1 as a is below, equal to or above b, missing components 0.
compare(a, b) := 0 if {
	not first_difference(a, b)
}

compare(a, b) := -1 if {
	i := first_difference(a, b)
	component(a, i) < component(b, i)
}

compare(a, b) := 1 if {
	i := first_difference(a, b)
	component(a, i) > component(b, i)
}

component(version, i) := version[i] if i < count(version)

component(version, i) := 0 if i >= count(version)

first_difference(a, b) := min({i |
	some i in numbers.range(0, max([count(a), count(b)]) - 1)
	component(a, i) != component(b, i)
})

holds(">=", c) if c >= 0

holds(">", c) if c > 0

holds("<=", c) if c <= 0

holds("<", c) if c < 0

holds("==", 0)

# Whether a version, as text, satisfies every comparator of a range.
satisfies(version, range) if {
	v := parse(version)
	every comparator in comparators(range) {
		holds(comparator.op, compare(v, comparator.version))
	}
}
