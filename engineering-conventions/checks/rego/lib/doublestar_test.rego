package conventions.lib.doublestar_test

import data.conventions.lib.doublestar

test_expand_without_braces if {
	doublestar.expand("**/*.md") == {"**/*.md"}
}

test_expand_one_group if {
	doublestar.expand("*.{ts,md}") == {"*.ts", "*.md"}
}

test_expand_two_groups if {
	doublestar.expand("{src,lib}/*.{ts,js}") == {"src/*.ts", "src/*.js", "lib/*.ts", "lib/*.js"}
}

test_expand_keeps_a_path_inside_a_group if {
	doublestar.expand("apps/*/{package.json,biome.json}") == {"apps/*/package.json", "apps/*/biome.json"}
}

test_variants_drop_each_double_star if {
	doublestar.variants("a/**/b/**/c") == {"a/**/b/**/c", "a/b/**/c", "a/**/b/c", "a/b/c"}
}

test_variants_without_double_star if {
	doublestar.variants("*.md") == {"*.md"}
}

test_double_star_matches_the_root_and_nested if {
	doublestar.match("**/*.md", "README.md")
	doublestar.match("**/*.md", "docs/a/b.md")
}

test_single_star_stays_in_one_segment if {
	doublestar.match("*.md", "README.md")
	not doublestar.match("*.md", "docs/guide.md")
}

test_braces_and_double_star_together if {
	doublestar.match(".github/**/*.{yml,yaml}", ".github/workflows/validate.yaml")
	doublestar.match("src/**/*.{ts,js}", "src/index.js")
	not doublestar.match("src/**/*.{ts,js}", "lib/index.js")
}

test_matches_any if {
	doublestar.matches_any("docs/*.md", {"README.md", "docs/guide.md"})
	not doublestar.matches_any("docs/*.md", {"README.md"})
}
