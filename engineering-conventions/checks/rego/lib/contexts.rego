# METADATA
# title: Required status checks
# description: >-
#   The contexts the rulesets require, and the contexts the workflows emit, so
#   GHA-15, GHA-16 and GHA-32 agree on what "emits a required check" means.
package conventions.lib.contexts

import data.conventions.lib.files
import data.conventions.lib.names

# GitHub Actions' app id. A required check pinned to another app (a coverage
# service, say) is reported by that app, not by any workflow here.
actions_integration_id := 15368

required contains {"context": check.context, "path": path} if {
	some path, ruleset in files.rulesets
	some rule in ruleset.rules
	rule.type == "required_status_checks"
	some check in rule.parameters.required_status_checks
	is_string(check.context)
	object.get(check, "integration_id", null) in {null, actions_integration_id}
}

# GitHub reports a job without `name:` under its id.
job_name(_, job) := job.name if is_string(job.name)

job_name(job_id, job) := job_id if not files.has_string(job, "name")

# A name built from an expression, or a job expanded by a matrix, has no one
# fixed context.
dynamic(job_id, job) if contains(job_name(job_id, job), "${{")

dynamic(_, job) if job.strategy.matrix

expression_marker := "\u0000"

# A regular expression for every context a job can report under: an
# expression matches any text, and a matrix job whose name uses no
# expression gets its matrix values appended in parentheses.
name_pattern(job_id, job) := concat("", [
	replace(
		regex.replace(
			regex.replace(job_name(job_id, job), `\$\{\{.*?\}\}`, expression_marker),
			`[\\.+*?()|\[\]{}^$]`,
			`\$0`,
		),
		expression_marker,
		".+",
	),
	matrix_suffix(job_id, job),
])

default matrix_suffix(_, _) := ""

matrix_suffix(job_id, job) := ` \(.+\)` if {
	job.strategy.matrix
	not contains(job_name(job_id, job), "${{")
}

calls(job) if is_string(job.uses)

local_callee(job) := files.normalise(job.uses) if {
	is_string(job.uses)
	startswith(job.uses, "./.github/workflows/")
}

remote_caller(job) if {
	calls(job)
	not startswith(job.uses, "./")
}

# The call graph over jobs. A node is a [workflow path, job id] pair,
# marshalled because the graph builtins key on strings; a job that calls a
# local workflow has an edge to each of the callee's jobs.
node(path, job_id) := json.marshal([path, job_id])

call_graph[node(path, job_id)] := [node(callee, callee_id) |
	callee := local_callee(job)
	some callee_id, _ in files.jobs(files.workflows[callee])
] if {
	some path, workflow in files.workflows
	some job_id, job in files.jobs(workflow)
}

roots contains node(path, job_id) if {
	some path, workflow in files.workflows
	files.is_entry_point(workflow)
	some job_id, _ in files.jobs(workflow)
}

# GitHub runs at most ten levels of workflows, the entry point included.
max_depth := 10

# Every chain of jobs from an entry point down to the job that runs, as
# [workflow path, job id] pairs. A cycle or a missing callee ends a chain at
# a caller, which reports nothing.
chains contains chain if {
	some nodes in graph.reachable_paths(call_graph, roots)
	count(nodes) <= max_depth
	chain := [json.unmarshal(encoded) | some encoded in nodes]
}

chain_job(pair) := files.jobs(files.workflows[pair[0]])[pair[1]]

leaf(chain) := chain_job(chain[count(chain) - 1])

chain_dynamic(chain) if {
	some pair in chain
	dynamic(pair[1], chain_job(pair))
}

chain_pattern(chain) := concat(" / ", [name_pattern(pair[1], chain_job(pair)) | some pair in chain])

# A called job reports as `<caller job name> / <callee job name>`, nested
# once per level of calls.
emitted contains {"context": context, "workflow": chain[0][0], "job": chain[0][1], "leaf": chain[count(chain) - 1]} if {
	some chain in chains
	not calls(leaf(chain))
	not chain_dynamic(chain)
	context := concat(" / ", [job_name(pair[1], chain_job(pair)) | some pair in chain])
}

patterned contains {
	"pattern": sprintf("^%s$", [chain_pattern(chain)]),
	"workflow": chain[0][0],
	"job": chain[0][1],
} if {
	some chain in chains
	not calls(leaf(chain))
	chain_dynamic(chain)
}

# A workflow in another repository cannot be read, so whatever its jobs
# report under the caller is taken on trust.
unverifiable contains sprintf("^%s / .+$", [chain_pattern(chain)]) if {
	some chain in chains
	remote_caller(leaf(chain))
}

emitted_names contains entry.context if some entry in emitted

required_names contains requirement.context if some requirement in required

# Whether the repository commits any ruleset, parsed or not: without one
# nothing says which contexts are required.
has_rulesets if {
	some path in files.repository_files
	regex.match(`^\.github/rulesets/[^/]+\.json$`, path)
}

matches_pattern(context) if {
	some entry in patterned
	regex.match(entry.pattern, context)
}

unverified(context) if {
	some pattern in unverifiable
	regex.match(pattern, context)
}

# Workflows whose jobs report at least one required context.
required_workflows contains entry.workflow if {
	some entry in emitted
	some requirement in required
	requirement.context == entry.context
}

required_workflows contains entry.workflow if {
	some entry in patterned
	some requirement in required
	regex.match(entry.pattern, requirement.context)
}

aggregate_names(path, workflow) := {sprintf("%s / Required", [name]) |
	some name in names.accepted_workflow_names(path, workflow)
}

# An aggregate is recognised by its id, or by its name in any case: GitHub
# matches contexts exactly, so a case difference is GHA-15's to report.
is_aggregate(_, _, "required", _)

is_aggregate(path, workflow, _, job) if {
	is_string(job.name)
	lower(job.name) in {lower(name) | some name in aggregate_names(path, workflow)}
}

aggregates(path, workflow) := {[job_id, job] |
	some job_id, job in files.jobs(workflow)
	is_aggregate(path, workflow, job_id, job)
}
