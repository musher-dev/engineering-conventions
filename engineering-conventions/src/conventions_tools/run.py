"""The runner: check a repository against the conventions with conftest.

Rego decides every finding, including profile selection, severity and
waivers (the `main` router). This module only gathers input, invokes conftest,
reports files that cannot be parsed, and renders findings. `bin/conventions`
is the consumer's equivalent, with no Python.
"""

import json
import re
import shutil
import subprocess
import tempfile
import tomllib
from collections.abc import Iterable
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import cast

from conventions_tools.content import SEVERITY_RANK
from conventions_tools.loading import (
    as_list,
    as_map,
    get_str,
    json_problem,
    yaml_problem,
)
from conventions_tools.paths import (
    index_file,
    rego_dir,
    release_file,
)

DECLARATION = ".repo/conventions.yaml"
OUTPUTS = ".repo/outputs.yaml"
# Where ADOPT-09 looks for the mise entry that pins the release; the same
# list as mise_config_paths in checks/rego/lib/files.rego.
MISE_CONFIGS = (
    "mise.toml",
    ".mise.toml",
    ".config/mise.toml",
    ".config/mise/config.toml",
    "mise/config.toml",
    ".devcontainer/mise.toml",
)
PARSE_ID = "PARSE"
WORKFLOW_DIR = ".github/workflows"
# Matched case-insensitively, so a `.YML` workflow is checked (and GHA-01
# asks for the lowercase extension) instead of silently skipped.
WORKFLOW_SUFFIXES = frozenset({".yml", ".yaml"})
INPUT_GLOBS = (
    ".github/actions/**/action.yml",
    ".github/actions/**/action.yaml",
    ".github/rulesets/*.json",
)
# How conftest names the file it could not parse when it aborts.
CONFTEST_PARSE_ERROR = re.compile(r"parse configurations: (?P<reason>.*), path: (?P<path>\S+)\s*$")


class RunnerError(Exception):
    """The check could not run; the message says what to fix."""


@dataclass(frozen=True)
class Finding:
    id: str
    path: str
    message: str
    severity: str
    url: str
    convention: str

    def line(self) -> str:
        return f"{self.severity} [{self.id}] {self.path} — {self.message} {self.url}"


@dataclass(frozen=True, order=True)
class ParseError:
    """A file left out of the check because it is not valid YAML or JSON."""

    path: str
    reason: str

    def line(self) -> str:
        return f"error [{PARSE_ID}] {self.path} — {self.reason}"

    def as_finding(self) -> Finding:
        return Finding(PARSE_ID, self.path, self.reason, "error", "", "")


@dataclass(frozen=True)
class Report:
    findings: list[Finding]
    errors: list[ParseError]


def sort_findings(findings: Iterable[Finding]) -> list[Finding]:
    return sorted(findings, key=lambda item: (item.path, item.id, item.message))


def utc_now() -> str:
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def validate_now(value: str) -> str:
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError as error:
        raise RunnerError(f"--now {value!r} is not an RFC 3339 timestamp") from error
    if parsed.tzinfo is None:
        raise RunnerError(f"--now {value!r} has no UTC offset; append Z or +00:00")
    return value


def input_files(repo: Path) -> list[str]:
    """Repository-relative paths conftest reads, in a stable order."""
    found = {
        path.relative_to(repo).as_posix()
        for pattern in INPUT_GLOBS
        for path in repo.glob(pattern)
        if path.is_file()
    }
    found |= {
        path.relative_to(repo).as_posix()
        for path in (repo / WORKFLOW_DIR).glob("*")
        if path.is_file() and path.suffix.lower() in WORKFLOW_SUFFIXES
    }
    found |= {name for name in (DECLARATION, OUTPUTS, *MISE_CONFIGS) if (repo / name).is_file()}
    return sorted(found)


