package conventions.lib.paths_test

import data.conventions.lib.paths

test_directory if {
	paths.directory("CLAUDE.md") == ""
	paths.directory(".claude/CLAUDE.md") == ".claude/"
	paths.directory("apps/api/CLAUDE.md") == "apps/api/"
}

test_resolve_beside_the_file if {
	paths.resolve("CLAUDE.md", "README.md") == "README.md"
	paths.resolve("CLAUDE.md", "./README.md") == "README.md"
	paths.resolve("apps/api/CLAUDE.md", "docs/guide.md") == "apps/api/docs/guide.md"
}

test_resolve_parent_segments if {
	paths.resolve(".claude/CLAUDE.md", "../README.md") == "README.md"
	paths.resolve("apps/api/CLAUDE.md", "../../README.md") == "README.md"
	paths.resolve("apps/api/CLAUDE.md", "../web/./notes.md") == "apps/web/notes.md"
	paths.resolve("a/b/c/CLAUDE.md", "../x/../../y.md") == "a/y.md"
	paths.resolve("a/CLAUDE.md", "b/..") == "a"
	paths.resolve("CLAUDE.md", "..hidden/../x.md") == "x.md"
}

test_resolve_outside_the_repository if {
	paths.outside(paths.resolve("CLAUDE.md", "../README.md"))
	paths.outside(paths.resolve(".claude/CLAUDE.md", "../.."))
	not paths.outside(paths.resolve(".claude/CLAUDE.md", "../README.md"))
}
