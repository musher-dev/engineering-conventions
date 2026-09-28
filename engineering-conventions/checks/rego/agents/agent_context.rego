# METADATA
# title: Agent context
# description: >-
#   The files that give a coding agent its instructions: one project memory
#   file (AGENT-01) that imports its README (AGENT-02), path-scoped rules
#   (AGENT-03), a bounded always-loaded context (AGENT-04), imports that
#   resolve (AGENT-05), one root AGENTS.md (AGENT-06), and no personal
#   agent files in git (AGENT-07).
# scope: package
# custom:
#   convention: EC-0013
package conventions.checks.agents.agent_context

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.paths
import data.conventions.lib.text

# AGENT-01
findings contains lib.finding("AGENT-01", ".claude/CLAUDE.md", message) if {
	count(project_memory) == 2
	message := concat(" ", [
		"the repository has both CLAUDE.md and .claude/CLAUDE.md, and Claude Code loads both as",
		"project memory; merge them into one of the two",
	])
}

# AGENT-02
findings contains lib.finding("AGENT-02", path, message) if {
	some path, _ in memory_texts
	readme := paired_readme(path)
	readme in files.repository_files
	not readme in imports(path)
	message := sprintf(
		"%s does not import %s; add the line @%s so the orientation is written once, in the README",
		[path, readme, import_token(path, readme)],
	)
}

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

# AGENT-05
findings contains lib.finding("AGENT-05", path, message) if {
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

# AGENT-06
findings contains lib.finding("AGENT-06", path, nested_message) if {
	some path in files.repository_files
	files.basename(path) == "AGENTS.md"
	path != "AGENTS.md"
}

findings contains lib.finding("AGENT-06", "AGENTS.md", message) if {
	count(project_memory) > 0
	not "AGENTS.md" in files.repository_files
	message := concat(" ", [
		"the repository has project memory but no AGENTS.md; add a root AGENTS.md that points",
		"coding agents other than Claude Code at it",
	])
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

# The two places Claude Code reads a project's memory from at launch.
project_memory_paths := ["CLAUDE.md", ".claude/CLAUDE.md"]

project_memory contains path if {
	some path in project_memory_paths
	path in files.repository_files
}

# Every CLAUDE.md whose text the runner embedded, at any depth.
memory_texts[path] := content if {
	some path, content in files.texts
	files.basename(path) == "CLAUDE.md"
}

# The repository paths a file imports. An import from the home directory
# (`@~/...`) is personal and outside the repository, so it is skipped.
imports(path) := {paths.resolve(path, target) |
	some target in text.imports(files.texts[path])
	not startswith(target, "~")
}

# AGENT-02 pairs the project memory file .claude/CLAUDE.md with the root
# README, and every other CLAUDE.md with the README beside it.
paired_readme(".claude/CLAUDE.md") := "README.md"

paired_readme(path) := concat("", [paths.directory(path), "README.md"]) if path != ".claude/CLAUDE.md"

import_token(".claude/CLAUDE.md", _) := "../README.md"

import_token(path, readme) := files.basename(readme) if path != ".claude/CLAUDE.md"

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

nested_message := concat(" ", [
	"an AGENTS.md below the root is a second set of agent instructions; move what it says",
	"into a CLAUDE.md or a path-scoped rule, and keep one AGENTS.md at the root",
])

personal(".claude/settings.local.json")

personal(path) if files.basename(path) == "CLAUDE.local.md"
