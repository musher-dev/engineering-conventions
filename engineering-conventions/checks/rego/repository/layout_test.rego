package conventions.checks.repository.layout_test

import data.conventions.checks.repository.layout
import data.conventions.lib.testdata_test as td

messages(found, id) := {f.message | some f in found; f.id == id}

# A conforming repository: platform-api/ holds a go.mod.
product_files := [".repo/repository.toml", "platform-api/go.mod", "platform-api/main.go", "README.md"]

identity(layout_table) := td.repository(object.union(td.identity, {"layout": layout_table}))

repo(layout_table, paths, documents) := array.concat([identity(layout_table), td.inventory(paths)], documents)

conforming := {"product": "platform-api"}

test_conforming_layout if {
	count(layout.findings) == 0 with input as repo(conforming, product_files, [])
}

test_no_product if {
	count(layout.findings) == 0 with input as repo({"product": ""}, [".repo/repository.toml", "README.md"], [])
}

test_repo_14_no_layout if {
	found := layout.findings with input as [td.repository(td.identity), td.inventory([".repo/repository.toml"])]
	td.pairs(found) == {["REPO-14", ".repo/repository.toml"]}
}

test_repo_14_layout_without_product if {
	found := layout.findings with input as repo({"root_exceptions": {}}, [".repo/repository.toml"], [])
	td.ids(found) == {"REPO-14"}
}

test_repo_14_quiet_without_a_declaration if {
	count(layout.findings) == 0 with input as [td.inventory(["README.md"])]
}

test_repo_15_missing_directory if {
	found := layout.findings with input as repo(conforming, [".repo/repository.toml"], [])
	td.pairs(found) == {["REPO-15", ".repo/repository.toml"]}
	messages(found, "REPO-15") == {
		"the declared product directory platform-api/ does not exist; create it, or correct [layout] product",
	}
}

test_repo_15_skips_a_malformed_product if {
	count(layout.findings) == 0 with input as repo({"product": "a/b"}, [".repo/repository.toml"], [])
}

test_repo_16_not_named_after_the_repository if {
	found := layout.findings with input as repo({"product": "api"}, [".repo/repository.toml", "api/go.mod"], [])
	td.pairs(found) == {["REPO-16", ".repo/repository.toml"]}
	messages(found, "REPO-16") == {concat("", [
		"the product directory api/ is not named after the repository; ",
		`rename it to platform-api/ and set [layout] product = "platform-api"`,
	])}
}

test_repo_17_no_manifest if {
	found := layout.findings with input as repo(conforming, [".repo/repository.toml", "platform-api/main.go"], [])
	td.pairs(found) == {["REPO-17", "platform-api"]}
	messages(found, "REPO-17") == {concat("", [
		"platform-api/ holds no build manifest; move the product's manifest into it (one of ",
		"Cargo.toml, build.gradle, build.gradle.kts, deno.json, deno.jsonc, go.mod, package.json, ",
		"pom.xml, pyproject.toml, settings.gradle, settings.gradle.kts), ",
		"or keep an OpenTofu root's .terraform.lock.hcl in it or in a directory below it",
	])}
}

test_repo_17_opentofu_root_below_the_product if {
	paths := [".repo/repository.toml", "platform-api/terraform/.terraform.lock.hcl", "platform-api/terraform/main.tf"]
	count(layout.findings) == 0 with input as repo(conforming, paths, [])
}

test_repo_17_opentofu_root_at_the_product if {
	paths := [".repo/repository.toml", "platform-api/.terraform.lock.hcl", "platform-api/main.tf"]
	count(layout.findings) == 0 with input as repo(conforming, paths, [])
}

test_repo_17_opentofu_lockfile_outside_the_product if {
	paths := [
		".repo/repository.toml", "platform-api/main.go",
		"terraform/.terraform.lock.hcl", "platform-api-old/.terraform.lock.hcl",
	]
	found := layout.findings with input as repo(conforming, paths, [])
	td.pairs(found) == {["REPO-17", "platform-api"]}
}

test_repo_17_opentofu_lockfile_name_must_match if {
	paths := [".repo/repository.toml", "platform-api/terraform/terraform.lock.hcl"]
	found := layout.findings with input as repo(conforming, paths, [])
	td.pairs(found) == {["REPO-17", "platform-api"]}
}

test_repo_17_any_ecosystem if {
	count(layout.findings) == 0 with input as repo(conforming, [".repo/repository.toml", "platform-api/pom.xml"], [])
}

test_repo_18_root_content if {
	paths := array.concat(product_files, ["package.json", "src/index.ts"])
	found := layout.findings with input as repo(conforming, paths, [])
	td.pairs(found) == {["REPO-18", "package.json"], ["REPO-18", "src"]}
	advice := "move it into platform-api/, or list it under [layout.root_exceptions] with the reason it stays"
	messages(found, "REPO-18") == {
		sprintf("package.json is product content at the repository root; %s", [advice]),
		sprintf("src is product content at the repository root; %s", [advice]),
	}
}

test_repo_18_applies_without_a_product if {
	found := layout.findings with input as repo({"product": ""}, [".repo/repository.toml", "go.mod"], [])
	td.pairs(found) == {["REPO-18", "go.mod"]}
	contains(concat("", messages(found, "REPO-18")), "a product directory declared in [layout] product")
}

