# METADATA
# title: Skills and subagents
# description: >-
#   The skills and subagents a repository gives Claude Code: frontmatter that
#   parses (AGENT-09; a Markdown file under .claude/agents/ without any is
#   documentation, not a subagent), skill frontmatter valid against the skill schema
#   (AGENT-10) with a name equal to its directory (AGENT-11), subagent
#   frontmatter valid against the subagent schema (AGENT-12), and preloaded
#   skills that exist (AGENT-13) and that the model may invoke (AGENT-14).
# scope: package
# custom:
#   convention: EC-0034
package conventions.checks.agents.skills_and_subagents

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.schema
import data.conventions.lib.text

# AGENT-09: a skill with no frontmatter at all. A subagent file without any
# is not a subagent, and is not in agent_files.
findings contains lib.finding("AGENT-09", path, no_frontmatter) if {
	some path, content in agent_files
	not text.has_frontmatter(content)
}

# AGENT-09: frontmatter that is not YAML. Every other requirement here reads
# the parsed frontmatter, so they all stay silent until this one is fixed.
findings contains lib.finding("AGENT-09", path, unparsed_frontmatter) if {
	some path, content in agent_files
	text.has_frontmatter(content)
	not text.frontmatter(content)
}

# AGENT-10
findings contains lib.finding("AGENT-10", path, message) if {
	some path, _ in skill_files
	problems := schema.problems_of(
		[frontmatter(path)],
		data.conventions.index.skill_frontmatter_schema,
		"the frontmatter",
	)
	count(problems) > 0
	message := sprintf("%s %s", [schema.summary_of(problems, "the frontmatter"), skill_fields])
}

# AGENT-11
findings contains lib.finding("AGENT-11", path, message) if {
	some path, directory in skill_files
	name := frontmatter(path).name
	is_string(name)
	name != directory
	message := sprintf(
		"the skill's name is %q but its directory is %s; set name: %s, or rename the directory to %s",
		[name, directory, directory, name],
	)
}

# AGENT-12
findings contains lib.finding("AGENT-12", path, message) if {
	some path in subagent_files
	problems := schema.problems_of(
		[frontmatter(path)],
		data.conventions.index.subagent_frontmatter_schema,
		"the frontmatter",
	)
	count(problems) > 0
	message := sprintf("%s %s", [schema.summary_of(problems, "the frontmatter"), subagent_fields])
}

# AGENT-13
findings contains lib.finding("AGENT-13", path, message) if {
	some path in subagent_files
	some name in preloads(path)
	not name in skill_names
	message := sprintf(
		concat(" ", [
			"skills: lists %s, but no .claude/skills/%s/SKILL.md exists and no skill is named %s,",
			"so Claude Code skips it without a warning; correct the name or remove the entry",
		]),
		[name, name, name],
	)
}

# AGENT-14
findings contains lib.finding("AGENT-14", path, message) if {
	some path in subagent_files
	some name in preloads(path)
	some skill, _ in skill_files
	name in names(skill)
	invocation_disabled(frontmatter(skill)["disable-model-invocation"])
	message := sprintf(
		concat(" ", [
			"skills: lists %s, but %s sets disable-model-invocation: true, so Claude Code cannot preload it;",
			"remove the entry, or let the model invoke the skill",
		]),
		[name, skill],
	)
}

no_frontmatter := concat(" ", [
	"the skill has no YAML frontmatter, so Claude Code takes its first line as the description it chooses",
	"the skill by; start it with a --- block that sets description:",
])

unparsed_frontmatter := concat(" ", [
	"the frontmatter is not valid YAML, so a strict parser cannot read it and nothing in it can be checked;",
	"quote any value that contains \": \", such as description: \"Use when ... Triggered by: ...\",",
	"or write it as a folded block (description: >-)",
])

skill_fields := concat(" ", [
	"Give the field the shape checks/schemas/skill-frontmatter.schema.json lists for it, or remove it",
])

subagent_fields := concat(" ", [
	"Give the field the shape checks/schemas/subagent-frontmatter.schema.json lists for it,",
	"or remove it",
])

# A skill is .claude/skills/<directory>/SKILL.md, at the root or in a nested
# directory of a monorepo, which Claude Code loads when it works there.
skill_pattern := `(^|/)\.claude/skills/([^/]+)/SKILL\.md$`

# Claude Code reads a Markdown file below .claude/agents/ as a subagent when
# it has frontmatter; one without, such as a README, is documentation.
subagent_pattern := `(^|/)\.claude/agents/.+\.md$`

# Each skill's path, mapped to its directory's name.
skill_files[path] := match[2] if {
	some path in files.repository_files
	some match in regex.find_all_string_submatch_n(skill_pattern, path, 1)
}

subagent_files contains path if {
	some path in files.repository_files
	regex.match(subagent_pattern, path)
	text.has_frontmatter(files.texts[path])
}

# The text of every skill and subagent the runner embedded; a file over its
# size limit is not judged.
agent_files[path] := files.texts[path] if some path, _ in skill_files

agent_files[path] := files.texts[path] if some path in subagent_files

frontmatter(path) := text.frontmatter(agent_files[path])

# The names a skill answers to: its directory, and its frontmatter name.
names(path) := {skill_files[path]} | {name |
	name := frontmatter(path).name
	is_string(name)
}

skill_names contains name if {
	some path, _ in skill_files
	some name in names(path)
}

# `skills` is a list, or one comma-separated string as `tools` is. A plugin's
# skill is named plugin:skill and lives outside the repository, so it cannot
# be checked here.
preloads(path) := {name |
	some entry in entries(frontmatter(path).skills)
	name := trim_space(entry)
	name != ""
	not contains(name, ":")
}

entries(value) := split(value, ",") if is_string(value)

entries(value) := [entry | some entry in value; is_string(entry)] if is_array(value)

# Claude Code reads these spellings as true; YAML gives true and 1 as values.
invocation_disabled(true)

invocation_disabled(1)

invocation_disabled(value) if value in {"true", "yes", "on", "1"}
