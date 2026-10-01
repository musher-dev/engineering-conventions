# METADATA
# title: Lefthook configuration
# description: >-
#   A lefthook configuration fails when lefthook is missing (HOOKS-01), pins
#   the version mise installs (HOOKS-02), matches globs with doublestar
#   (HOOKS-03) and anchors them (HOOKS-04), defines jobs (HOOKS-05) that say
#   how to fix a failure (HOOKS-06), restage only what they fix (HOOKS-07),
#   keep test runners out of pre-commit (HOOKS-08), federate nothing
#   (HOOKS-09), never swallow an exit code (HOOKS-10), and glob only files
#   that exist (HOOKS-11).
# scope: package
# custom:
#   convention: EC-0014
package conventions.checks.git_hooks.lefthook

import data.conventions.lib.doublestar
import data.conventions.lib.files
import data.conventions.lib.findings as lib

# The committed configurations lefthook reads: lefthook.yml, .lefthook.yml
# and .config/lefthook.yml. lefthook-local.yml is a personal override.
config_pattern := `^(\.?lefthook|\.config/lefthook)\.ya?ml$`

configs[doc.path] := doc.contents if {
	some doc in files.own_documents
	regex.match(config_pattern, doc.path)
	is_object(doc.contents)
}

# A hook is any top-level mapping; the settings that are mappings (colors,
# templates) hold no jobs, so nothing below reads them.
hooks contains [path, name, hook] if {
	some path, config in configs
	some name, hook in config
	is_object(hook)
}

# Every job of a hook, at any depth of group nesting, with its place in the
# hook: jobs[i], jobs[i].group.jobs[j], and so on.
jobs contains {"path": path, "hook": name, "trail": trail, "job": job} if {
	some [path, name, hook] in hooks
	is_array(hook.jobs)
	walk(hook, [trail, job])
	is_object(job)
	job_trail(trail)
}

job_trail(trail) if {
	count(trail) % 3 == 2
	every i, segment in trail {
		trail_segment(i % 3, segment)
	}
}

trail_segment(0, "jobs")

trail_segment(1, segment) if is_number(segment)

trail_segment(2, "group")

# A job that runs something, as opposed to a group of jobs.
leaf(job) if filled(job, "run")

leaf(job) if filled(job, "script")

# Whether a key holds a string that is not blank. `not filled(x, "k")` is
# true for a missing key, where a call on x.k would be undefined.
filled(mapping, key) if {
	is_string(mapping[key])
	trim_space(mapping[key]) != ""
}

label(entry) := sprintf("%s job %q", [entry.hook, entry.job.name]) if files.has_string(entry.job, "name")

label(entry) := sprintf("%s job at %s", [entry.hook, trail_text(entry.trail)]) if {
	not files.has_string(entry.job, "name")
}

trail_text(trail) := concat(".", [text |
	some i, segment in trail
	i % 3 != 1
	text := segment_text(trail, i, segment)
])

segment_text(trail, i, "jobs") := sprintf("jobs[%d]", [trail[i + 1]])

segment_text(_, _, "group") := "group"

# The shell a job runs, with `#` comments removed, so a comment explaining a
# rule does not trip it.
body(job) := regex.replace(job.run, `(?m)(^|\s)#[^\n]*`, "$1") if is_string(job.run)

default globs(_) := []

globs(job) := [job.glob] if is_string(job.glob)

globs(job) := [pattern | some pattern in job.glob; is_string(pattern)] if is_array(job.glob)

# The mise tool names lefthook is installed by (HOOKS-02).
tool_names := {
	"aqua:evilmartians/lefthook",
	"github:evilmartians/lefthook",
	"ubi:evilmartians/lefthook",
	"npm:lefthook",
	"lefthook",
}

# The lefthook version each mise configuration installs.
pins[path] := trim_prefix(version, "v") if {
	some doc in files.own_documents
	path := doc.path
	path in files.mise_config_paths
	some tool in tool_names
	version := pin_version(doc.contents.tools[tool])
}

pin_version(value) := value if is_string(value)

pin_version(value) := value.version if is_string(value.version)

# A command that only reports (HOOKS-07).
check_only_pattern := `(--check([^\w-]|$)|:check([^\w-]|$)|--dry-run|--exit-code)`

