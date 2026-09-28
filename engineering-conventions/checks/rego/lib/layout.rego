# METADATA
# title: Repository layout
# description: >-
#   The product directory the identity declaration names in [layout]
#   (EC-0018), read once for the layout and environment checks.
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
