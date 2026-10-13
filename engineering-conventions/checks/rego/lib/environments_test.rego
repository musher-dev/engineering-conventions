package conventions.lib.environments_test

import data.conventions.lib.environments
import data.conventions.lib.testdata_test as td

test_other_words_map_to_names if {
	words := environments.other_words with data.conventions.index as td.index
	words.prod == "production"
	words.dev == "development"
	words.stg == "staging"
	words.live == "production"
	not words.staging
	not words.test
}

test_production_words if {
	found := environments.production_words with data.conventions.index as td.index
	found == {"production", "prod"}
	without := environments.production_words with data.conventions.index as {"vocabulary": {}}
	without == {"production"}
}

test_name_words if {
	found := environments.name_words with data.conventions.index as td.index
	found == {"production", "prod", "prd", "staging", "stg", "stage", "preprod"}
}
