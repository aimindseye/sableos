#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re

SUPER_BYTES = 9_663_676_416
TARGET_BYTES = 3_200_548_864
MIN_REMAINING_SUPER_HEADROOM_BYTES = 536_870_912
REVIEWED_GROUP_SAFE_SYSTEM_TARGET_CEILING_BYTES = 3_263_168_512

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
            "N1I_D0_IMG0_FASTBOOT_STATE=FAIL "
            f"key={key} expected={expected} actual={actual or 'MISSING'}"
        )


def qualify(
    values: dict[str, str],
    phase: str,
) -> tuple[list[str], str]:
    if TARGET_BYTES > REVIEWED_GROUP_SAFE_SYSTEM_TARGET_CEILING_BYTES:
        raise SystemExit(
            "N1I_D0_IMG0_FASTBOOT_STATE=FAIL_GROUP_SAFE_TARGET_CEILING "
            f"target={TARGET_BYTES} "
            f"ceiling={REVIEWED_GROUP_SAFE_SYSTEM_TARGET_CEILING_BYTES}"
        )

    require(values, "product", "Titan_2")
    require(values, "current-slot", "a")
    require(values, "is-userspace", "yes")
    require(values, "unlocked", "yes")
    require(values, "snapshot-update-status", "none")
    require(values, "is-logical:system_a", "yes")

    system_bytes = parse_int(values.get("partition-size:system_a", ""))
    super_bytes = parse_int(values.get("partition-size:super", ""))
    if system_bytes <= 0:
        raise SystemExit("N1I_D0_IMG0_FASTBOOT_STATE=FAIL_SYSTEM_A_SIZE_UNREADABLE")
    if super_bytes != SUPER_BYTES:
        raise SystemExit(
            "N1I_D0_IMG0_FASTBOOT_STATE=FAIL "
            f"super_bytes={super_bytes} expected={SUPER_BYTES}"
        )

    logical_names = sorted(
        key.split(":", 1)[1]
        for key, value in values.items()
        if key.startswith("is-logical:") and value.lower() == "yes"
    )

    missing_active = sorted(REQUIRED_ACTIVE_LOGICAL - set(logical_names))
    if missing_active:
        raise SystemExit(
            "N1I_D0_IMG0_FASTBOOT_STATE=FAIL_MISSING_ACTIVE_LOGICAL="
            + ",".join(missing_active)
        )

    unexpected_odm = sorted(
        name
        for name in FORBIDDEN_ODM_MATERIALIZATION
        if name in logical_names
        or parse_int(values.get(f"partition-size:{name}", "")) > 0
    )
    if unexpected_odm:
        raise SystemExit(
            "N1I_D0_IMG0_FASTBOOT_STATE=FAIL_UNEXPECTED_ODM_MATERIALIZATION="
            + ",".join(unexpected_odm)
        )

    logical_sizes = {
        name: parse_int(values.get(f"partition-size:{name}", ""))
        for name in logical_names
    }
    bad_sizes = sorted(name for name, size in logical_sizes.items() if size <= 0)
    if bad_sizes:
        raise SystemExit(
            "N1I_D0_IMG0_FASTBOOT_STATE=FAIL_LOGICAL_SIZE_MISSING="
            + ",".join(bad_sizes)
        )

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
        raise SystemExit(
            "N1I_D0_IMG0_FASTBOOT_STATE=FAIL_ACTIVE_COWS="
            + ",".join(active_cows)
        )

    allocation_names = [
        name
        for name in logical_names
        if not (
            name in ACTIVE_BASES
            and f"{name}_a" in logical_sizes
        )
    ]
    allocated = sum(logical_sizes[name] for name in allocation_names)

    if phase == "pre":
        projected = allocated - system_bytes + TARGET_BYTES
        remaining = super_bytes - projected
        if projected > super_bytes:
            raise SystemExit(
                "N1I_D0_IMG0_FASTBOOT_STATE=FAIL_PROJECTED_SUPER_CAPACITY "
                f"projected={projected} super={super_bytes}"
            )
        if remaining < MIN_REMAINING_SUPER_HEADROOM_BYTES:
            raise SystemExit(
                "N1I_D0_IMG0_FASTBOOT_STATE=FAIL_PROJECTED_SUPER_HEADROOM "
                f"remaining={remaining} "
                f"minimum={MIN_REMAINING_SUPER_HEADROOM_BYTES}"
            )
        baseline = "LIVE_CURRENT_SYSTEM_A"
    else:
        if system_bytes != TARGET_BYTES:
            raise SystemExit(
                "N1I_D0_IMG0_FASTBOOT_STATE=FAIL_POST_SYSTEM_A_BYTES "
                f"actual={system_bytes} expected={TARGET_BYTES}"
            )
        projected = allocated
        remaining = super_bytes - allocated
        baseline = "POSTFLASH_D0_IMG0"

    rows = [
        f"N1I_D0_IMG0_FASTBOOT_PHASE={phase.upper()}",
        f"N1I_D0_IMG0_FASTBOOT_PRODUCT={values['product']}",
        f"N1I_D0_IMG0_FASTBOOT_SLOT={values['current-slot']}",
        f"N1I_D0_IMG0_FASTBOOT_IS_USERSPACE={values['is-userspace']}",
        f"N1I_D0_IMG0_FASTBOOT_UNLOCKED={values['unlocked']}",
        f"N1I_D0_IMG0_FASTBOOT_SNAPSHOT={values['snapshot-update-status']}",
        f"N1I_D0_IMG0_FASTBOOT_SYSTEM_A_BYTES={system_bytes}",
        f"N1I_D0_IMG0_FASTBOOT_SUPER_BYTES={super_bytes}",
        f"N1I_D0_IMG0_FASTBOOT_LOGICAL_ALLOCATED_BYTES={allocated}",
        f"N1I_D0_IMG0_FASTBOOT_PROJECTED_ALLOCATED_BYTES={projected}",
        f"N1I_D0_IMG0_FASTBOOT_PROJECTED_REMAINING_SUPER_BYTES={remaining}",
        (
            "N1I_D0_IMG0_FASTBOOT_MIN_REMAINING_SUPER_BYTES="
            f"{MIN_REMAINING_SUPER_HEADROOM_BYTES}"
        ),
        (
            "N1I_D0_IMG0_FASTBOOT_REVIEWED_GROUP_SAFE_TARGET_CEILING_BYTES="
            f"{REVIEWED_GROUP_SAFE_SYSTEM_TARGET_CEILING_BYTES}"
        ),
        "N1I_D0_IMG0_FASTBOOT_TARGET_WITHIN_REVIEWED_GROUP_CEILING=YES",
        f"N1I_D0_IMG0_FASTBOOT_BASELINE={baseline}",
        (
            "N1I_D0_IMG0_FASTBOOT_REQUIRED_ACTIVE_LOGICAL_COUNT="
            f"{len(REQUIRED_ACTIVE_LOGICAL)}"
        ),
        "N1I_D0_IMG0_FASTBOOT_ODM_MATERIALIZATION=ABSENT_AS_QUALIFIED",
        "N1I_D0_IMG0_FASTBOOT_ACTIVE_COW_COUNT=0",
        "N1I_D0_IMG0_FASTBOOT_IMPLICIT_RESIZE=YES",
        "N1I_D0_IMG0_FASTBOOT_MANUAL_PRE_RESIZE=NO",
        "N1I_D0_IMG0_FASTBOOT_STATE=PASS",
        "",
    ]
    return rows, baseline


