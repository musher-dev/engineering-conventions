package conventions.checks.agents.skills_and_subagents_test

import data.conventions.checks.agents.skills_and_subagents as checks
import data.conventions.lib.testdata_test as td

skill_path := ".claude/skills/writing-commits/SKILL.md"

agent_path := ".claude/agents/reviewer.md"

skill := "---\nname: writing-commits\ndescription: Draft commit messages.\n---\n\n# Writing commits\n"

agent := "---\nname: reviewer\ndescription: Reviews code.\nskills:\n  - writing-commits\n---\n\nYou review code.\n"

conforming := {
	skill_path: skill,
	".claude/skills/writing-commits/references/guide.md": "# Guide\n",
	agent_path: agent,
}

# The runner's inventory: every path, and the text of each skill and subagent.
repo(texts) := repo_embedding(texts, {path | some path, _ in texts; embedded(path)})

repo_embedding(texts, embedded_paths) := [td.file("/tmp/inventory.json", {"conventions_inventory": {
	"files": [path | some path, _ in texts],
	"texts": {path: texts[path] | some path in embedded_paths},
}})]

embedded(path) if endswith(path, "/SKILL.md")

embedded(path) if contains(path, ".claude/agents/")

with_files(extra) := object.union(conforming, extra)

with_skill(content) := with_files({skill_path: content})

with_agent(content) := with_files({agent_path: content})

test_conforming if {
	count(checks.findings) == 0 with input as repo(conforming)
		with data.conventions.index as td.index
}

test_no_skills_or_subagents if {
	count(checks.findings) == 0 with input as repo({"README.md": "# Project\n"})
		with data.conventions.index as td.index
}

test_agent_09_no_frontmatter if {
	result := checks.findings with input as repo(with_skill("# Writing commits\n\nDraft commit messages.\n"))
		with data.conventions.index as td.index
	td.pairs(result) == {["AGENT-09", skill_path]}
	{f.message | some f in result} == {concat(" ", [
		"the skill has no YAML frontmatter, so Claude Code takes its first line as the description it chooses",
		"the skill by; start it with a --- block that sets description:",
	])}
}

test_agent_09_a_document_among_subagents_is_not_one if {
	count(checks.findings) == 0 with input as repo(with_files({".claude/agents/README.md": "# Our subagents\n"}))
		with data.conventions.index as td.index
}

test_agent_09_unquoted_colon if {
	broken := concat("\n", [
		"---",
		"name: writing-commits",
		"description: Draft messages. Triggered by: commit, PR title.",
		"---",
	])
	result := checks.findings with input as repo(with_skill(broken))
		with data.conventions.index as td.index
	td.pairs(result) == {["AGENT-09", skill_path]}
	some f in result
	contains(f.message, "quote any value")
}

test_agent_09_quoted_colon_passes if {
	quoted := concat("\n", [
		"---",
		"name: writing-commits",
		"description: \"Draft messages. Triggered by: commit, PR title.\"",
		"---",
	])
	count(checks.findings) == 0 with input as repo(with_skill(quoted))
		with data.conventions.index as td.index
}

test_agent_09_skips_files_too_large_to_embed if {
	texts := with_files({".claude/skills/huge/SKILL.md": "# no frontmatter\n"})
	inventory := repo_embedding(texts, {skill_path, agent_path})
	count(checks.findings) == 0 with input as inventory
		with data.conventions.index as td.index
}

test_agent_10_unknown_shell if {
	shelled := "---\nname: writing-commits\ndescription: Draft commit messages.\nshell: zsh\n---\n"
	result := checks.findings with input as repo(with_skill(shelled))
		with data.conventions.index as td.index
	td.pairs(result) == {["AGENT-10", skill_path]}
	some f in result
	endswith(f.message, "Give the field the shape checks/schemas/skill-frontmatter.schema.json lists for it, or remove it")
}

test_agent_10_unknown_fields_and_no_description_pass if {
	versioned := "---\nname: writing-commits\nversion: 1.0.0\nowner: \"@docs\"\n---\n"
	count(checks.findings) == 0 with input as repo(with_skill(versioned))
		with data.conventions.index as td.index
}

test_agent_12_unknown_fields_pass if {
	extra := "---\nname: reviewer\ndescription: Reviews code.\nversion: 2\n---\n"
	count(checks.findings) == 0 with input as repo(with_agent(extra))
		with data.conventions.index as td.index
}

