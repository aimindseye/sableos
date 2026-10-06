#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "build/titan2/plan-n1i-c2-native-install.py"
A4 = ROOT / "product/titan2/n1i-c1/a4-native-superset.txt"
DECISIONS = ROOT / "product/titan2/n1i-c2/platform-native-provider.tsv"

spec = importlib.util.spec_from_file_location(
    "n1i_c2_native_plan",
    TOOL,
)
assert spec is not None and spec.loader is not None
mod = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)

KNOWN_KATI_TARGET = (
    "/system/lib64/android.hardware.drm-V1-ndk.so"
)
KNOWN_KATI_ID = "M029"


def targets() -> list[str]:
    rows = [
        line.strip()
        for line in A4.read_text(
            encoding="utf-8"
        ).splitlines()
        if line.strip()
        and not line.lstrip().startswith("#")
    ]
    assert len(rows) == 33
    return rows


def id_for_target(target: str) -> str:
    return f"M{7 + targets().index(target):03d}"


def stock_sha(index: int) -> str:
    return f"{index:064x}"[-64:]


def different_sha(index: int) -> str:
    return f"{index + 1000:064x}"[-64:]


def decisions() -> dict[tuple[str, str], str]:
    parsed = mod.platform_provider_decisions(
        DECISIONS
    )
    assert (
        parsed
        == mod.EXPECTED_ANDROID_PLATFORM_PROVIDERS
    )
    assert len(parsed) == 5
    return parsed


def probe_rows() -> list[dict[str, str]]:
    out: list[dict[str, str]] = []

    for index, target in enumerate(
        targets(),
        start=7,
    ):
        mid = f"M{index:03d}"
        out.append(
            {
                "id": mid,
                "target": target,
                "module": f"SableN1IC2Native{mid}",
                "stock_sha256": stock_sha(index),
                "c1_status": "ABSENT",
                "c1_sha256": "-",
                "c1_image_path": target,
            }
        )

    return out


def collision_rows() -> list[dict[str, str]]:
    reviewed = decisions()
    out: list[dict[str, str]] = []

    for index, target in enumerate(
        targets(),
        start=7,
    ):
        mid = f"M{index:03d}"
        module = f"SableN1IC2Native{mid}"
        key = (mid, target)

        if key in reviewed:
            state = "COLLISION"
            count = 2
            owners = (
                f"{module};{reviewed[key]}"
            )
        else:
            state = "SINGLE_OWNER"
            count = 1
            owners = module

        out.append(
            {
                "target": target,
                "state": state,
                "rule_count": str(count),
                "final_path": (
                    f"/out/{target.lstrip('/')}"
                ),
                "owner_hints": owners,
            }
        )

    return out


def row_for_target(
    rows: list[dict[str, str]],
    target: str,
) -> dict[str, str]:
    return next(
        row
        for row in rows
        if row["target"] == target
    )


def test_five_reviewed_platform_providers_preserved() -> None:
    composition, imports = mod.plan(
        probe_rows(),
        set(targets()),
        collision_rows(),
        decisions(),
    )

    assert len(composition) == 33
    assert len(imports) == 28

    for key, owner in decisions().items():
        mid, target = key
        row = row_for_target(
            composition,
            target,
        )
        assert row["id"] == mid
        assert (
            row["disposition"]
            == "USE_ANDROID_PLATFORM_PROVIDER"
        )
        assert (
            row["install_graph_state"]
            == "COLLISION"
        )
        assert (
            row["install_graph_rule_count"]
            == "2"
        )
        assert (
            owner
            in row["install_graph_owner_hints"]
        )
        assert row["module"] not in imports

    kati = row_for_target(
        composition,
        KNOWN_KATI_TARGET,
    )
    assert kati["id"] == KNOWN_KATI_ID
    assert (
        kati["disposition"]
        == "USE_ANDROID_PLATFORM_PROVIDER"
    )


def test_generated_packages_are_exact_28_imports() -> None:
    composition, imports = mod.plan(
        probe_rows(),
        set(targets()),
        collision_rows(),
        decisions(),
    )

    with tempfile.TemporaryDirectory() as td:
        out = Path(td) / "native-packages.mk"
        mod.write_packages(
            out,
            imports,
        )
        text = out.read_text(
            encoding="utf-8"
        )

        assert (
            text.count("SableN1IC2NativeM")
            == 28
        )

        for mid, _target in decisions():
            assert (
                f"SableN1IC2Native{mid}"
                not in text
            )


