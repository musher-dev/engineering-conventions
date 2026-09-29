package conventions.checks.outputs.declaration_test

import data.conventions.checks.outputs.declaration
import data.conventions.lib.testdata_test as td

messages(found, id) := {f.message | some f in found; f.id == id}

publish := td.file(".github/workflows/publish.yml", {"name": "Publish", "true": {"push": {"tags": ["v*"]}}})

# The files a conforming image output points at.
tree_paths := [
	".github/workflows/publish.yml",
	".github/workflows/validate.yml",
	".repo/outputs.toml",
	"api/Dockerfile",
	"api/README.md",
	"api/openapi.yaml",
]

tree := td.inventory(tree_paths)

test_conforming_outputs if {
	contract := object.union(td.image_output, {
		"id": "api-contract",
		"kind": "contract",
		"format": "openapi",
		"definition": "api/openapi.yaml",
	})
	count(declaration.findings) == 0 with input as [publish, tree, td.outputs([td.image_output, contract])]
		with data.conventions.index as td.index
}

test_out_01_publish_workflow_without_declaration if {
	found := declaration.findings with input as [publish, td.inventory([".github/workflows/publish.yml"])]
		with data.conventions.index as td.index
	td.pairs(found) == {["OUT-01", ".github/workflows/publish.yml"]}
	messages(found, "OUT-01") == {concat(" ", [
		"publish.yml publishes an output, but the repository has no .repo/outputs.toml;",
		"declare each output it publishes there",
	])}
}

test_out_01_reusable_publish_workflow if {
	path := ".github/workflows/reusable-publish-image.yml"
	found := declaration.findings with input as [td.inventory([path])]
		with data.conventions.index as td.index
	td.pairs(found) == {["OUT-01", path]}
}

test_out_01_quiet_without_publish_workflow if {
	count(declaration.findings) == 0 with input as [td.inventory([".github/workflows/validate.yml"])]
		with data.conventions.index as td.index
}

test_out_02_schema_problems_in_one_finding if {
	found := declaration.findings with input as [publish, tree, td.outputs([{"name": "api", "kind": "image"}])]
		with data.conventions.index as td.index
	messages(found, "OUT-02") == {concat(" ", [
		"`outputs.0`: Additional property name is not allowed.",
		"(1 more problem in the declaration)",
	])}
}

test_out_02_root_problem if {
	found := declaration.findings with input as [td.file(".repo/outputs.toml", {"schema_version": 1})]
		with data.conventions.index as td.index
	messages(found, "OUT-02") == {"the declaration: outputs is required."}
}

test_out_03_unknown_kind if {
	output := object.union(td.image_output, {"kind": "docker"})
	found := declaration.findings with input as [publish, tree, td.outputs([output])]
		with data.conventions.index as td.index
	messages(found, "OUT-03") == {concat(" ", [
		`output "api-image" has kind "docker", which is not an output kind; use one of`,
		`"bundle", "cli", "contract", "image", "library", "site", "vmimage"`,
	])}
}

test_out_04_duplicate_ids if {
	found := declaration.findings with input as [publish, tree, td.outputs([td.image_output, td.image_output])]
		with data.conventions.index as td.index
	messages(found, "OUT-04") == {`output ID "api-image" is used more than once; give each output its own ID`}
}

test_out_05_missing_paths if {
	output := object.union(td.image_output, {"source": "server/", "docs": "docs/api.md#run"})
	found := declaration.findings with input as [publish, tree, td.outputs([output])]
		with data.conventions.index as td.index
	messages(found, "OUT-05") == {
		concat(" ", [
			`output "api-image" names source "server/", which the repository does not hold;`,
			"point it at the file or directory",
		]),
		concat(" ", [
			`output "api-image" names docs "docs/api.md#run", which the repository does not hold;`,
			"point it at the file or directory",
		]),
	}
}

test_out_05_labels_an_output_without_id if {
	output := object.remove(object.union(td.image_output, {"source": "server"}), ["id"])
	found := declaration.findings with input as [publish, tree, td.outputs([output])]
		with data.conventions.index as td.index
	some message in messages(found, "OUT-05")
	startswith(message, `output 1 names source "server"`)
}

