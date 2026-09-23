package conventions.lib.names_test

import data.conventions.lib.names
import data.conventions.lib.testdata_test as td

test_title_case_uses_display_forms if {
	names.title_case("validate-pull-request") == "Validate Pull Request" with data.conventions.index as td.index
	names.title_case("deploy-production-api") == "Deploy Production API" with data.conventions.index as td.index
	names.title_case("reusable-build-image") == "Reusable Build Image" with data.conventions.index as td.index
	names.title_case("validate-devcontainer") == "Validate Dev Container" with data.conventions.index as td.index
}

test_declaration_adds_display_forms_but_never_overrides if {
	docs := [td.declaration({"vocabulary": {"display_forms": {"sbom": "SBOM", "api": "Api"}}})]
	names.title_case("publish-sbom-api") == "Publish SBOM API" with data.conventions.index as td.index with input as docs
}

test_declaration_extends_display_forms_as_list if {
	docs := [td.declaration({"vocabulary": {"display_forms": [{"token": "sbom", "display": "SBOM"}, {"token": 1}]}})]
	names.title_case("publish-sbom") == "Publish SBOM" with data.conventions.index as td.index with input as docs
}

test_display_forms_without_index if {
	names.title_case("validate") == "Validate"
}

test_workflow_names if {
	expected := names.expected_workflow_name(".github/workflows/validate-api.yml") with data.conventions.index as td.index
	expected == "Validate API"
	names.accepted_workflow_names(".github/workflows/validate.yml", {"name": "CI"}) == {"Validate", "CI"}
	names.accepted_workflow_names(".github/workflows/validate.yml", {}) == {"Validate"}
}

test_tokens if {
	names.meaningful_tokens("reusable-build-image") == ["build", "image"]
	names.meaningful_tokens("deploy-production") == ["deploy", "production"]
	names.is_reusable_name("reusable-build")
	not names.is_reusable_name("build-reusable")
}

test_filename_grammar if {
	regex.match(names.workflow_filename_pattern, "validate.yml")
	regex.match(names.workflow_filename_pattern, "reusable-build-image.yaml")
	regex.match(names.workflow_filename_pattern, "deploy-v2.yml")
	not regex.match(names.workflow_filename_pattern, "2-deploy.yml")
	not regex.match(names.workflow_filename_pattern, "Deploy.yml")
	not regex.match(names.workflow_filename_pattern, "deploy_api.yml")
	not regex.match(names.workflow_filename_pattern, "deploy.json")
}

test_snake_case if {
	names.is_snake_case("build_image")
	not names.is_snake_case("build-image")
	not names.is_snake_case("_build")
	names.snake_case("buildImage") == "build_image"
	names.snake_case("Build Image") == "build_image"
	names.snake_case("-attempt-1-") == "attempt_1"
}

test_kebab_case_and_quoted_list if {
	names.kebab_case("Deploy_API") == "deploy-api"
	names.quoted_list({"b", "a"}) == `"a", "b"`
}

test_vocabulary_sets if {
	"validate" in names.responsibility_tokens with data.conventions.index as td.index
	"build" in names.capability_tokens with data.conventions.index as td.index
	"setup" in names.action_tokens with data.conventions.index as td.index
	names.banned_tokens.ci == "validate" with data.conventions.index as td.index
	names.schedule_tokens == {"nightly", "scheduled"} with data.conventions.index as td.index
}
