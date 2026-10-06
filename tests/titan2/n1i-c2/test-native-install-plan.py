#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "build/titan2/plan-n1i-c2-native-install.py"
A4 = ROOT / "product/titan2/n1i-c1/a4-native-superset.txt"
DECISIONS = ROOT / "product/titan2/n1i-c2/platform-native-reuse.tsv"

spec = importlib.util.spec_from_file_location("n1i_c2_native_plan", TOOL)
assert spec is not None and spec.loader is not None
mod = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)

KNOWN_KATI_TARGET = "/system/lib64/android.hardware.drm-V1-ndk.so"
KNOWN_KATI_ID = "M029"


def targets() -> list[str]:
    rows = [
        line.strip()
        for line in A4.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
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
    parsed = mod.platform_reuse_decisions(DECISIONS)
    assert parsed == mod.EXPECTED_PLATFORM_REUSE
    assert len(parsed) == 5
    return parsed


def probe_rows() -> list[dict[str, str]]:
    reviewed = decisions()
    out: list[dict[str, str]] = []
    for index, target in enumerate(targets(), start=7):
        mid = f"M{index:03d}"
        key = (mid, target)
        status = "ABSENT"
        c1_sha = "-"
        c1_path = "-"
        if key in reviewed:
            status = "PRESENT"
            c1_sha = different_sha(index)
            c1_path = target
        out.append(
            {
                "id": mid,
                "target": target,
                "module": f"SableN1IC2Native{mid}",
                "stock_sha256": stock_sha(index),
                "c1_status": status,
                "c1_sha256": c1_sha,
                "c1_image_path": c1_path,
            }
        )
    return out


def collision_rows() -> list[dict[str, str]]:
    reviewed = decisions()
    out: list[dict[str, str]] = []
    for index, target in enumerate(targets(), start=7):
        mid = f"M{index:03d}"
        module = f"SableN1IC2Native{mid}"
        key = (mid, target)
        if key in reviewed:
            state = "COLLISION"
            count = 2
            owners = f"{module};{reviewed[key]}"
        else:
            state = "SINGLE_OWNER"
            count = 1
            owners = module
        out.append(
            {
                "target": target,
                "state": state,
                "rule_count": str(count),
                "final_path": f"/out/{target.lstrip('/')}",
                "owner_hints": owners,
            }
        )
    return out


def row_for_target(rows: list[dict[str, str]], target: str) -> dict[str, str]:
    return next(row for row in rows if row["target"] == target)


def test_five_reviewed_platform_collisions_reused() -> None:
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
        row = row_for_target(composition, target)
        assert row["id"] == mid
        assert row["disposition"] == "REUSE_C1_PLATFORM_DIFFERENT"
        assert row["install_graph_state"] == "COLLISION"
        assert row["install_graph_rule_count"] == "2"
        assert owner in row["install_graph_owner_hints"]
        assert row["module"] not in imports

    kati = row_for_target(composition, KNOWN_KATI_TARGET)
    assert kati["id"] == KNOWN_KATI_ID
    assert kati["disposition"] == "REUSE_C1_PLATFORM_DIFFERENT"


def test_generated_packages_are_exact_28_imports() -> None:
    composition, imports = mod.plan(
        probe_rows(),
        set(targets()),
        collision_rows(),
        decisions(),
    )
    with tempfile.TemporaryDirectory() as td:
        out = Path(td) / "native-packages.mk"
        mod.write_packages(out, imports)
        text = out.read_text(encoding="utf-8")
        assert text.count("SableN1IC2NativeM") == 28
        for mid, _target in decisions():
            assert f"SableN1IC2Native{mid}" not in text


def test_platform_owner_mismatch_fails_closed() -> None:
    rows = probe_rows()
    collisions = collision_rows()
    row = row_for_target(collisions, KNOWN_KATI_TARGET)
    row["owner_hints"] = f"SableN1IC2Native{KNOWN_KATI_ID};wrong.platform.owner"
    try:
        mod.plan(rows, set(targets()), collisions, decisions())
    except mod.PlanError as exc:
        text = str(exc)
        assert f"{KNOWN_KATI_ID}:{KNOWN_KATI_TARGET}" in text
        assert "expected_platform_owner=android.hardware.drm-V1-ndk" in text
    else:
        raise AssertionError("wrong platform owner was accepted")


def test_platform_reuse_target_absent_fails_closed() -> None:
    rows = probe_rows()
    target = KNOWN_KATI_TARGET
    row = row_for_target(rows, target)
    row["c1_status"] = "ABSENT"
    row["c1_sha256"] = "-"
    row["c1_image_path"] = "-"
    try:
        mod.plan(rows, set(targets()), collision_rows(), decisions())
    except mod.PlanError as exc:
        text = str(exc)
        assert f"{KNOWN_KATI_ID}:{KNOWN_KATI_TARGET}" in text
        assert "graph_rules=2" in text
    else:
        raise AssertionError("reviewed platform target absent from C1 was accepted")


def test_unreviewed_c1_different_fails_closed() -> None:
    rows = probe_rows()
    collisions = collision_rows()
    target = targets()[0]
    mid = id_for_target(target)
    row = row_for_target(rows, target)
    row["c1_status"] = "PRESENT"
    row["c1_sha256"] = "f" * 64
    row["c1_image_path"] = target
    collision = row_for_target(collisions, target)
    collision["state"] = "COLLISION"
    collision["rule_count"] = "2"
    collision["owner_hints"] = f"SableN1IC2Native{mid};unexpected.platform.owner"
    try:
        mod.plan(rows, set(targets()), collisions, decisions())
    except mod.PlanError as exc:
        text = str(exc)
        assert f"{mid}:{target}" in text
        assert "expected_platform_owner=NONE" in text
    else:
        raise AssertionError("unreviewed C1-different target was accepted")


def main() -> int:
    test_five_reviewed_platform_collisions_reused()
    test_generated_packages_are_exact_28_imports()
    test_platform_owner_mismatch_fails_closed()
    test_platform_reuse_target_absent_fails_closed()
    test_unreviewed_c1_different_fails_closed()

    print(
        "N1I_C2_NATIVE_INSTALL_PLAN_PLATFORM_REUSE_SET=PASS "
        "count=5 imports=28"
    )
    print(
        "N1I_C2_NATIVE_INSTALL_PLAN_KNOWN_KATI_COLLISION_PLATFORM_REUSE=PASS "
        f"id={KNOWN_KATI_ID} target={KNOWN_KATI_TARGET}"
    )
    print("N1I_C2_NATIVE_INSTALL_PLAN_PLATFORM_OWNER_FAIL_CLOSED=PASS")
    print("N1I_C2_NATIVE_INSTALL_PLAN_PLATFORM_ABSENT_FAIL_CLOSED=PASS")
    print("N1I_C2_NATIVE_INSTALL_PLAN_UNREVIEWED_DIFFERENT_FAIL_CLOSED=PASS")
    print("N1I_C2_NATIVE_INSTALL_PLAN_GENERATED_PACKAGES=PASS count=28")
    print("N1I_C2_NATIVE_INSTALL_PLAN_TEST=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
