#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import tempfile
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "build/titan2/plan-n1i-c2-native-install.py"
A4 = ROOT / "product/titan2/n1i-c1/a4-native-superset.txt"

KNOWN_KATI_TARGET = "/system/lib64/android.hardware.drm-V1-ndk.so"
KNOWN_KATI_ID = "M029"

spec = importlib.util.spec_from_file_location("n1i_c2_native_plan", TOOL)
assert spec is not None and spec.loader is not None
mod = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)


def targets() -> list[str]:
    rows = [
        line.strip()
        for line in A4.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    assert len(rows) == 33
    assert rows[22] == KNOWN_KATI_TARGET
    return rows


def id_for_target(target: str) -> str:
    return f"M{7 + targets().index(target):03d}"


def probe_rows(
    *,
    target_status: str = "PRESENT",
    target_same: bool = True,
    target: str = KNOWN_KATI_TARGET,
) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    for index, row_target in enumerate(targets(), start=7):
        stock = f"{index:064x}"[-64:]
        status = "ABSENT"
        c1_sha = "-"
        c1_path = "-"
        if row_target == target:
            status = target_status
            if status == "PRESENT":
                c1_sha = stock if target_same else "f" * 64
                c1_path = row_target
        out.append(
            {
                "id": f"M{index:03d}",
                "target": row_target,
                "module": f"SableN1IC2NativeM{index:03d}",
                "stock_sha256": stock,
                "c1_status": status,
                "c1_sha256": c1_sha,
                "c1_image_path": c1_path,
            }
        )
    return out


def collision_rows(
    *,
    target_state: str = "COLLISION",
    target: str = KNOWN_KATI_TARGET,
) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    for index, row_target in enumerate(targets(), start=7):
        state = "SINGLE_OWNER"
        count = 1
        owners = f"SableN1IC2NativeM{index:03d}"
        if row_target == target:
            state = target_state
            if state == "COLLISION":
                count = 2
                owners = (
                    "android.hardware.drm-V1-ndk;"
                    f"SableN1IC2NativeM{index:03d}"
                )
            elif state == "SINGLE_OWNER":
                count = 1
                owners = f"SableN1IC2NativeM{index:03d}"
            elif state == "UNCLAIMED":
                count = 0
                owners = "NONE"
            else:
                raise AssertionError(state)
        out.append(
            {
                "target": row_target,
                "state": state,
                "rule_count": str(count),
                "final_path": f"/out/{row_target.lstrip('/')}",
                "owner_hints": owners,
            }
        )
    return out


def row_for_target(rows: list[dict[str, str]], target: str) -> dict[str, str]:
    return next(row for row in rows if row["target"] == target)


def test_known_kati_collision_identical_baseline_reused() -> None:
    assert id_for_target(KNOWN_KATI_TARGET) == KNOWN_KATI_ID
    composition, imports = mod.plan(
        probe_rows(),
        set(targets()),
        collision_rows(),
    )
    row = row_for_target(composition, KNOWN_KATI_TARGET)
    assert len(composition) == 33
    assert len(imports) == 32
    assert row["id"] == KNOWN_KATI_ID
    assert row["disposition"] == "REUSE_C1_IDENTICAL"
    assert row["install_graph_state"] == "COLLISION"
    assert row["module"] not in imports


def test_graph_collision_absent_from_c1_fails_closed() -> None:
    try:
        mod.plan(
            probe_rows(target_status="ABSENT"),
            set(targets()),
            collision_rows(),
        )
    except mod.PlanError as exc:
        text = str(exc)
        assert "baseline_different_requires_explicit_decision=" in text
        assert f"{KNOWN_KATI_ID}:{KNOWN_KATI_TARGET}" in text
        assert "graph_rules=2" in text
    else:
        raise AssertionError("known Kati graph collision absent from C1 was admitted")


def test_different_baseline_fails_closed() -> None:
    try:
        mod.plan(
            probe_rows(target_status="PRESENT", target_same=False),
            set(targets()),
            collision_rows(),
        )
    except mod.PlanError as exc:
        text = str(exc)
        assert "baseline_different_requires_explicit_decision=" in text
        assert f"{KNOWN_KATI_ID}:{KNOWN_KATI_TARGET}" in text
        assert "c1=" in text
        assert "stock=" in text
    else:
        raise AssertionError("different C1 baseline was silently overridden")


def test_generated_packages_exclude_known_reuse() -> None:
    composition, imports = mod.plan(
        probe_rows(),
        set(targets()),
        collision_rows(),
    )
    row = row_for_target(composition, KNOWN_KATI_TARGET)
    assert row["disposition"] == "REUSE_C1_IDENTICAL"
    with tempfile.TemporaryDirectory() as td:
        out = Path(td) / "native-packages.mk"
        mod.write_packages(out, imports)
        text = out.read_text(encoding="utf-8")
        assert "PRODUCT_PACKAGES +=" in text
        assert f"SableN1IC2Native{KNOWN_KATI_ID}" not in text
        assert text.count("SableN1IC2NativeM") == 32


def main() -> int:
    test_known_kati_collision_identical_baseline_reused()
    test_graph_collision_absent_from_c1_fails_closed()
    test_different_baseline_fails_closed()
    test_generated_packages_exclude_known_reuse()
    print(
        "N1I_C2_NATIVE_INSTALL_PLAN_KNOWN_KATI_COLLISION_REUSE=PASS "
        f"id={KNOWN_KATI_ID} target={KNOWN_KATI_TARGET}"
    )
    print("N1I_C2_NATIVE_INSTALL_PLAN_GRAPH_COLLISION_FAIL_CLOSED=PASS")
    print("N1I_C2_NATIVE_INSTALL_PLAN_DIFFERENT_BASELINE_FAIL_CLOSED=PASS")
    print("N1I_C2_NATIVE_INSTALL_PLAN_GENERATED_PACKAGES=PASS")
    print("N1I_C2_NATIVE_INSTALL_PLAN_TEST=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
