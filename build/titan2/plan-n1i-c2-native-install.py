#!/usr/bin/env python3
"""Plan Titan 2 N1I-C2 native installs without duplicating baseline paths.

Input is a read-only probe of the sealed C1 image against the 33 frozen A4
native targets. A target already present in C1 with the exact frozen stock hash
is satisfied by the baseline and MUST NOT be installed again. A target absent
from C1 is imported from the frozen C2 stock bundle. A target present with a
different hash fails closed and requires an explicit compatibility decision.
"""
from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

EXPECTED_IDS = [f"M{i:03d}" for i in range(7, 40)]
EXPECTED_COUNT = 33


class PlanError(RuntimeError):
    pass


def read_tsv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as fp:
        reader = csv.DictReader(fp, delimiter="\t")
        if reader.fieldnames is None:
            raise PlanError(f"missing_header={path}")
        return list(reader)


def canonical_targets(path: Path) -> set[str]:
    targets = {
        line.strip()
        for line in path.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }
    if len(targets) != EXPECTED_COUNT:
        raise PlanError(
            f"a4_target_count={len(targets)} expected={EXPECTED_COUNT}"
        )
    return targets


def plan(
    rows: list[dict[str, str]],
    expected_targets: set[str],
    collision_rows: list[dict[str, str]],
) -> tuple[list[dict[str, str]], list[str]]:
    required = {
        "id", "target", "module", "stock_sha256",
        "c1_status", "c1_sha256", "c1_image_path",
    }
    if len(rows) != EXPECTED_COUNT:
        raise PlanError(f"probe_row_count={len(rows)} expected={EXPECTED_COUNT}")
    if rows and not required.issubset(rows[0]):
        raise PlanError(
            "probe_columns_missing=" + ",".join(sorted(required - set(rows[0])))
        )

    ids = [row["id"] for row in rows]
    if ids != EXPECTED_IDS:
        raise PlanError(
            "probe_id_order_drift="
            f"expected:{','.join(EXPECTED_IDS)};"
            f"actual:{','.join(ids)}"
        )

    targets = {row["target"] for row in rows}
    if targets != expected_targets:
        raise PlanError(
            "probe_target_set_drift="
            f"missing:{','.join(sorted(expected_targets - targets)) or 'NONE'};"
            f"extra:{','.join(sorted(targets - expected_targets)) or 'NONE'}"
        )

    modules = {row["module"] for row in rows}
    if len(modules) != EXPECTED_COUNT:
        raise PlanError("probe_module_duplicate")

    collision_required = {"target", "state", "rule_count", "final_path", "owner_hints"}
    if len(collision_rows) != EXPECTED_COUNT:
        raise PlanError(
            f"collision_row_count={len(collision_rows)} expected={EXPECTED_COUNT}"
        )
    if collision_rows and not collision_required.issubset(collision_rows[0]):
        raise PlanError(
            "collision_columns_missing="
            + ",".join(sorted(collision_required - set(collision_rows[0])))
        )
    collision_by_target = {row["target"]: row for row in collision_rows}
    if len(collision_by_target) != EXPECTED_COUNT:
        raise PlanError("collision_target_duplicate")
    if set(collision_by_target) != expected_targets:
        raise PlanError(
            "collision_target_set_drift="
            f"missing:{','.join(sorted(expected_targets - set(collision_by_target))) or 'NONE'};"
            f"extra:{','.join(sorted(set(collision_by_target) - expected_targets)) or 'NONE'}"
        )

    composition: list[dict[str, str]] = []
    imports: list[str] = []
    blockers: list[str] = []

    for row in rows:
        stock = row["stock_sha256"]
        c1_status = row["c1_status"]
        c1_sha = row["c1_sha256"]
        if len(stock) != 64:
            raise PlanError(f"bad_stock_sha256={row['id']}:{stock}")

        collision = collision_by_target[row["target"]]
        state = collision["state"]
        try:
            rule_count = int(collision["rule_count"])
        except ValueError as exc:
            raise PlanError(
                f"bad_collision_rule_count={row['id']}:{collision['rule_count']}"
            ) from exc

        if state == "COLLISION" and rule_count < 2:
            raise PlanError(f"collision_state_count_mismatch={row['id']}:{rule_count}")
        if state == "SINGLE_OWNER" and rule_count != 1:
            raise PlanError(f"single_owner_count_mismatch={row['id']}:{rule_count}")
        if state == "UNCLAIMED" and rule_count != 0:
            raise PlanError(f"unclaimed_count_mismatch={row['id']}:{rule_count}")
        if state not in {"COLLISION", "SINGLE_OWNER", "UNCLAIMED"}:
            raise PlanError(f"bad_collision_state={row['id']}:{state}")

        owner_tokens = {
            token
            for part in collision["owner_hints"].split(";")
            for token in part.split(",")
            if token and token not in {"NONE", "UNRESOLVED_FROM_RULE"}
        }
        sable_owner_present = row["module"] in owner_tokens

        if c1_status == "ABSENT":
            if c1_sha not in {"", "-"}:
                raise PlanError(
                    f"absent_with_c1_sha={row['id']}:{c1_sha}"
                )
            if state == "SINGLE_OWNER" and sable_owner_present:
                disposition = "IMPORT_FROZEN_STOCK"
                imports.append(row["module"])
            elif state == "SINGLE_OWNER":
                disposition = "BLOCK_SINGLE_OWNER_NOT_SABLE_MODULE"
                blockers.append(
                    f"{row['id']}:{row['target']}:"
                    f"owner_hints={collision['owner_hints']}:"
                    f"expected_module={row['module']}"
                )
            elif state == "COLLISION":
                disposition = "BLOCK_GRAPH_OWNER_NOT_IN_C1"
                blockers.append(
                    f"{row['id']}:{row['target']}:"
                    f"graph_rules={rule_count}:owners={collision['owner_hints']}"
                )
            else:
                disposition = "BLOCK_EXPECTED_SABLE_OWNER_MISSING"
                blockers.append(
                    f"{row['id']}:{row['target']}:graph_rules={rule_count}"
                )
        elif c1_status == "PRESENT":
            if len(c1_sha) != 64:
                raise PlanError(f"bad_c1_sha256={row['id']}:{c1_sha}")
            if c1_sha != stock:
                disposition = "BLOCK_C1_DIFFERENT"
                blockers.append(
                    f"{row['id']}:{row['target']}:"
                    f"c1={c1_sha}:stock={stock}"
                )
            elif state == "COLLISION" and sable_owner_present:
                disposition = "REUSE_C1_IDENTICAL"
            elif state == "COLLISION":
                disposition = "BLOCK_COLLISION_MISSING_SABLE_OWNER"
                blockers.append(
                    f"{row['id']}:{row['target']}:"
                    f"owner_hints={collision['owner_hints']}:"
                    f"expected_module={row['module']}"
                )
            else:
                disposition = "BLOCK_C1_PRESENT_WITHOUT_BASE_GRAPH_OWNER"
                blockers.append(
                    f"{row['id']}:{row['target']}:"
                    f"state={state}:rules={rule_count}"
                )
        else:
            raise PlanError(
                f"bad_c1_status={row['id']}:{c1_status}"
            )

        composition.append({
            **row,
            "install_graph_state": state,
            "install_graph_rule_count": str(rule_count),
            "install_graph_owner_hints": collision["owner_hints"],
            "disposition": disposition,
        })

    if blockers:
        raise PlanError(
            "baseline_different_requires_explicit_decision="
            + "|".join(blockers)
        )

    return composition, imports


