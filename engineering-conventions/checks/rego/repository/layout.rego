# METADATA
# title: Repository layout
# description: >-
#   The identity declaration says where the product lives (REPO-14); the
#   product directory exists (REPO-15), is named after the repository
#   (REPO-16) and holds its build manifest (REPO-17); the root holds no
#   product content (REPO-18) except exceptions with reasons (REPO-19); and
#   Dependabot (REPO-20, REPO-22) and the Taskfile (REPO-21) agree with it.
# scope: package
# custom:
#   convention: EC-0018
package conventions.checks.repository.layout

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.layout
import data.conventions.lib.updates

# REPO-14. Only a declaration that exists; without one, REPO-01 reports it.
findings contains lib.finding("REPO-14", files.repository_path, message) if {
	files.repository_declared
	not product_key_declared
	message := concat(" ", [
		"the identity declaration does not say where the product lives; add [layout] with",
		`product = "<repository-name>", or product = "" when the repository has no product directory`,
	])
}

# REPO-15
findings contains lib.finding("REPO-15", files.repository_path, message) if {
	product_dir
	not product_dir in existing_directories
	message := sprintf(
		"the declared product directory %s/ does not exist; create it, or correct [layout] product",
		[product_dir],
	)
}

# REPO-16. Judged against the declared name: REPO-07 reports a declared name
# that is not the actual one.
findings contains lib.finding("REPO-16", files.repository_path, message) if {
	name := files.repository_declaration.name
	is_string(name)
	product_dir != name
	message := sprintf(
		"the product directory %s/ is not named after the repository; rename it to %s/ and set [layout] product = %q",
		[product_dir, name, name],
	)
}

# REPO-17. A missing directory is REPO-15's.
findings contains lib.finding("REPO-17", product_dir, message) if {
	product_dir in existing_directories
	count(product_ecosystems) == 0
	message := sprintf(
		concat(" ", [
			"%s/ holds no build manifest; move the product's manifest into it (one of %s),",
			"or keep an OpenTofu root's %s in it or in a directory below it",
		]),
		[product_dir, concat(", ", sort(manifests)), opentofu_lockfile],
	)
}

# REPO-18
findings contains lib.finding("REPO-18", name, message) if {
	declares_placement
	some name in root_entries
	name in root_content
	not name in object.keys(root_exceptions)
	message := sprintf(
		concat(" ", [
			"%s is product content at the repository root; move it into %s, or list it under",
			"[layout.root_exceptions] with the reason it stays",
		]),
		[name, home],
	)
}

# REPO-19
findings contains lib.finding("REPO-19", files.repository_path, message) if {
	declares_placement
	some name, reason in root_exceptions
	not has_reason(reason)
	message := sprintf(
		"the root exception %q gives no reason; say why it stays at the root, or remove the entry",
		[name],
	)
}

findings contains lib.finding("REPO-19", files.repository_path, message) if {
	declares_placement
	some name, reason in root_exceptions
	has_reason(reason)
	not name in root_entries
	message := sprintf(
		"the root exception %q names nothing at the repository root; remove the entry",
		[name],
	)
}

# REPO-20. Another directory is fine: repository tooling may keep its own
# manifest. A directory that does not exist is REPO-22's.
findings contains lib.finding("REPO-20", path, message) if {
	declares_placement
	some entry in dependabot_updates
	path := entry.path
	ecosystem := entry.update["package-ecosystem"]
	dependabot_ecosystems[ecosystem]
	not excepted_ecosystem(ecosystem)
	some directory in update_directories(entry.update)
	is_root(directory)
	manifest := concat(" or ", dependabot_ecosystems[ecosystem])
	message := sprintf(
		"the %s update scans %q, the repository root, which holds no %s; set its directory to %s",
		[ecosystem, directory, manifest, dependabot_home],
	)
}

# REPO-21. Only a Taskfile that names the product: one that never needs the
# path does not have to define it.
findings contains lib.finding("REPO-21", path, message) if {
	product_dir
	expected := sprintf("{{.ROOT_DIR}}/%s", [product_dir])
	some path, taskfile in root_taskfiles
	"PRODUCT_DIR" in object.keys(object.get(taskfile, "vars", {}))
	object.get(object.get(taskfile, "vars", {}), "PRODUCT_DIR", null) != expected
	message := sprintf(
		"vars.PRODUCT_DIR is %s; set it to '%s' so tasks reach the product through dir: '{{.PRODUCT_DIR}}'",
		[describe(taskfile.vars.PRODUCT_DIR), expected],
	)
}

findings contains lib.finding("REPO-21", path, unexpected_product_dir) if {
	declared_product == ""
	some path, taskfile in root_taskfiles
	"PRODUCT_DIR" in object.keys(object.get(taskfile, "vars", {}))
}

