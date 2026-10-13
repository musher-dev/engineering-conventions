package conventions.lib.images_test

import data.conventions.lib.images
import data.conventions.lib.testdata_test as td

test_dockerfiles_by_every_name_docker_reads if {
	paths := [
		"api/docker/Dockerfile",
		"api/docker/worker.Dockerfile",
		"api/docker/Dockerfile.dev",
		"Containerfile",
		"web/dockerfile",
	]
	images.dockerfiles == {path | some path in paths} with input as [td.inventory(paths)]
}

test_dockerfiles_leave_out_ignore_files_and_test_input if {
	paths := [
		"api/docker/Dockerfile.dockerignore",
		"api/tests/docker/Dockerfile",
		"tests/fixtures/repos/case/Dockerfile",
		"README.md",
	]
	count(images.dockerfiles) == 0 with input as [td.inventory(paths)]
}

test_fixture_path if {
	images.fixture_path("tests/Dockerfile")
	images.fixture_path("api/fixtures/Dockerfile")
	not images.fixture_path("api/docker/Dockerfile")
}
