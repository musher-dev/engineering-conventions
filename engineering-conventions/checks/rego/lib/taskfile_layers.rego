# METADATA
# title: Taskfile layers
# description: >-
#   The tool wrappers in taskfiles/tools/ and what they wrap, the program a
#   shell line starts, and the sources globs that match nothing (EC-0015).
package conventions.lib.taskfile_layers

import data.conventions.lib.doublestar
import data.conventions.lib.files
import data.conventions.lib.taskfiles

# A tool wrapper: a Taskfile named <tool>.Taskfile.yml in a taskfiles/tools/
# directory, which another Taskfile includes, holding how that one tool runs.
# Each is mapped to its stem, the tool's name (TASK-25, TASK-26, HOOKS-15).
wrapper_pattern := `^([^/]+/){0,2}taskfiles/tools/([^/]+)\.Taskfile\.ya?ml$`

wrappers[path] := stem if {
	some include in taskfiles.includes
	path := taskfiles.target(include)
	taskfiles.documents[path]
	some match in regex.find_all_string_submatch_n(wrapper_pattern, path, 1)
	stem := match[2]
}

# The includes that load a tool wrapper.
wrapper_includes contains include if {
	some include in taskfiles.includes
	wrappers[taskfiles.target(include)]
}

# The tools a repository wraps, each mapped to the wrapper that runs it.
wrapped_tools[stem] := path if some path, stem in wrappers

# Whether a task in path can call a task in wrapper: Task is run from a
# Taskfile that loads both.
callable_from(path, wrapper) if {
	some root in taskfiles.entry_points
	reach := graph.reachable(taskfiles.edges, {root})
	path in reach
	wrapper in reach
}

# The tools the root Taskfile can run through a wrapper, each mapped to it.
root_wrapped_tools[stem] := path if {
	some stem, path in wrapped_tools
	path in graph.reachable(taskfiles.edges, {taskfiles.root_path})
}

# The fragments TASK-18 and TASK-19 read: every area fragment and every tool
# wrapper, each mapped to its area or tool.
all_fragments := object.union(taskfiles.fragments, wrappers)

# The fragments TASK-21 and TASK-22 hold to one shape: the flattened area
# fragments and every tool wrapper, which TASK-25 asks to be flattened.
layout_fragments := object.union(taskfiles.flattened_fragments, wrappers)

# The program a shell line starts: its first word, after any leading
# NAME=value assignments. Undefined for a line that starts with a template,
# a quote or a subshell, whose program cannot be read.
program(line) := word if {
	rest := regex.replace(line, `^([A-Za-z_][A-Za-z0-9_]*=("[^"]*"|'[^']*'|[^\s"']*)\s+)+`, "")
	some match in regex.find_all_string_submatch_n(`^([A-Za-z0-9_][A-Za-z0-9._+-]*)(\s|$)`, rest, 1)
	word := match[1]
}

# A sources glob that matches no file or directory the repository holds,
# from every directory it may run from, although the directory it starts
# from is held: Task then fingerprints nothing for it (TASK-28). A glob
# under a directory the repository does not hold, such as build output, is
# not judged.
unmatched_glob(path, value) if {
	candidates := {resolved |
		some context in object.get(taskfiles.contexts, path, set())
		resolved := anchored_glob(path, context, value)
	}
	count(candidates) > 0
	every candidate in candidates {
		taskfiles.exists(glob_base(candidate))
		not doublestar.matches_any(candidate, files.all_files)
		not doublestar.matches_any(candidate, files.directories)
	}
}

anchored_glob(_, context, value) := taskfiles.join(context.root, rest) if {
	rest := trim_prefix(value, "{{.ROOT_DIR}}/")
	rest != value
	plain_glob(rest)
}

anchored_glob(path, _, value) := taskfiles.join(taskfiles.dir(path), rest) if {
	rest := trim_prefix(value, "{{.TASKFILE_DIR}}/")
	rest != value
	plain_glob(rest)
}

anchored_glob(_, context, value) := taskfiles.join(context.work, value) if plain_glob(value)

# A relative glob with no template in it.
plain_glob(value) if {
	regex.match(`[*?\[{]`, value)
	not contains(value, "{{")
	not regex.match(`^([A-Za-z][A-Za-z0-9+.-]*://|~|/|!)`, value)
}

# The directory a glob starts from: its segments before the first that holds
# a glob character; "" for the directory it runs in.
glob_base(pattern) := concat("/", array.slice(parts, 0, first)) if {
	parts := split(pattern, "/")
	first := min({i | some i, part in parts; regex.match(`[*?\[{]`, part)})
}
