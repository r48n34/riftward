#!/usr/bin/env python3
"""Validate tests/suites.json and emit the GitHub Actions matrix.

`tests/suites.json` is the single source of truth for the headless suites: the
local gate (tests/run_all.ps1) and the GitHub Actions workflow
(.github/workflows/tests.yml, which the README "headless-tests" badge reports)
both read it. This helper only does the CI half and is deliberately
dependency-free — it runs on the python3 that ships with the ubuntu runners.

    python3 tools/ci_matrix.py --check   # fail with ::error:: lines if broken
    python3 tools/ci_matrix.py --json    # {"include": [...]} for strategy.matrix
"""
from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "tests" / "suites.json"


def load_manifest() -> dict:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def check(data: dict) -> list[str]:
    problems: list[str] = []
    suites = data.get("suites") or []
    if not suites:
        problems.append("no suites defined")
        return problems

    names = [suite.get("name") for suite in suites]
    if len(names) != len(set(names)):
        problems.append(f"duplicate suite names: {names}")

    for suite in suites:
        name = suite.get("name", "<unnamed>")
        args = suite.get("args") or []
        if not args:
            problems.append(f"{name}: empty args")
        for token in args:
            if isinstance(token, str) and token.startswith("res://"):
                target = ROOT / token[len("res://"):]
                if not target.exists():
                    problems.append(f"{name}: missing {token}")
        timeout = suite.get("timeoutSeconds")
        if not isinstance(timeout, int) or isinstance(timeout, bool) or timeout <= 0:
            problems.append(f"{name}: timeoutSeconds must be a positive integer")
        marker = suite.get("marker")
        if marker is not None and not isinstance(marker, str):
            problems.append(f"{name}: marker must be a string or null")

    return problems


def matrix(data: dict) -> dict:
    entries = [
        {
            "name": suite["name"],
            "args": " ".join(str(token) for token in suite["args"]),
            "marker": suite.get("marker") or "",
            "timeout": int(suite["timeoutSeconds"]),
        }
        for suite in data["suites"]
    ]
    return {"include": entries}


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] not in {"--check", "--json"}:
        print("usage: ci_matrix.py [--check|--json]", file=sys.stderr)
        return 2

    data = load_manifest()

    if argv[1] == "--check":
        problems = check(data)
        for problem in problems:
            print(f"::error::tests/suites.json: {problem}")
        if problems:
            return 1
        print(
            f"tests/suites.json ok: {len(data['suites'])} suites, "
            f"Godot {data.get('godotVersion')}"
        )
        return 0

    print(json.dumps(matrix(data), separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
