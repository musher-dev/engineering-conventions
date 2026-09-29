package conventions.checks.configuration.tool_configuration_test

import data.conventions.checks.configuration.tool_configuration as config
import data.conventions.lib.testdata_test as td

index_text := concat("\n", [
	"# Tool configuration",
	"",
	"| File | Tool | Caller |",
	"| --- | --- | --- |",
	"| `lefthook.yml` | lefthook | lefthook |",
	"| `yaml/yamllint.yaml` | yamllint | `task lint:yaml` |",
	"| `mise/config.toml` | mise | mise |",
	"| `mise/locks/` | mise | mise |",
	"",
])

conforming_files := [
	".config/README.md",
	".config/lefthook.yml",
	".config/yaml/yamllint.yaml",
	".config/mise/config.toml",
	".config/mise/locks/pipx-yamllint/1.38.0/uv.lock",
	"Taskfile.yml",
	".gitignore",
]

taskfile := td.file("Taskfile.yml", {
	"version": "3",
	"vars": {"YAML_CONFIG": ".config/yaml/yamllint.yaml"},
	"tasks": {"lint:yaml": {"desc": "Lint YAML.", "cmds": ["yamllint -c {{.YAML_CONFIG}} ."]}},
})

inventory(paths, texts) := td.file("/tmp/inventory.json", {"conventions_inventory": {"files": paths, "texts": texts}})

repo(paths, texts, docs) := array.concat([inventory(paths, texts)], docs)

conforming := repo(conforming_files, {".config/README.md": index_text}, [taskfile])

ids_at(found) := {[f.id, f.path] | some f in found}

messages(found, id) := {f.message | some f in found; f.id == id}

test_conforming_repository if {
	count(config.findings) == 0 with input as conforming
}

test_no_config_directory if {
	count(config.findings) == 0 with input as repo(["Taskfile.yml"], {}, [])
}

test_conf_01_root_configs if {
	paths := array.concat(conforming_files, [".yamllint.yaml", ".regal/config.yaml", ".editorconfig"])
	found := config.findings with input as repo(paths, {".config/README.md": index_text}, [taskfile])
	ids_at(found) == {["CONF-01", ".yamllint.yaml"], ["CONF-01", ".regal/config.yaml"]}
	messages(found, "CONF-01") == {
		concat(" ", [
			"yamllint configuration sits at the repository root; move it to",
			".config/<concern>/yamllint.yaml and pass that path to yamllint explicitly",
		]),
		concat(" ", [
			"Regal configuration sits at the repository root; move it to",
			".config/<concern>/regal.yaml and pass that path to Regal explicitly",
		]),
	}
}

test_conf_01_only_at_the_root if {
	paths := array.concat(conforming_files, ["docs/.markdownlint.jsonc"])
	count(config.findings) == 0 with input as repo(paths, {".config/README.md": index_text}, [taskfile])
}

test_conf_02_missing_index if {
	paths := [p | some p in conforming_files; p != ".config/README.md"]
	found := config.findings with input as repo(paths, {}, [taskfile])
	ids_at(found) == {["CONF-02", ".config/README.md"]}
}

test_conf_02_self_discovered_only_needs_no_index if {
	paths := [".config/mise/config.toml", ".config/mise/mise.lock", ".config/lefthook.yml", ".config/mise/locks/a.json"]
	found := config.findings with input as repo(paths, {}, [])
	ids_at(found) == set()
}

test_conf_03_self_discovered_need_not_be_indexed if {
	paths := array.concat(conforming_files, [".config/mise/config.toml", ".config/mise/mise.lock"])
	found := config.findings with input as repo(paths, {".config/README.md": index_text}, [taskfile])
	not "CONF-03" in {id | some [id, _] in ids_at(found)}
}

test_conf_03_unindexed_file if {
	paths := array.concat(conforming_files, [".config/spelling/typos.toml"])
	docs := [td.file("Taskfile.yml", {"version": "3", "tasks": {"lint": {"cmds": [
		"yamllint -c .config/yaml/yamllint.yaml .",
		"typos --config .config/spelling/typos.toml",
	]}}})]
	found := config.findings with input as repo(paths, {".config/README.md": index_text}, docs)
	ids_at(found) == {["CONF-03", ".config/spelling/typos.toml"]}
	messages(found, "CONF-03") == {concat(" ", [
		".config/spelling/typos.toml is not listed in .config/README.md; add a row for",
		"`spelling/typos.toml` naming its tool and caller",
	])}
}

