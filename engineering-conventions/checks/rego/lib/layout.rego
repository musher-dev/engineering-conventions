# METADATA
# title: Repository layout
# description: >-
#   The product directory the identity declaration names in [layout]
#   (EC-0018), or the product directories a multi-product repository lists,
#   read once for the layout, environment and interface checks.
package conventions.lib.layout

import data.conventions.lib.files

table := files.repository_declaration.layout if is_object(files.repository_declaration.layout)

product_key_declared if "product" in object.keys(table)

declared_product := table.product if is_string(table.product)

# One path segment, as the schema has it; anything else is REPO-02's.
segment_pattern := `^[A-Za-z0-9][A-Za-z0-9._-]*$`

# The declared product directory, when there is one.
product_dir := declared_product if regex.match(segment_pattern, declared_product)

# A layout the checks can use: a product directory, or none.
declared if product_dir

declared if declared_product == ""

default root_exceptions := {}

root_exceptions := table.root_exceptions if is_object(table.root_exceptions)

# A multi-product repository declares product = "" and lists its peer
# products: each entry a path whose segments are names or `*`, such as
# apps/*. Read only beside product = "", as the schema requires.
default products := []

products := [entry | some entry in table.products; regex.match(products_pattern, entry)] if {
	declared_product == ""
	is_array(table.products)
}

products_pattern := `^[A-Za-z0-9][A-Za-z0-9._-]*(/([A-Za-z0-9][A-Za-z0-9._-]*|\*))*$`

# The directories the products entries name, as they exist in the repository.
product_dirs contains dir if {
	some entry in products
	some dir in files.directories
	glob.match(entry, ["/"], dir)
}
