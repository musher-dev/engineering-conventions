# METADATA
# title: Agent context
# description: >-
#   The files that give a coding agent its instructions: one root AGENTS.md
#   as the project memory (AGENT-15), no CLAUDE.md (AGENT-16), the README
#   imported (AGENT-17), path-scoped rules (AGENT-03), a bounded
#   always-loaded context (AGENT-04), imports that resolve (AGENT-18), and
#   no personal agent files in git (AGENT-07). AGENT-01, 02, 05, 06 and 08
#   are retired.
# scope: package
# custom:
#   convention: EC-0013
package conventions.checks.agents.agent_context

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.paths
import data.conventions.lib.text

# AGENT-03
findings contains lib.finding("AGENT-03", path, unscoped_message) if {
	some path in unconditional_rules
}

# AGENT-04
findings contains lib.finding("AGENT-04", budget_path, message) if {
	always_loaded_bytes > budget
	listing := concat(", ", [sprintf("%s (%d bytes)", [path, size(path)]) | some path in sort(always_loaded)])
	message := sprintf(
		concat(" ", [
			"the context Claude Code loads at every launch is %d bytes, over the %d-byte budget: %s;",
			"move content into path-scoped rules, or trim the project memory and what it imports",
		]),
		[always_loaded_bytes, budget, listing],
	)
}

# AGENT-15
findings contains lib.finding("AGENT-15", "AGENTS.md", message) if {
	count(instruction_files) > 0
	not "AGENTS.md" in files.repository_files
	message := concat(" ", [
		"the repository has agent context but no AGENTS.md at its root; add one as the project",
		"memory every coding agent reads, and import the README from it",
	])
}

findings contains lib.finding("AGENT-15", ".claude/AGENTS.md", message) if {
	".claude/AGENTS.md" in files.repository_files
	message := concat(" ", [
		"Claude Code loads .claude/AGENTS.md beside the root AGENTS.md, which splits the project",
		"memory in two; move what it says into the root AGENTS.md",
	])
}

# AGENT-16
findings contains lib.finding("AGENT-16", path, message) if {
	some path in files.repository_files
	files.basename(path) == "CLAUDE.md"
	message := sprintf(
		concat(" ", [
			"Claude Code reads %s and ignores every AGENTS.md while it exists; move what it says",
			"into the AGENTS.md beside it and delete it",
		]),
		[path],
	)
}

# AGENT-17
findings contains lib.finding("AGENT-17", path, message) if {
	some path, _ in memory_texts
	path != ".claude/AGENTS.md"
	readme := concat("", [paths.directory(path), "README.md"])
	readme in files.repository_files
	not readme in imports(path)
	message := sprintf(
		"%s does not import %s; add the line @README.md so the orientation is written once, in the README",
		[path, readme],
	)
}

# AGENT-18
findings contains lib.finding("AGENT-18", path, message) if {
	some path, content in memory_texts
	some written in text.imports(content)
	not startswith(written, "~")
	not resolves(paths.resolve(path, written))
	message := sprintf(
		concat(" ", [
			"@%s does not name a file in the repository; correct the path, or put the text in",
			"backticks if it is not meant as an import",
		]),
		[written],
	)
}

# AGENT-07
findings contains lib.finding("AGENT-07", path, message) if {
	some path in files.repository_files
	personal(path)
	message := sprintf(
		"%s is one person's local agent configuration; remove it from git and add it to .gitignore",
		[files.basename(path)],
	)
}

# What Claude Code loads as project memory at launch: the root AGENTS.md
# and .claude/AGENTS.md, unless a root CLAUDE.md or .claude/CLAUDE.md is
# committed, which it then reads instead (AGENT-16 reports those).
claude_memory contains path if {
	some path in ["CLAUDE.md", ".claude/CLAUDE.md"]
	path in files.repository_files
}

agents_memory contains path if {
	some path in ["AGENTS.md", ".claude/AGENTS.md"]
	path in files.repository_files
}

project_memory := claude_memory if count(claude_memory) > 0

project_memory := agents_memory if count(claude_memory) == 0

# Anything that gives a coding agent instructions: an AGENTS.md or a
# CLAUDE.md at any depth, or a rule.
instruction_files contains path if {
	some path in files.repository_files
	files.basename(path) in {"AGENTS.md", "CLAUDE.md"}
}

instruction_files contains path if {
	some path in files.repository_files
	regex.match(rule_pattern, path)
}

# Every AGENTS.md whose text the runner embedded, at any depth.
memory_texts[path] := content if {
	some path, content in files.texts
	files.basename(path) == "AGENTS.md"
}

# The repository paths a file imports. An import from the home directory
# (`@~/...`) is personal and outside the repository, so it is skipped.
imports(path) := {paths.resolve(path, target) |
	some target in text.imports(files.texts[path])
	not startswith(target, "~")
}

rule_pattern := `^\.claude/rules/.+\.md$`

# Claude Code reads `paths` as a list of globs or one comma-separated
# string; a rule whose frontmatter is missing or does not parse loads in
# every session. A rule whose text the runner did not embed is not judged.
unconditional_rules contains path if {
	some path in files.repository_files
	regex.match(rule_pattern, path)
	not scoped(files.texts[path])
}

scoped(content) if {
	value := text.frontmatter(content).paths
	is_string(value)
	trim_space(value) != ""
}

scoped(content) if {
	some pattern in text.frontmatter(content).paths
	is_string(pattern)
	trim_space(pattern) != ""
}

unscoped_message := concat(" ", [
	"the rule has no paths: frontmatter, so Claude Code loads it in every session; add a",
	"paths: list naming the files the rule governs",
])

# AGENT-04 counts what Claude Code loads at launch: the project memory, what
# it imports to four hops, and every rule without paths. Imports are
# followed through the files whose text the runner reads; a file that is
# not Markdown has no recorded size and counts as 0 bytes.
budget := 40960

hop(sources) := {target |
	some source in sources
	some target in imports(source)
	not paths.outside(target)
}

second_hop := hop(hop(project_memory))

third_hop := hop(second_hop)

imported := union({hop(project_memory), second_hop, third_hop, hop(third_hop)})

always_loaded := union({project_memory, imported, unconditional_rules})

default size(_) := 0

size(path) := files.sizes[path]

always_loaded_bytes := sum([size(path) | some path in always_loaded])

# The finding sits on the project memory file, or on the first rule when
# there is none.
budget_path := sort(project_memory)[0] if count(project_memory) > 0

budget_path := sort(unconditional_rules)[0] if count(project_memory) == 0

resolves(target) if {
	not paths.outside(target)
	target in files.all_files
}

personal(".claude/settings.local.json")

personal(path) if files.basename(path) == "CLAUDE.local.md"
