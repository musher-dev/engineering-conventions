# METADATA
# title: Dockerfile linting
# description: >-
#   A repository with a Dockerfile configures hadolint at
#   .config/docker/hadolint.yaml (IMAGE-07), pins it in mise (IMAGE-08),
#   runs it in lefthook's pre-commit hook on every staged Dockerfile
#   (IMAGE-09) and in a validate workflow (IMAGE-10). Whether each
#   Dockerfile passes is hadolint's to say (IMAGE-06, delegated).
# scope: package
# custom:
#   convention: EC-0040
package conventions.checks.container_images.hadolint

import data.conventions.lib.doublestar
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.images
import data.conventions.lib.mise
import data.conventions.lib.runs

config_paths := [".config/docker/hadolint.yaml", ".config/docker/hadolint.yml"]

# A Dockerfile to report against: the first, for a stable path.
first_dockerfile := sort(images.dockerfiles)[0]

# IMAGE-07
findings contains lib.finding("IMAGE-07", config_paths[0], message) if {
	count(images.dockerfiles) > 0
	not configured
	message := sprintf(
		concat(" ", [
			"the repository has Dockerfiles, such as %s, but no hadolint configuration; add %s",
			"(failure-threshold: warning, and each rule turned off with its reason), so every run",
			"judges a Dockerfile the same way",
		]),
		[first_dockerfile, config_paths[0]],
	)
}

# IMAGE-08
findings contains lib.finding("IMAGE-08", path, message) if {
	count(images.dockerfiles) > 0
	mise.configured
	not mise.pinned("hadolint")
	path := sort(object.keys(mise.configs))[0]
	message := concat(" ", [
		"the mise configuration does not pin hadolint, so the hook and CI can lint a Dockerfile with",
		"different releases; add \"aqua:hadolint/hadolint\" = \"<version>\" under [tools]",
	])
}

# IMAGE-09
findings contains lib.finding("IMAGE-09", path, hook_message) if {
	count(images.dockerfiles) > 0
	some path, config in lefthooks
	not hook_lints(config)
}

# IMAGE-10
findings contains lib.finding("IMAGE-10", first_dockerfile, message) if {
	count(images.dockerfiles) > 0
	not runs.validated(commands)
	message := concat(" ", [
		"no validate workflow lints the Dockerfiles; run `conventions hadolint`, or",
		"`hadolint --config .config/docker/hadolint.yaml` on every Dockerfile, in a validate workflow,",
		"directly or through a task, so a Dockerfile that breaks a rule cannot merge",
	])
}

configured if {
	some path in config_paths
	path in files.repository_files
}

# `conventions hadolint`, also as a path to the launcher; or hadolint with a
# configuration named on its command line, also through a runner such as
# `mise exec`. The configuration may be a task variable, such as
# {{.HADOLINT_CONFIG}}, which the check does not resolve.
commands := [
	`(?m)(^|[\s;&|(/])conventions\s+hadolint(\s|$)`,
	`(?m)(^|[\s;&|(/])hadolint\s[^;&|\n]*(--config|-c)[=\s]+["']?[^\s"']`,
]

lefthook_pattern := `^(\.?lefthook|\.config/lefthook)\.ya?ml$`

lefthooks[doc.path] := doc.contents if {
	some doc in files.own_documents
	regex.match(lefthook_pattern, doc.path)
	is_object(doc.contents)
}

# Every job in the pre-commit hook, at any depth of group nesting, that runs
# something.
pre_commit_jobs(config) := {node |
	is_object(config["pre-commit"])
	walk(config["pre-commit"], [_, node])
	is_object(node)
	is_string(node.run)
}

hook_lints(config) if {
	some job in pre_commit_jobs(config)
	runs.line_runs(commands, job.run)
	covers_dockerfiles(job)
}

# A job without a glob runs on every commit; one with a glob must match both
# a Dockerfile and a <name>.Dockerfile at any depth.
covers_dockerfiles(job) if not job.glob

covers_dockerfiles(job) if {
	every sample in ["api/docker/Dockerfile", "apps/web/docker/build.Dockerfile"] {
		some pattern in globs(job)
		doublestar.match(pattern, sample)
	}
}

globs(job) := [job.glob] if is_string(job.glob)

globs(job) := [pattern | some pattern in job.glob; is_string(pattern)] if is_array(job.glob)

hook_message := concat(" ", [
	"the pre-commit hook does not run hadolint with --config .config/docker/hadolint.yaml on every",
	"staged Dockerfile; add a job with glob \"**/{Dockerfile,*.Dockerfile}\" that runs",
	"hadolint --config .config/docker/hadolint.yaml {staged_files}",
])
