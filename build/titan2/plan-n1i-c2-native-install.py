#!/usr/bin/env python3
"""Plan Titan 2 N1I-C2 native installs without duplicate Kati targets.

The sealed C1 control is an authority boundary, not a native provider: all 33
C2 native targets must be absent from that image. Twenty-eight reviewed frozen
stock natives are admitted through Sable-unique prebuilt modules. Five exact
collision targets are instead satisfied by already-selected Android 16 platform
providers, but only when the retained Kati graph proves exactly two owners: the
reviewed Sable candidate and the exact reviewed Android provider.
"""
from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

EXPECTED_IDS = [f"M{i:03d}" for i in range(7, 40)]
EXPECTED_COUNT = 33

EXPECTED_ANDROID_PLATFORM_PROVIDERS = {
    ("M008", "/system/lib64/android.hardware.radio-V4-ndk.so"):
        "android.hardware.radio-V4-ndk",
    ("M017", "/system/lib64/android.hardware.graphics.common-V6-ndk.so"):
        "android.hardware.graphics.common-V6-ndk",
    ("M029", "/system/lib64/android.hardware.drm-V1-ndk.so"):
        "android.hardware.drm-V1-ndk",
    ("M038", "/system/lib64/libheif.so"):
        "libheif",
    ("M039", "/system/lib64/libsuspend.so"):
        "libsuspend",
}


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


def platform_provider_decisions(path: Path) -> dict[tuple[str, str], str]:
    rows = read_tsv(path)
    required = {"id", "target", "expected_android_owner", "rationale"}
    if rows and not required.issubset(rows[0]):
        raise PlanError(
            "platform_provider_columns_missing="
            + ",".join(sorted(required - set(rows[0])))
        )
    decisions: dict[tuple[str, str], str] = {}
    for row in rows:
        key = (row["id"], row["target"])
        if key in decisions:
            raise PlanError(
                f"platform_provider_duplicate={key[0]}:{key[1]}"
            )
        owner = row["expected_android_owner"]
        if not owner or not row["rationale"]:
            raise PlanError(
                f"platform_provider_incomplete={key[0]}:{key[1]}"
            )
        decisions[key] = owner

    if decisions != EXPECTED_ANDROID_PLATFORM_PROVIDERS:
        missing = sorted(
            set(EXPECTED_ANDROID_PLATFORM_PROVIDERS) - set(decisions)
        )
        extra = sorted(
            set(decisions) - set(EXPECTED_ANDROID_PLATFORM_PROVIDERS)
        )
        wrong = sorted(
            key
            for key in set(decisions) & set(EXPECTED_ANDROID_PLATFORM_PROVIDERS)
            if decisions[key] != EXPECTED_ANDROID_PLATFORM_PROVIDERS[key]
        )
        raise PlanError(
            "platform_provider_set_drift="
            f"missing:{missing or 'NONE'};"
            f"extra:{extra or 'NONE'};"
            f"wrong_owner:{wrong or 'NONE'}"
        )
    return decisions


