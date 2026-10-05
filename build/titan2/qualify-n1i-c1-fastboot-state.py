#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re

SUPER_BYTES = 9_663_676_416
TARGET_BYTES = 3_210_661_888
MIN_REMAINING_SUPER_HEADROOM_BYTES = 536_870_912
REVIEWED_GROUP_SAFE_SYSTEM_TARGET_CEILING_BYTES = 3_263_168_512
KNOWN_PREFLASH_SYSTEM_A = {
    757_059_584: "STOCK_V010014",
    3_146_977_280: "C3A_ANDROID16_CONTROL",
    3_200_540_672: "N1F_PHYSICAL_CONTROL",
}
REQUIRED_ACTIVE_LOGICAL = {
    "system_a",
    "system_ext_a",
    "product_a",
    "vendor_a",
    "system_dlkm_a",
    "vendor_dlkm_a",
    "odm_dlkm_a",
}
FORBIDDEN_ODM_MATERIALIZATION = {"odm", "odm_a", "odm_b"}
ACTIVE_BASES = {name.removesuffix("_a") for name in REQUIRED_ACTIVE_LOGICAL}


def parse_fastboot(path: pathlib.Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = re.sub(r"^\s*\([^)]*\)\s*", "", raw.strip())
        if not line:
            continue
        match = re.match(r"^(.+):\s*([^:]+)\s*$", line)
        if match:
            values.setdefault(match.group(1).strip(), match.group(2).strip())
    return values


def parse_int(value: str) -> int:
    token = value.strip().split()[0] if value.strip() else ""
    try:
        return int(token, 0)
    except ValueError:
        return 0


def require(values: dict[str, str], key: str, expected: str) -> None:
    actual = values.get(key, "")
    if actual.lower() != expected.lower():
        raise SystemExit(
            f"N1I_C1_FASTBOOT_STATE=FAIL key={key} expected={expected} actual={actual or 'MISSING'}"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--getvar-all", required=True, type=pathlib.Path)
    parser.add_argument("--phase", required=True, choices=("pre", "post"))
    parser.add_argument("--out-env", required=True, type=pathlib.Path)
    args = parser.parse_args()

    if not args.getvar_all.is_file():
        print("N1I_C1_FASTBOOT_STATE=FAIL getvar_all_missing")
        return 64

    if TARGET_BYTES > REVIEWED_GROUP_SAFE_SYSTEM_TARGET_CEILING_BYTES:
        print(
            "N1I_C1_FASTBOOT_STATE=FAIL_GROUP_SAFE_TARGET_CEILING "
            f"target={TARGET_BYTES} "
            f"ceiling={REVIEWED_GROUP_SAFE_SYSTEM_TARGET_CEILING_BYTES}"
        )
        return 1

    values = parse_fastboot(args.getvar_all)
    require(values, "product", "Titan_2")
    require(values, "current-slot", "a")
    require(values, "is-userspace", "yes")
    require(values, "unlocked", "yes")
    require(values, "snapshot-update-status", "none")
    require(values, "is-logical:system_a", "yes")

    system_bytes = parse_int(values.get("partition-size:system_a", ""))
    super_bytes = parse_int(values.get("partition-size:super", ""))
    if super_bytes != SUPER_BYTES:
        print(
            f"N1I_C1_FASTBOOT_STATE=FAIL super_bytes={super_bytes} "
            f"expected={SUPER_BYTES}"
        )
        return 1

    logical_names = sorted(
        key.split(":", 1)[1]
        for key, value in values.items()
        if key.startswith("is-logical:") and value.lower() == "yes"
    )
    missing_active = sorted(REQUIRED_ACTIVE_LOGICAL - set(logical_names))
    if missing_active:
        print(
            "N1I_C1_FASTBOOT_STATE=FAIL_MISSING_ACTIVE_LOGICAL="
            + ",".join(missing_active)
        )
        return 1

    unexpected_odm = sorted(
        name
        for name in FORBIDDEN_ODM_MATERIALIZATION
        if name in logical_names
        or parse_int(values.get(f"partition-size:{name}", "")) > 0
    )
    if unexpected_odm:
        print(
            "N1I_C1_FASTBOOT_STATE=FAIL_UNEXPECTED_ODM_MATERIALIZATION="
            + ",".join(unexpected_odm)
        )
        return 1

    logical_sizes = {
        name: parse_int(values.get(f"partition-size:{name}", ""))
        for name in logical_names
    }
    bad_sizes = sorted(name for name, size in logical_sizes.items() if size <= 0)
    if bad_sizes:
        print("N1I_C1_FASTBOOT_STATE=FAIL logical_size_missing=" + ",".join(bad_sizes))
        return 1

    active_cows = sorted(
        {
            name
            for name, size in logical_sizes.items()
            if name.endswith("_a-cow") and size > 0
        }
        | {
            key.split(":", 1)[1]
            for key, value in values.items()
            if key.startswith("partition-size:")
            and key.split(":", 1)[1].endswith("_a-cow")
            and parse_int(value) > 0
        }
    )
    if active_cows:
        print("N1I_C1_FASTBOOT_STATE=FAIL active_cows=" + ",".join(active_cows))
        return 1

    # Some fastboot builds may expose an unsuffixed alias (for example
    # "system") as well as the active concrete logical name ("system_a").
    # They refer to the same active allocation on this Titan model and must
    # not be double-counted. Unknown additional logical partitions still count.
    allocation_names = [
        name
        for name in logical_names
        if not (
            name in ACTIVE_BASES
            and f"{name}_a" in logical_sizes
        )
    ]
    allocated = sum(logical_sizes[name] for name in allocation_names)
    baseline = "POSTFLASH_C1"
    projected = allocated

    if args.phase == "pre":
        if system_bytes == TARGET_BYTES:
            print("N1I_C1_FASTBOOT_STATE=REFUSE_ALREADY_TARGET_SIZE")
            return 20
        baseline = KNOWN_PREFLASH_SYSTEM_A.get(system_bytes, "")
        if not baseline:
            print(
                f"N1I_C1_FASTBOOT_STATE=FAIL_UNKNOWN_BASELINE "
                f"system_a_bytes={system_bytes}"
            )
            return 1
        projected = allocated - system_bytes + TARGET_BYTES
        remaining = super_bytes - projected
        if projected > super_bytes:
            print(
                f"N1I_C1_FASTBOOT_STATE=FAIL_PROJECTED_SUPER_CAPACITY "
                f"projected={projected} super={super_bytes}"
            )
            return 1
        if remaining < MIN_REMAINING_SUPER_HEADROOM_BYTES:
            print(
                f"N1I_C1_FASTBOOT_STATE=FAIL_PROJECTED_SUPER_HEADROOM "
                f"remaining={remaining} "
                f"minimum={MIN_REMAINING_SUPER_HEADROOM_BYTES}"
            )
            return 1
    else:
        if system_bytes != TARGET_BYTES:
            print(
                f"N1I_C1_FASTBOOT_STATE=FAIL_POST_SYSTEM_A_BYTES "
                f"actual={system_bytes} expected={TARGET_BYTES}"
            )
            return 1

    args.out_env.write_text(
        "\n".join(
            (
                f"N1I_C1_FASTBOOT_PHASE={args.phase.upper()}",
                f"N1I_C1_FASTBOOT_PRODUCT={values['product']}",
                f"N1I_C1_FASTBOOT_SLOT={values['current-slot']}",
                f"N1I_C1_FASTBOOT_IS_USERSPACE={values['is-userspace']}",
                f"N1I_C1_FASTBOOT_UNLOCKED={values['unlocked']}",
                f"N1I_C1_FASTBOOT_SNAPSHOT={values['snapshot-update-status']}",
                f"N1I_C1_FASTBOOT_SYSTEM_A_BYTES={system_bytes}",
                f"N1I_C1_FASTBOOT_SUPER_BYTES={super_bytes}",
                f"N1I_C1_FASTBOOT_LOGICAL_ALLOCATED_BYTES={allocated}",
                f"N1I_C1_FASTBOOT_PROJECTED_ALLOCATED_BYTES={projected}",
                f"N1I_C1_FASTBOOT_PROJECTED_REMAINING_SUPER_BYTES={super_bytes - projected}",
                f"N1I_C1_FASTBOOT_MIN_REMAINING_SUPER_BYTES={MIN_REMAINING_SUPER_HEADROOM_BYTES}",
                f"N1I_C1_FASTBOOT_REVIEWED_GROUP_SAFE_TARGET_CEILING_BYTES={REVIEWED_GROUP_SAFE_SYSTEM_TARGET_CEILING_BYTES}",
                "N1I_C1_FASTBOOT_TARGET_WITHIN_REVIEWED_GROUP_CEILING=YES",
                f"N1I_C1_FASTBOOT_BASELINE={baseline}",
                f"N1I_C1_FASTBOOT_REQUIRED_ACTIVE_LOGICAL_COUNT={len(REQUIRED_ACTIVE_LOGICAL)}",
                "N1I_C1_FASTBOOT_ODM_MATERIALIZATION=ABSENT_AS_QUALIFIED",
                "N1I_C1_FASTBOOT_ACTIVE_COW_COUNT=0",
                "N1I_C1_FASTBOOT_IMPLICIT_RESIZE=YES",
                "N1I_C1_FASTBOOT_MANUAL_PRE_RESIZE=NO",
                "N1I_C1_FASTBOOT_STATE=PASS",
                "",
            )
        ),
        encoding="utf-8",
    )
    print(
        f"N1I_C1_FASTBOOT_STATE=PASS phase={args.phase} "
        f"baseline={baseline} system_a_bytes={system_bytes}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
