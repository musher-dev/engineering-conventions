# METADATA
# title: Environment contract
# description: >-
#   A service declares its runtime environment at <product>/env.schema.yaml
#   (ENVS-01), and environment schemas live only there and in
#   .devcontainer/ (ENVS-02). A dev container asks for every variable its
#   schema takes from the host (ENVS-15).
# scope: package
# custom:
#   convention: EC-0019
package conventions.checks.environment.env_contract

import data.conventions.lib.env
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.layout
import data.conventions.lib.mise

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

# ENVS-15. Only a dev container with a dev environment schema beside it; a
# name that differs only in case is still two variables.
findings contains lib.finding("ENVS-15", path, message) if {
	dev_schema in object.keys(env.documents)
	some path, devcontainer in mise.devcontainers
	startswith(path, ".devcontainer/")
	secrets := declared_secrets(devcontainer)
	some name in (host_bindings - secrets)
	message := sprintf(
		"%s comes from the host (source: host in %s) but is not in secrets; add it so Codespaces asks for it",
		[name, dev_schema],
	)
}

findings contains lib.finding("ENVS-15", path, message) if {
	dev_schema in object.keys(env.documents)
	some path, devcontainer in mise.devcontainers
	startswith(path, ".devcontainer/")
	some name in (declared_secrets(devcontainer) - host_bindings)
	message := sprintf(
		"secrets names %s, which %s does not declare with source: host; declare it there, or remove it",
		[name, dev_schema],
	)
}

product_schema := sprintf("%s/env.schema.yaml", [layout.product_dir])

allowed contains dev_schema

allowed contains product_schema

default home := "<product>/env.schema.yaml"

home := sprintf("%s/env.schema.yaml", [layout.product_dir])

destination(path) := dev_schema if startswith(path, ".devcontainer/")

destination(path) := home if not startswith(path, ".devcontainer/")

host_bindings contains name if {
	some name, binding in env.bindings_of(dev_schema)
	is_object(binding)
	binding.source == "host"
}

default declared_secrets(_) := set()

declared_secrets(devcontainer) := object.keys(devcontainer.secrets) if is_object(devcontainer.secrets)
