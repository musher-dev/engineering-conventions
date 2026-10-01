# METADATA
# title: Documents derived from the environment schema
# description: >-
#   A service that offers its environment as an env-schema interface commits
#   the contract derived from <product>/env.schema.yaml under
#   contracts/env/ and names it in the interface (ENVS-20), and a product's
#   .env.example is the one its schema derives (ENVS-21). The runner derives
#   both with bin/env-contract.jq (decision 0026), so these rules only
#   compare.
# scope: package
# custom:
#   convention: EC-0019
package conventions.checks.environment.env_derived

import data.conventions.lib.contracts
import data.conventions.lib.env
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.layout

# ENVS-20. The contract is missing.
findings contains lib.finding("ENVS-20", schema_path, message) if {
	not contract_path in files.repository_files
	some entry in env_interfaces
	message := sprintf(
		concat(" ", [
			"interface %s offers this environment as env-schema, so commit the contract derived from it:",
			"conventions env-contract %s > %s",
		]),
		[entry.id, schema_path, contract_path],
	)
}

# ENVS-20. The contract exists, and the interface does not name it.
findings contains lib.finding("ENVS-20", files.outputs_path, message) if {
	contract_path in files.repository_files
	some entry in env_interfaces
	not contract_path in contracts.interface_files(entry)
	message := sprintf(
		"interface %s is the environment contract; name %s in its definitions",
		[entry.id, contract_path],
	)
}

# ENVS-20. The committed contract is not the one the schema derives.
findings contains lib.finding("ENVS-20", contract_path, message) if {
	committed_contract != files.derived[schema_path].contract
	message := sprintf(
		"this is not the contract %s derives; generate it again with conventions env-contract %s > %s",
		[schema_path, schema_path, contract_path],
	)
}

# ENVS-21
findings contains lib.finding("ENVS-21", example_path, message) if {
	derived := files.derived[schema_path].example
	text := files.texts[example_path]
	text != derived
	message := sprintf(
		"this is not the .env.example %s derives; generate it again with conventions env-contract --example %s > %s",
		[schema_path, schema_path, example_path],
	)
}

# The product's schema, when the repository has one the checks read.
schema_path := path if {
	path := sprintf("%s/env.schema.yaml", [layout.product_dir])
	is_object(env.documents[path])
}

# The service names the contract's file, so it must be one path segment.
service := name if {
	name := env.documents[schema_path].service
	regex.match(`^[A-Za-z0-9][A-Za-z0-9._-]*$`, name)
}

contract_path := sprintf("%s/env/%s.env.schema.json", [contracts.dir, service])

# The contract as committed, when conftest parsed it.
committed_contract := doc.contents if {
	some doc in files.own_documents
	doc.path == contract_path
}

example_path := sprintf("%s/.env.example", [layout.product_dir])

env_interfaces contains entry if {
	schema_path
	some entry in contracts.interfaces
	entry.format == "env-schema"
	is_string(entry.id)
}
