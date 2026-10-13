package conventions.lib.contracts_test

import data.conventions.lib.contracts
import data.conventions.lib.testdata_test as td

identity(product_dir) := td.repository(object.union(td.identity, {"layout": {"product": product_dir}}))

repo(product_dir, files) := [identity(product_dir), td.inventory(files)]

interfaces(entries) := td.file(".repo/outputs.toml", {"schema_version": 2, "interfaces": entries})

test_dir_is_under_the_product if {
	contracts.dir == "app/contracts" with input as repo("app", [])
	contracts.vendor_dir == "app/contracts/vendor" with input as repo("app", [])
}

test_dir_is_at_the_root_without_a_product if {
	contracts.dir == "contracts" with input as repo("", [])
}

test_dir_is_undefined_until_the_layout_is_declared if {
	not contracts.dir with input as [td.repository(td.identity), td.inventory([])]
}

test_offered_files_leave_out_vendored_copies_documents_and_dotfiles if {
	paths := [
		"app/contracts/openapi/public.json",
		"app/contracts/README.md",
		"app/contracts/.gitkeep",
		"app/contracts/vendor/specifications/schemas/release.json",
		"app/src/main.go",
	]
	contracts.offered_files == {"app/contracts/openapi/public.json"} with input as repo("app", paths)
}

test_interfaces_are_the_declared_objects if {
	entries := [{"id": "public-http", "definitions": ["a.json"]}, "stray"]
	contracts.interfaces == [{"id": "public-http", "definitions": ["a.json"]}] with input as [interfaces(entries)]
	contracts.interfaces == [] with input as [td.outputs([])]
}

test_definitions_keep_only_strings if {
	contracts.definitions({"definitions": ["a.json", 3]}) == ["a.json"]
	contracts.definitions({"definitions": "a.json"}) == []
	contracts.definitions({}) == []
}

paths := [
	"app/contracts/openapi/public.json",
	"app/contracts/openapi/admin.json",
	"app/contracts/events/order.schema.json",
	"app/contracts/events/nested/refund.schema.json",
]

test_covered_by_a_file if {
	covered := contracts.covered("app/contracts/openapi/public.json") with input as repo("app", paths)
	covered == {"app/contracts/openapi/public.json"}
}

test_covered_by_a_directory_with_or_without_its_slash if {
	expected := {"app/contracts/openapi/public.json", "app/contracts/openapi/admin.json"}
	contracts.covered("app/contracts/openapi/") == expected with input as repo("app", paths)
	contracts.covered("app/contracts/openapi") == expected with input as repo("app", paths)
}

test_covered_by_a_glob if {
	top := contracts.covered("app/contracts/events/*.schema.json") with input as repo("app", paths)
	top == {"app/contracts/events/order.schema.json"}
	all_events := {"app/contracts/events/order.schema.json", "app/contracts/events/nested/refund.schema.json"}
	contracts.covered("app/contracts/events/**/*.schema.json") == all_events with input as repo("app", paths)
}

test_covered_by_nothing if {
	contracts.covered("app/contracts/missing.json") == set() with input as repo("app", paths)
}

test_interface_files_join_every_definition if {
	entry := {"definitions": ["app/contracts/openapi/public.json", "app/contracts/events/"]}
	expected := {
		"app/contracts/openapi/public.json",
		"app/contracts/events/order.schema.json",
		"app/contracts/events/nested/refund.schema.json",
	}
	contracts.interface_files(entry) == expected with input as repo("app", paths)
}

test_vendored_files_name_their_repository_and_output if {
	vendored := [
		"app/contracts/vendor/specifications/schemas/release.json",
		"app/contracts/vendor/specifications/schemas/v1/order.json",
		"app/contracts/vendor/specifications/README.md",
	]
	found := contracts.vendored with input as repo("app", vendored)
	found == {
		{
			"repository": "specifications", "output": "schemas",
			"file": "app/contracts/vendor/specifications/schemas/release.json",
			"path": "release.json",
		},
		{
			"repository": "specifications", "output": "schemas",
			"file": "app/contracts/vendor/specifications/schemas/v1/order.json",
			"path": "v1/order.json",
		},
	}
}

test_copy_and_record_paths if {
	copy := contracts.copy_dir("specifications", "schemas") with input as repo("app", [])
	copy == "app/contracts/vendor/specifications/schemas"
	record := contracts.record_path("specifications", "schemas") with input as repo("app", [])
	record == "app/contracts/vendor/specifications/schemas/release.json"
}

test_records_are_the_parsed_release_records if {
	record := {"conventions": {"release": {"version": "1.2.0"}}}
	path := "app/contracts/vendor/specifications/schemas/release.json"
	documents := [td.file(path, record), td.file("app/contracts/openapi/release.json", {})]
	contracts.records == {path: record} with input as documents
}
