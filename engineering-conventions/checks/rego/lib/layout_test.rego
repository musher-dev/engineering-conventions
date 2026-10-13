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

inventory(paths) := td.file("/tmp/inventory.json", {"conventions_inventory": {"files": paths, "texts": {}}})

test_products if {
	table := {"product": "", "products": ["apps/*", "docs/site", "/abs", "a/**"]}
	paths := ["apps/console/package.json", "apps/hq/package.json", "docs/site/package.json", "docs/README.md"]
	docs := array.concat(declared(table), [inventory(paths)])
	layout.products == ["apps/*", "docs/site"] with input as docs
	layout.product_dirs == {"apps/console", "apps/hq", "docs/site"} with input as docs
}

test_products_need_no_product if {
	docs := array.concat(declared({"product": "app", "products": ["apps/*"]}), [inventory(["apps/a/x"])])
	layout.products == [] with input as docs
	count(layout.product_dirs) == 0 with input as docs
}
