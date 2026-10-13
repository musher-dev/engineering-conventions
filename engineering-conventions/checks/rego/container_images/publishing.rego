# METADATA
# title: Publishing container images
# description: >-
#   A job that pushes an image scans it with Trivy before the push and fails
#   on HIGH and CRITICAL vulnerabilities (IMAGE-11), and attests its build
#   provenance in the registry, unless the repository declares it cannot
#   (IMAGE-12).
# scope: package
# custom:
#   convention: EC-0043
package conventions.checks.container_images.publishing

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.images
import data.conventions.lib.permissions
import data.conventions.lib.repository
import data.conventions.lib.runs
import data.conventions.lib.steps

# IMAGE-11
findings contains lib.finding("IMAGE-11", entry.path, message) if {
	some entry in images.pushing_jobs
	not scanned_before_push(entry)
	message := sprintf(
		concat(" ", [
			"job %q pushes an image without scanning it first; before the push, run trivy image",
			"--exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed on the built image (or",
			"aquasecurity/trivy-action with exit-code: 1), so a known vulnerability stops the publish",
		]),
		[entry.job_id],
	)
}

# IMAGE-12
findings contains lib.finding("IMAGE-12", entry.path, message) if {
	not repository.attestations_unavailable
	some entry in images.pushing_jobs
	not attested(entry.job)
	message := sprintf(
		concat(" ", [
			"job %q pushes an image without attesting its build provenance; attest the pushed digest",
			"with actions/attest and push-to-registry: true (a private or internal repository, where",
			"GitHub offers no attestations, declares visibility in .repo/repository.toml)",
		]),
		[entry.job_id],
	)
}

findings contains lib.finding("IMAGE-12", entry.path, message) if {
	not repository.attestations_unavailable
	some entry in images.pushing_jobs
	attested(entry.job)
	some permission in ["id-token", "attestations"]
	not permissions.granted(entry.workflow, entry.job, permission)
	message := sprintf(
		"job %q attests the image without %s: write; grant it so the attestation can be signed and stored",
		[entry.job_id, permission],
	)
}

attested(job) if {
	some step in files.steps(job)
	images.registry_attestation(step)
}

# --- IMAGE-11: the scan ------------------------------------------------------

scanned_before_push(entry) if {
	some index, step in files.steps(entry.job)
	index <= entry.push
	scans(step)
}

trivy_action := "aquasecurity/trivy-action"

scans(step) if {
	steps.action(step) == trivy_action
	inputs := steps.inputs(step)
	object.get(inputs, "scan-type", "image") == "image"
	nonzero(object.get(inputs, "exit-code", "0"))
	severity_covered(object.get(inputs, "severity", ""))
}

scans(step) if {
	some line in steps.command_lines(step)
	scan_line(line, object.get(step, "env", {}))
}

# Through a task: a task runs a scan line, itself or through a task it
# calls.
scans(step) if {
	some line in steps.command_lines(step)
	some name in runs.task_arguments(line)
	some task in scanning_tasks
	runs.called_as(name, task)
}

direct_scanning_tasks contains entry.name if {
	some entry in runs.tasks
	some command in runs.commands(entry.task)
	scan_line(command, {})
}

scanning_tasks := graph.reachable(runs.callers, direct_scanning_tasks)

trivy_image := `(^|[\s;&|(/])trivy\s+(image|i)\s`

scan_line(line, env) if {
	regex.match(trivy_image, line)
	fails_on_findings(line, env)
	severity_covered(severity_flag(line))
}

fails_on_findings(line, _) if regex.match(`--exit-code[=\s]+["']?[1-9]`, line)

fails_on_findings(_, env) if nonzero(object.get(env, "TRIVY_EXIT_CODE", "0"))

# A configuration file may set the exit code; it is not read.
fails_on_findings(line, _) if regex.match(`\s(--config|-c)[=\s]+\S`, line)

nonzero(value) if {
	is_number(value)
	value != 0
}

nonzero(value) if {
	is_string(value)
	regex.match(`^\s*[1-9][0-9]*\s*$`, value)
}

default severity_flag(_) := ""

severity_flag(line) := match[1] if {
	some match in regex.find_all_string_submatch_n(`--severity[=\s]+["']?([A-Za-z,]+)`, line, 1)
}

# No severity scans at every level, HIGH and CRITICAL among them.
severity_covered("")

severity_covered(value) if {
	levels := {trim_space(level) | some level in split(upper(value), ",")}
	"HIGH" in levels
	"CRITICAL" in levels
}
