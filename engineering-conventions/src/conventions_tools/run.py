"""The runner: check a repository against the conventions with conftest.

Rego decides every finding, including profile selection, severity and
waivers (the `main` router). This module only gathers input, invokes conftest,
reports files that cannot be parsed, and renders findings. `bin/conventions`
is the consumer's equivalent, with no Python.
"""

import hashlib
import json
import os
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
    read_json,
    yaml_problem,
)
from conventions_tools.paths import (
    index_file,
    launcher_file,
    product_dir,
    rego_dir,
    release_file,
)

PARSE_ID = "PARSE"
# A pattern bin/conventions builds, one assignment per line:
#   NAME='regex'   or   NAME="${NAME}|"'regex'
LAUNCHER_PATTERN = re.compile(r"^(?P<name>[A-Z_]+)=(?:\"\$\{(?P=name)\}\|\")?'(?P<regex>[^']*)'$")
LAUNCHER_NUMBER = re.compile(r"^(?P<name>[A-Z_]+)=(?P<value>[0-9]+)$")
# A repository name the runner passes on; anything else is treated as unknown,
# as bin/conventions does.
REPOSITORY_NAME = re.compile(r"[A-Za-z0-9._-]+")
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
    # False for a finding in a family a staged adoption does not enforce yet:
    # reported, but never counted toward --fail-on (lib/enforcement.rego).
    enforced: bool = True

    def line(self) -> str:
        mark = "" if self.enforced else " (not enforced)"
        return f"{self.severity}{mark} [{self.id}] {self.path} — {self.message} {self.url}"


@dataclass(frozen=True, order=True)
class ParseError:
    """A file left out of the check because it is not valid YAML, TOML or JSON."""

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


@dataclass(frozen=True)
class Selection:
    """Which files the runner reads, and how: the patterns bin/conventions defines.

    Read from the launcher itself, so the two runners cannot select different
    files (decision 0015).
    """

    inputs: re.Pattern[str]
    jsonnet: re.Pattern[str]
    dockerfiles: re.Pattern[str]
    not_dockerfiles: re.Pattern[str]
    texts: re.Pattern[str]
    sizes: re.Pattern[str]
    digests: re.Pattern[str]
    text_limit: int


def selection(product: Path | None = None) -> Selection:
    patterns: dict[str, list[str]] = {}
    numbers: dict[str, int] = {}
    for line in launcher_file(product or product_dir()).read_text(encoding="utf-8").splitlines():
        if matched := LAUNCHER_PATTERN.match(line):
            patterns.setdefault(matched["name"], []).append(matched["regex"])
        elif matched := LAUNCHER_NUMBER.match(line):
            numbers[matched["name"]] = int(matched["value"])

    def compiled(name: str) -> re.Pattern[str]:
        if name not in patterns:
            raise RunnerError(f"bin/conventions defines no {name} pattern")
        return re.compile("|".join(patterns[name]))

    return Selection(
        inputs=compiled("INPUTS"),
        jsonnet=compiled("JSONNET"),
        dockerfiles=compiled("DOCKERFILES"),
        not_dockerfiles=compiled("NOT_DOCKERFILES"),
        texts=compiled("TEXTS"),
        sizes=compiled("SIZES"),
        digests=compiled("DIGESTS"),
        text_limit=numbers["TEXT_LIMIT"],
    )


def input_files(
    repo: Path, files: list[str] | None = None, chosen: Selection | None = None
) -> list[str]:
    """Repository-relative paths conftest reads, in a stable order."""
    pattern = (chosen or selection()).inputs
    return sorted(
        path for path in (inventory(repo) if files is None else files) if pattern.search(path)
    )


def _git(repo: Path, *arguments: str) -> subprocess.CompletedProcess[str] | None:
    git = shutil.which("git")
    if git is None:
        return None
    return subprocess.run(
        [git, "-C", str(repo), *arguments], capture_output=True, text=True, check=False
    )