# A test runner, raw or as a task whose name is or ends in test (HOOKS-08).
runner_patterns := [
	`(^|[^\w./:-])(pytest|vitest|jest)([^\w.-]|$)`,
	`(^|[^\w./:-])(go\s+test|cargo\s+(test|nextest)|bun\s+test)([^\w-]|$)`,
	`(^|[^\w-])task(\s+[^\s;&|]+)*?\s+([\w-]+:)*test(:[\w-]+)*(\s|[;&|]|$)`,
]

# An exit code thrown away (HOOKS-10).
swallow_pattern := `(\|\|\s*(true|:|exit\s+0|echo)([^\w-]|$))|((^|[;&\s])set\s+\+e([^\w]|$))`

assert_message := concat(" ", [
	"assert_lefthook_installed is not true, so where the lefthook executable is missing",
	"the hooks skip without a word; set assert_lefthook_installed: true",
])

min_version_message := concat(" ", [
	"min_version is not set, so an older lefthook runs this file with whatever subset",
	"of it that version understands; set min_version to the lefthook version the repository installs",
])

glob_matcher_message := concat(" ", [
	"glob_matcher is not doublestar, so `**/` needs at least one directory and misses",
	"root files; set glob_matcher: doublestar",
])

# HOOKS-01
findings contains lib.finding("HOOKS-01", path, assert_message) if {
	some path, config in configs
	not config.assert_lefthook_installed == true
}

# HOOKS-02
findings contains lib.finding("HOOKS-02", path, min_version_message) if {
	some path, config in configs
	not filled(config, "min_version")
}

findings contains lib.finding("HOOKS-02", path, message) if {
	some path, config in configs
	is_string(config.min_version)
	declared := trim_prefix(config.min_version, "v")
	some mise_path, pinned in pins
	declared != pinned
	message := sprintf(
		"min_version is %q but %s installs lefthook %s; set min_version to %q so the floor is the version everyone runs",
		[config.min_version, mise_path, pinned, pinned],
	)
}

# HOOKS-03
findings contains lib.finding("HOOKS-03", path, glob_matcher_message) if {
	some path, config in configs
	not config.glob_matcher == "doublestar"
}

# HOOKS-04
findings contains lib.finding("HOOKS-04", entry.path, message) if {
	some entry in jobs
	some pattern in globs(entry.job)
	some alternative in doublestar.expand(pattern)
	regex.match(`[*?\[]`, alternative)
	not contains(alternative, "/")
	message := sprintf(
		"%s: glob %q matches only files at the repository root under doublestar; write %q to match at any depth",
		[label(entry), alternative, concat("", ["**/", alternative])],
	)
}

# HOOKS-05
findings contains lib.finding("HOOKS-05", path, message) if {
	some [path, name, hook] in hooks
	some key in {"commands", "scripts"}
	key in object.keys(hook)
	message := sprintf(
		"%s defines %s:, the form lefthook replaced; move each entry into jobs:, as run: or script:",
		[name, key],
	)
}

# HOOKS-06
findings contains lib.finding("HOOKS-06", entry.path, message) if {
	some entry in jobs
	leaf(entry.job)
	not filled(entry.job, "fail_text")
	message := sprintf(
		"%s has no fail_text; add one sentence saying what to run or change when it fails",
		[label(entry)],
	)
}

# HOOKS-07
findings contains lib.finding("HOOKS-07", entry.path, message) if {
	some entry in jobs
	entry.job.stage_fixed == true
	regex.match(check_only_pattern, body(entry.job))
	message := sprintf(
		"%s sets stage_fixed: true but only checks, so nothing is fixed to restage; run the fixing form or drop stage_fixed",
		[label(entry)],
	)
}

# HOOKS-08
findings contains lib.finding("HOOKS-08", entry.path, message) if {
	some entry in jobs
	entry.hook == "pre-commit"
	some pattern in runner_patterns
	regex.match(pattern, body(entry.job))
	message := sprintf(
		"%s runs tests, which is too slow for every commit; move it to pre-push or CI",
		[label(entry)],
	)
}

# HOOKS-09
findings contains lib.finding("HOOKS-09", path, message) if {
	some path, config in configs
	some key in {"remotes", "extends"}
	key in object.keys(config)
	message := sprintf(
		"%s: merges configuration from elsewhere into the hooks; write the jobs in this file",
		[key],
	)
}

