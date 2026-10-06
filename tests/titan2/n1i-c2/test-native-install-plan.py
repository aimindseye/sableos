#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "build/titan2/plan-n1i-c2-native-install.py"
A4 = ROOT / "product/titan2/n1i-c1/a4-native-superset.txt"

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
    return rows


def probe_rows(
    *,
    identical_target: str | None = None,
    different_target: str | None = None,
) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    for index, target in enumerate(targets(), start=7):
        mid = f"M{index:03d}"
        stock = f"{index:064x}"[-64:]
        status = "ABSENT"
        c1_sha = "-"
        c1_path = "-"
        if target == identical_target:
            status = "PRESENT"
            c1_sha = stock
            c1_path = target
        if target == different_target:
            status = "PRESENT"
            c1_sha = "f" * 64 if stock != "f" * 64 else "e" * 64
            c1_path = target
        out.append({
            "id": mid,
            "target": target,
            "module": f"SableN1IC2Native{mid}",
            "stock_sha256": stock,
            "c1_status": status,
            "c1_sha256": c1_sha,
            "c1_image_path": c1_path,
        })
    return out


def test_known_kati_collision_is_reused() -> None:
    drm = "/system/lib64/android.hardware.drm-V1-ndk.so"
    rows = probe_rows(identical_target=drm)
    composition, imports = mod.plan(rows, set(targets()))

    drm_row = next(row for row in composition if row["target"] == drm)
    assert drm_row["disposition"] == "REUSE_C1_IDENTICAL"
    assert drm_row["module"] not in imports
    assert len(imports) == 32


def test_absent_target_imported() -> None:
    rows = probe_rows()
    composition, imports = mod.plan(rows, set(targets()))
    assert len(imports) == 33
    assert all(row["disposition"] == "IMPORT_FROZEN_STOCK" for row in composition)


def test_different_baseline_fails_closed() -> None:
    drm = "/system/lib64/android.hardware.drm-V1-ndk.so"
    rows = probe_rows(different_target=drm)
    try:
        mod.plan(rows, set(targets()))
    except mod.PlanError as exc:
        text = str(exc)
        assert "baseline_different_requires_explicit_decision=" in text
        assert drm in text
    else:
        raise AssertionError("different baseline native was silently overridden")


def test_generated_packages_exclude_reuse() -> None:
    drm = "/system/lib64/android.hardware.drm-V1-ndk.so"
    composition, imports = mod.plan(
        probe_rows(identical_target=drm),
        set(targets()),
    )
    del composition
    with tempfile.TemporaryDirectory() as td:
        out = Path(td) / "native-packages.mk"
        mod.write_packages(out, imports)
        text = out.read_text(encoding="utf-8")
        assert "PRODUCT_PACKAGES +=" in text
        assert "SableN1IC2NativeM029" not in text
        assert text.count("SableN1IC2NativeM") == 32


def main() -> int:
    test_known_kati_collision_is_reused()
    test_absent_target_imported()
    test_different_baseline_fails_closed()
    test_generated_packages_exclude_reuse()
    print("N1I_C2_NATIVE_INSTALL_PLAN_KNOWN_KATI_COLLISION_REUSE=PASS")
    print("N1I_C2_NATIVE_INSTALL_PLAN_ABSENT_IMPORT=PASS")
    print("N1I_C2_NATIVE_INSTALL_PLAN_DIFFERENT_FAIL_CLOSED=PASS")
    print("N1I_C2_NATIVE_INSTALL_PLAN_GENERATED_PACKAGES=PASS")
    print("N1I_C2_NATIVE_INSTALL_PLAN_TEST=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