test_conf_03_by_name_or_full_path if {
	text := "`typos.toml` and `.config/yaml/yamllint.yaml` and `lefthook.yml` and `mise/`"
	paths := array.concat(conforming_files, [".config/spelling/typos.toml"])
	docs := [td.file("package.json", {"scripts": {
		"spell": "typos --config .config/spelling/typos.toml",
		"yaml": "yamllint -c ./.config/yaml/yamllint.yaml .",
	}})]
	count(config.findings) == 0 with input as repo(paths, {".config/README.md": text}, docs)
}

test_conf_03_silent_without_index_text if {
	paths := array.concat(conforming_files, [".config/spelling/typos.toml"])
	docs := [td.file("Taskfile.yml", {"cmds": ["typos -c .config/spelling/typos.toml", ".config/yaml/yamllint.yaml"]})]
	count(config.findings) == 0 with input as repo(paths, {}, docs)
}

test_conf_04_uncalled_file if {
	found := config.findings with input as repo(conforming_files, {".config/README.md": index_text}, [])
	ids_at(found) == {["CONF-04", ".config/yaml/yamllint.yaml"]}
	messages(found, "CONF-04") == {concat(" ", [
		"nothing names .config/yaml/yamllint.yaml; pass it by path from a Taskfile, the lefthook",
		"configuration, a workflow, an action or devcontainer.json, or delete it",
	])}
}

test_conf_04_callers_of_every_kind if {
	some caller in [
		td.file(".config/lefthook.yml", {"pre-commit": {"jobs": [{"run": "yamllint -c .config/yaml/yamllint.yaml"}]}}),
		td.file(
			".github/workflows/validate.yml",
			{"jobs": {"lint": {"steps": [{"run": "yamllint -c .config/yaml/yamllint.yaml"}]}}},
		),
		td.file(".github/actions/lint/action.yml", {"runs": {"steps": [{"run": "yamllint -c .config/yaml/yamllint.yaml"}]}}),
		td.file(".devcontainer/devcontainer.json", {"settings": {"yaml": "${workspaceFolder}/.config/yaml/yamllint.yaml"}}),
		td.file("taskfiles/lint.Taskfile.yml", {"vars": {"C": "{{.ROOT_DIR}}/.config/yaml"}}),
	]
	count(config.findings) == 0 with input as repo(conforming_files, {".config/README.md": index_text}, [caller])
}

test_conf_04_a_home_path_is_not_a_caller if {
	docs := [td.file(".devcontainer/devcontainer.json", {"mounts": [
		"source=gh,target=/home/vscode/.config/yaml/yamllint.yaml,type=volume",
		"$HOME/.config/yaml/yamllint.yaml",
		"~/.config/yaml/yamllint.yaml",
	]})]
	found := config.findings with input as repo(conforming_files, {".config/README.md": index_text}, docs)
	ids_at(found) == {["CONF-04", ".config/yaml/yamllint.yaml"]}
}

test_conf_04_a_fixture_is_not_a_caller if {
	docs := [
		td.declaration({"paths": {"fixtures": ["tests/**"]}}),
		td.file("tests/Taskfile.yml", {"vars": {"C": ".config/yaml/yamllint.yaml"}}),
	]
	found := config.findings with input as repo(conforming_files, {".config/README.md": index_text}, docs)
	ids_at(found) == {["CONF-04", ".config/yaml/yamllint.yaml"]}
}

test_conf_04_named_by_another_config_file if {
	paths := array.concat(conforming_files, [".config/spelling/cspell.json", ".config/spelling/musher.txt"])
	texts := {
		".config/README.md": index_text,
		".config/spelling/cspell.json": concat("\n", [
			`{`,
			`  // The dictionary sits beside this file.`,
			`  "dictionaryDefinitions": [{"name": "musher", "path": "./musher.txt"}],`,
			`  "import": [".config/yaml/yamllint.yaml"]`,
			`}`,
		]),
	}
	docs := [td.file("Taskfile.yml", {"cmds": ["cspell --config .config/spelling/cspell.json"]})]
	found := config.findings with input as repo(paths, texts, docs)
	not "CONF-04" in {finding.id | some finding in found}
}

