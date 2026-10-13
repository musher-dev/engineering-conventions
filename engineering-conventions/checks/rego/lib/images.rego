# METADATA
# title: Container image files
# description: >-
#   The Dockerfiles a repository holds, by any name Docker reads, less the
#   test input under a tests/ or fixtures/ directory (EC-0039, EC-0040,
#   DEPS-12), and the jobs that publish an image (OUT-14, IMAGE-11,
#   IMAGE-12).
package conventions.lib.images

import data.conventions.lib.filenames
import data.conventions.lib.files
import data.conventions.lib.steps

# Every Dockerfile that is not test input. The pattern is the runner's
# (bin/conventions DOCKERFILES), less the BuildKit ignore file named after a
# Dockerfile.
dockerfiles contains path if {
	some path in files.repository_files
	regex.match(`^([^/]+\.)?([Dd]ockerfile|[Cc]ontainerfile)(\.[A-Za-z0-9_-]+)?$`, files.basename(path))
	not endswith(path, ".dockerignore")
	not fixture_path(path)
}

fixture_path(path) if regex.match(`(^|/)(tests|fixtures)/`, path)

# --- Publishing an image -------------------------------------------------

# The responsibility tokens of the workflows that publish (EC-0002): an
# image built in a validate workflow is checked, not published.
delivery_tokens := {"release", "publish", "deploy"}

# Each job of a release, publish or deploy workflow that pushes an image to
# a registry, as {"path", "job_id", "job", "workflow", "push"}: push is the
# index of its first pushing step.
pushing_jobs contains {"path": path, "job_id": job_id, "job": job, "workflow": workflow, "push": first} if {
	some path, workflow in files.workflows
	filenames.slot(files.stem(path)) in delivery_tokens
	some job_id, job in files.jobs(workflow)
	indexes := [index | some index, step in files.steps(job); pushes(step)]
	count(indexes) > 0
	first := min(indexes)
}

# A step that pushes an image: docker/build-push-action or
# docker/bake-action with push true or an expression, or a run: line that
# runs docker push or a build with --push. A push to a registry on the
# runner itself (localhost) publishes nothing.
pushes(step) if {
	steps.action(step) in {"docker/build-push-action", "docker/bake-action"}
	pushing(steps.inputs(step).push)
}

pushes(step) if {
	some line in steps.command_lines(step)
	push_line(line)
	not regex.match(`(^|[\s/=])(localhost|127\.0\.0\.1)(:\d+)?/`, line)
}

pushing(true)

pushing("true")

pushing(value) if {
	is_string(value)
	contains(value, "${{")
}

push_line(line) if regex.match(`(^|[\s;&|(])docker\s+(image\s+)?push\s`, line)

push_line(line) if regex.match(`(^|[\s;&|(])docker\s+(buildx\s+)?(build|bake)\s(.*\s)?--push(\s|=|$)`, line)

# The steps that attest an image's provenance and push the attestation to
# the registry beside it: actions/attest or actions/attest-build-provenance
# with push-to-registry true.
attest_actions := {"actions/attest", "actions/attest-build-provenance"}

registry_attestation(step) if {
	steps.action(step) in attest_actions
	steps.inputs(step)["push-to-registry"] in {true, "true"}
}