def _git_files(repo: Path) -> list[str] | None:
    """Tracked and untracked-but-not-ignored files, when repo is a git work tree root.

    A directory inside some other repository (a fixture, say) is walked
    instead: its files are relative to itself, not to that repository.
    """
    git = shutil.which("git")
    if git is None:
        return None
    top = subprocess.run(
        [git, "-C", str(repo), "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=False,
    )
    if top.returncode != 0 or Path(top.stdout.strip()).resolve() != repo.resolve():
        return None
    listed = subprocess.run(
        [git, "-C", str(repo), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        capture_output=True,
        text=True,
        check=True,
    )
    # The index still lists a file deleted from the work tree until the
    # deletion is staged; only files that exist are part of the repository.
    return sorted({name for name in listed.stdout.split("\0") if name and (repo / name).exists()})


def _walk_files(repo: Path) -> list[str]:
    return sorted(
        path.relative_to(repo).as_posix()
        for path in repo.rglob("*")
        if path.is_file() and ".git" not in path.relative_to(repo).parts
    )


def inventory(repo: Path) -> list[str]:
    files = _git_files(repo)
    return files if files is not None else _walk_files(repo)


def _conftest() -> str:
    found = shutil.which("conftest")
    if found is None:
        raise RunnerError(
            "conftest is not on PATH. Install the version pinned in .devcontainer/mise.toml "
            "(`task tools:install`), or put a conftest binary on PATH."
        )
    return found


def parse_problem(repo: Path, relative: str) -> str | None:
    """Why a file conftest would read cannot be parsed, in one line, or None."""
    try:
        text = (repo / relative).read_text(encoding="utf-8")
    except UnicodeDecodeError as error:
        return f"not UTF-8 text: {error.reason} at byte {error.start}"
    if relative.endswith(".toml"):
        return toml_problem(text)
    return json_problem(text) if relative.endswith(".json") else yaml_problem(text)


def toml_problem(text: str) -> str | None:
    try:
        tomllib.loads(text)
    except tomllib.TOMLDecodeError as error:
        return f"not valid TOML: {' '.join(str(error).split())}"
    return None


def conftest_command(
    product: Path,
    scratch: Path,
    files: list[str],
    release: Path | None = None,
) -> list[str]:
    data = [index_file(product), scratch / "runtime.json"]
    if release is not None:
        data.append(release)
    command = [_conftest(), "test", "--combine", "-p", str(rego_dir(product))]
    for path in data:
        command += ["-d", str(path)]
    return [*command, "-o", "json", "--no-color", *files, str(scratch / "inventory.json")]


def _finding_from_result(result: dict[str, object], bucket: str) -> Finding:
    metadata = as_map(result.get("metadata"))
    missing = [
        key for key in ("id", "path", "message", "url", "convention") if not get_str(metadata, key)
    ]
    if missing:
        raise RunnerError(
            f"conftest returned a {bucket} result without {', '.join(missing)}: "
            f"{json.dumps(result, sort_keys=True)}"
        )
    severity = get_str(metadata, "severity") or ("error" if bucket == "failures" else "warning")
    return Finding(
        id=get_str(metadata, "id"),
        path=get_str(metadata, "path"),
        message=get_str(metadata, "message"),
        severity=severity,
        url=get_str(metadata, "url"),
        convention=get_str(metadata, "convention"),
    )


def parse_conftest_output(stdout: str) -> list[Finding]:
    try:
        results = cast("object", json.loads(stdout))
    except json.JSONDecodeError as error:
        raise RunnerError(f"conftest output is not JSON: {stdout[:500]!r}") from error
    findings: list[Finding] = []
    for entry in map(as_map, as_list(results)):
        for bucket in ("failures", "warnings"):
            findings.extend(
                _finding_from_result(as_map(item), bucket) for item in as_list(entry.get(bucket))
            )
    return findings


class UnparsableInputError(RunnerError):
    """conftest aborted on a file the runner's own parse accepted."""

    def __init__(self, error: ParseError) -> None:
        super().__init__(error.line())
        self.error = error


def run_conftest(
    product: Path, repo: Path, files: list[str], now: str, release: Path | None = None
) -> list[Finding]:
    if not index_file(product).is_file():
        raise RunnerError(f"{index_file(product)} is missing; run `conventions generate`")
    if not rego_dir(product).is_dir():
        raise RunnerError(f"{rego_dir(product)} is missing")
    with tempfile.TemporaryDirectory(prefix="conventions-") as temp:
        scratch = Path(temp)
        runtime = {"conventions": {"runtime": {"now": now}}}
        (scratch / "runtime.json").write_text(json.dumps(runtime), encoding="utf-8")
        listing = {"conventions_inventory": {"files": inventory(repo)}}
        (scratch / "inventory.json").write_text(json.dumps(listing), encoding="utf-8")
        completed = subprocess.run(
            conftest_command(product, scratch, files, release),
            cwd=repo,
            capture_output=True,
            text=True,
            check=False,
        )
    # conftest exits 1 both when it reports failures and when it cannot load
    # the policies or inputs; only the first prints results on stdout.
    unparsed = CONFTEST_PARSE_ERROR.search(completed.stderr.strip())
    if not completed.stdout.strip() and unparsed and unparsed["path"] in files:
        reason = " ".join(unparsed["reason"].split())
        raise UnparsableInputError(
            ParseError(unparsed["path"], f"conftest cannot parse it: {reason}")
        )
    if completed.returncode not in {0, 1} or not completed.stdout.strip():
        raise RunnerError(
            f"conftest exited {completed.returncode}: "
            f"{completed.stderr.strip() or completed.stdout.strip()}"
        )
    return parse_conftest_output(completed.stdout)


def _release(product: Path, release: Path | None) -> Path | None:
    # conftest runs from the checked repository, so the path must be absolute.
    if release is not None:
        return release.resolve()
    return release_file(product) if release_file(product).is_file() else None


def check(product: Path, repo: Path, now: str, release: Path | None = None) -> Report:
    """Check `repo`; `release` overrides the bundle's release data (fixtures use it)."""
    repo = repo.resolve()
    if not repo.is_dir():
        raise RunnerError(f"{repo} is not a directory")
    release = _release(product, release)
    files = input_files(repo)
    errors = [
        ParseError(relative, problem)
        for relative in files
        if (problem := parse_problem(repo, relative)) is not None
    ]
    unparsed = {error.path for error in errors}
    files = [relative for relative in files if relative not in unparsed]
    findings, skipped = _conftest_findings(product, repo, files, now, release)
    return Report(sort_findings(findings), sorted(errors + skipped))


def _conftest_findings(
    product: Path, repo: Path, files: list[str], now: str, release: Path | None
) -> tuple[list[Finding], list[ParseError]]:
    """Run conftest, leaving out any file it refuses to parse.

    The runner's own parse catches almost every such file first; this covers
    a file the two parsers disagree on. Each retry drops one file, so it ends.
    """
    remaining = list(files)
    skipped: list[ParseError] = []
    while True:
        try:
            return run_conftest(product, repo, remaining, now, release), skipped
        except UnparsableInputError as unparsable:
            skipped.append(unparsable.error)
            remaining.remove(unparsable.error.path)


def fails(findings: list[Finding], fail_on: str) -> bool:
    threshold = SEVERITY_RANK[fail_on]
    return any(SEVERITY_RANK.get(finding.severity, 0) >= threshold for finding in findings)


def render_text(report: Report) -> str:
    lines = [finding.line() for finding in report.findings]
    lines += [error.line() for error in report.errors]
    return "".join(f"{line}\n" for line in lines)


def render_json(report: Report) -> str:
    entries = [*report.findings, *(error.as_finding() for error in report.errors)]
    return json.dumps([asdict(entry) for entry in entries], indent=2, sort_keys=True) + "\n"
