"""The `repo` command.

    repo check            run every policy
    repo config check     .config/ layout and liveness
    repo layout check     repo root vs the declared product directory
    repo paths check      configured globs and directories still resolve
    repo env check        env schemas have the shared shape
    repo env doctor       what the enabled stacks still need (local)
    repo env setup        fill it in, interactively (local)
    repo ports check      port declarations agree
    repo hooks check      local hooks and CI stay in step
"""

from __future__ import annotations

import argparse
import sys

from governance import __version__, envtools
from governance.policies import POLICIES
from governance.reporting import render_reports

#: Groups that carry developer commands beside their `check`. These read the
#: developer's own gitignored files, so they are never part of `repo check`.
EXTRA_ACTIONS = {"env": (envtools.ACTIONS, envtools.FLAGS)}


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="repo",
        description="Structural policy checks for this repository.",
    )
    parser.add_argument("--version", action="version", version=f"repo {__version__}")
    sub = parser.add_subparsers(dest="group", required=True)

    run_all = sub.add_parser("check", help="run every policy")
    run_all.set_defaults(policies=list(POLICIES))

    for name in POLICIES:
        group = sub.add_parser(name, help=f"{name} policy")
        actions = group.add_subparsers(dest="action", required=True)
        actions.add_parser("check", help=f"run the {name} policy")
        group.set_defaults(policies=[name])

        commands, flags = EXTRA_ACTIONS.get(name, ({}, {}))
        for action, (run, help_text) in commands.items():
            parser_for = actions.add_parser(action, help=help_text)
            for flag, flag_help in flags.get(action, []):
                parser_for.add_argument(flag, action="store_true", help=flag_help)
            parser_for.set_defaults(run=run, policies=[])

    return parser


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    if getattr(args, "run", None) is not None:
        return args.run(args)
    reports = [POLICIES[name]() for name in args.policies]
    return render_reports(reports)


if __name__ == "__main__":
    sys.exit(main())
