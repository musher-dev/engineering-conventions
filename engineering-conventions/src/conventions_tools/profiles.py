"""Resolving convention profiles into the requirement lists the router enforces.

Inheritance flattens selectors, not results: a profile's includes, excludes
and severity overrides are the union of its own and every ancestor's, and
the union is then applied once to the catalog. That keeps the result
independent of inheritance order, and an exclude anywhere in the ancestry
always wins.
"""

from dataclasses import dataclass, field

from conventions_tools.content import (
    SEVERITY_RANK,
    Profile,
    Requirement,
    requirement_sort_key,
)


class ProfileError(Exception):
    """A profile cannot be resolved; the message says which and why."""


@dataclass(frozen=True)
class ResolvedProfile:
    id: str
    display_name: str
    requirements: tuple[str, ...]
    severity: dict[str, str]


@dataclass
class _Selectors:
    families: set[str] = field(default_factory=set[str])
    conventions: set[str] = field(default_factory=set[str])
    requirements: set[str] = field(default_factory=set[str])
    excludes: set[str] = field(default_factory=set[str])
    include_proposed: bool = False
    raises: dict[str, str] = field(default_factory=dict[str, str])


def _merge_raise(raises: dict[str, str], requirement_id: str, severity: str) -> None:
    current = raises.get(requirement_id)
    if current is None or SEVERITY_RANK[severity] > SEVERITY_RANK[current]:
        raises[requirement_id] = severity


def _selectors(
    profile_id: str,
    profiles: dict[str, Profile],
    chain: tuple[str, ...],
) -> _Selectors:
    if profile_id in chain:
        cycle = " -> ".join((*chain[chain.index(profile_id) :], profile_id))
        raise ProfileError(f"profile inheritance cycle: {cycle}")
    profile = profiles.get(profile_id)
    if profile is None:
        referrer = f"profile {chain[-1]!r} inherits" if chain else "requested"
        raise ProfileError(f"{referrer} unknown profile {profile_id!r}")
    merged = _Selectors()
    inherited_proposed = False
    for parent in profile.inherits:
        inherited = _selectors(parent, profiles, (*chain, profile_id))
        merged.families |= inherited.families
        merged.conventions |= inherited.conventions
        merged.requirements |= inherited.requirements
        merged.excludes |= inherited.excludes
        inherited_proposed = inherited_proposed or inherited.include_proposed
        for requirement_id, severity in inherited.raises.items():
            _merge_raise(merged.raises, requirement_id, severity)
    merged.families |= set(profile.include_families)
    merged.conventions |= set(profile.include_conventions)
    merged.requirements |= set(profile.include_requirements)
    merged.excludes |= set(profile.exclude_requirements)
    merged.include_proposed = (
        inherited_proposed if profile.include_proposed is None else profile.include_proposed
    )
    for requirement_id, severity in profile.severity.items():
        inherited_severity = merged.raises.get(requirement_id)
        if inherited_severity and SEVERITY_RANK[severity] < SEVERITY_RANK[inherited_severity]:
            raise ProfileError(
                f"profile {profile_id!r} lowers {requirement_id} from the {inherited_severity} "
                f"it inherits to {severity}; a profile may only raise a severity"
            )
        merged.raises[requirement_id] = severity
    return merged


def _check_references(
    profile_id: str,
    selectors: _Selectors,
    requirements: dict[str, Requirement],
    families: set[str],
) -> None:
    conventions = {req.convention for req in requirements.values()}
    unknown = [
        *(f"family {name}" for name in sorted(selectors.families - families)),
        *(f"convention {name}" for name in sorted(selectors.conventions - conventions)),
        *(
            f"requirement {name}"
            for name in sorted(
                (selectors.requirements | selectors.excludes | set(selectors.raises))
                - set(requirements)
            )
        ),
    ]
    if unknown:
        raise ProfileError(f"profile {profile_id!r} names unknown {', '.join(unknown)}")


def _selected(req: Requirement, selectors: _Selectors) -> bool:
    if req.status == "retired" or req.id in selectors.excludes:
        return False
    if req.status == "proposed" and not selectors.include_proposed:
        return False
    return (
        req.family in selectors.families
        or req.convention in selectors.conventions
        or req.id in selectors.requirements
    )


def _severities(
    profile_id: str,
    selected: list[Requirement],
    raises: dict[str, str],
) -> dict[str, str]:
    selected_ids = {req.id for req in selected}
    stray = sorted(set(raises) - selected_ids, key=requirement_sort_key)
    if stray:
        raise ProfileError(
            f"profile {profile_id!r} sets a severity for requirements it does not select: "
            + ", ".join(stray)
        )
    severity: dict[str, str] = {}
    for req in selected:
        override = raises.get(req.id, req.severity)
        if SEVERITY_RANK[override] < SEVERITY_RANK[req.severity]:
            raise ProfileError(
                f"profile {profile_id!r} lowers {req.id} from {req.severity} to {override}; "
                "a profile may only raise a severity"
            )
        severity[req.id] = override
    return severity


def resolve(
    profile_id: str,
    profiles: dict[str, Profile],
    requirements: dict[str, Requirement],
    families: set[str],
) -> ResolvedProfile:
    selectors = _selectors(profile_id, profiles, ())
    _check_references(profile_id, selectors, requirements, families)
    selected = sorted(
        (req for req in requirements.values() if _selected(req, selectors)),
        key=lambda req: requirement_sort_key(req.id),
    )
    return ResolvedProfile(
        id=profile_id,
        display_name=profiles[profile_id].display_name,
        requirements=tuple(req.id for req in selected),
        severity=_severities(profile_id, selected, selectors.raises),
    )


def resolve_all(
    profiles: tuple[Profile, ...],
    requirements: tuple[Requirement, ...],
    families: set[str],
) -> dict[str, ResolvedProfile]:
    by_id = {profile.id: profile for profile in profiles}
    catalog = {req.id: req for req in requirements}
    return {
        profile_id: resolve(profile_id, by_id, catalog, families) for profile_id in sorted(by_id)
    }
