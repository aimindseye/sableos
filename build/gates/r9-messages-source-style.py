#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HUB = ROOT / "apps/r8/android/hub"
MAX_LINE_LENGTH = 120

failures: list[str] = []
files = [
    HUB / "build.gradle.kts",
    *sorted((HUB / "src/main").rglob("*.kt")),
    *sorted((HUB / "src/test").rglob("*.kt")),
]

if not files:
    failures.append("no_hub_kotlin_sources")

for path in files:
    if not path.is_file():
        failures.append(f"missing_file={path.relative_to(ROOT)}")
        continue

    value = path.read_text(encoding="utf-8")
    rel = path.relative_to(ROOT)

    if "\r" in value:
        failures.append(f"cr_character={rel}")

    if not value.endswith("\n"):
        failures.append(f"missing_final_newline={rel}")

    if "import androidx.compose.foundation.layout.weight" in value:
        failures.append(f"forbidden_compose_weight_import={rel}")

    lines = value.splitlines()
    for line_number, line in enumerate(lines, start=1):
        if len(line) > MAX_LINE_LENGTH:
            failures.append(
                f"max_line_length={rel}:{line_number}:"
                f"{len(line)}>{MAX_LINE_LENGTH}"
            )
        if "\t" in line:
            failures.append(f"tab_character={rel}:{line_number}")
        if line.rstrip(" \t") != line:
            failures.append(f"trailing_whitespace={rel}:{line_number}")

    for index, line in enumerate(lines):
        stripped = line.lstrip(" ")
        if stripped != ".query(":
            continue

        call_indent = len(line) - len(stripped)
        depth = 1
        for nested_index in range(index + 1, len(lines)):
            nested_line = lines[nested_index]
            nested_stripped = nested_line.lstrip(" ")
            nested_indent = len(nested_line) - len(nested_stripped)

            if depth == 1 and nested_stripped.startswith(")"):
                if nested_indent != call_indent:
                    failures.append(
                        f"query_closing_indent={rel}:{nested_index + 1}:"
                        f"{nested_indent}!={call_indent}"
                    )
                break

            if nested_stripped and nested_indent < call_indent + 4:
                failures.append(
                    f"query_argument_indent={rel}:{nested_index + 1}:"
                    f"{nested_indent}<{call_indent + 4}"
                )

            depth += nested_line.count("(")
            depth -= nested_line.count(")")
        else:
            failures.append(f"unterminated_query_call={rel}:{index + 1}")

if failures:
    print("R9_MESSAGES_SOURCE_STYLE_PREFLIGHT=FAIL")
    for failure in failures:
        print(f"FAILURE={failure}")
    raise SystemExit(1)

print(f"R9_MESSAGES_SOURCE_STYLE_FILES=PASS count={len(files)}")
print(f"R9_MESSAGES_SOURCE_MAX_LINE_LENGTH=PASS value={MAX_LINE_LENGTH}")
print("R9_MESSAGES_SOURCE_WHITESPACE=PASS")
print("R9_MESSAGES_SOURCE_CHAIN_INDENTATION=PASS")
print("R9_MESSAGES_COMPOSE_WEIGHT_IMPORT=PASS_SCOPED")
print("R9_MESSAGES_SOURCE_STYLE_PREFLIGHT=PASS")
