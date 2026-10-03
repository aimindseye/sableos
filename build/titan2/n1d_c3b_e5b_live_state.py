#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re
import tempfile

FAMILIES = (
    "system",
    "system_ext",
    "product",
    "vendor",
    "odm",
    "system_dlkm",
    "vendor_dlkm",
    "odm_dlkm",
)


class PreflightError(ValueError):
    pass


def normalize_getvar(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in text.splitlines():
        line = re.sub(r"^\s*\([^)]*\)\s*", "", raw.strip())
        if not line:
            continue
        match = re.match(r"^(.+):\s*([^:]+)$", line)
        if match:
            values.setdefault(
                match.group(1).strip(),
                match.group(2).strip(),
            )
    return values


def as_int(value: str) -> int:
    token = value.strip().split()[0] if value.strip() else ""
    try:
        return int(token, 0)
    except ValueError:
        return 0


def evaluate(
    text: str,
    *,
    expected_product: str,
    expected_slot: str,
    expected_system: int,
    expected_super: int,
    expected_allocated: int,
) -> dict[str, str | int]:
    values = normalize_getvar(text)

    required = {
        "product": expected_product,
        "current-slot": expected_slot,
        "is-userspace": "yes",
        "unlocked": "yes",
        "snapshot-update-status": "none",
        "is-logical:system_a": "yes",
    }
    for key, expected in required.items():
        actual = values.get(key, "")
        if actual.lower() != expected.lower():
            raise PreflightError(
                f"key={key} expected={expected} "
                f"actual={actual or 'MISSING'}"
            )

    system_bytes = as_int(
        values.get("partition-size:system_a", "")
    )
    super_bytes = as_int(
        values.get("partition-size:super", "")
    )
    system_b_bytes = as_int(
        values.get("partition-size:system_b", "")
    )

    if system_bytes != expected_system:
        raise PreflightError(
            f"system_a_bytes={system_bytes} "
            f"expected={expected_system}"
        )
    if super_bytes != expected_super:
        raise PreflightError(
            f"super_bytes={super_bytes} "
            f"expected={expected_super}"
        )
    if system_b_bytes != 0:
        raise PreflightError(
            f"system_b_bytes={system_b_bytes} expected=0"
        )

    fallback_all_slots_total = 0
    complete_family_evidence = True

    for base in FAMILIES:
        unsuffixed = as_int(
            values.get(f"partition-size:{base}", "")
        )
        a = as_int(
            values.get(f"partition-size:{base}_a", "")
        )
        b = as_int(
            values.get(f"partition-size:{base}_b", "")
        )
        has_slot = values.get(
            f"has-slot:{base}",
            "",
        ).lower()

        active = (
            as_int(
                values.get(
                    f"partition-size:{base}_{expected_slot}",
                    "",
                )
            )
            if expected_slot in {"a", "b"}
            else 0
        )
        active = active or unsuffixed or max(a, b)

        if has_slot == "yes":
            complete = a > 0 and b > 0
            all_slots = a + b if complete else 0
        elif has_slot == "no":
            complete = unsuffixed > 0 or active > 0
            all_slots = unsuffixed or active
        elif a or b:
            complete = a > 0 and b > 0
            all_slots = a + b if complete else 0
        elif unsuffixed:
            complete = True
            all_slots = unsuffixed
        else:
            complete = True
            all_slots = 0

        if not complete:
            complete_family_evidence = False
        fallback_all_slots_total += all_slots

    logical_names = {
        key.split(":", 1)[1]
        for key, value in values.items()
        if key.startswith("is-logical:")
        and value.lower() == "yes"
    }

    active_cows = sorted(
        name
        for name in logical_names
        if name.endswith(f"_{expected_slot}-cow")
    )
    if active_cows:
        raise PreflightError(
            "active_cows=" + ",".join(active_cows)
        )

    deduped = set(logical_names)
    for name in list(logical_names):
        if not (
            name.endswith("_a")
            or name.endswith("_b")
        ):
            if (
                f"{name}_a" in logical_names
                or f"{name}_b" in logical_names
            ):
                deduped.discard(name)

    reported_sizes = {
        name: as_int(
            values.get(
                f"partition-size:{name}",
                "",
            )
        )
        for name in deduped
    }

    reported_logical_complete = (
        bool(reported_sizes)
        and all(
            size > 0
            for size in reported_sizes.values()
        )
    )

    if reported_logical_complete:
        allocated = sum(reported_sizes.values())
        allocation_basis = (
            "GETVAR_ALL_LOGICAL_PARTITIONS_COMPLETE"
        )
    elif (
        complete_family_evidence
        and fallback_all_slots_total > 0
    ):
        allocated = fallback_all_slots_total
        allocation_basis = (
            "KNOWN_FAMILY_COMPLETE_FALLBACK"
        )
    else:
        raise PreflightError(
            "allocation_evidence_incomplete"
        )

    if allocated != expected_allocated:
        raise PreflightError(
            f"allocated={allocated} "
            f"expected={expected_allocated}"
        )

    return {
        "LIVE_PRODUCT": values["product"],
        "LIVE_CURRENT_SLOT": values["current-slot"],
        "LIVE_IS_USERSPACE": values["is-userspace"],
        "LIVE_UNLOCKED": values["unlocked"],
        "LIVE_SNAPSHOT_UPDATE_STATUS":
            values["snapshot-update-status"],
        "LIVE_SYSTEM_A_BYTES": system_bytes,
        "LIVE_SYSTEM_B_BYTES": system_b_bytes,
        "LIVE_SUPER_BYTES": super_bytes,
        "LIVE_MATERIALIZED_LOGICAL_BYTES":
            allocated,
        "LIVE_ALLOCATION_BASIS":
            allocation_basis,
        "LIVE_ACTIVE_COW_COUNT": 0,
    }


def write_env(
    path: pathlib.Path,
    state: dict[str, str | int],
) -> None:
    path.write_text(
        "".join(
            f"{key}={value}\n"
            for key, value in state.items()
        ),
        encoding="utf-8",
    )


def base_fixture(
    *,
    system: int,
    other: int,
    super_bytes: int,
) -> str:
    prefix = "(bootloader) "
    return "".join(
        [
            f"{prefix}product: Titan_2\n",
            f"{prefix}current-slot: a\n",
            f"{prefix}is-userspace: yes\n",
            f"{prefix}unlocked: yes\n",
            (
                f"{prefix}"
                "snapshot-update-status: none\n"
            ),
            (
                f"{prefix}"
                "is-logical:system_a: yes\n"
            ),
            (
                f"{prefix}partition-size:system_a: "
                f"{system}\n"
            ),
            (
                f"{prefix}partition-size:system_b: "
                "0\n"
            ),
            (
                f"{prefix}partition-size:super: "
                f"{super_bytes}\n"
            ),
            (
                f"{prefix}"
                "is-logical:product_a: yes\n"
            ),
            (
                f"{prefix}partition-size:product_a: "
                f"{other}\n"
            ),
        ]
    )


def self_test() -> None:
    system = 757_059_584
    allocated = 4_203_425_792
    other = allocated - system
    super_bytes = 9_663_676_416

    valid = base_fixture(
        system=system,
        other=other,
        super_bytes=super_bytes,
    )
    state = evaluate(
        valid,
        expected_product="Titan_2",
        expected_slot="a",
        expected_system=system,
        expected_super=super_bytes,
        expected_allocated=allocated,
    )
    assert state["LIVE_ALLOCATION_BASIS"] == (
        "GETVAR_ALL_LOGICAL_PARTITIONS_COMPLETE"
    )

    snapshot = valid.replace(
        "snapshot-update-status: none",
        "snapshot-update-status: merging",
    )
    try:
        evaluate(
            snapshot,
            expected_product="Titan_2",
            expected_slot="a",
            expected_system=system,
            expected_super=super_bytes,
            expected_allocated=allocated,
        )
    except PreflightError as exc:
        assert "snapshot-update-status" in str(exc)
    else:
        raise AssertionError(
            "snapshot merge state was accepted"
        )

    cow = valid + "".join(
        [
            "(bootloader) "
            "is-logical:system_a-cow: yes\n",
            "(bootloader) "
            "partition-size:system_a-cow: 4096\n",
        ]
    )
    try:
        evaluate(
            cow,
            expected_product="Titan_2",
            expected_slot="a",
            expected_system=system,
            expected_super=super_bytes,
            expected_allocated=allocated,
        )
    except PreflightError as exc:
        assert "active_cows=system_a-cow" in str(exc)
    else:
        raise AssertionError(
            "active system_a COW was accepted"
        )

    incomplete = (
        valid
        + "(bootloader) "
        "is-logical:system_b: yes\n"
    )
    try:
        evaluate(
            incomplete,
            expected_product="Titan_2",
            expected_slot="a",
            expected_system=system,
            expected_super=super_bytes,
            expected_allocated=allocated,
        )
    except PreflightError as exc:
        assert (
            "allocation_evidence_incomplete"
            in str(exc)
        )
    else:
        raise AssertionError(
            "zero-size advertised system_b "
            "was silently accepted"
        )

    fallback = "".join(
        [
            "(bootloader) product: Titan_2\n",
            "(bootloader) current-slot: a\n",
            "(bootloader) is-userspace: yes\n",
            "(bootloader) unlocked: yes\n",
            "(bootloader) "
            "snapshot-update-status: none\n",
            "(bootloader) "
            "is-logical:system_a: yes\n",
            "(bootloader) "
            f"partition-size:system_a: {system}\n",
            "(bootloader) "
            "partition-size:system_b: 0\n",
            "(bootloader) "
            f"partition-size:super: {super_bytes}\n",
            "(bootloader) "
            "has-slot:system: no\n",
            "(bootloader) "
            f"partition-size:system: {system}\n",
            "(bootloader) "
            "has-slot:product: no\n",
            "(bootloader) "
            f"partition-size:product: {other}\n",
            "(bootloader) "
            "is-logical:unknown_test: yes\n",
        ]
    )
    state = evaluate(
        fallback,
        expected_product="Titan_2",
        expected_slot="a",
        expected_system=system,
        expected_super=super_bytes,
        expected_allocated=allocated,
    )
    assert state["LIVE_ALLOCATION_BASIS"] == (
        "KNOWN_FAMILY_COMPLETE_FALLBACK"
    )

    with tempfile.TemporaryDirectory() as td:
        out = pathlib.Path(td) / "live.env"
        write_env(out, state)
        text = out.read_text(encoding="utf-8")
        assert (
            "LIVE_ACTIVE_COW_COUNT=0\n"
            in text
        )

    print(
        "N1D_C3B_E5B_LIVE_STATE_VALID=PASS"
    )
    print(
        "N1D_C3B_E5B_LIVE_STATE_SNAPSHOT_REJECT=PASS"
    )
    print(
        "N1D_C3B_E5B_LIVE_STATE_ACTIVE_COW_REJECT=PASS"
    )
    print(
        "N1D_C3B_E5B_LIVE_STATE_ZERO_INACTIVE_FAIL_CLOSED=PASS"
    )
    print(
        "N1D_C3B_E5B_LIVE_STATE_FALLBACK=PASS"
    )
    print(
        "N1D_C3B_E5B_LIVE_STATE_SELF_TEST=PASS"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--getvar-all",
        type=pathlib.Path,
    )
    parser.add_argument(
        "--expected-product",
    )
    parser.add_argument(
        "--expected-slot",
    )
    parser.add_argument(
        "--expected-system-bytes",
        type=int,
    )
    parser.add_argument(
        "--expected-super-bytes",
        type=int,
    )
    parser.add_argument(
        "--expected-allocated-bytes",
        type=int,
    )
    parser.add_argument(
        "--output-env",
        type=pathlib.Path,
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
    )
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0

    required = (
        args.getvar_all,
        args.expected_product,
        args.expected_slot,
        args.expected_system_bytes,
        args.expected_super_bytes,
        args.expected_allocated_bytes,
        args.output_env,
    )
    if any(value is None for value in required):
        parser.error(
            "live-state mode requires all expected "
            "values and --output-env"
        )

    assert args.getvar_all is not None
    assert args.output_env is not None

    try:
        state = evaluate(
            args.getvar_all.read_text(
                encoding="utf-8",
                errors="replace",
            ),
            expected_product=str(
                args.expected_product
            ),
            expected_slot=str(
                args.expected_slot
            ),
            expected_system=int(
                args.expected_system_bytes
            ),
            expected_super=int(
                args.expected_super_bytes
            ),
            expected_allocated=int(
                args.expected_allocated_bytes
            ),
        )
    except PreflightError as exc:
        print(
            "TITAN2_N1D_E5B_LIVE_PREFLIGHT=FAIL "
            f"{exc}"
        )
        return 2

    write_env(
        args.output_env,
        state,
    )

    for key, value in state.items():
        print(f"{key}={value}")
    print(
        "TITAN2_N1D_E5B_LIVE_PREFLIGHT=PASS"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