# REPO-22. Every Dependabot directory, whatever the layout.
findings contains lib.finding("REPO-22", path, message) if {
	some entry in dependabot_updates
	path := entry.path
	update := entry.update
	some directory in update_directories(update)
	not directory_exists(directory)
	message := sprintf(
		"the %s update names the directory %q, which does not exist; correct it, or remove it",
		[object.get(update, "package-ecosystem", "unnamed"), directory],
	)
}

unexpected_product_dir := concat(" ", [
	"vars.PRODUCT_DIR is set, but the repository declares no product directory;",
	"remove it, or declare the product",
])

# The declaration's [layout], read once in lib/layout.rego, which the
# environment checks share.
product_key_declared if layout.product_key_declared

declared_product := layout.declared_product

product_dir := layout.product_dir

declares_placement if layout.declared

root_exceptions := layout.root_exceptions

has_reason(reason) if {
	is_string(reason)
	trim_space(reason) != ""
}

home := sprintf("%s/", [product_dir]) if product_dir

home := "a product directory declared in [layout] product" if declared_product == ""

dependabot_home := sprintf("/%s", [product_dir]) if product_dir

dependabot_home := "the product directory, once [layout] product declares one" if declared_product == ""

# Every entry at the top of the repository: files, and the first segment of
# every path below it. Files the conventions declaration sets apart as
# fixtures still exist, so existence is judged over every file.
root_entries contains split(path, "/")[0] if some path in files.all_files

existing_directories contains dir if {
	some path in files.all_files
	parts := split(path, "/")
	count(parts) > 1
	some i in numbers.range(1, count(parts) - 1)
	dir := concat("/", array.slice(parts, 0, i))
}

# What a product is built from, by ecosystem (lib/updates.rego).
ecosystems := updates.ecosystems

manifests contains manifest if {
	some ecosystem in ecosystems
	some manifest in ecosystem.manifests
}

# An OpenTofu root has no manifest at the top of the product directory: its
# dependency record is the lockfile `tofu init` writes, in the root's own
# directory, which may sit anywhere below the product directory.
opentofu_lockfile := ".terraform.lock.hcl"

product_ecosystems contains name if {
	some name, ecosystem in ecosystems
	some manifest in ecosystem.manifests
	concat("/", [product_dir, manifest]) in files.all_files
}

product_ecosystems contains "opentofu" if {
	product_dir
	some path in files.all_files
	startswith(path, concat("", [product_dir, "/"]))
	endswith(path, concat("", ["/", opentofu_lockfile]))
}

dependabot_ecosystems[updater] := ecosystem.manifests if {
	some ecosystem in ecosystems
	some updater in ecosystem.dependabot
}

# An ecosystem whose manifest the root keeps on purpose may scan the root.
excepted_ecosystem(updater) if {
	some manifest in dependabot_ecosystems[updater]
	manifest in object.keys(root_exceptions)
}

# Product content by name: every ecosystem's manifests, lockfiles, toolchain
# files and configuration a tool finds by walking up, and source trees.
root_content := {
	"Cargo.toml", "Cargo.lock", "rust-toolchain", "rust-toolchain.toml", ".cargo",
	"rustfmt.toml", ".rustfmt.toml", "clippy.toml", ".clippy.toml", "deny.toml", ".deny.toml",
	"package.json", "package-lock.json", "npm-shrinkwrap.json", "pnpm-lock.yaml",
	"pnpm-workspace.yaml", "yarn.lock", "bun.lock", "bun.lockb", "tsconfig.json",
	".nvmrc", ".node-version",
	"pyproject.toml", "uv.lock", "poetry.lock", "setup.py", "setup.cfg", ".python-version",
	"ruff.toml", ".ruff.toml", "pytest.ini", "tox.ini",
	"go.mod", "go.sum", "go.work", "go.work.sum",
	"deno.json", "deno.jsonc", "deno.lock",
	"pom.xml", "build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts",
	"gradlew", "mvnw",
	"src", "crates", "cmd", "internal", "pkg", "lib", "tests", "apps", "packages",
}

# The Dependabot updates and the directories each scans (lib/updates.rego).
dependabot_updates := updates.dependabot_updates

update_directories(update) := updates.update_directories(update)

is_root(directory) if trim(directory, "/ ") == ""

directory_exists(directory) if is_root(directory)

directory_exists(directory) if trim(directory, "/ ") in existing_directories

directory_exists(directory) if {
	pattern := trim(directory, "/ ")
	regex.match(`[*?\[]`, pattern)
	some dir in existing_directories
	glob.match(pattern, ["/"], dir)
}

root_taskfiles[doc.path] := doc.contents if {
	some doc in files.own_documents
	regex.match(`^[Tt]askfile(\.dist)?\.ya?ml$`, doc.path)
	is_object(doc.contents)
}

describe(value) := sprintf("'%v'", [value])
