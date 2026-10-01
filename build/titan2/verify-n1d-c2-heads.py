#!/usr/bin/env python3
"""Verify N1D C2 project admission against sealed base and exact C2 pins."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def die(message: str) -> "NoReturn":
    raise SystemExit(f"N1D_C2_HEAD_VERIFY=FAIL {message}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", required=True, type=Path)
    parser.add_argument("--current", required=True, type=Path)
    parser.add_argument("--c2", required=True, type=Path)
    parser.add_argument("--expected-base-count", required=True, type=int)
    parser.add_argument("--expected-c2-count", required=True, type=int)
    parser.add_argument("--expected-total-count", required=True, type=int)
    return parser.parse_args()


def load(path: Path) -> dict[str, str]:
    if not path.is_file():
        die(f"missing={path}")

    result: dict[str, str] = {}
    for line_number, raw in enumerate(
        path.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        if not raw:
            continue
        fields = raw.split("\t")
        if len(fields) < 2:
            die(f"bad_row file={path} line={line_number}")
        project_path, revision = fields[0], fields[1]
        if project_path in result:
            die(f"duplicate_path file={path} path={project_path}")
        result[project_path] = revision
    return result


def check_subset(
    expected: dict[str, str],
    current: dict[str, str],
    label: str,
) -> None:
    for project_path, expected_revision in sorted(expected.items()):
        actual = current.get(project_path)
        if actual is None:
            die(f"{label}_missing path={project_path}")
        if actual != expected_revision:
            die(
                f"{label}_revision path={project_path} "
                f"expected={expected_revision} actual={actual}"
            )


def main() -> int:
    args = parse_args()
    base = load(args.base)
    current = load(args.current)
    c2 = load(args.c2)

    if len(base) != args.expected_base_count:
        die(
            f"base_count expected={args.expected_base_count} "
            f"actual={len(base)}"
        )
    if len(c2) != args.expected_c2_count:
        die(
            f"c2_count expected={args.expected_c2_count} "
            f"actual={len(c2)}"
        )
    if len(current) != args.expected_total_count:
        die(
            f"total_count expected={args.expected_total_count} "
            f"actual={len(current)}"
        )

    overlap = sorted(set(base).intersection(c2))
    if overlap:
        die(f"base_c2_overlap paths={','.join(overlap)}")

    check_subset(base, current, "base")
    check_subset(c2, current, "c2")

    unexpected = sorted(set(current) - set(base) - set(c2))
    if unexpected:
        die(f"unexpected_paths={','.join(unexpected)}")

    print(f"N1D_C2_BASE_PROJECT_COUNT={len(base)}")
    print(f"N1D_C2_ADMITTED_PROJECT_COUNT={len(c2)}")
    print(f"N1D_C2_TOTAL_PROJECT_COUNT={len(current)}")
    print("N1D_C2_BASE_HEADS_UNCHANGED=PASS")
    print("N1D_C2_EXACT_HEADS=PASS")
    print("N1D_C2_NO_UNEXPECTED_PROJECTS=PASS")
    print("N1D_C2_HEAD_VERIFY=PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