def plan(
    rows: list[dict[str, str]],
    expected_targets: set[str],
    collision_rows: list[dict[str, str]],
    platform_providers: dict[tuple[str, str], str],
) -> tuple[list[dict[str, str]], list[str]]:
    required = {
        "id", "target", "module", "stock_sha256",
        "c1_status", "c1_sha256", "c1_image_path",
    }
    if len(rows) != EXPECTED_COUNT:
        raise PlanError(
            f"probe_row_count={len(rows)} expected={EXPECTED_COUNT}"
        )
    if rows and not required.issubset(rows[0]):
        raise PlanError(
            "probe_columns_missing="
            + ",".join(sorted(required - set(rows[0])))
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

    collision_required = {
        "target", "state", "rule_count", "final_path", "owner_hints",
    }
    if len(collision_rows) != EXPECTED_COUNT:
        raise PlanError(
            f"collision_row_count={len(collision_rows)} "
            f"expected={EXPECTED_COUNT}"
        )
    if collision_rows and not collision_required.issubset(collision_rows[0]):
        raise PlanError(
            "collision_columns_missing="
            + ",".join(
                sorted(collision_required - set(collision_rows[0]))
            )
        )

    collision_by_target = {
        row["target"]: row
        for row in collision_rows
    }
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
    consumed_platform_providers: set[tuple[str, str]] = set()

    for row in rows:
        stock = row["stock_sha256"]
        c1_status = row["c1_status"]
        c1_sha = row["c1_sha256"]

        if len(stock) != 64:
            raise PlanError(
                f"bad_stock_sha256={row['id']}:{stock}"
            )

        if c1_status != "ABSENT" or c1_sha not in {"", "-"}:
            raise PlanError(
                "c1_native_present_not_allowed="
                f"{row['id']}:{row['target']}:"
                f"status={c1_status}:sha={c1_sha}"
            )

        collision = collision_by_target[row["target"]]
        state = collision["state"]
        try:
            rule_count = int(collision["rule_count"])
        except ValueError as exc:
            raise PlanError(
                f"bad_collision_rule_count="
                f"{row['id']}:{collision['rule_count']}"
            ) from exc

        if state == "COLLISION" and rule_count < 2:
            raise PlanError(
                f"collision_state_count_mismatch="
                f"{row['id']}:{rule_count}"
            )
        if state == "SINGLE_OWNER" and rule_count != 1:
            raise PlanError(
                f"single_owner_count_mismatch="
                f"{row['id']}:{rule_count}"
            )
        if state == "UNCLAIMED" and rule_count != 0:
            raise PlanError(
                f"unclaimed_count_mismatch="
                f"{row['id']}:{rule_count}"
            )
        if state not in {"COLLISION", "SINGLE_OWNER", "UNCLAIMED"}:
            raise PlanError(
                f"bad_collision_state={row['id']}:{state}"
            )

        owner_tokens = {
            token
            for part in collision["owner_hints"].split(";")
            for token in part.split(",")
            if token
            and token not in {
                "NONE",
                "UNRESOLVED_FROM_RULE",
            }
        }
        sable_owner_present = row["module"] in owner_tokens

        key = (row["id"], row["target"])
        expected_android_owner = platform_providers.get(key)

        if expected_android_owner:
            expected_owners = {
                row["module"],
                expected_android_owner,
            }
            if (
                state == "COLLISION"
                and rule_count == 2
                and owner_tokens == expected_owners
            ):
                disposition = "USE_ANDROID_PLATFORM_PROVIDER"
                consumed_platform_providers.add(key)
            else:
                disposition = "BLOCK_REVIEWED_PLATFORM_PROVIDER_GRAPH"
                blockers.append(
                    f"{row['id']}:{row['target']}:"
                    f"state={state}:rules={rule_count}:"
                    f"owners={collision['owner_hints']}:"
                    f"expected_android_owner={expected_android_owner}"
                )
        elif state == "SINGLE_OWNER" and sable_owner_present:
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
            disposition = "BLOCK_UNREVIEWED_COLLISION"
            blockers.append(
                f"{row['id']}:{row['target']}:"
                f"rules={rule_count}:"
                f"owners={collision['owner_hints']}"
            )
        else:
            disposition = "BLOCK_EXPECTED_SABLE_OWNER_MISSING"
            blockers.append(
                f"{row['id']}:{row['target']}:"
                f"graph_rules={rule_count}"
            )

        composition.append(
            {
                **row,
                "install_graph_state": state,
                "install_graph_rule_count": str(rule_count),
                "install_graph_owner_hints": collision["owner_hints"],
                "disposition": disposition,
            }
        )

    expected_provider_keys = set(platform_providers)
    if consumed_platform_providers != expected_provider_keys:
        missing = sorted(
            expected_provider_keys - consumed_platform_providers
        )
        blockers.append(
            "platform_provider_decision_not_consumed="
            + ",".join(
                f"{mid}:{target}"
                for mid, target in missing
            )
        )

    if blockers:
        raise PlanError(
            "platform_provider_admission_blocked="
            + "|".join(blockers)
        )

    return composition, imports


def write_composition(
    path: Path,
    rows: list[dict[str, str]],
) -> None:
    fields = [
        "id", "target", "module", "stock_sha256",
        "c1_status", "c1_sha256", "c1_image_path",
        "install_graph_state", "install_graph_rule_count",
        "install_graph_owner_hints", "disposition",
    ]
    with path.open(
        "w",
        encoding="utf-8",
        newline="",
    ) as fp:
        writer = csv.DictWriter(
            fp,
            fieldnames=fields,
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        writer.writerows(rows)


def write_packages(
    path: Path,
    imports: list[str],
) -> None:
    with path.open("w", encoding="utf-8") as fp:
        fp.write(
            "# Generated by plan-n1i-c2-native-install.py.\n"
            "# Exactly 28 frozen natives are installed by C2. "
            "Five reviewed Android 16 platform providers are "
            "preserved in place.\n"
        )
        if imports:
            fp.write("PRODUCT_PACKAGES += \\\n")
            for index, module in enumerate(imports):
                suffix = (
                    " \\\n"
                    if index + 1 < len(imports)
                    else "\n"
                )
                fp.write(f"    {module}{suffix}")
        else:
            fp.write(
                "# No frozen native imports admitted.\n"
            )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--probe-tsv", type=Path, required=True)
    ap.add_argument("--collision-tsv", type=Path, required=True)
    ap.add_argument("--a4-reference", type=Path, required=True)
    ap.add_argument(
        "--platform-provider-decisions",
        type=Path,
        required=True,
    )
    ap.add_argument("--composition-out", type=Path, required=True)
    ap.add_argument("--packages-out", type=Path, required=True)
    ap.add_argument("--admission-out", type=Path, required=True)
    args = ap.parse_args()

    rows = read_tsv(args.probe_tsv)
    collision_rows = read_tsv(args.collision_tsv)
    expected = canonical_targets(args.a4_reference)
    provider_decisions = platform_provider_decisions(
        args.platform_provider_decisions
    )
    composition, imports = plan(
        rows,
        expected,
        collision_rows,
        provider_decisions,
    )

    args.composition_out.parent.mkdir(
        parents=True,
        exist_ok=True,
    )
    args.packages_out.parent.mkdir(
        parents=True,
        exist_ok=True,
    )
    args.admission_out.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    write_composition(
        args.composition_out,
        composition,
    )
    write_packages(
        args.packages_out,
        imports,
    )

    module_to_target = {
        row["module"]: row["target"]
        for row in composition
    }
    with args.admission_out.open(
        "w",
        encoding="utf-8",
    ) as fp:
        fp.write(
            "# N1I-C2 collision-qualified frozen native "
            "admission candidate.\n"
            "# Generated from sealed C1 zero-presence evidence "
            "+ retained Kati graph.\n"
        )
        for module in imports:
            fp.write(
                module_to_target[module]
                + "\n"
            )

    c1_reuse_count = sum(
        row["disposition"].startswith("REUSE_C1_")
        for row in composition
    )
    platform_provider_count = sum(
        row["disposition"]
        == "USE_ANDROID_PLATFORM_PROVIDER"
        for row in composition
    )
    import_count = len(imports)

    if (
        c1_reuse_count != 0
        or platform_provider_count != 5
        or import_count != 28
        or platform_provider_count + import_count
        != EXPECTED_COUNT
    ):
        raise PlanError(
            "composition_count="
            f"c1_reuse:{c1_reuse_count},"
            f"android_platform:{platform_provider_count},"
            f"import:{import_count}"
        )

    print(
        "N1I_C2_C1_NATIVE_REUSE_COUNT="
        f"{c1_reuse_count}"
    )
    print(
        "N1I_C2_ANDROID_PLATFORM_PROVIDER_COUNT="
        f"{platform_provider_count}"
    )
    print(
        "N1I_C2_NATIVE_IMPORT_COUNT="
        f"{import_count}"
    )
    print(
        "N1I_C2_NATIVE_ADMISSION_OUT="
        f"{args.admission_out.resolve()}"
    )
    print(
        "N1I_C2_NATIVE_INSTALL_COLLISION_PREFLIGHT="
        "PASS_NO_DUPLICATE_KATI_TARGETS"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, PlanError) as exc:
        print(
            "N1I_C2_NATIVE_INSTALL_COLLISION_PREFLIGHT="
            f"FAIL reason={exc}",
            file=sys.stderr,
        )
        raise SystemExit(2)
