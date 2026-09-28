package conventions.checks.decisions.records_test

import data.conventions.checks.decisions.records
import data.conventions.lib.testdata_test as td

# A record with frontmatter `fields` and the sections every record has.
record(fields) := concat("", [
	"---\n",
	yaml.marshal(object.union({"title": "A decision", "date": "2026-01-01", "status": "accepted"}, fields)),
	"---\n\n# A decision\n\n## Context\n\nWhy.\n\n## Decision\n\nWhat.\n\n",
	"## Consequences\n\nSo.\n\n## Enforcement\n\nreview-only: a reviewer checks it.\n",
])

conforming := record({})

index_linking(names) := concat("\n", array.concat(
	["# Decisions\n", "| ID | Decision |", "| --- | --- |"],
	[sprintf("| [%s](%s.md) | x |", [substring(name, 0, 4), name]) | some name in names],
))

# The combined input for a repository whose files hold `texts`, plus `extra`
# paths with no text.
repository(texts, extra) := [td.file("/tmp/inventory.json", {"conventions_inventory": {
	"files": array.concat([path | some path, body in texts; is_string(body)], extra),
	"texts": {path: body | some path, body in texts; is_string(body)},
}})]

# Two conforming records and their index, with `changes` applied.
standard(changes) := object.union(
	{
		"docs/decisions/README.md": index_linking(["0000-charter", "0001-use-a-queue"]),
		"docs/decisions/template.md": "# Template\n",
		"docs/decisions/0000-charter.md": conforming,
		"docs/decisions/0001-use-a-queue.md": conforming,
	},
	changes,
)

changed(changes) := repository(standard(changes), [])

messages(findings, id) := {f.message | some f in findings; f.id == id}

test_conforming_records if {
	count(records.findings) == 0 with input as changed({})
		with data.conventions.index as td.index
}

test_nothing_without_a_decisions_directory if {
	count(records.findings) == 0 with input as repository({"README.md": "# x\n"}, [".github/workflows/x.yml"])
		with data.conventions.index as td.index
}

test_dec_01_file_names if {
	result := records.findings with input as repository(
		standard({
			"docs/decisions/0002_Use_Redis.md": conforming,
			"docs/decisions/archive/0003-old.md": conforming,
		}),
		[],
	)
		with data.conventions.index as td.index
	td.pairs(result) == {
		["DEC-01", "docs/decisions/0002_Use_Redis.md"],
		["DEC-01", "docs/decisions/archive/0003-old.md"],
	}
	messages(result, "DEC-01") == {
		concat(" ", [
			`decision record "0002_Use_Redis" is not named NNNN-kebab-slug; rename it to a four-digit`,
			"number and a lowercase, hyphenated slug, such as 0007-store-sessions-in-the-database",
		]),
		concat(" ", [
			"docs/decisions/archive/0003-old.md is in a subdirectory of docs/decisions, where only",
			"NNNN-slug.md records, README.md and template.md belong; move it into docs/decisions as a",
			"record, or out of the decisions directory",
		]),
	}
}

site := "docs/site/(docs)/adrs"

directory_form := td.declaration({"decisions": {"path": site, "form": "directory", "page": "+page.md"}})

test_dec_01_directory_form if {
	texts := {
		concat("/", [site, "+page.md"]): "[a](/adrs/0001-first) [b](./0002-second/)\n",
		concat("/", [site, "template/+page.md"]): "# Template\n",
		concat("/", [site, "0001-first/+page.md"]): conforming,
		concat("/", [site, "0002-second/+page.md"]): conforming,
		concat("/", [site, "0002-second/notes.md"]): "notes\n",
		concat("/", [site, "0003-Third/+page.md"]): conforming,
		concat("/", [site, "0004-loose.md"]): conforming,
	}
	docs := array.concat(repository(texts, []), [directory_form])
	result := records.findings with input as docs
		with data.conventions.index as td.index
	td.pairs(result) == {
		["DEC-01", concat("/", [site, "0003-Third/+page.md"])],
		["DEC-01", concat("/", [site, "0004-loose.md"])],
	}
}

test_dec_01_directory_form_default_page if {
	declared := td.declaration({"decisions": {"path": "docs/adrs", "form": "directory"}})
	texts := {"docs/adrs/README.md": "[a](0001-first/README.md)\n", "docs/adrs/0001-first/README.md": conforming}
	count(records.findings) == 0 with input as array.concat(repository(texts, []), [declared])
		with data.conventions.index as td.index
}

