"""Reading YAML, JSON and Markdown frontmatter into plain, typed values."""

import json
from pathlib import Path
from typing import cast

import yaml


class ContentError(Exception):
    """Content in the product directory is unreadable or invalid."""

    def __init__(self, problems: list[str]) -> None:
        super().__init__("\n".join(problems))
        self.problems = problems


class _PlainLoader(yaml.SafeLoader):
    """A safe loader that keeps dates as the strings they were written as.

    JSON Schema (and conftest) see `created: 2026-09-23` as a string; PyYAML
    would otherwise turn it into a datetime.date and every date field would
    fail validation here while passing everywhere else.
    """


_PlainLoader.yaml_implicit_resolvers = {
    first: [(tag, regexp) for tag, regexp in resolvers if tag != "tag:yaml.org,2002:timestamp"]
    for first, resolvers in yaml.SafeLoader.yaml_implicit_resolvers.items()
}


def parse_yaml(text: str, source: str) -> object:
    try:
        return cast("object", yaml.load(text, Loader=_PlainLoader))
    except yaml.YAMLError as error:
        raise ContentError([f"{source}: not valid YAML: {error}"]) from error


def yaml_problem(text: str) -> str | None:
    """Why `text` is not YAML, in one line, or None when it parses."""
    try:
        for _ in yaml.load_all(text, Loader=_PlainLoader):
            pass
    except yaml.MarkedYAMLError as error:
        mark = error.problem_mark
        where = f"line {mark.line + 1}, column {mark.column + 1}: " if mark else ""
        return f"not valid YAML: {where}{error.problem or error.context}"
    except yaml.YAMLError as error:
        return f"not valid YAML: {' '.join(str(error).split())}"
    return None


def json_problem(text: str) -> str | None:
    """Why `text` is not JSON, in one line, or None when it parses."""
    try:
        json.loads(text)
    except json.JSONDecodeError as error:
        return f"not valid JSON: line {error.lineno}, column {error.colno}: {error.msg}"
    return None


def read_yaml(path: Path) -> object:
    return parse_yaml(path.read_text(encoding="utf-8"), str(path))


def read_json(path: Path) -> object:
    try:
        return cast("object", json.loads(path.read_text(encoding="utf-8")))
    except json.JSONDecodeError as error:
        raise ContentError([f"{path}: not valid JSON: {error}"]) from error


def split_frontmatter(text: str, source: str) -> tuple[object, str]:
    """Return (frontmatter, body) for a Markdown document that opens with `---`."""
    lines = text.splitlines(keepends=True)
    if not lines or lines[0].rstrip("\r\n") != "---":
        raise ContentError([f"{source}: does not open with a --- frontmatter block"])
    for number, line in enumerate(lines[1:], start=1):
        if line.rstrip("\r\n") == "---":
            head = "".join(lines[1:number])
            body = "".join(lines[number + 1 :])
            return parse_yaml(head, source), body
    raise ContentError([f"{source}: frontmatter block is never closed with ---"])


def as_map(value: object) -> dict[str, object]:
    if isinstance(value, dict):
        return cast("dict[str, object]", value)
    return {}


def as_list(value: object) -> list[object]:
    if isinstance(value, list):
        return cast("list[object]", value)
    return []


def get_str(data: dict[str, object], key: str) -> str:
    value = data.get(key)
    return value if isinstance(value, str) else ""


def get_opt_str(data: dict[str, object], key: str) -> str | None:
    value = data.get(key)
    return value if isinstance(value, str) else None


def get_str_list(data: dict[str, object], key: str) -> tuple[str, ...]:
    return tuple(item for item in as_list(data.get(key)) if isinstance(item, str))
