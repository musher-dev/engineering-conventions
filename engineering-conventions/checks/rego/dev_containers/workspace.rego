# METADATA
# title: Dev container workspace
# description: >-
#   A dev container mounts into the workspace only inside a declared product
#   directory (DEVC-22), and links each Cargo product for rust-analyzer
#   (DEVC-23). The product directory is the identity declaration's [layout]
#   (EC-0018).
# scope: package
# custom:
#   convention: EC-0027
package conventions.checks.dev_containers.workspace

import data.conventions.checks.dev_containers.configuration
import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.layout
import data.conventions.lib.mise

devcontainers := mise.devcontainers

# DEVC-22. Silent without an identity declaration, and beside a product
# REPO-02 reports as malformed.
findings contains lib.finding("DEVC-22", path, message) if {
	files.repository_declared
	not malformed_product
	some [path, target, inside] in folder_mounts
	not in_product(inside, product_patterns)
	message := sprintf("the mount at %s %s", [target, stray_advice])
}

# DEVC-23. One finding per Cargo product the setting does not list.
findings contains lib.finding("DEVC-23", path, message) if {
	some path, devcontainer in devcontainers
	some manifest in cargo_manifests
	not manifest in linked_projects(devcontainer)
	message := sprintf(
		`customizations.vscode.settings["rust-analyzer.linkedProjects"] does not list %s; %s`,
		[manifest, concat(" ", [
			"add it so rust-analyzer loads the product; it searches only near the root,",
			"and without it the editor has no Rust analysis",
		])],
	)
}

# --- Mounts ---------------------------------------------------------------

# The workspace folder, as a mount's target names it.
folder_prefixes := ["/workspaces/${localWorkspaceFolderBasename}/", "${containerWorkspaceFolder}/"]

# Each mount that lands in the workspace: the configuration, the target, and
# the target's path within the workspace.
folder_mounts contains [path, target, inside] if {
	some path, devcontainer in devcontainers
	some mount in object.get(devcontainer, "mounts", [])
	target := configuration.mount_target(configuration.mount_fields(mount))
	some prefix in folder_prefixes
	startswith(target, prefix)
	inside := trim_prefix(target, prefix)
}

# --- The product directory ------------------------------------------------

# A product is declared, but not as one path segment; REPO-02 reports it.
malformed_product if {
	is_string(layout.declared_product)
	layout.declared_product != ""
	not layout.product_dir
}

# The product directory, or a multi-product repository's products entries.
default product_patterns := []

product_patterns := [layout.product_dir] if layout.product_dir

product_patterns := layout.products if not layout.product_dir

# A path is a pattern's directory or under it. A pattern's segments are
# names or `*`, so it is matched against as many leading segments.
in_product(inside, patterns) if {
	parts := split(inside, "/")
	some pattern in patterns
	depth := count(split(pattern, "/"))
	count(parts) >= depth
	glob.match(pattern, ["/"], concat("/", array.slice(parts, 0, depth)))
}

stray_advice := sprintf(
	"lands outside the product directory %s; mount it under %s/, or remove it",
	[layout.product_dir, layout.product_dir],
) if {
	layout.product_dir
} else := sprintf(
	"lands outside every product directory (%s); mount it under one, or remove it",
	[concat(", ", layout.products)],
) if {
	count(layout.products) > 0
} else := concat(" ", [
	"lands in the workspace, but .repo/repository.toml declares no product directory;",
	"declare one in [layout] and mount under it, or remove the mount",
])

# --- Editor links ---------------------------------------------------------

product_dirs contains layout.product_dir

product_dirs contains dir if some dir in layout.product_dirs

cargo_manifests contains manifest if {
	some dir in product_dirs
	manifest := concat("/", [dir, "Cargo.toml"])
	manifest in files.repository_files
}

# The paths rust-analyzer.linkedProjects lists, relative to the workspace.
default linked_projects(_) := set()

linked_projects(devcontainer) := {trim_prefix(trim_prefix(entry, "${workspaceFolder}/"), "./") |
	some entry in devcontainer.customizations.vscode.settings["rust-analyzer.linkedProjects"]
	is_string(entry)
}
