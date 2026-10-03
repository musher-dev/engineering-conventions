package conventions.checks.container_images.hadolint_test

import data.conventions.checks.container_images.hadolint
import data.conventions.lib.testdata_test as td

config := ".config/docker/hadolint.yaml"

mise_pinned := td.file(".config/mise/config.toml", {"tools": {"aqua:hadolint/hadolint": "2.15.1"}})

mise_unpinned := td.file(".config/mise/config.toml", {"tools": {"aqua:jqlang/jq": "1.8.2"}})

validate(run) := td.file(".github/workflows/validate.yml", {
	"name": "Validate",
	"on": {"pull_request": {}},
	"jobs": {"lint": {"runs-on": "ubuntu-24.04", "steps": [{"name": "Lint", "run": run}]}},
})

lefthook(job) := td.file(".config/lefthook.yml", {"pre-commit": {"jobs": [job]}})

good_job := {
	"name": "dockerfile",
	"glob": "**/{Dockerfile,*.Dockerfile}",
	"run": "hadolint --config .config/docker/hadolint.yaml {staged_files}",
}

paths := [".devcontainer/Dockerfile", config, ".config/mise/config.toml", ".config/lefthook.yml"]

repo(extra, listed) := array.concat(extra, [td.inventory(listed)])

conforming := repo(
	[mise_pinned, lefthook(good_job), validate("hadolint --config .config/docker/hadolint.yaml .devcontainer/Dockerfile")],
	paths,
)

test_conforming if {
	count(hadolint.findings) == 0 with input as conforming
}

test_no_dockerfile_asks_nothing if {
	count(hadolint.findings) == 0 with input as repo([mise_unpinned, lefthook({"run": "true"})], ["README.md"])
}

test_test_input_is_not_a_dockerfile if {
	count(hadolint.findings) == 0 with input as repo([], ["tests/molecule/Dockerfile"])
}

test_image_07_no_configuration if {
	listed := [path | some path in paths; path != config]
	docs := repo([mise_pinned, lefthook(good_job), validate("conventions hadolint")], listed)
	found := hadolint.findings with input as docs
	td.pairs(found) == {["IMAGE-07", config]}
}

test_image_07_yml_counts if {
	listed := array.concat([path | some path in paths; path != config], [".config/docker/hadolint.yml"])
	docs := repo([mise_pinned, lefthook(good_job), validate("conventions hadolint")], listed)
	count(hadolint.findings) == 0 with input as docs
}

test_image_08_unpinned if {
	docs := repo([mise_unpinned, lefthook(good_job), validate("conventions hadolint")], paths)
	found := hadolint.findings with input as docs
	td.pairs(found) == {["IMAGE-08", ".config/mise/config.toml"]}
}

test_image_08_without_mise if {
	docs := repo([lefthook(good_job), validate("conventions hadolint")], paths)
	count(hadolint.findings) == 0 with input as docs
}

test_image_09_glob_misses_named if {
	job := object.union(good_job, {"glob": "**/Dockerfile"})
	docs := repo([mise_pinned, lefthook(job), validate("conventions hadolint")], paths)
	found := hadolint.findings with input as docs
	td.pairs(found) == {["IMAGE-09", ".config/lefthook.yml"]}
}

test_image_09_glob_list if {
	job := object.union(good_job, {"glob": ["**/Dockerfile", "**/*.Dockerfile"]})
	docs := repo([mise_pinned, lefthook(job), validate("conventions hadolint")], paths)
	count(hadolint.findings) == 0 with input as docs
}

test_image_09_without_config if {
	job := object.union(good_job, {"run": "hadolint {staged_files}"})
	docs := repo([mise_pinned, lefthook(job), validate("conventions hadolint")], paths)
	found := hadolint.findings with input as docs
	td.pairs(found) == {["IMAGE-09", ".config/lefthook.yml"]}
}

test_image_09_in_a_group if {
	grouped := td.file(".config/lefthook.yml", {"pre-commit": {"jobs": [{"group": {"jobs": [good_job]}}]}})
	docs := repo([mise_pinned, grouped, validate("conventions hadolint")], paths)
	count(hadolint.findings) == 0 with input as docs
}

test_image_09_other_hook_does_not_count if {
	pushed := td.file(".config/lefthook.yml", {"pre-push": {"jobs": [good_job]}})
	docs := repo([mise_pinned, pushed, validate("conventions hadolint")], paths)
	found := hadolint.findings with input as docs
	td.pairs(found) == {["IMAGE-09", ".config/lefthook.yml"]}
}

test_image_10_not_validated if {
	docs := repo([mise_pinned, lefthook(good_job), validate("task test")], paths)
	found := hadolint.findings with input as docs
	td.pairs(found) == {["IMAGE-10", ".devcontainer/Dockerfile"]}
}

test_image_10_through_a_task if {
	taskfile := td.file("Taskfile.yml", {"version": "3", "tasks": {
		"lint:docker": {"cmds": ["git ls-files -z '*Dockerfile' | xargs -0 -r hadolint -c .config/docker/hadolint.yaml"]},
		"check": {"cmds": [{"task": "lint:docker"}]},
	}})
	extra := [mise_pinned, lefthook(good_job), validate("task check"), taskfile]
	docs := repo(extra, array.concat(paths, ["Taskfile.yml"]))
	count(hadolint.findings) == 0 with input as docs
}

test_image_10_configuration_in_a_variable if {
	taskfile := td.file("Taskfile.yml", {"version": "3", "tasks": {"lint:docker": {"cmds": [
		"{{.LIST_FILES}} '**/Dockerfile' | xargs -0 -r hadolint --config {{.HADOLINT_CONFIG}}",
	]}}})
	extra := [mise_pinned, lefthook(good_job), validate("task lint:docker"), taskfile]
	docs := repo(extra, array.concat(paths, ["Taskfile.yml"]))
	count(hadolint.findings) == 0 with input as docs
}

test_image_10_without_a_configuration if {
	docs := repo([mise_pinned, lefthook(good_job), validate("hadolint .devcontainer/Dockerfile")], paths)
	found := hadolint.findings with input as docs
	td.pairs(found) == {["IMAGE-10", ".devcontainer/Dockerfile"]}
}
