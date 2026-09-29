# METADATA
# title: Release tags
# description: >-
#   An active tag ruleset committed under .github/rulesets/ covers every tag
#   release-please creates, blocks creating, moving and deleting them, and
#   lets only an App bypass it.
# scope: package
# custom:
#   convention: EC-0025
package conventions.checks.releases.tags

import data.conventions.lib.files
import data.conventions.lib.findings as lib
import data.conventions.lib.release_please as rp

# The rules that make a tag permanent once the release App creates it.
required_rules := ["creation", "deletion", "non_fast_forward", "update"]

# REL-12
findings contains lib.finding("REL-12", rp.config_path, message) if {
	some tag in release_tags
	not covered(tag)
	message := sprintf(
		concat(" ", [
			"no active tag ruleset in .github/rulesets/ covers %s, so anyone who can push may create,",
			"move or delete it; add one with target \"tag\" whose ref_name includes %s",
		]),
		[tag, suggested_pattern(tag)],
	)
}

# REL-13
findings contains lib.finding("REL-13", path, message) if {
	some path, ruleset in protecting
	missing := [rule | some rule in required_rules; not rule in rule_types(ruleset)]
	count(missing) > 0
	message := sprintf(
		concat(" ", [
			"the tag ruleset protecting release tags has no %s rule; add %s so a release tag can be",
			"neither created by hand nor moved or deleted after it is cut",
		]),
		[concat(", ", missing), concat(", ", missing)],
	)
}

findings contains lib.finding("REL-13", path, message) if {
	some path, ruleset in protecting
	some actor in files.as_list(ruleset.bypass_actors)
	is_object(actor)
	object.get(actor, "actor_type", "") != "Integration"
	message := sprintf(
		concat(" ", [
			"the tag ruleset protecting release tags lets a %s bypass it; only the release App",
			"(actor_type \"Integration\") may create a release tag",
		]),
		[object.get(actor, "actor_type", "actor with no actor_type")],
	)
}

# A sample of each tag the config creates: vX.Y.Z for one package,
# <component>/vX.Y.Z for each of several.
release_tags contains "refs/tags/v1.0.0" if {
	rp.configured
	count(rp.packages) == 1
}

release_tags contains sprintf("refs/tags/%s/v1.0.0", [pkg.component]) if {
	rp.several
	some pkg in rp.packages
	is_string(pkg.component)
	pkg.component != ""
}

suggested_pattern(tag) := concat("", [regex.replace(tag, `v1\.0\.0$`, ""), "v*"])

tag_rulesets[path] := ruleset if {
	some path, ruleset in files.rulesets
	ruleset.target == "tag"
	ruleset.enforcement == "active"
}

covered(tag) if {
	some ruleset in tag_rulesets
	covers(ruleset, tag)
}

covers(ruleset, tag) if {
	not excluded(ruleset, tag)
	some pattern in files.as_list(ruleset.conditions.ref_name.include)
	matches(pattern, tag)
}

excluded(ruleset, tag) if {
	some pattern in files.as_list(ruleset.conditions.ref_name.exclude)
	matches(pattern, tag)
}

# GitHub matches ruleset patterns with fnmatch: * stops at a slash, ** does
# not, and ~ALL is every ref.
matches("~ALL", _)

matches(pattern, tag) if {
	is_string(pattern)
	pattern != "~ALL"
	glob.match(pattern, ["/"], tag)
}

# The active tag rulesets that cover at least one release tag.
protecting[path] := ruleset if {
	some path, ruleset in tag_rulesets
	some tag in release_tags
	covers(ruleset, tag)
}

rule_types(ruleset) := {rule.type |
	some rule in files.as_list(ruleset.rules)
	is_string(rule.type)
}