test_repo_18_root_exception if {
	table := {"product": "platform-api", "root_exceptions": {"package.json": "Repository tooling only."}}
	count(layout.findings) == 0 with input as repo(table, array.concat(product_files, ["package.json"]), [])
}

test_repo_19_exception_without_reason if {
	table := {"product": "platform-api", "root_exceptions": {"package.json": "  "}}
	found := layout.findings with input as repo(table, array.concat(product_files, ["package.json"]), [])
	td.pairs(found) == {["REPO-19", ".repo/repository.toml"]}
	messages(found, "REPO-19") == {
		`the root exception "package.json" gives no reason; say why it stays at the root, or remove the entry`,
	}
}

test_repo_19_exception_names_nothing if {
	table := {"product": "platform-api", "root_exceptions": {"package.json": "Tooling."}}
	found := layout.findings with input as repo(table, product_files, [])
	messages(found, "REPO-19") == {
		`the root exception "package.json" names nothing at the repository root; remove the entry`,
	}
}

dependabot(updates) := td.file(".github/dependabot.yml", {"version": 2, "updates": updates})

test_repo_20_product_ecosystem_scans_the_root if {
	docs := [dependabot([
		{"package-ecosystem": "gomod", "directory": "/"},
		{"package-ecosystem": "github-actions", "directory": "/"},
		{"package-ecosystem": "gomod", "directory": "/platform-api"},
	])]
	found := layout.findings with input as repo(conforming, product_files, docs)
	td.pairs(found) == {["REPO-20", ".github/dependabot.yml"]}
	messages(found, "REPO-20") == {
		`the gomod update scans "/", the repository root, which holds no go.mod; set its directory to /platform-api`,
	}
}

test_repo_20_directories_and_no_product if {
	docs := [dependabot([{"package-ecosystem": "npm", "directories": ["/tools", "/"]}])]
	found := layout.findings with input as repo({"product": ""}, [".repo/repository.toml", "tools/package.json"], docs)
	td.ids(found) == {"REPO-20"}
	contains(concat("", messages(found, "REPO-20")), "the product directory, once [layout] product declares one")
}

test_repo_20_excepted_manifest if {
	table := {"product": "platform-api", "root_exceptions": {"package.json": "Tooling."}}
	docs := [dependabot([{"package-ecosystem": "npm", "directory": "/"}])]
	count(layout.findings) == 0 with input as repo(table, array.concat(product_files, ["package.json"]), docs)
}

test_repo_21_product_dir_var if {
	taskfile := td.file("Taskfile.yml", {"version": "3", "vars": {"PRODUCT_DIR": "{{.ROOT_DIR}}/api"}})
	found := layout.findings with input as repo(conforming, product_files, [taskfile])
	td.pairs(found) == {["REPO-21", "Taskfile.yml"]}
	messages(found, "REPO-21") == {concat("", [
		"vars.PRODUCT_DIR is '{{.ROOT_DIR}}/api'; set it to '{{.ROOT_DIR}}/platform-api' ",
		"so tasks reach the product through dir: '{{.PRODUCT_DIR}}'",
	])}
}

test_repo_21_no_var_is_fine if {
	taskfile := td.file("Taskfile.yml", {"version": "3"})
	count(layout.findings) == 0 with input as repo(conforming, product_files, [taskfile])
}

test_repo_21_non_string_var if {
	taskfile := td.file("Taskfile.yml", {"version": "3", "vars": {"PRODUCT_DIR": {"sh": "pwd"}}})
	found := layout.findings with input as repo(conforming, product_files, [taskfile])
	td.pairs(found) == {["REPO-21", "Taskfile.yml"]}
}

test_repo_21_matching_var if {
	taskfile := td.file("Taskfile.yml", {"version": "3", "vars": {"PRODUCT_DIR": "{{.ROOT_DIR}}/platform-api"}})
	count(layout.findings) == 0 with input as repo(conforming, product_files, [taskfile])
}

test_repo_21_var_without_a_product if {
	taskfile := td.file("Taskfile.yml", {"version": "3", "vars": {"PRODUCT_DIR": "{{.ROOT_DIR}}/x"}})
	found := layout.findings with input as repo({"product": ""}, [".repo/repository.toml"], [taskfile])
	td.pairs(found) == {["REPO-21", "Taskfile.yml"]}
}

test_repo_22_missing_directory if {
	docs := [dependabot([
		{"package-ecosystem": "github-actions", "directories": ["/", "/.github/actions/*", "/.github/gone"]},
		{"package-ecosystem": "docker", "directory": "/platform-api"},
	])]
	paths := array.concat(product_files, [".github/actions/setup/action.yml"])
	found := layout.findings with input as repo(conforming, paths, docs)
	td.pairs(found) == {["REPO-22", ".github/dependabot.yml"]}
	messages(found, "REPO-22") == {
		`the github-actions update names the directory "/.github/gone", which does not exist; correct it, or remove it`,
	}
}

test_repo_22_without_a_layout if {
	docs := [
		td.repository(td.identity),
		td.inventory([".repo/repository.toml"]),
		dependabot([{"package-ecosystem": "npm", "directory": "/web"}]),
	]
	found := layout.findings with input as docs
	td.ids(found) == {"REPO-14", "REPO-22"}
}

test_update_directories_default if {
	layout.update_directories({"package-ecosystem": "npm"}) == ["/"]
}