test_out_06_missing_workflow if {
	output := object.union(td.image_output, {"publish_workflow": "publish-api.yml"})
	found := declaration.findings with input as [publish, tree, td.outputs([output])]
		with data.conventions.index as td.index
	messages(found, "OUT-06") == {concat(" ", [
		`output "api-image" names publish workflow "publish-api.yml", which is not in .github/workflows/;`,
		"name the workflow that publishes it",
	])}
}

test_out_06_workflow_that_does_not_publish if {
	output := object.union(td.image_output, {"publish_workflow": "validate.yml"})
	found := declaration.findings with input as [publish, tree, td.outputs([output])]
		with data.conventions.index as td.index
	messages(found, "OUT-06") == {concat(" ", [
		`output "api-image" names "validate.yml", whose responsibility is neither publish nor release;`,
		"name the workflow that publishes it",
	])}
}

test_out_06_release_workflow_may_publish if {
	output := object.union(td.image_output, {"publish_workflow": "release.yml"})
	release := td.file(".github/workflows/release.yml", {"name": "Release", "true": {"push": {"branches": ["main"]}}})
	with_release := td.inventory(array.concat(tree_paths, [".github/workflows/release.yml"]))
	found := declaration.findings with input as [release, with_release, td.outputs([output])]
		with data.conventions.index as td.index
	count(messages(found, "OUT-06")) == 0
}

test_out_06_deploy_workflow_does_not_publish if {
	output := object.union(td.image_output, {"publish_workflow": "deploy.yml"})
	with_deploy := td.inventory(array.concat(tree_paths, [".github/workflows/deploy.yml"]))
	found := declaration.findings with input as [publish, with_deploy, td.outputs([output])]
		with data.conventions.index as td.index
	messages(found, "OUT-06") == {concat(" ", [
		`output "api-image" names "deploy.yml", whose responsibility is neither publish nor release;`,
		"name the workflow that publishes it",
	])}
}

site_output := {
	"id": "docs-site",
	"kind": "site",
	"source": "api",
	"publish_workflow": "deploy-docs.yml",
	"location": "https://docs.example.com",
	"docs": "api/README.md",
}

with_deploy_docs := td.inventory(array.concat(tree_paths, [".github/workflows/deploy-docs.yml"]))

test_out_06_deploy_workflow_publishes_a_site if {
	found := declaration.findings with input as [publish, with_deploy_docs, td.outputs([site_output])]
		with data.conventions.index as td.index
	count(found) == 0
}

test_out_06_validate_workflow_does_not_publish_a_site if {
	output := object.union(site_output, {"publish_workflow": "validate.yml"})
	found := declaration.findings with input as [publish, with_deploy_docs, td.outputs([output])]
		with data.conventions.index as td.index
	messages(found, "OUT-06") == {concat(" ", [
		`output "docs-site" names "validate.yml", whose responsibility is not publish, release or deploy;`,
		"name the workflow that publishes it",
	])}
}

test_out_12_site_location_without_scheme if {
	output := object.union(site_output, {"location": "docs.example.com"})
	found := declaration.findings with input as [publish, with_deploy_docs, td.outputs([output])]
		with data.conventions.index as td.index
	td.pairs(found) == {["OUT-12", ".repo/outputs.toml"]}
	messages(found, "OUT-12") == {concat(" ", [
		`output "docs-site" is a site but its location "docs.example.com" is not an https:// origin;`,
		"give the URL people and tools fetch it from",
	])}
}

test_out_12_plain_http_is_not_an_origin if {
	output := object.union(site_output, {"location": "http://docs.example.com"})
	found := declaration.findings with input as [publish, with_deploy_docs, td.outputs([output])]
		with data.conventions.index as td.index
	td.pairs(found) == {["OUT-12", ".repo/outputs.toml"]}
}

test_out_12_other_kinds_are_not_sites if {
	output := object.union(td.image_output, {"location": "ghcr.io/example/api"})
	found := declaration.findings with input as [publish, tree, td.outputs([output])]
		with data.conventions.index as td.index
	count(messages(found, "OUT-12")) == 0
}

test_out_07_contract_without_format_or_definition if {
	output := object.union(td.image_output, {"kind": "contract"})
	found := declaration.findings with input as [publish, tree, td.outputs([output])]
		with data.conventions.index as td.index
	messages(found, "OUT-07") == {concat(" ", [
		`output "api-image" is a contract but does not name its format or definition;`,
		"add the interface format and the definition file",
	])}
}
