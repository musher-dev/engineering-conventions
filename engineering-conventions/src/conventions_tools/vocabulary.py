"""Projecting terminology into the vocabulary the Rego checks and Vale read."""

from dataclasses import dataclass

from conventions_tools.content import Alias, Term, Terminology
from conventions_tools.loading import ContentError

RESPONSIBILITY_TAG = "gha.responsibility"
CAPABILITY_TAG = "gha.capability"
ACTION_TAG = "gha.action"
OUTPUT_KIND_TAG = "outputs.kind"
SYSTEM_TAG = "repository.system"
KIND_TAG = "repository.kind"
LIFECYCLE_TAG = "repository.lifecycle"
AUDIENCE_TAG = "repository.audience"
INTERFACE_FORMAT_TAG = "interfaces.format"
COMPATIBILITY_TAG = "interfaces.compatibility"
RUNTIME_CAPABILITY_TAG = "runtime.capability"
# Environment variable names reserved for every Musher program; the token is
# the name in lower kebab-case (musher-environment is MUSHER_ENVIRONMENT).
ORG_SCOPED_VARIABLE_TAG = "env.org-scoped"
# Every tag whose terms carry a token the checks read; a token is unique
# within each (invariants.terminology_consistent).
TOKEN_TAGS = (
    RESPONSIBILITY_TAG,
    CAPABILITY_TAG,
    ACTION_TAG,
    OUTPUT_KIND_TAG,
    SYSTEM_TAG,
    KIND_TAG,
    LIFECYCLE_TAG,
    AUDIENCE_TAG,
    INTERFACE_FORMAT_TAG,
    COMPATIBILITY_TAG,
    RUNTIME_CAPABILITY_TAG,
    ORG_SCOPED_VARIABLE_TAG,
)
REPOSITORY_NAME_SCOPE = "repository-name"
# Words that stand in for an action token as the first token of a composite
# action's directory. GHA-20 only suggests the term's token for them; they are
# never banned elsewhere, so validate and verify stay workflow responsibilities.
ACTION_TOKEN_SCOPE = "action-token"
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


def banned_repository_tokens(terminology: Terminology) -> dict[str, str]:
    """Tokens banned anywhere in a repository name, each with the advice REPO-10 prints."""
    banned: dict[str, str] = {}
    missing: list[str] = []
    for term, alias in _terms_with_aliases(terminology):
        if alias.status != "banned" or REPOSITORY_NAME_SCOPE not in alias.scope:
            continue
        if alias.note is None:
            missing.append(
                f"{terminology.path}: alias {alias.text!r} of {term.id} is banned in repository "
                "names but has no note to say what to do instead"
            )
            continue
        banned[alias.text] = alias.note
    if missing:
        raise ContentError(missing)
    return banned


def action_synonyms(terminology: Terminology) -> dict[str, str]:
    """Stand-ins for an action token, each mapped to the token GHA-20 suggests."""
    synonyms: dict[str, str] = {}
    missing: list[str] = []
    for term, alias in _terms_with_aliases(terminology):
        if alias.status != "banned" or ACTION_TOKEN_SCOPE not in alias.scope:
            continue
        if ACTION_TAG not in term.tags or term.token is None:
            missing.append(
                f"{terminology.path}: alias {alias.text!r} of {term.id} is scoped to action "
                f"tokens but the term is not a {ACTION_TAG} term with a token"
            )
            continue
        synonyms[alias.text] = term.token
    if missing:
        raise ContentError(missing)
    return synonyms


def schedule_tokens(terminology: Terminology) -> list[str]:
    return sorted(
        alias.text
        for term, alias in _terms_with_aliases(terminology)
        if term.id == SCHEDULE_TERM and alias.status == "banned" and "identifier" in alias.scope
    )


def org_scoped_variables(terminology: Terminology) -> list[str]:
    """The reserved variable names ENVS-25 accepts under any consumer prefix."""
    return sorted(
        token.upper().replace("-", "_") for token in tokens(terminology, ORG_SCOPED_VARIABLE_TAG)
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
        "action_synonyms": action_synonyms(terminology),
        "action_tokens": tokens(terminology, ACTION_TAG),
        "banned_identifier_tokens": banned_identifier_tokens(terminology),
        "banned_repository_tokens": banned_repository_tokens(terminology),
        "capability_tokens": tokens(terminology, CAPABILITY_TAG),
        "display_forms": display_forms(terminology),
        "interface_compatibilities": tokens(terminology, COMPATIBILITY_TAG),
        "interface_formats": tokens(terminology, INTERFACE_FORMAT_TAG),
        "org_scoped_variables": org_scoped_variables(terminology),
        "output_kinds": tokens(terminology, OUTPUT_KIND_TAG),
        "repository_audiences": tokens(terminology, AUDIENCE_TAG),
        "repository_kinds": tokens(terminology, KIND_TAG),
        "repository_lifecycles": tokens(terminology, LIFECYCLE_TAG),
        "repository_systems": tokens(terminology, SYSTEM_TAG),
        "responsibility_tokens": tokens(terminology, RESPONSIBILITY_TAG),
        "runtime_capabilities": tokens(terminology, RUNTIME_CAPABILITY_TAG),
        "schedule_tokens": schedule_tokens(terminology),
    }
