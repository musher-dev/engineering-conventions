# METADATA
# title: Environment contract
# description: >-
#   A service declares its runtime environment at <product>/env.schema.yaml
#   (ENVS-01), and environment schemas live only there and in
#   .devcontainer/ (ENVS-02).
# scope: package
# custom:
#   convention: EC-0019
package conventions.checks.environment.env_contract

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.layout

dev_schema := ".devcontainer/env.schema.yaml"

# ENVS-01. The service profile selects it; without a product directory
# there is nowhere to put the contract, and REPO-14 or REPO-15 says so.
findings contains lib.finding("ENVS-01", product_schema, message) if {
	not product_schema in files.all_files
	message := sprintf(
		"the service declares no environment contract; add %s with every variable the product reads",
		[product_schema],
	)
}

# ENVS-02
findings contains lib.finding("ENVS-02", path, message) if {
	layout.declared
	some path in files.repository_files
	regex.match(`^env\.schema\.ya?ml$`, files.basename(path))
	not path in allowed
	message := sprintf(
		"an environment schema lives at %s or %s, nowhere else; move this one to %s",
		[home, dev_schema, destination(path)],
	)
}

product_schema := sprintf("%s/env.schema.yaml", [layout.product_dir])

allowed contains dev_schema

allowed contains product_schema

default home := "<product>/env.schema.yaml"

home := sprintf("%s/env.schema.yaml", [layout.product_dir])

destination(path) := dev_schema if startswith(path, ".devcontainer/")

destination(path) := home if not startswith(path, ".devcontainer/")
