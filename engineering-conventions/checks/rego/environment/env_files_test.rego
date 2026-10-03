package conventions.checks.environment.env_files_test

import data.conventions.checks.environment.env_files
import data.conventions.lib.testdata_test as td

schema := "platform-api/env.schema.yaml"

repo(paths, texts) := [td.file("/tmp/inventory.json", {"conventions_inventory": {
	"files": array.concat(paths, [path | some path, _ in texts]),
	"texts": texts,
}})]

ignoring(text) := repo([schema], {".gitignore": text})

test_conforming if {
	count(env_files.findings) == 0 with input as ignoring("/platform-api/.env\n")
}

test_no_schema_asks_nothing if {
	count(env_files.findings) == 0 with input as repo(["README.md"], {})
}

test_envs_26_committed_example if {
	docs := repo([schema, "platform-api/.env.example"], {".gitignore": ".env\n"})
	found := env_files.findings with input as docs
	td.pairs(found) == {["ENVS-26", "platform-api/.env.example"]}
	concat(" ", [
		".env.example is an environment file in the repository; delete it from git, keep the variables in",
		"env.schema.yaml, and write a local .env with conventions env-file platform-api/env.schema.yaml",
	]) in {f.message | some f in found}
}

test_envs_26_root_and_devcontainer if {
	docs := repo([schema, ".env", ".devcontainer/env.schema.yaml", ".devcontainer/.env.local"], {".gitignore": ".env*\n"})
	found := env_files.findings with input as docs
	td.pairs(found) == {["ENVS-26", ".env"], ["ENVS-26", ".devcontainer/.env.local"]}
}

test_envs_26_elsewhere_is_not_reported if {
	docs := repo([schema, "examples/demo/.env.example", "platform-api/env.schema.yaml.bak"], {".gitignore": ".env\n"})
	count(env_files.findings) == 0 with input as docs
}

test_envs_27_not_ignored if {
	found := env_files.findings with input as ignoring("/dist/\n")
	td.pairs(found) == {["ENVS-27", schema]}
}

test_envs_27_no_gitignore if {
	found := env_files.findings with input as repo([schema], {})
	td.pairs(found) == {["ENVS-27", schema]}
}

test_envs_27_accepted_forms if {
	every pattern in [
		".env", "/platform-api/.env", "platform-api/.env", "**/.env", ".env*", "*.env", ".env/",
		"platform-api/", "/platform-api/.env*",
	] {
		count(env_files.findings) == 0 with input as ignoring(sprintf("# local\n%s\n", [pattern]))
	}
}

test_envs_27_product_gitignore if {
	docs := repo([schema], {"platform-api/.gitignore": "/.env\n"})
	count(env_files.findings) == 0 with input as docs
}

test_envs_27_negated_after if {
	found := env_files.findings with input as ignoring(".env*\n!.env\n")
	td.pairs(found) == {["ENVS-27", schema]}
}

test_envs_27_negation_then_ignore if {
	count(env_files.findings) == 0 with input as ignoring("!.env\n.env\n")
}

test_envs_27_product_gitignore_wins if {
	docs := repo([schema], {".gitignore": ".env\n", "platform-api/.gitignore": "!.env\n"})
	found := env_files.findings with input as docs
	td.pairs(found) == {["ENVS-27", schema]}
}

test_envs_27_anchored_elsewhere if {
	found := env_files.findings with input as ignoring("/.env\nother/.env\n")
	td.pairs(found) == {["ENVS-27", schema]}
}

test_envs_27_skips_the_dev_environment if {
	docs := repo([".devcontainer/env.schema.yaml"], {".gitignore": "/dist/\n"})
	count(env_files.findings) == 0 with input as docs
}
