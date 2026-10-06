#!/usr/bin/env python3
"""Audit Titan 2 C2 proposed native install paths against a Kati install graph.

Read-only host tool. It does not mutate Android source, build, use the network,
contact a device, reboot, or flash.

The audit is intentionally install-path based. A Sable prebuilt with a unique
module name can still collide with an existing platform module when both install
the same final path; Kati rejects that condition as "overriding commands for
target".
"""
from __future__ import annotations

import argparse
import csv
import pathlib
import re
import sys

TOOL_VERSION = "1.0.0"


class AuditError(RuntimeError):
    pass


def load_targets(path: pathlib.Path) -> list[str]:
    if not path.is_file():
        raise AuditError(f"target_list_missing={path}")
    rows = [
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    if not rows:
        raise AuditError(f"target_list_empty={path}")
    if len(rows) != len(set(rows)):
        raise AuditError(f"target_list_duplicate={path}")
    for target in rows:
        if not target.startswith(("/system/", "/system_ext/", "/product/")):
            raise AuditError(f"unsupported_target={target}")
    return rows


def installed_path(product_out: pathlib.Path, target: str) -> pathlib.Path:
    if target.startswith("/system_ext/"):
        return product_out / "system/system_ext" / target.removeprefix("/system_ext/")
    if target.startswith("/product/"):
        return product_out / "system/product" / target.removeprefix("/product/")
    if target.startswith("/system/"):
        return product_out / "system" / target.removeprefix("/system/")
    raise AuditError(f"unsupported_target={target}")


def rule_locations(
    installs_files: list[pathlib.Path],
    target: pathlib.Path,
) -> list[tuple[pathlib.Path, int, str, str]]:
    needle = f"{target}:"
    found: list[tuple[pathlib.Path, int, str, str]] = []
    for installs in installs_files:
        lines = installs.read_text(encoding="utf-8", errors="replace").splitlines()
        for index, line in enumerate(lines):
            if not line.startswith(needle):
                continue
            context_start = max(0, index - 1)
            context_end = min(len(lines), index + 2)
            context = " || ".join(lines[context_start:context_end])
            found.append((installs, index + 1, line, context))
    return found


def owner_hints(rule: str) -> str:
    hints: list[str] = []
    for match in re.findall(r"(?:^|/)([^/\s:]+)\.intermediates(?:/|$)", rule):
        if match not in hints:
            hints.append(match)
    for match in re.findall(r"/(SableN1IC2NativeM\d{3})(?:/|\.)", rule):
        if match not in hints:
            hints.append(match)
    return ",".join(hints) if hints else "UNRESOLVED_FROM_RULE"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", type=pathlib.Path, required=True)
    ap.add_argument("--product-out", type=pathlib.Path, required=True)
    ap.add_argument("--target-list", type=pathlib.Path, required=True)
    ap.add_argument(
        "--report-only",
        action="store_true",
        help="return zero even when collisions are found",
    )
    ap.add_argument(
        "--tsv-out",
        type=pathlib.Path,
        help="write one machine-readable row per audited target",
    )
    args = ap.parse_args()

    out_dir = args.out_dir.resolve()
    product_out = args.product_out.resolve()
    target_list = args.target_list.resolve()

    print("===== N1I-C2 INSTALL OWNERSHIP COLLISION AUDIT =====")
    print("SOURCE_MUTATION_AUTHORIZED=NO")
    print("BUILD_AUTHORIZED=NO")
    print("DEVICE_CONTACT_AUTHORIZED=NO")
    print("NETWORK_FETCH_AUTHORIZED=NO")
    print("REBOOT_AUTHORIZED=NO")
    print("FLASH_AUTHORIZED=NO")
    print(f"TOOL_VERSION={TOOL_VERSION}")
    print(f"OUT_DIR={out_dir}")
    print(f"PRODUCT_OUT={product_out}")
    print(f"TARGET_LIST={target_list}")

    if not out_dir.is_dir():
        raise AuditError(f"out_dir_missing={out_dir}")
    if not product_out.is_dir():
        raise AuditError(f"product_out_missing={product_out}")

    installs_files = sorted((out_dir / "soong").glob("installs-*.mk"))
    if not installs_files:
        raise AuditError(f"installs_graph_missing={out_dir / 'soong'}")

    targets = load_targets(target_list)
    collision_count = 0
    unclaimed_count = 0
    single_owner_count = 0
    report_rows: list[dict[str, str]] = []

    print(f"N1I_C2_INSTALL_AUDIT_TARGET_COUNT={len(targets)}")
    print(f"N1I_C2_INSTALL_AUDIT_GRAPH_FILE_COUNT={len(installs_files)}")

    for target in targets:
        final = installed_path(product_out, target)
        rules = rule_locations(installs_files, final)
        count = len(rules)
        if count >= 2:
            collision_count += 1
            state = "COLLISION"
        elif count == 1:
            single_owner_count += 1
            state = "SINGLE_OWNER"
        else:
            unclaimed_count += 1
            state = "UNCLAIMED"

        print(
            "N1I_C2_INSTALL_TARGET="
            f"{target}|state={state}|rule_count={count}|final={final}"
        )
        report_rows.append(
            {
                "target": target,
                "state": state,
                "rule_count": str(count),
                "final_path": str(final),
                "owner_hints": ";".join(
                    owner_hints(rule)
                    for _mk, _line_no, rule, _context in rules
                ) or "NONE",
            }
        )
        for idx, (mk, line_no, rule, context) in enumerate(rules):
            print(
                "N1I_C2_INSTALL_RULE="
                f"{target}|index={idx}|file={mk}|line={line_no}|"
                f"owner_hint={owner_hints(rule)}|rule={rule}"
            )
            print(
                "N1I_C2_INSTALL_RULE_CONTEXT="
                f"{target}|index={idx}|context={context}"
            )

    if args.tsv_out is not None:
        args.tsv_out.parent.mkdir(parents=True, exist_ok=True)
        with args.tsv_out.open("w", encoding="utf-8", newline="") as fp:
            writer = csv.DictWriter(
                fp,
                fieldnames=[
                    "target", "state", "rule_count", "final_path", "owner_hints",
                ],
                delimiter="\t",
                lineterminator="\n",
            )
            writer.writeheader()
            writer.writerows(report_rows)
        print(f"N1I_C2_INSTALL_AUDIT_TSV={args.tsv_out.resolve()}")

    print(f"N1I_C2_INSTALL_COLLISION_COUNT={collision_count}")
    print(f"N1I_C2_INSTALL_SINGLE_OWNER_COUNT={single_owner_count}")
    print(f"N1I_C2_INSTALL_UNCLAIMED_COUNT={unclaimed_count}")

    if collision_count:
        print("N1I_C2_INSTALL_OWNERSHIP_AUDIT=FAIL_COLLISIONS")
        return 0 if args.report_only else 3

    print("N1I_C2_INSTALL_OWNERSHIP_AUDIT=PASS_NO_COLLISIONS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AuditError as exc:
        print(f"N1I_C2_INSTALL_OWNERSHIP_AUDIT=FAIL reason={exc}", file=sys.stderr)
        raise SystemExit(2)
