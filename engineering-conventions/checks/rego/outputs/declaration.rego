# METADATA
# title: Outputs declaration
# description: >-
#   A repository with a publish workflow declares its outputs in
#   .repo/outputs.toml (OUT-01), and the declaration is valid, names known
#   kinds, unique IDs, existing paths and real publish workflows (OUT-02 to
#   OUT-06), and serves each site from an HTTPS origin (OUT-12). OUT-07 is
#   retired: interfaces are declared under [[interfaces]] (EC-0030).
# scope: package
# custom:
#   convention: EC-0007
package conventions.checks.outputs.declaration

import data.conventions.lib.filenames
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.names

# OUT-01. Reported on each publish workflow, so the finding sits where the
# output is published.
findings contains lib.finding("OUT-01", path, message) if {
	not files.outputs_declared
	some path in publish_workflows
	message := sprintf(
		"%s publishes an output, but the repository has no %s; declare each output it publishes there",
		[files.basename(path), files.outputs_path],
	)
}

# OUT-02. One finding per declaration: the first problem, and how many more.
findings contains lib.finding("OUT-02", files.outputs_path, message) if {
	count(schema_problems) > 0
	rest := count(schema_problems) - 1
	message := summary(schema_problems[0], rest)
}

# OUT-03
findings contains lib.finding("OUT-03", files.outputs_path, message) if {
	some index, output in outputs
	is_string(output.kind)
	not output.kind in output_kinds
	output.kind != "contract"
	message := sprintf(
		"%s has kind %q, which is not an output kind; use one of %s",
		[label(output, index), output.kind, names.quoted_list(output_kinds)],
	)
}

findings contains lib.finding("OUT-03", files.outputs_path, message) if {
	some index, output in outputs
	output.kind == "contract"
	message := sprintf(
		concat(" ", [
			"%s has kind \"contract\", which is retired; declare the definition as an [[interfaces]] entry",
			"(schema_version = 2) delivered by the bundle, site or library output that ships it",
		]),
		[label(output, index)],
	)
}

# OUT-04
findings contains lib.finding("OUT-04", files.outputs_path, message) if {
	some id in {output.id | some output in outputs; is_string(output.id)}
	count([output | some output in outputs; output.id == id]) > 1
	message := sprintf("output ID %q is used more than once; give each output its own ID", [id])
}

# OUT-05
findings contains lib.finding("OUT-05", files.outputs_path, message) if {
	some index, output in outputs
	some field in path_fields
	files.has_string(output, field)
	target := trim_suffix(regex.replace(output[field], `#.*$`, ""), "/")
	not exists(target)
	message := sprintf(
		"%s names %s %q, which the repository does not hold; point it at the file or directory",
		[label(output, index), field, output[field]],
	)
}

# OUT-06
findings contains lib.finding("OUT-06", files.outputs_path, message) if {
	some index, output in outputs
	files.has_string(output, "publish_workflow")
	not workflow_path(output.publish_workflow) in files.workflow_files
	message := sprintf(
		"%s names publish workflow %q, which is not in .github/workflows/; name the workflow that publishes it",
		[label(output, index), output.publish_workflow],
	)
}

findings contains lib.finding("OUT-06", files.outputs_path, message) if {
	some index, output in outputs
	files.has_string(output, "publish_workflow")
	path := workflow_path(output.publish_workflow)
	path in files.workflow_files
	not publishes(output, path)
	message := sprintf(
		"%s names %q, whose responsibility is %s; name the workflow that publishes it",
		[label(output, index), output.publish_workflow, accepted_responsibilities(output)],
	)
}

# OUT-12
findings contains lib.finding("OUT-12", files.outputs_path, message) if {
	some index, output in outputs
	output.kind == "site"
	files.has_string(output, "location")
	not regex.match(`^https://[^/\s]+`, output.location)
	message := sprintf(
		"%s is a site but its location %q is not an https:// origin; give the URL people and tools fetch it from",
		[label(output, index), output.location],
	)
}

# A workflow whose responsibility slot is publish, entry point or reusable.
publish_workflows contains path if {
	some path in files.workflow_files
	filenames.slot(lower(files.stem(path))) == "publish"
}

# The workflows an output may name (OUT-06): a publish workflow, or a release
# workflow, which may publish the artifacts of the release it cuts. Only a
# publish workflow is taken to publish something (OUT-01): a release workflow
# may cut releases that publish nothing.
publishing_workflows := publish_workflows | {path |
	some path in files.workflow_files
	filenames.slot(lower(files.stem(path))) == "release"
}

# Whether the workflow at path may publish the output (OUT-06). A site is
# also published by a deploy workflow: pushing its files to the host that
# serves them is what makes it available.
publishes(_, path) if path in publishing_workflows

publishes(output, path) if {
	output.kind == "site"
	path in deploy_workflows
}

deploy_workflows contains path if {
	some path in files.workflow_files
	filenames.slot(lower(files.stem(path))) == "deploy"
}

accepted_responsibilities(output) := "not publish, release or deploy" if output.kind == "site"

else := "neither publish nor release"

output_kinds := {kind | some kind in data.conventions.index.vocabulary.output_kinds}

default outputs := []

outputs := [output | some output in files.outputs_declaration.outputs; is_object(output)] if {
	is_array(files.outputs_declaration.outputs)
}

path_fields := ["source", "definition", "docs"]

workflow_path(name) := concat("", [".github/workflows/", name])

# The inventory lists files, so a directory exists when a file sits under it.
exists(path) if path in files.repository_files

exists(path) if {
	some file in files.repository_files
	startswith(file, concat("", [path, "/"]))
}

label(output, _) := sprintf("output %q", [output.id]) if files.has_string(output, "id")

label(output, index) := sprintf("output %d", [index + 1]) if not files.has_string(output, "id")

schema_problems := [problem |
	some contents in files.outputs_documents
	[_, errors] := json.match_schema(contents, data.conventions.index.outputs_schema)
	some error in sort_errors(errors)
	problem := schema_message(error)
]

sort_errors(errors) := [error |
	some key in sort({sprintf("%s\u0000%s", [e.field, e.desc]) | some e in errors})
	some error in errors
	sprintf("%s\u0000%s", [error.field, error.desc]) == key
]

schema_message(error) := sprintf("the declaration: %s.", [trim_suffix(error.desc, ".")]) if error.field == "(Root)"

else := sprintf("`%s`: %s.", [error.field, trim_suffix(error.desc, ".")])

summary(first, 0) := first

summary(first, rest) := sprintf("%s (%d more problem%s in the declaration)", [first, rest, plural(rest)]) if rest > 0

plural(1) := ""

plural(n) := "s" if n != 1