def test_platform_owner_mismatch_fails_closed() -> None:
    rows = probe_rows()
    collisions = collision_rows()

    row = row_for_target(
        collisions,
        KNOWN_KATI_TARGET,
    )
    row["owner_hints"] = (
        f"SableN1IC2Native{KNOWN_KATI_ID};"
        "wrong.platform.owner"
    )

    try:
        mod.plan(
            rows,
            set(targets()),
            collisions,
            decisions(),
        )
    except mod.PlanError as exc:
        text = str(exc)
        assert (
            f"{KNOWN_KATI_ID}:"
            f"{KNOWN_KATI_TARGET}"
            in text
        )
        assert (
            "expected_android_owner="
            "android.hardware.drm-V1-ndk"
            in text
        )
    else:
        raise AssertionError(
            "wrong platform owner was accepted"
        )


def test_c1_native_presence_fails_closed() -> None:
    rows = probe_rows()

    row = row_for_target(
        rows,
        KNOWN_KATI_TARGET,
    )
    row["c1_status"] = "PRESENT"
    row["c1_sha256"] = different_sha(29)
    row["c1_image_path"] = KNOWN_KATI_TARGET

    try:
        mod.plan(
            rows,
            set(targets()),
            collision_rows(),
            decisions(),
        )
    except mod.PlanError as exc:
        text = str(exc)
        assert (
            "c1_native_present_not_allowed="
            in text
        )
        assert KNOWN_KATI_ID in text
        assert KNOWN_KATI_TARGET in text
    else:
        raise AssertionError(
            "unexpected C1 native presence was accepted"
        )


def test_unreviewed_collision_fails_closed() -> None:
    rows = probe_rows()
    collisions = collision_rows()

    reviewed_keys = set(decisions())
    target = next(
        target
        for target in targets()
        if (
            id_for_target(target),
            target,
        )
        not in reviewed_keys
    )
    mid = id_for_target(target)

    collision = row_for_target(
        collisions,
        target,
    )
    collision["state"] = "COLLISION"
    collision["rule_count"] = "2"
    collision["owner_hints"] = (
        f"SableN1IC2Native{mid};"
        "unexpected.platform.owner"
    )

    try:
        mod.plan(
            rows,
            set(targets()),
            collisions,
            decisions(),
        )
    except mod.PlanError as exc:
        text = str(exc)
        assert f"{mid}:{target}" in text
        assert (
            "platform_provider_admission_blocked="
            in text
        )
        assert "unexpected.platform.owner" in text
    else:
        raise AssertionError(
            "unreviewed collision was accepted"
        )


def main() -> int:
    test_five_reviewed_platform_providers_preserved()
    test_generated_packages_are_exact_28_imports()
    test_platform_owner_mismatch_fails_closed()
    test_c1_native_presence_fails_closed()
    test_unreviewed_collision_fails_closed()

    print(
        "N1I_C2_NATIVE_INSTALL_PLAN_PLATFORM_PROVIDER_SET=PASS count=5 imports=28 c1_reuse=0"
    )
    print(
        "N1I_C2_NATIVE_INSTALL_PLAN_KNOWN_KATI_COLLISION_ANDROID_PLATFORM_PROVIDER=PASS "
        f"id={KNOWN_KATI_ID} "
        f"target={KNOWN_KATI_TARGET}"
    )
    print(
        "N1I_C2_NATIVE_INSTALL_PLAN_"
        "PLATFORM_OWNER_FAIL_CLOSED=PASS"
    )
    print(
        "N1I_C2_NATIVE_INSTALL_PLAN_"
        "C1_PRESENT_FAIL_CLOSED=PASS"
    )
    print(
        "N1I_C2_NATIVE_INSTALL_PLAN_"
        "UNREVIEWED_COLLISION_FAIL_CLOSED=PASS"
    )
    print(
        "N1I_C2_NATIVE_INSTALL_PLAN_"
        "GENERATED_PACKAGES=PASS count=28"
    )
    print(
        "N1I_C2_NATIVE_INSTALL_PLAN_TEST=PASS"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
