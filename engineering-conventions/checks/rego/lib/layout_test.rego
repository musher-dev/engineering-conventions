package conventions.lib.layout_test

import data.conventions.lib.layout
import data.conventions.lib.testdata_test as td

declared(table) := [td.repository(object.union(td.identity, {"layout": table}))]

test_product_dir if {
	layout.product_dir == "platform-api" with input as declared({"product": "platform-api"})
	layout.declared with input as declared({"product": "platform-api"})
}

test_no_product if {
	layout.declared with input as declared({"product": ""})
	not layout.product_dir with input as declared({"product": ""})
}

test_malformed_product if {
	not layout.declared with input as declared({"product": "a/b"})
	layout.product_key_declared with input as declared({"product": "a/b"})
}

test_root_exceptions if {
	layout.root_exceptions == {} with input as declared({"product": ""})
	table := {"product": "", "root_exceptions": {"go.sum": "why"}}
	layout.root_exceptions == {"go.sum": "why"} with input as declared(table)
}
