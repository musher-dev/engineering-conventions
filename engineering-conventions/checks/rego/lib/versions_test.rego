package conventions.lib.versions_test

import data.conventions.lib.versions

test_parse if {
	versions.parse("9.0.1") == [9, 0, 1]
	versions.parse("18") == [18]
	not versions.parse("9.0-alpine")
	not versions.parse("v9")
	not versions.parse(9)
}

test_comparators if {
	versions.comparators(">=9, <10") == [{"op": ">=", "version": [9]}, {"op": "<", "version": [10]}]
	versions.comparators("== 1.2") == [{"op": "==", "version": [1, 2]}]
	not versions.comparators("^9")
	not versions.comparators(">=9,")
	not versions.comparators(">=9 <10")
	versions.valid_range(">18")
	not versions.valid_range("~=18")
}

test_compare_pads_missing_components if {
	versions.compare([10], [10, 0]) == 0
	versions.compare([9, 9], [10]) == -1
	versions.compare([10, 0, 1], [10]) == 1
	versions.compare([18], [17, 99]) == 1
}

test_satisfies if {
	versions.satisfies("9.0.2", ">=9, <10")
	versions.satisfies("9", ">=9, <10")
	not versions.satisfies("10.0", ">=9, <10")
	not versions.satisfies("8.1", ">=9, <10")
	versions.satisfies("18.1", ">=18")
	versions.satisfies("18.1", ">18")
	not versions.satisfies("18", ">18")
	versions.satisfies("17", "<=17.0")
	versions.satisfies("1.2.0", "==1.2")
	not versions.satisfies("1.2.1", "==1.2")
	not versions.satisfies("latest", ">=1")
	not versions.satisfies("9", "^9")
}
