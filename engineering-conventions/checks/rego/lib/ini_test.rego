package conventions.lib.ini_test

import data.conventions.lib.ini

vale := concat("\n", [
	"# A comment",
	"StylesPath = styles",
	"Packages = a.zip, https://example.com/b.zip ; trailing",
	"",
	"[formats]",
	"svelte = html",
	"",
	"[*.{md,svelte}]",
	"; another comment",
	"BasedOnStyles = MusherCopy, proselint",
	"MusherCopy.Banned = NO",
	"[*.{md,svelte}]",
	"MusherCopy.Banned = YES",
])

test_global_keys_are_read if {
	ini.value(vale, ini.global, "StylesPath") == "styles"
}

test_a_trailing_comment_is_dropped if {
	ini.value(vale, ini.global, "Packages") == "a.zip, https://example.com/b.zip"
}

test_keys_belong_to_the_section_above_them if {
	ini.value(vale, "formats", "svelte") == "html"
	ini.value(vale, "*.{md,svelte}", "BasedOnStyles") == "MusherCopy, proselint"
	not ini.value(vale, ini.global, "svelte")
}

test_the_last_value_wins if {
	ini.value(vale, "*.{md,svelte}", "MusherCopy.Banned") == "YES"
}

test_comments_are_not_entries if {
	every entry in ini.entries(vale) {
		not startswith(entry.key, "#")
		not startswith(entry.key, ";")
	}
}

test_entries_carry_their_line if {
	some entry in ini.entries(vale)
	entry.key == "svelte"
	entry.line == 6
}

test_sections_are_listed_once if {
	ini.sections(vale) == {"formats", "*.{md,svelte}"}
}

test_a_list_drops_blanks if {
	ini.list(" a, b ,, c ") == ["a", "b", "c"]
}

test_crlf_line_endings_are_read if {
	ini.value("[*]\r\nBasedOnStyles = A\r\n", "*", "BasedOnStyles") == "A"
}

test_a_file_without_sections_is_all_global if {
	every entry in ini.entries("A = 1\nB = 2") {
		entry.section == ini.global
	}
}
