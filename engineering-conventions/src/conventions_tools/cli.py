"""The `conventions` command line."""

import argparse
import sys
from collections.abc import Sequence
from pathlib import Path

from conventions_tools import generate, invariants, run
from conventions_tools.content import load_content
from conventions_tools.fixtures import case_dirs, run_case
from conventions_tools.loading import ContentError
from conventions_tools.paths import product_dir
from conventions_tools.profiles import ProfileError

EXIT_OK = 0
EXIT_FINDINGS = 1
EXIT_ERROR = 2


def _generate(arguments: argparse.Namespace) -> int:
    product = product_dir()
    outputs = generate.build_outputs(load_content(product))
    if arguments.check:
        diffs = generate.drift(outputs, product)
        for diff in diffs:
            sys.stdout.write(diff)
        if diffs:
            print("generated files are out of date; run `conventions generate`", file=sys.stderr)
            return EXIT_FINDINGS
        return EXIT_OK
    for path in generate.write(outputs):
        print(f"wrote {path.relative_to(product)}")
    return EXIT_OK


def _invariants(arguments: argparse.Namespace) -> int:
    problems = invariants.check_all(product_dir(), arguments.baseline)
    for problem in problems:
        print(problem)
    if problems:
        print(f"{len(problems)} invariant problem(s)", file=sys.stderr)
        return EXIT_FINDINGS
    print("invariants hold")
    return EXIT_OK


def _check(arguments: argparse.Namespace) -> int:
    now = run.validate_now(arguments.now) if arguments.now else run.utc_now()
    report = run.check(product_dir(), Path(arguments.repo_dir), now)
    if arguments.format == "json":
        sys.stdout.write(run.render_json(report))
    else:
        sys.stdout.write(run.render_text(report))
    if report.errors:
        return EXIT_ERROR
    return EXIT_FINDINGS if run.fails(report.findings, arguments.fail_on) else EXIT_OK


def _fixtures(_: argparse.Namespace) -> int:
    product = product_dir()
    cases = case_dirs(product)
    if not cases:
        print("no fixture repositories found under tests/fixtures/repos/", file=sys.stderr)
        return EXIT_FINDINGS
    results = [run_case(product, case) for case in cases]
    for result in results:
        print(result.report())
    failed = [result.name for result in results if not result.passed]
    if failed:
        print(f"{len(failed)} of {len(results)} fixture(s) failed", file=sys.stderr)
        return EXIT_FINDINGS
    return EXIT_OK


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="conventions",
        description="Generate, verify and run musher-dev/engineering-conventions.",
    )
    commands = parser.add_subparsers(dest="command", required=True)

    generate_parser = commands.add_parser(
        "generate",
        help="write checks/data/index.json, the Vale styles and definitions/conventions/README.md",
    )
    generate_parser.add_argument(
        "--check",
        action="store_true",
        help="print a diff against the committed files instead of writing; exit 1 on drift",
    )
    generate_parser.set_defaults(handler=_generate)

    invariants_parser = commands.add_parser(
        "invariants", help="check the content, Rego checks and fixtures against each other"
    )
    invariants_parser.add_argument(
        "--baseline",
        default="HEAD",
        metavar="REF",
        help=(
            "git ref whose index.json IDs must survive (append-only check); default HEAD. "
            "A ref that does not resolve fails; an empty or all-zero value (a branch's first "
            "push) skips the check with a notice"
        ),
    )
    invariants_parser.set_defaults(handler=_invariants)

    check_parser = commands.add_parser(
        "check",
        help="check a repository against the conventions",
        description="Check a repository against the conventions and print one line per finding.",
        epilog=(
            f"A workflow, action or ruleset that is not valid YAML or JSON is left out of the "
            f"check and reported as `error [{run.PARSE_ID}] <path> — <reason>`; {run.PARSE_ID} "
            "is a diagnostic, not a requirement, and cannot be waived. Every other finding is "
            "still printed. Exit status: 0 when nothing at or above --fail-on is found, 1 when "
            f"something is, 2 when the check could not run or any file was reported as "
            f"{run.PARSE_ID}."
        ),
    )
    check_parser.add_argument("repo_dir", help="root of the repository to check")
    check_parser.add_argument("--format", choices=("text", "json"), default="text")
    check_parser.add_argument(
        "--fail-on",
        choices=("warning", "error"),
        default="error",
        help="lowest severity that makes the command exit 1 (default: error)",
    )
    check_parser.add_argument(
        "--now",
        metavar="RFC3339",
        help="evaluate waiver expiry at this time instead of the current time",
    )
    check_parser.set_defaults(handler=_check)

    fixtures_parser = commands.add_parser(
        "fixtures", help="run every tests/fixtures/repos case and compare with expected.json"
    )
    fixtures_parser.set_defaults(handler=_fixtures)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    arguments = build_parser().parse_args(argv)
    handler = arguments.handler
    try:
        return handler(arguments)
    except (ContentError, ProfileError, run.RunnerError) as error:
        print(f"conventions {arguments.command}: {error}", file=sys.stderr)
        return EXIT_ERROR