test_dec_02_missing_and_unparseable_frontmatter if {
	result := records.findings with input as repository(
		standard({
			"docs/decisions/0000-charter.md": "# Charter\n",
			"docs/decisions/0001-use-a-queue.md": "---\ntitle: [unclosed\n---\n# x\n",
		}),
		[],
	)
		with data.conventions.index as td.index
	messages(result, "DEC-02") == {
		"the decision record has no frontmatter; start it with a --- block holding at least title, date and status",
		"the decision record's frontmatter is not valid YAML; fix the block between the --- lines",
	}
}

test_dec_02_schema_problems if {
	docs := changed({"docs/decisions/0001-use-a-queue.md": record({"status": "done", "owner": "x"})})
	result := records.findings with input as docs
		with data.conventions.index as td.index
	messages(result, "DEC-02") == {
		"the frontmatter: Additional property owner is not allowed. (1 more problem in the frontmatter)",
	}
}

# The real schema, as the index carries it: OPA honours its draft-07
# if/then, so a superseded record without superseded_by fails.
test_dec_02_real_schema_requires_superseded_by if {
	texts := standard({"docs/decisions/0001-use-a-queue.md": record({"status": "superseded"})})
	result := records.findings with input as repository(texts, [])
	td.pairs(result) == {["DEC-02", "docs/decisions/0001-use-a-queue.md"]}
}

test_real_schema_accepts_every_field if {
	fields := {
		"status": "accepted",
		"deciders": ["@a"],
		"consulted": ["@b"],
		"informed": ["@c"],
		"amends": ["0000"],
	}
	texts := standard({
		"docs/decisions/0001-use-a-queue.md": record(fields),
		"docs/decisions/0000-charter.md": record({"amended_by": ["0001"]}),
	})
	count(records.findings) == 0 with input as repository(texts, [])
}

test_dec_03_duplicate_numbers if {
	result := records.findings with input as repository(
		standard({
			"docs/decisions/README.md": index_linking(["0000-charter", "0001-use-a-queue", "0001-use-a-cache"]),
			"docs/decisions/0001-use-a-cache.md": conforming,
		}),
		[],
	)
		with data.conventions.index as td.index
	messages(result, "DEC-03") == {
		concat(" ", [
			"number 0001 is also used by 0001-use-a-cache; give this decision the next unused number,",
			"since a number is never shared",
		]),
		concat(" ", [
			"number 0001 is also used by 0001-use-a-queue; give this decision the next unused number,",
			"since a number is never shared",
		]),
	}
}

test_dec_03_gap if {
	result := records.findings with input as repository(
		standard({
			"docs/decisions/README.md": index_linking(["0000-charter", "0001-use-a-queue", "0010-later"]),
			"docs/decisions/0010-later.md": conforming,
		}),
		[],
	)
		with data.conventions.index as td.index
	td.pairs(result) == {["DEC-03", "docs/decisions/0010-later.md"]}
	messages(result, "DEC-03") == {concat(" ", [
		"no decision record is numbered 0009, the number before 0010; a record is never deleted, so",
		"restore it (a withdrawn decision stays, with status rejected or deprecated), or renumber this",
		"record if it is new",
	])}
}

test_dec_03_first_number if {
	texts := {"docs/decisions/README.md": "[x](0005-late.md)\n", "docs/decisions/0005-late.md": conforming}
	result := records.findings with input as repository(texts, [])
		with data.conventions.index as td.index
	messages(result, "DEC-03") == {
		"the first decision record is numbered 0005; number records from 0000 or 0001, without gaps",
	}
}

test_dec_03_numbering_from_one if {
	texts := {"docs/decisions/README.md": "[x](0001-first.md)\n", "docs/decisions/0001-first.md": conforming}
	count(records.findings) == 0 with input as repository(texts, [])
		with data.conventions.index as td.index
}

test_dec_04_one_sided_links if {
	result := records.findings with input as repository(
		standard({
			"docs/decisions/0001-use-a-queue.md": record({"supersedes": ["0000"], "amends": ["0007"]}),
		}),
		[],
	)
		with data.conventions.index as td.index
	td.pairs(result) == {
		["DEC-04", "docs/decisions/0000-charter.md"],
		["DEC-04", "docs/decisions/0001-use-a-queue.md"],
	}
	messages(result, "DEC-04") == {
		`0001 lists 0000 in supersedes, but this record's superseded_by does not list 0001; add "0001" to superseded_by`,
		"amends lists 0007, but no decision record is numbered 0007; correct the number or remove it",
	}
}

