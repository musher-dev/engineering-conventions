# METADATA
# title: Shared test data matches the real index
# description: >-
#   Every other package's tests run against the hand-written index in
#   testdata_test.rego, not checks/data/index.json. These hold that index to
#   the real one's shape, so a rename in the generator cannot leave every test
#   passing against data no release ships.
package conventions.lib.testdata_shape_test

import data.conventions.lib.testdata_test as td

real := data.conventions.index

# GHA-99 stands in for a retired requirement; no release has one to borrow.
stand_ins := {"GHA-99"}

keys_outside(value, allowed) := object.keys(value) - object.keys(allowed)

test_the_index_has_only_real_keys if {
	count(keys_outside(td.index, real)) == 0
}

test_every_requirement_is_a_real_requirement if {
	object.keys(td.index.requirements) - object.keys(real.requirements) == stand_ins
}

test_every_requirement_entry_has_real_keys if {
	shape := real.requirements["GHA-07"]
	extra := {key | some entry in td.index.requirements; some key in keys_outside(entry, shape)}
	count(extra) == 0
}

test_every_profile_has_the_real_keys if {
	shape := object.keys(real.profiles["base-repo"])
	wrong := {name | some name, profile in td.index.profiles; object.keys(profile) != shape}
	count(wrong) == 0
}

test_every_convention_entry_has_real_keys if {
	shape := real.conventions["EC-0002"]
	extra := {key | some entry in td.index.conventions; some key in keys_outside(entry, shape)}
	count(extra) == 0
}

test_the_vocabulary_has_only_real_keys if {
	count(keys_outside(td.index.vocabulary, real.vocabulary)) == 0
}