test_agent_10_long_description if {
	long := sprintf("---\ndescription: %s\n---\n", [concat("", ["x" | some _ in numbers.range(1, 1025)])])
	result := checks.findings with input as repo(with_skill(long))
		with data.conventions.index as td.index
	td.pairs(result) == {["AGENT-10", skill_path]}
}

test_agent_11_name_differs_from_directory if {
	texts := object.union(with_skill("---\nname: commits\ndescription: Draft commit messages.\n---\n"), {
		agent_path: "---\nname: reviewer\ndescription: Reviews code.\n---\n",
	})
	result := checks.findings with input as repo(texts)
		with data.conventions.index as td.index
	td.pairs(result) == {["AGENT-11", skill_path]}
	{f.message | some f in result} == {concat(" ", [
		"the skill's name is \"commits\" but its directory is writing-commits; set name: writing-commits,",
		"or rename the directory to commits",
	])}
}

test_agent_11_nested_skill_directory if {
	nested := {"apps/web/.claude/skills/deploy/SKILL.md": "---\nname: deploy\ndescription: Deploy the web app.\n---\n"}
	count(checks.findings) == 0 with input as repo(with_files(nested))
		with data.conventions.index as td.index
}

test_agent_12_missing_description if {
	result := checks.findings with input as repo(with_agent("---\nname: reviewer\n---\n"))
		with data.conventions.index as td.index
	td.pairs(result) == {["AGENT-12", agent_path]}
}

test_agent_12_nested_subagent if {
	nested := {".claude/agents/review/security.md": "---\nname: review:security\ndescription: x\n---\n"}
	result := checks.findings with input as repo(with_files(nested))
		with data.conventions.index as td.index
	td.pairs(result) == {["AGENT-12", ".claude/agents/review/security.md"]}
}

test_agent_13_dangling_preload if {
	dangling := concat("\n", [
		"---",
		"name: reviewer",
		"description: Reviews code.",
		"skills: [writing-commits, auditing-python]",
		"---",
	])
	result := checks.findings with input as repo(with_agent(dangling))
		with data.conventions.index as td.index
	td.pairs(result) == {["AGENT-13", agent_path]}
	some f in result
	contains(f.message, "auditing-python")
}

test_agent_13_comma_separated_string if {
	listed := "---\nname: reviewer\ndescription: Reviews code.\nskills: writing-commits, auditing-python\n---\n"
	result := checks.findings with input as repo(with_agent(listed))
		with data.conventions.index as td.index
	td.pairs(result) == {["AGENT-13", agent_path]}
	count(result) == 1
}

test_agent_13_resolves_by_frontmatter_name if {
	texts := {
		".claude/skills/commits/SKILL.md": "---\ndescription: Draft commit messages.\n---\n",
		".claude/skills/other/SKILL.md": "---\nname: other\ndescription: x\n---\n",
		agent_path: "---\nname: reviewer\ndescription: x\nskills: [commits, other]\n---\n",
	}
	count(checks.findings) == 0 with input as repo(texts)
		with data.conventions.index as td.index
}

test_agent_13_skips_plugin_skills if {
	plugin := "---\nname: reviewer\ndescription: Reviews code.\nskills:\n  - stripe:stripe-docs\n---\n"
	count(checks.findings) == 0 with input as repo(with_agent(plugin))
		with data.conventions.index as td.index
}

test_agent_14_preloads_a_manual_skill if {
	manual := concat("\n", [
		"---",
		"name: writing-commits",
		"description: Draft commit messages.",
		"disable-model-invocation: true",
		"---",
	])
	result := checks.findings with input as repo(with_skill(manual))
		with data.conventions.index as td.index
	td.pairs(result) == {["AGENT-14", agent_path]}
}

test_agent_14_false_passes if {
	invocable := concat("\n", [
		"---",
		"name: writing-commits",
		"description: Draft commit messages.",
		"disable-model-invocation: false",
		"---",
	])
	count(checks.findings) == 0 with input as repo(with_skill(invocable))
		with data.conventions.index as td.index
}

test_invocation_disabled_spellings if {
	checks.invocation_disabled(true)
	checks.invocation_disabled(1)
	checks.invocation_disabled("yes")
	not checks.invocation_disabled(false)
	not checks.invocation_disabled("no")
}
