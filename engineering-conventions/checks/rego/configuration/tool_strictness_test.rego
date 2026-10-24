package conventions.checks.configuration.tool_strictness_test

import data.conventions.checks.configuration.tool_strictness as strictness
import data.conventions.lib.testdata_test as td

ids_at(found) := {[f.id, f.path] | some f in found}

test_conforming_configurations if {
	docs := [
		td.file(".config/yaml/yamllint.yaml", {"extends": "default", "rules": {"document-start": "disable"}}),
		td.file(".config/markdown/markdownlint.jsonc", {"default": true, "MD013": false}),
		td.file(".config/markdown/markdownlint-cli2.yaml", {"config": {"MD034": false}}),
		td.file("engineering-conventions/pyproject.toml", {"tool": {
			"basedpyright": {"typeCheckingMode": "strict"},
			"ruff": {"lint": {"select": ["E"]}},
		}}),
		td.file("tools/pyproject.toml", {"tool": {"basedpyright": {"include": ["src"]}}}),
		td.file("pyrightconfig.json", {"typeCheckingMode": "all"}),
		td.file("apps/web/tsconfig.json", {"compilerOptions": {"strict": true}}),
		td.file("apps/api/tsconfig.json", {"extends": "../../tsconfig.base.json"}),
		td.file("biome.json", {"linter": {"rules": {"recommended": true}}}),
		td.file("apps/site/biome.jsonc", {"formatter": {"enabled": true}}),
		td.file(".config/security/gitleaks.toml", {"extend": {"useDefault": true}}),
		td.file(".gitleaks.toml", {"title": "custom rules only", "rules": []}),
		td.file(".config/security/ci/gitleaks.toml", {"extend": {"path": ".config/security/gitleaks.toml"}}),
	]
	count(strictness.findings) == 0 with input as docs
}

test_conf_16_yamllint_without_default if {
	docs := [
		td.file(".config/yaml/yamllint.yaml", {"rules": {"line-length": {"max": 120}}}),
		td.file(".yamllint.yml", {"extends": "relaxed"}),
		td.file(".config/yaml/extended.yaml", {"rules": {}}),
	]
	found := strictness.findings with input as docs
	ids_at(found) == {["CONF-16", ".config/yaml/yamllint.yaml"], ["CONF-16", ".yamllint.yml"]}
}

test_conf_17_markdownlint_default_off if {
	docs := [
		td.file(".config/markdown/markdownlint.jsonc", {"default": false, "MD001": true}),
		td.file(".markdownlint-cli2.jsonc", {"config": {"default": false}}),
		td.file(".config/markdown/markdownlint-cli2.yaml", {"default": false, "config": {}}),
	]
	found := strictness.findings with input as docs
	ids_at(found) == {
		["CONF-17", ".config/markdown/markdownlint.jsonc"],
		["CONF-17", ".markdownlint-cli2.jsonc"],
	}
}

test_conf_18_pyright_below_strict if {
	docs := [
		td.file("pyproject.toml", {"tool": {"pyright": {"include": ["src"]}}}),
		td.file("service/pyproject.toml", {"tool": {"basedpyright": {"typeCheckingMode": "standard"}}}),
		td.file("lib/pyrightconfig.json", {"typeCheckingMode": "basic"}),
	]
	found := strictness.findings with input as docs
	ids_at(found) == {
		["CONF-18", "pyproject.toml"],
		["CONF-18", "service/pyproject.toml"],
		["CONF-18", "lib/pyrightconfig.json"],
	}
	{f.message | some f in found; f.path == "pyproject.toml"} == {concat(" ", [
		"pyright checks types at typeCheckingMode standard, below the floor; set it to strict",
		"(or basedpyright's recommended or all) and turn off a rule beside its reason",
	])}
}

test_conf_19_tsconfig_not_strict if {
	docs := [
		td.file("tsconfig.json", {"compilerOptions": {"target": "es2022"}}),
		td.file("apps/web/tsconfig.json", {"extends": "../../tsconfig.base.json", "compilerOptions": {"strict": false}}),
	]
	found := strictness.findings with input as docs
	ids_at(found) == {["CONF-19", "tsconfig.json"], ["CONF-19", "apps/web/tsconfig.json"]}
}

test_conf_20_biome_recommended_off if {
	docs := [td.file("biome.json", {"linter": {"rules": {"recommended": false}}})]
	found := strictness.findings with input as docs
	ids_at(found) == {["CONF-20", "biome.json"]}
}

test_conf_21_gitleaks_extend_without_default if {
	docs := [
		td.file(".config/security/gitleaks.toml", {"extend": {"disabledRules": ["generic-api-key"]}}),
		td.file(".gitleaks.toml", {"extend": {"useDefault": false}}),
	]
	found := strictness.findings with input as docs
	ids_at(found) == {["CONF-21", ".config/security/gitleaks.toml"], ["CONF-21", ".gitleaks.toml"]}
}
