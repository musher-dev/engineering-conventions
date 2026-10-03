package conventions.checks.agents.agent_context_test

import data.conventions.checks.agents.agent_context
import data.conventions.lib.testdata_test as td

rule := "---\npaths:\n  - \"src/**\"\n---\n\n# Source\n"

memory := "# Project\n\n@README.md\n\nThe contract.\n"

# A repository conforming to every requirement: a root AGENTS.md that
# imports its README, and a path-scoped rule.
conforming := {
	"AGENTS.md": memory,
	"README.md": "# Project\n",
	".claude/rules/source.md": rule,
}

# The runner's inventory: every path, the text of each agent-context file
# and the size of each Markdown file.
repo(texts) := repo_with_sizes(texts, {path: count(content) |
	some path, content in texts
	endswith(path, ".md")
})

repo_with_sizes(texts, sizes) := [td.file("/tmp/inventory.json", {"conventions_inventory": {
	"files": [path | some path, _ in texts],
	"texts": {path: content | some path, content in texts; embedded(path)},
	"sizes": sizes,
}})]

embedded(path) if endswith(path, "CLAUDE.md")

embedded(path) if endswith(path, "AGENTS.md")

embedded(path) if startswith(path, ".claude/rules/")

with_files(extra) := object.union(conforming, extra)

test_conforming if {
	count(agent_context.findings) == 0 with input as repo(conforming)
}

test_no_agent_context if {
	count(agent_context.findings) == 0 with input as repo({"README.md": "# Project\n"})
}

test_agent_15_rule_without_agents_md if {
	found := agent_context.findings with input as repo(object.remove(conforming, ["AGENTS.md"]))
	td.pairs(found) == {["AGENT-15", "AGENTS.md"]}
}

test_agent_15_nested_without_root if {
	texts := object.remove(with_files({"apps/api/AGENTS.md": "# API\n"}), ["AGENTS.md"])
	found := agent_context.findings with input as repo(texts)
	td.pairs(found) == {["AGENT-15", "AGENTS.md"]}
}

test_agent_15_dot_claude_agents_md if {
	found := agent_context.findings with input as repo(with_files({".claude/AGENTS.md": "x\n"}))
	td.pairs(found) == {["AGENT-15", ".claude/AGENTS.md"]}
}

test_agent_15_nested_agents_md_passes if {
	texts := with_files({"apps/api/AGENTS.md": "# API\n"})
	count(agent_context.findings) == 0 with input as repo(texts)
}

test_agent_16_claude_md_anywhere if {
	texts := with_files({"CLAUDE.md": "@AGENTS.md\n", ".claude/CLAUDE.md": "x\n", "apps/api/CLAUDE.md": "# API\n"})
	found := agent_context.findings with input as repo(texts)
	{p | some p in td.pairs(found); p[0] == "AGENT-16"} == {
		["AGENT-16", "CLAUDE.md"],
		["AGENT-16", ".claude/CLAUDE.md"],
		["AGENT-16", "apps/api/CLAUDE.md"],
	}
}

test_agent_16_claude_md_alone_also_needs_agents_md if {
	texts := object.remove(with_files({"CLAUDE.md": memory}), ["AGENTS.md"])
	found := agent_context.findings with input as repo(texts)
	td.pairs(found) == {["AGENT-15", "AGENTS.md"], ["AGENT-16", "CLAUDE.md"]}
}

test_agent_17_missing_readme_import if {
	found := agent_context.findings with input as repo(with_files({"AGENTS.md": "# Project\n\nSee README.md.\n"}))
	td.pairs(found) == {["AGENT-17", "AGENTS.md"]}
	{f.message | some f in found} == {concat(" ", [
		"AGENTS.md does not import README.md; add the line @README.md so the orientation is",
		"written once, in the README",
	])}
}

test_agent_17_nested_pair if {
	texts := with_files({"apps/api/AGENTS.md": "# API\n", "apps/api/README.md": "# API\n"})
	found := agent_context.findings with input as repo(texts)
	td.pairs(found) == {["AGENT-17", "apps/api/AGENTS.md"]}
	fixed := object.union(texts, {"apps/api/AGENTS.md": "@./README.md\n"})
	count(agent_context.findings) == 0 with input as repo(fixed)
}

test_agent_17_standalone_agents_md if {
	count(agent_context.findings) == 0 with input as repo(with_files({"apps/api/AGENTS.md": "# API\n"}))
}

test_agent_17_import_in_code_does_not_count if {
	texts := with_files({"AGENTS.md": "Write `@README.md` to import.\n"})
	found := agent_context.findings with input as repo(texts)
	td.pairs(found) == {["AGENT-17", "AGENTS.md"]}
}

test_agent_03_rule_without_paths if {
	texts := with_files({".claude/rules/everywhere.md": "# Everywhere\n"})
	found := agent_context.findings with input as repo(texts)
	td.pairs(found) == {["AGENT-03", ".claude/rules/everywhere.md"]}
}

