"""Projecting terminology into the vocabulary the Rego checks and Vale read."""

from dataclasses import dataclass

from conventions_tools.content import Alias, Term, Terminology
from conventions_tools.loading import ContentError

RESPONSIBILITY_TAG = "gha.responsibility"
CAPABILITY_TAG = "gha.capability"
ACTION_TAG = "gha.action"
OUTPUT_KIND_TAG = "outputs.kind"
# The term whose identifier aliases name when a workflow runs. They are banned
# anywhere in a filename, unlike the other banned tokens, which are synonyms
# banned only where the responsibility goes (GHA-05).
SCHEDULE_TERM = "gha.scheduled-workflow"


@dataclass(frozen=True)
class ProseSwap:
    text: str
    suggest: str


def tokens(terminology: Terminology, tag: str) -> list[str]:
    return sorted(
        {
            term.token
            for term in terminology.terms
            if tag in term.tags and term.token and not term.deprecated
        }
    )


def _terms_with_aliases(terminology: Terminology) -> list[tuple[Term, Alias]]:
    return [(term, alias) for term in terminology.terms for alias in term.aliases]


def identifier_suggestion(term: Term, alias: Alias) -> str | None:
    return alias.suggest or term.token


def banned_identifier_tokens(terminology: Terminology) -> dict[str, str]:
    banned: dict[str, str] = {}
    missing: list[str] = []
    for term, alias in _terms_with_aliases(terminology):
        if alias.status != "banned" or "identifier" not in alias.scope:
            continue
        suggestion = identifier_suggestion(term, alias)
        if suggestion is None:
            missing.append(
                f"{terminology.path}: alias {alias.text!r} of {term.id} is banned in identifiers "
                "but neither the alias (suggest) nor the term (token) says what to use instead"
            )
            continue
        banned[alias.text] = suggestion
    if missing:
        raise ContentError(missing)
    return banned


def schedule_tokens(terminology: Terminology) -> list[str]:
    return sorted(
        alias.text
        for term, alias in _terms_with_aliases(terminology)
        if term.id == SCHEDULE_TERM and alias.status == "banned" and "identifier" in alias.scope
    )


def display_forms(terminology: Terminology) -> dict[str, str]:
    return dict(terminology.display_forms)


def prose_swaps(terminology: Terminology, status: str) -> list[ProseSwap]:
    swaps = [
        ProseSwap(text=alias.text, suggest=alias.suggest or term.display_name)
        for term, alias in _terms_with_aliases(terminology)
        if alias.status == status and "prose" in alias.scope
    ]
    return sorted(swaps, key=lambda swap: swap.text)


def project(terminology: Terminology) -> dict[str, object]:
    """The `vocabulary` object of index.json."""
    return {
        "action_tokens": tokens(terminology, ACTION_TAG),
        "banned_identifier_tokens": banned_identifier_tokens(terminology),
        "capability_tokens": tokens(terminology, CAPABILITY_TAG),
        "display_forms": display_forms(terminology),
        "output_kinds": tokens(terminology, OUTPUT_KIND_TAG),
        "responsibility_tokens": tokens(terminology, RESPONSIBILITY_TAG),
        "schedule_tokens": schedule_tokens(terminology),
    }
