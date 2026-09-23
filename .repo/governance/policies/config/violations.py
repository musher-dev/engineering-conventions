"""What can go wrong with the .config/ layout, and why each rule exists."""

from __future__ import annotations

from governance.reporting import Violation

DOCS = "CONFIGURATION.md#where-configuration-lives"


def missing_config_dir() -> Violation:
    return Violation(
        code="CFG-01",
        summary=".config/ does not exist",
        reason=(
            "The repo declares one home for tool configuration. Without the "
            "directory the convention is aspirational and the next config "
            "lands at the root."
        ),
        fix="Create .config/ and move tool configs into it.",
        where=".config/",
        docs=DOCS,
    )


def missing_index() -> Violation:
    return Violation(
        code="CFG-02",
        summary=".config/README.md is missing",
        reason=(
            "The index is what makes the directory self-explaining: which "
            "tool reads each file and how the file is reached."
        ),
        fix="Add .config/README.md with a row per config file.",
        where=".config/README.md",
        docs=DOCS,
    )


def not_in_index(rel: str) -> Violation:
    return Violation(
        code="CFG-03",
        summary=f"{rel} is not listed in the .config/ index",
        reason=(
            "A config absent from the index is invisible to the next reader, "
            "who cannot tell which tool consumes it or how."
        ),
        fix=f"Add a row for `{rel}` to the index table in .config/README.md.",
        where=f".config/{rel}",
        docs=DOCS,
    )


def orphaned(rel: str) -> Violation:
    return Violation(
        code="CFG-04",
        summary=f"{rel} is never referenced by any caller",
        reason=(
            "Configs are passed explicitly, so a file no caller names is dead "
            "weight -- it looks authoritative while affecting nothing."
        ),
        fix=(
            f"Reference .config/{rel} from taskfiles/, Taskfile.yml or a "
            "workflow, or delete it."
        ),
        where=f".config/{rel}",
        docs=DOCS,
    )


def dotted_filename(rel: str) -> Violation:
    name = rel.rsplit("/", 1)[-1]
    return Violation(
        code="CFG-05",
        summary=f"{rel} has a leading dot inside .config/",
        reason=(
            "The directory is already dotted. A second dot signals "
            "auto-discovery that is not happening and adds nothing."
        ),
        fix=f"Rename to {name.lstrip('.')}.",
        where=f".config/{rel}",
        docs=DOCS,
    )


def shadowing_root_config(name: str) -> Violation:
    return Violation(
        code="CFG-06",
        summary=f"{name} at the repo root shadows .config/lefthook.yml",
        reason=(
            "Lefthook's config search is first-match-wins over "
            "[lefthook.*, .lefthook.*, .config/lefthook.*], so a root file "
            "silently wins and different hooks run with no warning."
        ),
        fix=f"Delete ./{name}; the canonical config is .config/lefthook.yml.",
        where=name,
        docs=DOCS,
    )


def stray_root_config(name: str) -> Violation:
    return Violation(
        code="CFG-07",
        summary=f"{name} is a tool config sitting at the repo root",
        reason=(
            "Root dotfile accretion is the problem .config/ exists to "
            "prevent, and this repo is a template -- whatever it ships is "
            "replicated into every repo scaffolded from it."
        ),
        fix=f"Move {name} into .config/<concern>/ and pass its path explicitly.",
        where=name,
        docs=DOCS,
    )


def misplaced_top_level(name: str) -> Violation:
    return Violation(
        code="CFG-07",
        summary=f"{name} sits at the top level of .config/, not in a concern bucket",
        reason=(
            "The layout is .config/<concern>/<tool>.<ext>. Only the index and "
            "lefthook belong at the top level -- lefthook because its config "
            "search does not descend past .config/lefthook.*."
        ),
        fix=f"Move {name} into .config/<concern>/ and update its callers.",
        where=f".config/{name}",
        docs=DOCS,
    )


def executable_in_config(rel: str) -> Violation:
    return Violation(
        code="CFG-08",
        summary=f"{rel} is a program, not a declaration",
        reason=(
            ".config/ holds configuration and nothing else. A build asset "
            "belongs beside what builds it; a repo-level runner belongs in "
            ".repo/governance/."
        ),
        fix=f"Move .config/{rel} next to what uses it, or into .repo/.",
        where=f".config/{rel}",
        docs=DOCS,
    )


def dangling_reference(ref: str, caller: str) -> Violation:
    return Violation(
        code="CFG-09",
        summary=f"{caller} names {ref}, which does not exist",
        reason=(
            "CFG-04 proves every config has a caller; this proves every caller "
            "has a config. A tool handed a missing --config path either errors "
            "late or falls back to its defaults, silently checking something else."
        ),
        fix=f"Point {caller} at the real file under .config/, or create {ref}.",
        where=caller,
        docs=DOCS,
    )