test_dec_04_back_links_from_the_older_record if {
	result := records.findings with input as repository(
		standard({
			"docs/decisions/0000-charter.md": record({"amended_by": ["0001"]}),
		}),
		[],
	)
		with data.conventions.index as td.index
	messages(result, "DEC-04") == {
		`0000 lists 0001 in amended_by, but this record's amends does not list 0000; add "0000" to amends`,
	}
}

test_dec_04_status_matches_superseded_by if {
	result := records.findings with input as repository(
		standard({
			"docs/decisions/0000-charter.md": record({"superseded_by": ["0001"]}),
			"docs/decisions/0001-use-a-queue.md": record({"supersedes": ["0000"]}),
		}),
		[],
	)
		with data.conventions.index as td.index
	messages(result, "DEC-04") == {
		`superseded_by is set but the status is "accepted"; a decision another replaces has status superseded`,
	}
}

test_dec_04_agreeing_links if {
	result := records.findings with input as repository(
		standard({
			"docs/decisions/0000-charter.md": record({"status": "superseded", "superseded_by": ["0001"]}),
			"docs/decisions/0001-use-a-queue.md": record({"supersedes": ["0000"]}),
		}),
		[],
	)
		with data.conventions.index as td.index
	not "DEC-04" in td.ids(result)
}

test_dec_05_sections if {
	body := concat("", [
		"---\ntitle: x\ndate: 2026-01-01\nstatus: accepted\n---\n\n",
		"## Context and Problem Statement\n\nx\n\n### Decision\n\nx\n\n",
		"```markdown\n## Consequences\n```\n\n## Enforcement\n\nreview-only\n",
	])
	result := records.findings with input as changed({"docs/decisions/0001-use-a-queue.md": body})
		with data.conventions.index as td.index
	messages(result, "DEC-05") == {
		"the decision record has no `## Decision` section; add it (Context, Decision and Consequences are required)",
		concat("", [
			"the decision record has no `## Consequences` section; add it",
			" (Context, Decision and Consequences are required)",
		]),
	}
}

test_dec_06_missing_and_empty_enforcement if {
	base := "---\ntitle: x\ndate: 2026-01-01\nstatus: accepted\n---\n\n## Context\n\n## Decision\n\n## Consequences\n\n"
	result := records.findings with input as repository(
		standard({
			"docs/decisions/0000-charter.md": base,
			"docs/decisions/0001-use-a-queue.md": concat("", [base, "## Enforcement\n\n## References\n"]),
		}),
		[],
	)
		with data.conventions.index as td.index
	td.pairs(result) == {
		["DEC-06", "docs/decisions/0000-charter.md"],
		["DEC-06", "docs/decisions/0001-use-a-queue.md"],
	}
}

test_dec_06_enforcement_at_the_end if {
	body := concat("", [
		"---\ntitle: x\ndate: 2026-01-01\nstatus: accepted\n---\n\n",
		"## Context\n\n## Decision\n\n## Consequences\n\n## Enforcement\n\nGHA-07, checked by conftest.",
	])
	count(records.findings) == 0 with input as changed({"docs/decisions/0001-use-a-queue.md": body})
		with data.conventions.index as td.index
}

test_dec_07_missing_index if {
	result := records.findings with input as changed({"docs/decisions/README.md": null})
		with data.conventions.index as td.index
	td.pairs(result) == {["DEC-07", "docs/decisions/README.md"]}
}

test_dec_07_unlinked_record if {
	index := concat("\n", [
		"| [0000](0000-charter.md) | x |",
		"See 0001-use-a-queue for the rest, or [0001](0001-use-a-queue-v2.md).",
	])
	result := records.findings with input as changed({"docs/decisions/README.md": index})
		with data.conventions.index as td.index
	messages(result, "DEC-07") == {"the index does not link decision record 0001-use-a-queue; add a link to it"}
}

test_dec_07_reference_links if {
	index := "[0000]: ./0000-charter.md\n[0001]: 0001-use-a-queue.md\n"
	count(records.findings) == 0 with input as changed({"docs/decisions/README.md": index})
		with data.conventions.index as td.index
}