def selftest() -> int:
    values = {
        "product": "Titan_2",
        "current-slot": "a",
        "is-userspace": "yes",
        "unlocked": "yes",
        "snapshot-update-status": "none",
        "is-logical:system_a": "yes",
        "partition-size:super": hex(SUPER_BYTES),
    }
    sizes = {
        "system_a": 3_210_661_888,
        "system_ext_a": 600_000_000,
        "product_a": 500_000_000,
        "vendor_a": 1_400_000_000,
        "system_dlkm_a": 64_000_000,
        "vendor_dlkm_a": 128_000_000,
        "odm_dlkm_a": 64_000_000,
    }
    for name, size in sizes.items():
        values[f"is-logical:{name}"] = "yes"
        values[f"partition-size:{name}"] = hex(size)

    rows, baseline = qualify(values, "pre")
    assert baseline == "LIVE_CURRENT_SYSTEM_A"
    assert "N1I_D0_IMG0_FASTBOOT_STATE=PASS" in rows

    values["partition-size:system_a"] = hex(TARGET_BYTES)
    rows, baseline = qualify(values, "post")
    assert baseline == "POSTFLASH_D0_IMG0"
    assert "N1I_D0_IMG0_FASTBOOT_STATE=PASS" in rows

    print("N1I_D0_IMG0_FASTBOOT_STATE_SELFTEST=PASS")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--getvar-all", type=pathlib.Path)
    parser.add_argument("--phase", choices=("pre", "post"))
    parser.add_argument("--out-env", type=pathlib.Path)
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()

    if args.selftest:
        return selftest()

    if (
        args.getvar_all is None
        or args.phase is None
        or args.out_env is None
    ):
        parser.error("--getvar-all, --phase and --out-env are required")

    if not args.getvar_all.is_file():
        print("N1I_D0_IMG0_FASTBOOT_STATE=FAIL getvar_all_missing")
        return 64

    values = parse_fastboot(args.getvar_all)
    try:
        rows, baseline = qualify(values, args.phase)
    except SystemExit as exc:
        print(str(exc))
        return 1

    args.out_env.write_text("\n".join(rows), encoding="utf-8")
    print(
        "N1I_D0_IMG0_FASTBOOT_STATE=PASS "
        f"phase={args.phase} baseline={baseline} "
        f"system_a_bytes={parse_int(values.get('partition-size:system_a', ''))}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
