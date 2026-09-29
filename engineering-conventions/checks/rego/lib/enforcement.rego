# METADATA
# title: Enforcement
# description: >-
#   Decides which findings count toward --fail-on. A repository adopting the
#   conventions in stages lists the families it enforces in the [adoption]
#   table of its conventions declaration; findings of the other families are
#   still reported, marked not enforced. Without the table, or once it has
#   expired, every family is enforced.
package conventions.lib.enforcement

import data.conventions.lib.dates
import data.conventions.lib.files

# The ADOPT family polices the declaration itself, so it is always enforced.
always_enforced := {"ADOPT"}

adoption := files.declaration.adoption if is_object(files.declaration.adoption)

default declared_families := []

declared_families := [family | some family in adoption.enforce; is_string(family)] if {
	is_array(adoption.enforce)
}

# The families this release defines: the prefixes of its requirement IDs.
known_families contains family(id) if some id, _ in data.conventions.index.requirements

# A staged adoption is in force from the day it is declared until its expires
# date, inclusive; a table with no valid date stages nothing.
staged if {
	count(declared_families) > 0
	dates.date_ns(adoption.expires) >= dates.now_ns
}

expired if dates.past(adoption.expires)

too_long if dates.beyond_term(adoption.expires)

family(id) := split(id, "-")[0]

enforced(_) if not staged

enforced(id) if family(id) in always_enforced

enforced(id) if family(id) in declared_families
