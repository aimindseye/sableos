#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "build/titan2/plan-n1i-c2-native-install.py"
A4 = ROOT / "product/titan2/n1i-c1/a4-native-superset.txt"
KNOWN_KATI_TARGET = "/system/lib64/android.hardware.drm-V1-ndk.so"

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
    assert KNOWN_KATI_TARGET in rows
    return rows


def mutation_id_for(target: str) -> str:
    return f"M{7 + targets().index(target):03d}"


def probe_rows(
    *,
    special_target: str = KNOWN_KATI_TARGET,
    special_status: str = "PRESENT",
    special_same: bool = True,
) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    for index, target in enumerate(targets(), start=7):
        stock = f"{index:064x}"[-64:]
        status = "ABSENT"
        c1_sha = "-"
        if target == special_target:
            status = special_status
            if status == "PRESENT":
                c1_sha = stock if special_same else "f" * 64
        out.append({
            "id": f"M{index:03d}",
            "target": target,
            "module": f"SableN1IC2NativeM{index:03d}",
            "stock_sha256": stock,
            "c1_status": status,
            "c1_sha256": c1_sha,
            "c1_image_path": f"/fixture/{index}",
        })
    return out


def collision_rows(
    *,
    special_target: str = KNOWN_KATI_TARGET,
    special_state: str = "COLLISION",
) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    for index, target in enumerate(targets(), start=7):
        state = "SINGLE_OWNER"
        count = 1
        owners = f"SableN1IC2NativeM{index:03d}"
        if target == special_target:
            state = special_state
            count = 2 if state == "COLLISION" else 1
            owners = f"platform_owner;SableN1IC2NativeM{index:03d}"
        out.append({
            "target": target,
            "state": state,
            "rule_count": str(count),
            "final_path": f"/out/{target.lstrip('/')}",
            "owner_hints": owners,
        })
    return out


def row_for(rows: list[dict[str, str]], target: str) -> dict[str, str]:
    matches = [row for row in rows if row["target"] == target]
    assert len(matches) == 1
    return matches[0]


def test_known_kati_collision_reused() -> None:
    composition, imports = mod.plan(
        probe_rows(),
        set(targets()),
        collision_rows(),
    )
    drm = row_for(composition, KNOWN_KATI_TARGET)
    assert drm["id"] == mutation_id_for(KNOWN_KATI_TARGET)
    assert drm["disposition"] == "REUSE_C1_IDENTICAL"
    assert drm["install_graph_state"] == "COLLISION"
    assert drm["module"] not in imports
    assert len(composition) == 33
    assert len(imports) == 32


def test_graph_collision_absent_from_c1_fails_closed() -> None:
    try:
        mod.plan(
            probe_rows(special_status="ABSENT"),
            set(targets()),
            collision_rows(),
        )
    except mod.PlanError as exc:
        text = str(exc)
        assert "baseline_different_requires_explicit_decision=" in text
        assert mutation_id_for(KNOWN_KATI_TARGET) in text
        assert "graph_rules=2" in text
    else:
        raise AssertionError("graph collision absent from C1 was admitted")


def test_different_baseline_fails_closed() -> None:
    try:
        mod.plan(
            probe_rows(special_status="PRESENT", special_same=False),
            set(targets()),
            collision_rows(),
        )
    except mod.PlanError as exc:
        text = str(exc)
        assert "baseline_different_requires_explicit_decision=" in text
        assert mutation_id_for(KNOWN_KATI_TARGET) in text
        assert "c1=" in text
        assert "stock=" in text
    else:
        raise AssertionError("different C1 baseline was silently overridden")


def test_generated_packages_excludes_reused_collision() -> None:
    composition, imports = mod.plan(
        probe_rows(),
        set(targets()),
        collision_rows(),
    )
    drm = row_for(composition, KNOWN_KATI_TARGET)
    assert drm["disposition"] == "REUSE_C1_IDENTICAL"

    with tempfile.TemporaryDirectory() as td:
        out = Path(td) / "native-packages.mk"
        mod.write_packages(out, imports)
        text = out.read_text(encoding="utf-8")
        assert "PRODUCT_PACKAGES +=" in text
        assert drm["module"] not in text
        assert text.count("SableN1IC2NativeM") == 32


def main() -> int:
    test_known_kati_collision_reused()
    test_graph_collision_absent_from_c1_fails_closed()
    test_different_baseline_fails_closed()
    test_generated_packages_excludes_reused_collision()

    print(
        "N1I_C2_NATIVE_INSTALL_PLAN_KNOWN_KATI_COLLISION_REUSE=PASS "
        f"target={KNOWN_KATI_TARGET} id={mutation_id_for(KNOWN_KATI_TARGET)}"
    )
    print("N1I_C2_NATIVE_INSTALL_PLAN_GRAPH_COLLISION_FAIL_CLOSED=PASS")
    print("N1I_C2_NATIVE_INSTALL_PLAN_DIFFERENT_FAIL_CLOSED=PASS")
    print("N1I_C2_NATIVE_INSTALL_PLAN_GENERATED_PACKAGES=PASS")
    print("N1I_C2_NATIVE_INSTALL_PLAN_TEST=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
