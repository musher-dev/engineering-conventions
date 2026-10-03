# METADATA
# title: Container image files
# description: >-
#   The Dockerfiles a repository holds, by any name Docker reads, less the
#   test input under a tests/ or fixtures/ directory (EC-0039, EC-0040,
#   DEPS-12).
package conventions.lib.images

import data.conventions.lib.files

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