def write_composition(path: Path, rows: list[dict[str, str]]) -> None:
    fields = [
        "id", "target", "module", "stock_sha256",
        "c1_status", "c1_sha256", "c1_image_path",
        "install_graph_state", "install_graph_rule_count",
        "install_graph_owner_hints", "disposition",
    ]
    with path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.DictWriter(
            fp,
            fieldnames=fields,
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)


def write_packages(path: Path, imports: list[str]) -> None:
    with path.open("w", encoding="utf-8") as fp:
        fp.write(
            "# Generated by plan-n1i-c2-native-install.py.\n"
            "# Only frozen natives absent from the sealed C1 baseline are "
            "installed by C2.\n"
        )
        if imports:
            fp.write("PRODUCT_PACKAGES += \\\n")
            for index, module in enumerate(imports):
                suffix = " \\\n" if index + 1 < len(imports) else "\n"
                fp.write(f"    {module}{suffix}")
        else:
            fp.write("# All 33 frozen native targets are already C1-identical.\n")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--probe-tsv", type=Path, required=True)
    ap.add_argument("--collision-tsv", type=Path, required=True)
    ap.add_argument("--a4-reference", type=Path, required=True)
    ap.add_argument("--composition-out", type=Path, required=True)
    ap.add_argument("--packages-out", type=Path, required=True)
    ap.add_argument("--admission-out", type=Path, required=True)
    args = ap.parse_args()

    rows = read_tsv(args.probe_tsv)
    collision_rows = read_tsv(args.collision_tsv)
    expected = canonical_targets(args.a4_reference)
    composition, imports = plan(rows, expected, collision_rows)

    args.composition_out.parent.mkdir(parents=True, exist_ok=True)
    args.packages_out.parent.mkdir(parents=True, exist_ok=True)
    args.admission_out.parent.mkdir(parents=True, exist_ok=True)
    write_composition(args.composition_out, composition)
    write_packages(args.packages_out, imports)

    module_to_target = {row["module"]: row["target"] for row in composition}
    with args.admission_out.open("w", encoding="utf-8") as fp:
        fp.write(
            "# N1I-C2 collision-qualified native admission candidate.\n"
            "# Generated read-only from sealed C1 baseline + failed C2 install graph.\n"
        )
        for module in imports:
            fp.write(module_to_target[module] + "\n")

    reuse_count = sum(
        row["disposition"] == "REUSE_C1_IDENTICAL"
        for row in composition
    )
    import_count = len(imports)
    if reuse_count + import_count != EXPECTED_COUNT:
        raise PlanError(
            f"composition_count=reuse:{reuse_count},import:{import_count}"
        )

    print(f"N1I_C2_NATIVE_BASELINE_REUSE_COUNT={reuse_count}")
    print(f"N1I_C2_NATIVE_IMPORT_COUNT={import_count}")
    print(f"N1I_C2_NATIVE_ADMISSION_OUT={args.admission_out.resolve()}")
    print(
        "N1I_C2_NATIVE_INSTALL_COLLISION_PREFLIGHT="
        "PASS_NO_DUPLICATE_BASELINE_INSTALLS"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, PlanError) as exc:
        print(
            f"N1I_C2_NATIVE_INSTALL_COLLISION_PREFLIGHT=FAIL reason={exc}",
            file=sys.stderr,
        )
        raise SystemExit(2)
