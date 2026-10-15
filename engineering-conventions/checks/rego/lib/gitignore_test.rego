package conventions.lib.gitignore_test

import data.conventions.lib.gitignore

test_slash_free_pattern_matches_at_any_depth if {
	gitignore.matches("*.sh", "a/b/c.sh")
	gitignore.matches(".env", "platform-api/.env")
	gitignore.matches("node_modules/", "web/node_modules/x/index.js")
	not gitignore.matches(".env", ".devcontainer/.env.example")
}

test_slash_anchors_the_pattern if {
	gitignore.matches("/platform-api/.env", "platform-api/.env")
	gitignore.matches("docs/*.md", "docs/a.md")
	not gitignore.matches("docs/*.md", "web/docs/a.md")
	not gitignore.matches("/.env", "platform-api/.env")
}

test_leading_double_star_matches_at_any_depth if {
	gitignore.matches("**/.env", "a/b/.env")
	not gitignore.matches("**/.env", "a/b/.env.example")
}
