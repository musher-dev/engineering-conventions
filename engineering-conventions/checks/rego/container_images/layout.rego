# METADATA
# title: Container image layout
# description: >-
#   Every Dockerfile outside .devcontainer/ lives in a docker/ directory
#   (IMAGE-01), is named Dockerfile or <name>.Dockerfile (IMAGE-02), and has
#   its <Dockerfile>.dockerignore beside it (IMAGE-03); no .dockerignore is
#   committed outside .devcontainer/ (IMAGE-04), and compose files live in a
#   docker/ directory or .devcontainer/ (IMAGE-05). Files under a tests/ or
#   fixtures/ directory are test input and are not judged.
# scope: package
# custom:
#   convention: EC-0039
package conventions.checks.container_images.layout

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.images
import data.conventions.lib.paths

# IMAGE-01
findings contains lib.finding("IMAGE-01", path, message) if {
	some path in images.dockerfiles
	not in_dev_container(path)
	not in_docker_directory(path)
	message := sprintf(
		concat(" ", [
			"%s is not in a docker/ directory; move it to %sdocker/, with its ignore file and compose",
			"files, and point the build at it with -f",
		]),
		[path, paths.directory(path)],
	)
}

# IMAGE-02: a name Docker reads that is not Dockerfile or <name>.Dockerfile.
findings contains lib.finding("IMAGE-02", path, message) if {
	some path in images.dockerfiles
	name := files.basename(path)
	not conventional_name(name)
	message := sprintf(
		"%s is not a Dockerfile name editors and linters recognise; rename it to %s",
		[name, suggested_name(name)],
	)
}

# IMAGE-02: a bare Dockerfile beside named ones.
findings contains lib.finding("IMAGE-02", path, message) if {
	some path in images.dockerfiles
	files.basename(path) == "Dockerfile"
	directory := paths.directory(path)
	count({other | some other in images.dockerfiles; paths.directory(other) == directory}) > 1
	message := sprintf(
		"%s builds several images, so a bare Dockerfile does not say which; name it <name>.Dockerfile like the others",
		[directory],
	)
}

# IMAGE-03
findings contains lib.finding("IMAGE-03", path, message) if {
	some path in images.dockerfiles
	not in_dev_container(path)
	not ignore_file(path) in files.repository_files
	message := sprintf(
		concat(" ", [
			"%s has no %s beside it, so the build sends its whole context; add one that starts",
			"from * and lists what the image needs",
		]),
		[path, files.basename(ignore_file(path))],
	)
}

# IMAGE-04
findings contains lib.finding("IMAGE-04", path, context_root_message) if {
	some path in files.repository_files
	files.basename(path) == ".dockerignore"
	not in_dev_container(path)
	not images.fixture_path(path)
}

# IMAGE-05
findings contains lib.finding("IMAGE-05", path, message) if {
	some path in files.repository_files
	regex.match(compose_pattern, files.basename(path))
	not in_dev_container(path)
	not in_docker_directory(path)
	not images.fixture_path(path)
	message := sprintf(
		"%s runs an image, so it belongs beside the Dockerfile; move it to %sdocker/",
		[path, paths.directory(path)],
	)
}

compose_pattern := `^(docker-)?compose(\.[^/]+)?\.ya?ml$`

in_dev_container(path) if startswith(path, ".devcontainer/")

in_docker_directory(path) if regex.match(`(^|/)docker/[^/]+$`, path)

conventional_name("Dockerfile")

conventional_name(name) if regex.match(`^[a-z0-9][a-z0-9._-]*\.Dockerfile$`, name)

ignore_file(path) := concat("", [path, ".dockerignore"])

# Dockerfile.dev becomes dev.Dockerfile; anything else, Dockerfile.
suggested_name(name) := concat("", [lower(suffix), ".Dockerfile"]) if {
	parts := regex.find_all_string_submatch_n(`^(?i:docker|container)file\.([A-Za-z0-9_-]+)$`, name, 1)
	suffix := parts[0][1]
}

suggested_name(name) := "Dockerfile, or <name>.Dockerfile" if {
	not regex.match(`^(?i:docker|container)file\.[A-Za-z0-9_-]+$`, name)
}

context_root_message := concat(" ", [
	"a .dockerignore belongs to no image, and BuildKit skips it for a Dockerfile with its own",
	"ignore file; move its patterns into <Dockerfile>.dockerignore beside each Dockerfile",
])