def is_work_tree_root(repo: Path) -> bool:
    """Whether repo is the top of a git work tree, not a directory inside one."""
    top = _git(repo, "rev-parse", "--show-toplevel")
    return (
        top is not None
        and top.returncode == 0
        and Path(top.stdout.strip()).resolve() == repo.resolve()
    )


def remote_name(url: str) -> str:
    """The last path segment of a remote URL: https://, git@host:owner/x.git or ssh://."""
    last = url.strip().removesuffix("/").removesuffix(".git").rsplit("/", 1)[-1]
    return last.rsplit(":", 1)[-1]


def _valid_name(name: str | None) -> str | None:
    if name and name not in {".", ".."} and REPOSITORY_NAME.fullmatch(name):
        return name
    return None


def repository_name(repo: Path, given: str | None = None) -> str | None:
    """The repository's actual name, found the way bin/conventions finds it (EC-0010).

    `given` (--repository), else CONVENTIONS_REPOSITORY, else GITHUB_REPOSITORY
    when repo is GITHUB_WORKSPACE, else the origin remote when repo is a work
    tree root. Only the command line calls this: `check` never reads the
    environment, so fixtures and tests see only the name they pass.
    """
    name = given or os.environ.get("CONVENTIONS_REPOSITORY")
    github, workspace = os.environ.get("GITHUB_REPOSITORY"), os.environ.get("GITHUB_WORKSPACE")
    if not name and github and workspace and Path(workspace).resolve() == repo.resolve():
        name = github.rsplit("/", 1)[-1]
    if not name and is_work_tree_root(repo):
        origin = _git(repo, "remote", "get-url", "origin")
        if origin is not None and origin.returncode == 0:
            name = remote_name(origin.stdout)
    return _valid_name(name)


def _git_files(repo: Path) -> list[str] | None:
    """Tracked and untracked-but-not-ignored files, when repo is a git work tree root.

    A directory inside some other repository (a fixture, say) is walked
    instead: its files are relative to itself, not to that repository.
    """
    git = shutil.which("git")
    if git is None or not is_work_tree_root(repo):
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
            "conftest is not on PATH. Install the version pinned in .config/mise/config.toml "
            "(`task tools:install`), or put a conftest binary on PATH."
        )
    return found


def conftest_reason(error: str) -> str:
    """conftest's error on one line, as bin/inventory.jq shortens it."""
    reason = re.sub(r"\s+", " ", error)
    reason = re.sub(r"^ ?Error: ", "", reason)
    reason = re.sub(r"^parse configurations: ", "", reason)
    reason = re.sub(r" ?, path: .*$", "", reason)
    return "conftest cannot parse it: " + re.sub(r" $", "", reason)