# HOOKS-10
findings contains lib.finding("HOOKS-10", entry.path, message) if {
	some entry in jobs
	regex.match(swallow_pattern, body(entry.job))
	message := sprintf(
		"%s discards its command's exit code, so a failure passes; remove the || true (or set +e) and let it fail",
		[label(entry)],
	)
}

# HOOKS-11
findings contains lib.finding("HOOKS-11", entry.path, message) if {
	some entry in jobs
	some pattern in globs(entry.job)
	not doublestar.matches_any(pattern, files.repository_files)
	message := sprintf(
		"%s: glob %q matches no file in the repository, so the job never runs; correct the pattern or remove the job",
		[label(entry), pattern],
	)
}

# HOOKS-12. lefthook restages only in pre-commit.
findings contains lib.finding("HOOKS-12", entry.path, message) if {
	some entry in jobs
	entry.hook == "pre-commit"
	filled(entry.job, "run")
	fixes(entry.job)
	not entry.job.stage_fixed == true
	message := sprintf(
		concat(" ", [
			"%s fixes files but does not set stage_fixed: true, so its fixes stay unstaged and",
			"the commit records the files as they were; add stage_fixed: true",
		]),
		[label(entry)],
	)
}

# HOOKS-13
findings contains lib.finding("HOOKS-13", push.path, message) if {
	some push in jobs
	push.hook == "pre-push"
	some commit in jobs
	commit.path == push.path
	commit.hook == "pre-commit"
	signature(push.job) == signature(commit.job)
	message := sprintf(
		concat(" ", [
			"%s runs the same command as %s, so every push repeats what each commit already ran;",
			"keep it in one stage",
		]),
		[label(push), label(commit)],
	)
}

# HOOKS-14
findings contains lib.finding("HOOKS-14", entry.path, message) if {
	some entry in jobs
	some match in regex.find_all_string_submatch_n(package_runner_pattern, body(entry.job), -1)
	message := sprintf(
		concat(" ", [
			"%s runs %q directly, so the tool's version is chosen in the hook and CI can run a",
			"different one; put the command in a task and run that task here and in CI",
		]),
		[label(entry), regex.replace(match[2], `\s+`, " ")],
	)
}

# A command that writes the fixes it finds (HOOKS-12): a --write or --fix
# flag, a formatter that writes by default, or a task named for fixing.
fix_patterns := [
	`(^|\s)--(write|fix)([\s=]|$)`,
	concat("", [
		`(^|[\s;&|(])(ruff\s+format|taplo\s+(fmt|format)|cargo\s+fmt|go\s+fmt|`,
		`gofmt\s+(\S+\s+)*-w|(terraform|tofu)\s+fmt)(\s|$)`,
	]),
	`(^|[\s;&|(])task(\s+[^\s;&|]+)*?\s+([\w-]+:)*(fmt|format|fix)(:[\w-]+)*(\s|[;&|]|$)`,
]

# A flag that turns a fixer back into a report.
report_pattern := concat("", [
	`(--check([^\w-]|$)|:check([^\w-]|$)|--dry-run|--exit-code|`,
	`--diff([^\w-]|$)|(^|\s)-check(\s|$)|--list-different)`,
])

fixes(job) if {
	not regex.match(report_pattern, body(job))
	some pattern in fix_patterns
	regex.match(pattern, body(job))
}

# What a job runs, with its file-list template unified, so the same command
# over staged files and over pushed files reads the same (HOOKS-13).
signature(job) := ["run", object.get(job, "root", ""), normalised(body(job))] if is_string(job.run)

signature(job) := ["script", object.get(job, "root", ""), job.script, object.get(job, "runner", "")] if {
	is_string(job.script)
}

normalised(text) := trim_space(regex.replace(
	regex.replace(text, `\{(staged_files|push_files|all_files|files)\}`, "{files}"),
	`\s+`,
	" ",
))

# A one-shot package runner: a command that fetches the tool it runs at the
# moment it runs, at whatever version it resolves then (HOOKS-14). `bun x`
# and `uv tool run` are bunx's and uvx's long forms. Runners of lockfile-pinned
# tools (uv run, pnpm exec, npm exec, go run) are not among them.
package_runner_pattern := concat("", [
	`(^|[\s;&|(])(npx|bunx|pnpx|uvx|bun\s+x|pnpm\s+dlx|yarn\s+dlx|`,
	`uv\s+tool\s+run|pipx\s+run)(\s|$)`,
])
