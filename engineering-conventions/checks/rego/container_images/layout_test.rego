package conventions.checks.container_images.layout_test

import data.conventions.checks.container_images.layout
import data.conventions.lib.testdata_test as td

repo(paths) := [td.inventory(paths)]

conforming := [
	"platform-api/go.mod",
	"platform-api/docker/Dockerfile",
	"platform-api/docker/Dockerfile.dockerignore",
	"platform-api/docker/compose.yaml",
	"platform-api/docker/compose.coolify.yaml",
	"apps/console/docker/build.Dockerfile",
	"apps/console/docker/build.Dockerfile.dockerignore",
	".devcontainer/Dockerfile",
	".devcontainer/.dockerignore",
	".devcontainer/stacks/postgres/compose.yaml",
	"tests/molecule/Dockerfile",
	"tests/fixtures/x/compose.yaml",
	"tests/fixtures/x/.dockerignore",
]

test_conforming if {
	count(layout.findings) == 0 with input as repo(conforming)
}

test_image_01_outside_docker if {
	paths := ["Dockerfile", "Dockerfile.dockerignore", "api/Dockerfile", "api/Dockerfile.dockerignore"]
	found := layout.findings with input as repo(paths)
	td.pairs(found) == {["IMAGE-01", "Dockerfile"], ["IMAGE-01", "api/Dockerfile"]}
	concat(" ", [
		"api/Dockerfile is not in a docker/ directory; move it to api/docker/, with its ignore file and compose",
		"files, and point the build at it with -f",
	]) in {f.message | some f in found}
}

test_image_01_docker_must_be_the_directory if {
	found := layout.findings with input as repo(["docker/api/Dockerfile", "docker/api/Dockerfile.dockerignore"])
	td.pairs(found) == {["IMAGE-01", "docker/api/Dockerfile"]}
}

test_image_02_suffix_names if {
	paths := [
		"api/docker/Dockerfile.dev", "api/docker/Dockerfile.dev.dockerignore",
		"api/docker/Containerfile", "api/docker/Containerfile.dockerignore",
	]
	found := layout.findings with input as repo(paths)
	{p | some p in td.pairs(found); p[0] == "IMAGE-02"} == {
		["IMAGE-02", "api/docker/Dockerfile.dev"],
		["IMAGE-02", "api/docker/Containerfile"],
	}
	concat(" ", [
		"Dockerfile.dev is not a Dockerfile name editors and linters recognise;",
		"rename it to dev.Dockerfile",
	]) in {f.message | some f in found}
}

test_image_02_bare_beside_named if {
	paths := [
		"tools/docker/Dockerfile", "tools/docker/Dockerfile.dockerignore",
		"tools/docker/worker.Dockerfile", "tools/docker/worker.Dockerfile.dockerignore",
	]
	found := layout.findings with input as repo(paths)
	td.pairs(found) == {["IMAGE-02", "tools/docker/Dockerfile"]}
}

test_image_02_named_alone_passes if {
	count(layout.findings) == 0 with input as repo(["a/docker/build.Dockerfile", "a/docker/build.Dockerfile.dockerignore"])
}

test_image_03_missing_ignore if {
	found := layout.findings with input as repo(["api/docker/Dockerfile", ".devcontainer/Dockerfile"])
	td.pairs(found) == {["IMAGE-03", "api/docker/Dockerfile"]}
}

test_image_04_context_root_ignore if {
	paths := ["api/docker/Dockerfile", "api/docker/Dockerfile.dockerignore", "api/.dockerignore", ".dockerignore"]
	found := layout.findings with input as repo(paths)
	td.pairs(found) == {["IMAGE-04", "api/.dockerignore"], ["IMAGE-04", ".dockerignore"]}
}

test_image_05_compose_outside if {
	paths := ["docker-compose.yml", "api/compose.yaml", "api/compose.override.yml", "api/docker/compose.yaml"]
	found := layout.findings with input as repo(paths)
	td.pairs(found) == {
		["IMAGE-05", "docker-compose.yml"],
		["IMAGE-05", "api/compose.yaml"],
		["IMAGE-05", "api/compose.override.yml"],
	}
}

test_image_05_not_compose if {
	count(layout.findings) == 0 with input as repo(["docs/compose-guide.md", "api/composer.yaml"])
}