def _preparse(repo: Path, parser: str, relative: str) -> tuple[object, str | None]:
    completed = subprocess.run(
        [_conftest(), "parse", "--combine", "--parser", parser, relative],
        cwd=repo,
        capture_output=True,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        return None, conftest_reason(completed.stderr)
    # --combine gives each file as {path, contents}, the shape conftest test reads.
    return as_map(as_list(json.loads(completed.stdout))[0]).get("contents"), None


def inventory_document(
    repo: Path, files: list[str], repository: str | None, chosen: Selection
) -> dict[str, object]:
    """The inventory conftest reads beside the files: what bin/inventory.jq writes."""
    parsed: list[dict[str, object]] = []
    unparsed: list[dict[str, str]] = []
    for parser, pattern, excluded in (
        ("jsonnet", chosen.jsonnet, None),
        ("dockerfile", chosen.dockerfiles, chosen.not_dockerfiles),
    ):
        for relative in files:
            if pattern.search(relative) and not (excluded and excluded.search(relative)):
                contents, problem = _preparse(repo, parser, relative)
                if problem is None:
                    parsed.append({"path": relative, "contents": contents})
                else:
                    unparsed.append({"path": relative, "reason": problem})
    texts = {
        relative: (repo / relative).read_text(encoding="utf-8", errors="replace")
        for relative in files
        if chosen.texts.search(relative) and (repo / relative).stat().st_size <= chosen.text_limit
    }
    sizes = {
        relative: (repo / relative).stat().st_size
        for relative in files
        if chosen.sizes.search(relative)
    }
    digests = {
        relative: hashlib.sha256((repo / relative).read_bytes()).hexdigest()
        for relative in files
        if chosen.digests.search(relative)
    }
    listing: dict[str, object] = {"files": files}
    if repository is not None:
        listing["repository"] = {"name": repository}
    listing |= {
        "texts": texts,
        "sizes": sizes,
        "digests": digests,
        "parsed": parsed,
        "unparsed": unparsed,
    }
    return {"conventions_inventory": listing}


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


def _policy_args(policies: Path) -> list[str]:
    # The policy files the release bundle ships, never the *_test.rego files
    # beside them: conftest compiles every file it is given, and the tests
    # double the compile cost of a check without adding a rule. A directory
    # with no policy file is passed whole, so conftest reports it.
    files = sorted(
        path for path in policies.rglob("*.rego") if not path.name.endswith("_test.rego")
    )
    if not files:
        return ["-p", str(policies)]
    return [arg for path in files for arg in ("-p", str(path))]


def conftest_command(
    product: Path,
    scratch: Path,
    files: list[str],
    release: Path | None = None,
) -> list[str]:
    data = [index_file(product), scratch / "runtime.json"]
    if release is not None:
        data.append(release)
    command = [_conftest(), "test", "--combine", *_policy_args(rego_dir(product))]
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
        enforced=metadata.get("enforced") is not False,
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


@dataclass(frozen=True)
class RunData:
    """What a run passes to conftest besides the files: the time, the release, the name."""

    now: str
    release: Path | None = None
    repository: str | None = None
    inventory: dict[str, object] | None = None


def run_conftest(product: Path, repo: Path, files: list[str], data: RunData) -> list[Finding]:
    if not index_file(product).is_file():
        raise RunnerError(f"{index_file(product)} is missing; run `conventions generate`")
    if not rego_dir(product).is_dir():
        raise RunnerError(f"{rego_dir(product)} is missing")
    with tempfile.TemporaryDirectory(prefix="conventions-") as temp:
        scratch = Path(temp)
        runtime = {"conventions": {"runtime": {"now": data.now}}}
        (scratch / "runtime.json").write_text(json.dumps(runtime), encoding="utf-8")
        document = data.inventory or inventory_document(
            repo, inventory(repo), data.repository, selection(product)
        )
        (scratch / "inventory.json").write_text(json.dumps(document), encoding="utf-8")
        completed = subprocess.run(
            conftest_command(product, scratch, files, data.release),
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


def check(
    product: Path,
    repo: Path,
    now: str,
    release: Path | None = None,
    repository: str | None = None,
) -> Report:
    """Check `repo`; `release` overrides the bundle's release data (fixtures use it).

    `repository` is the repository's actual name, which REPO-07 compares with
    the declared one; None leaves it unknown. It is never read from the
    environment here (see `repository_name`).
    """
    repo = repo.resolve()
    if not repo.is_dir():
        raise RunnerError(f"{repo} is not a directory")
    release = _release(product, release)
    listed = inventory(repo)
    chosen = selection(product)
    files = input_files(repo, listed, chosen)
    errors = [
        ParseError(relative, problem)
        for relative in files
        if (problem := parse_problem(repo, relative)) is not None
    ]
    unparsed = {error.path for error in errors}
    files = [relative for relative in files if relative not in unparsed]
    name = _valid_name(repository)
    document = inventory_document(repo, listed, name, chosen)
    errors += [
        ParseError(get_str(item, "path"), get_str(item, "reason"))
        for item in map(as_map, as_list(as_map(document["conventions_inventory"]).get("unparsed")))
    ]
    data = RunData(now, release, name, document)
    findings, skipped = _conftest_findings(product, repo, files, data)
    return Report(sort_findings(findings), sorted(errors + skipped))


def _conftest_findings(
    product: Path, repo: Path, files: list[str], data: RunData
) -> tuple[list[Finding], list[ParseError]]:
    """Run conftest, leaving out any file it refuses to parse.

    The runner's own parse catches almost every such file first; this covers
    a file the two parsers disagree on. Each retry drops one file, so it ends.
    """
    remaining = list(files)
    skipped: list[ParseError] = []
    while True:
        try:
            return run_conftest(product, repo, remaining, data), skipped
        except UnparsableInputError as unparsable:
            skipped.append(unparsable.error)
            remaining.remove(unparsable.error.path)


def fails(findings: list[Finding], fail_on: str) -> bool:
    threshold = SEVERITY_RANK[fail_on]
    return any(
        finding.enforced and SEVERITY_RANK.get(finding.severity, 0) >= threshold
        for finding in findings
    )


PARSE_TITLE = "A file that does not parse cannot be checked"


def requirement_titles(product: Path) -> dict[str, str]:
    """Each requirement's title, from the index the checks read."""
    index = as_map(as_map(as_map(read_json(index_file(product))).get("conventions")).get("index"))
    return {
        requirement_id: get_str(as_map(entry), "title")
        for requirement_id, entry in as_map(index.get("requirements")).items()
    }


def _plural(count: int, word: str) -> str:
    return f"{count} {word}" if count == 1 else f"{count} {word}s"


def render_text(report: Report, titles: dict[str, str], fail_on: str = "error") -> str:
    """The report for a person: one block per requirement, then a summary.

    bin/conventions renders the same text with jq; tests/test_launcher.py
    holds the two to the same output.
    """
    findings = [*report.findings, *(error.as_finding() for error in report.errors)]
    if not findings:
        return "No findings.\n"
    by_id: dict[str, list[Finding]] = {}
    for finding in findings:
        by_id.setdefault(finding.id, []).append(finding)
    blocks: list[str] = []
    for requirement_id, group in sorted(
        by_id.items(), key=lambda item: (-SEVERITY_RANK.get(item[1][0].severity, 0), item[0])
    ):
        group.sort(key=lambda item: (item.path, item.message))
        title = PARSE_TITLE if requirement_id == PARSE_ID else titles.get(requirement_id, "")
        mark = "" if group[0].enforced else " (not enforced)"
        lines = [f"{requirement_id}  {group[0].severity}{mark}  {_plural(len(group), 'finding')}"]
        lines += [text for text in (title, group[0].url) if text]
        path = None
        for finding in group:
            if finding.path != path:
                path = finding.path
                lines.append(f"  {path}")
            lines.append(f"    {finding.message}")
        blocks.append("\n".join(lines))
    errors = sum(1 for finding in findings if finding.severity == "error")
    warnings = len(findings) - errors
    summary = (
        f"{_plural(warnings, 'warning')}, {_plural(errors, 'error')} "
        f"in {_plural(len(by_id), 'requirement')}."
    )
    if fail_on == "error" and errors == 0:
        summary += "\nWarnings do not fail the check; --fail-on warning makes them fail."
    unenforced = [finding for finding in findings if not finding.enforced]
    if unenforced:
        families = ", ".join(sorted({finding.id.split("-")[0] for finding in unenforced}))
        verb = "is" if len(unenforced) == 1 else "are"
        summary += (
            f"\n{len(unenforced)} of them {verb} in families this repository does not enforce "
            f"yet ({families}), so they do not fail the check."
        )
    return "\n\n".join([*blocks, summary]) + "\n"


def render_json(report: Report) -> str:
    entries = [*report.findings, *(error.as_finding() for error in report.errors)]
    return json.dumps([asdict(entry) for entry in entries], indent=2, sort_keys=True) + "\n"