test_conf_04_a_chain_nothing_calls_is_reported_where_it_starts if {
	paths := array.concat(conforming_files, [".config/spelling/cspell.json", ".config/spelling/musher.txt"])
	texts := {
		".config/README.md": index_text,
		".config/spelling/cspell.json": `{"dictionaryDefinitions": [{"path": "musher.txt"}]}`,
	}
	found := config.findings with input as repo(paths, texts, [])
	{path | some [id, path] in ids_at(found); id == "CONF-04"} == {
		".config/spelling/cspell.json",
		".config/yaml/yamllint.yaml",
	}
}

test_conf_04_a_file_does_not_name_itself if {
	paths := array.concat(conforming_files, [".config/spelling/words.txt"])
	texts := {".config/README.md": index_text, ".config/spelling/words.txt": "words.txt\n./words.txt"}
	docs := [td.file("Taskfile.yml", {"cmds": [".config/yaml/yamllint.yaml"]})]
	found := config.findings with input as repo(paths, texts, docs)
	{path | some [id, path] in ids_at(found); id == "CONF-04"} == {".config/spelling/words.txt"}
}

test_conf_05_leading_dot if {
	paths := array.concat(conforming_files, [".config/yaml/.yamllint.yaml"])
	docs := [td.file("Taskfile.yml", {"cmds": [".config/yaml/yamllint.yaml", ".config/yaml/.yamllint.yaml"]})]
	index := {".config/README.md": concat("", [index_text, "`.yamllint.yaml`"])}
	found := config.findings with input as repo(paths, index, docs)
	ids_at(found) == {["CONF-05", ".config/yaml/.yamllint.yaml"]}
	messages(found, "CONF-05") == {
		".config/yaml/.yamllint.yaml has a leading dot inside .config/; rename it to yamllint.yaml and update its callers",
	}
}

test_conf_06_root_lefthook if {
	paths := array.concat(conforming_files, ["lefthook.yml", ".lefthook.toml", "docs/lefthook.yml"])
	found := config.findings with input as repo(paths, {".config/README.md": index_text}, [taskfile])
	ids_at(found) == {["CONF-06", "lefthook.yml"], ["CONF-06", ".lefthook.toml"]}
}

test_conf_07_top_level if {
	paths := array.concat(conforming_files, [".config/yamllint.yaml", ".config/lefthook-local.yml"])
	docs := [td.file("Taskfile.yml", {"cmds": [".config/yaml/yamllint.yaml", ".config/yamllint.yaml"]})]
	index := {".config/README.md": concat("", [index_text, "`yamllint.yaml`"])}
	found := config.findings with input as repo(paths, index, docs)
	ids_at(found) == {["CONF-07", ".config/yamllint.yaml"]}
	messages(found, "CONF-07") == {concat(" ", [
		".config/yamllint.yaml sits at the top level of .config/, which holds only README.md, lefthook.yml",
		"and lefthook-local.yml; move it to .config/<concern>/yamllint.yaml",
	])}
}

test_conf_08_programs if {
	paths := array.concat(conforming_files, [".config/scripts/banner.SH"])
	docs := [td.file("Taskfile.yml", {"cmds": [".config/yaml/yamllint.yaml", "sh .config/scripts/banner.SH"]})]
	index := {".config/README.md": concat("", [index_text, "`scripts/banner.SH`"])}
	found := config.findings with input as repo(paths, index, docs)
	ids_at(found) == {["CONF-08", ".config/scripts/banner.SH"]}
}

test_conf_09_dangling_reference if {
	docs := [td.file("Taskfile.yml", {"cmds": [
		"yamllint -c .config/yaml/yamllint.yaml",
		"markdownlint-cli2 --config .config/markdown/markdownlint.jsonc",
		"lefthook uses .config/lefthook-local.yml when it exists",
		"a directory: .config/mise",
	]})]
	found := config.findings with input as repo(conforming_files, {".config/README.md": index_text}, docs)
	ids_at(found) == {["CONF-09", "Taskfile.yml"]}
	messages(found, "CONF-09") == {
		"names .config/markdown/markdownlint.jsonc, which does not exist; correct the path or remove the reference",
	}
}

test_suggested_name_default if {
	config.suggested_name("elsewhere/x.yml") == "<tool>.<ext>"
}
