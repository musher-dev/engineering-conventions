package conventions.checks.outputs.declaration_test

import data.conventions.checks.outputs.declaration
import data.conventions.lib.testdata_test as td

messages(found, id) := {f.message | some f in found; f.id == id}

publish := td.file(".github/workflows/publish.yml", {"name": "Publish", "true": {"push": {"tags": ["v*"]}}})

# The files a conforming image output points at.
tree := td.inventory([
	".github/workflows/publish.yml",
	".github/workflows/validate.yml",
	".repo/outputs.yaml",
	"api/Dockerfile",
	"api/README.md",
	"api/openapi.yaml",
])

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
		"publish.yml publishes an output, but the repository has no .repo/outputs.yaml;",
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
	found := declaration.findings with input as [td.file(".repo/outputs.yaml", {"schema_version": 1})]
		with data.conventions.index as td.index
	messages(found, "OUT-02") == {"the declaration: outputs is required."}
}

test_out_03_unknown_kind if {
	output := object.union(td.image_output, {"kind": "docker"})
	found := declaration.findings with input as [publish, tree, td.outputs([output])]
		with data.conventions.index as td.index
	messages(found, "OUT-03") == {concat(" ", [
		`output "api-image" has kind "docker", which is not an output kind; use one of`,
		`"bundle", "cli", "contract", "image", "library"`,
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
		`output "api-image" names "validate.yml", whose responsibility is not publish;`,
		"name the workflow that publishes it",
	])}
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
