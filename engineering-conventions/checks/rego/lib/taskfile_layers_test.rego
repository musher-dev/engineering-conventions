package conventions.lib.taskfile_layers_test

import data.conventions.lib.taskfile_layers as layers

test_program if {
	layers.program("yamllint --strict .") == "yamllint"
	layers.program("NO_COLOR=1 A='x y' B=\"z\" ruff check") == "ruff"
	layers.program("markdownlint-cli2") == "markdownlint-cli2"
	not layers.program("{{.UV_RUN}} ruff")
	not layers.program("'quoted' x")
	not layers.program("(cd x && ruff)")
}

test_glob_base if {
	layers.glob_base("src/**/*.go") == "src"
	layers.glob_base("**/*.go") == ""
	layers.glob_base("a/b/*.{ts,js}") == "a/b"
}