test_agent_03_empty_or_unparsed_paths if {
	texts := with_files({
		".claude/rules/empty.md": "---\npaths: []\n---\n",
		".claude/rules/blank.md": "---\npaths: [\"  \"]\n---\n",
		".claude/rules/other.md": "---\ndescription: x\n---\n",
		".claude/rules/broken.md": "---\npaths: [unclosed\n---\n",
		".claude/rules/nested/deep.md": "no frontmatter\n",
	})
	found := agent_context.findings with input as repo(texts)
	{f.path | some f in found; f.id == "AGENT-03"} == {
		".claude/rules/empty.md",
		".claude/rules/blank.md",
		".claude/rules/other.md",
		".claude/rules/broken.md",
		".claude/rules/nested/deep.md",
	}
}

test_agent_03_comma_separated_string if {
	texts := with_files({".claude/rules/csv.md": "---\npaths: \"src/**, lib/**\"\n---\n"})
	count(agent_context.findings) == 0 with input as repo(texts)
}

test_agent_03_quiet_without_text if {
	found := agent_context.findings with input as [td.inventory([".claude/rules/huge.md", "AGENTS.md"])]
	count(found) == 0
}

test_agent_04_over_budget_through_imports if {
	texts := with_files({
		"AGENTS.md": "@README.md\n@docs/guide.md\n",
		"docs/guide.md": "# Guide\n",
		".claude/rules/everywhere.md": "# Everywhere\n",
	})
	sizes := {"AGENTS.md": 1000, "README.md": 20000, "docs/guide.md": 20000, ".claude/rules/everywhere.md": 5000}
	found := agent_context.findings with input as repo_with_sizes(texts, sizes)
	td.pairs(found) == {["AGENT-03", ".claude/rules/everywhere.md"], ["AGENT-04", "AGENTS.md"]}
	some f in found
	f.id == "AGENT-04"
	contains(f.message, "is 46000 bytes, over the 40960-byte budget")
	contains(f.message, "docs/guide.md (20000 bytes)")
}

test_agent_04_counts_claude_md_when_committed if {
	texts := with_files({"CLAUDE.md": "# Claude\n"})
	loaded := agent_context.always_loaded with input as repo(texts)
	loaded == {"CLAUDE.md"}
}

test_agent_04_follows_imports_four_hops if {
	texts := with_files({
		"AGENTS.md": "@README.md\n@a/AGENTS.md\n",
		"a/AGENTS.md": "@../b/AGENTS.md\n",
		"b/AGENTS.md": "@../c/AGENTS.md\n",
		"c/AGENTS.md": "@../d/AGENTS.md\n",
		"d/AGENTS.md": "@../e/AGENTS.md\n",
		"e/AGENTS.md": "# Five hops\n",
	})
	sizes := {"d/AGENTS.md": 30000, "e/AGENTS.md": 30000}
	loaded := agent_context.always_loaded with input as repo_with_sizes(texts, sizes)
	"d/AGENTS.md" in loaded
	not "e/AGENTS.md" in loaded
	count(agent_context.findings) == 0 with input as repo_with_sizes(texts, sizes)
}

test_agent_04_home_and_outside_imports_do_not_count if {
	texts := with_files({"AGENTS.md": "@README.md\n@~/.claude/mine.md\n"})
	loaded := agent_context.always_loaded with input as repo(texts)
	loaded == {"AGENTS.md", "README.md"}
}

test_agent_04_unconditional_rules_alone if {
	texts := {".claude/rules/a.md": "# A\n", "AGENTS.md": "# Project\n"}
	sizes := {".claude/rules/a.md": 50000}
	found := agent_context.findings with input as repo_with_sizes(texts, sizes)
	td.pairs(found) == {["AGENT-03", ".claude/rules/a.md"], ["AGENT-04", "AGENTS.md"]}
}

test_agent_18_unresolved_import if {
	texts := with_files({"AGENTS.md": "@README.md\nAsk @octocat, use @testing-library, or read @docs/gone.md.\n"})
	found := agent_context.findings with input as repo(texts)
	td.pairs(found) == {["AGENT-18", "AGENTS.md"]}
	{f.message | some f in found} == {concat(" ", [
		"@docs/gone.md does not name a file in the repository; correct the path, or put the text",
		"in backticks if it is not meant as an import",
	])}
}

test_agent_18_outside_the_repository if {
	texts := with_files({"AGENTS.md": "@README.md\n@../README.md\n@~/.claude/mine.md\n"})
	found := agent_context.findings with input as repo(texts)
	td.pairs(found) == {["AGENT-18", "AGENTS.md"]}
}

test_agent_18_nested_resolves_from_its_directory if {
	texts := with_files({"apps/api/AGENTS.md": "@docs/api.md\n", "apps/api/docs/api.md": "# API\n"})
	count(agent_context.findings) == 0 with input as repo(texts)
}

test_agent_07_personal_files if {
	texts := with_files({".claude/settings.local.json": "{}", "apps/CLAUDE.local.md": "mine\n"})
	found := agent_context.findings with input as repo(texts)
	td.pairs(found) == {["AGENT-07", ".claude/settings.local.json"], ["AGENT-07", "apps/CLAUDE.local.md"]}
}
