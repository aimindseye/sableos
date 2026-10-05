#!/usr/bin/env python3
from __future__ import annotations

import csv
import importlib.util
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "build/titan2/materialize-n1i-c2-cellular-mvp-stock.py"

spec = importlib.util.spec_from_file_location("n1i_c2_materialize", TOOL)
assert spec is not None and spec.loader is not None
mod = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)


def write_env(path: Path, values: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "".join(f"{key}={value}\n" for key, value in values.items()),
        encoding="utf-8",
    )


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as fp:
        return list(csv.DictReader(fp, delimiter="\t"))


def write_tsv(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.DictWriter(fp, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def seal(root: Path) -> None:
    files = sorted(p for p in root.rglob("*") if p.is_file() and p.name != "SHA256SUMS.txt")
    with (root / "SHA256SUMS.txt").open("w", encoding="utf-8") as fp:
        for path in files:
            fp.write(f"{mod.sha256_file(path)}  {path.relative_to(root).as_posix()}\n")


def make_manifest(root: Path) -> tuple[Path, list[str]]:
    refs = [
        line.strip()
        for line in (ROOT / "product/titan2/n1i-c1/a4-native-superset.txt")
        .read_text(encoding="utf-8")
        .splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    assert len(refs) == 33

    manifest = root / "manifest"
    manifest.mkdir(parents=True)
    write_env(
        manifest / "CELLULAR_MVP_SUMMARY.env",
        {
            "N1I_C2_MANIFEST_OEM_IMS_SHA256": mod.EXPECTED_OEM_IMS_SHA,
            "N1I_C2_MANIFEST_NATIVE_AUTHORITY": "N1I_A_A4_ACCEPTED_SUPERSET",
            "N1I_C2_MANIFEST_N1I_A_A4_SHA256": mod.EXPECTED_A4_SHA,
            "N1I_C2_MANIFEST_NATIVE_IMPORT_COUNT": "33",
            "N1I_C2_MANIFEST_NATIVE_CLOSURE": "PASS_FINITE",
            "N1I_C2_MANIFEST_MUTATION_COUNT": "41",
            "N1I_C2_MANIFEST_MUTATION_SET": "PASS_FINITE_REVIEWABLE",
            "N1I_C2_CELLULAR_MVP_MUTATION_MANIFEST": "PASS",
        },
    )

    rows: list[dict[str, str]] = [
        {
            "id": "M001", "domain": "OEM_IMS", "action": "RETAIN",
            "target": "/system_ext/priv-app/ImsService/ImsService.apk",
            "source": "fixture", "sha256_or_blob": mod.EXPECTED_OEM_IMS_SHA,
            "basis": "fixture", "status": "PROPOSED_NOT_AUTHORIZED",
        },
        {
            "id": "M002", "domain": "JAVA", "action": "RETAIN",
            "target": "/system_ext/framework/mediatek-common.jar",
            "source": "fixture", "sha256_or_blob": mod.EXPECTED_COMMON_JAR_SHA,
            "basis": "fixture", "status": "PROPOSED_NOT_AUTHORIZED",
        },
        {
            "id": "M003", "domain": "JAVA", "action": "RETAIN",
            "target": "/system_ext/framework/mediatek-ims-base.jar",
            "source": "fixture", "sha256_or_blob": mod.EXPECTED_IMS_BASE_JAR_SHA,
            "basis": "fixture", "status": "PROPOSED_NOT_AUTHORIZED",
        },
    ]
    rows.extend([
        {
            "id": "M004", "domain": "FRAMEWORK", "action": "APPLY_PATCH",
            "target": "/fixture/android/frameworks/opt/telephony/src/java/com/android/internal/telephony/metrics/TelephonyMetrics.java",
            "source": "fixture", "sha256_or_blob": mod.EXPECTED_TMETRICS_PATCH_BLOB,
            "basis": "fixture", "status": "PROPOSED_NOT_AUTHORIZED",
        },
        {
            "id": "M005", "domain": "TELEPHONY", "action": "SET_PRODUCT_PROPERTY_FALSE",
            "target": "ro.telephony.block_binder_thread_on_incoming_calls",
            "source": "fixture", "sha256_or_blob": mod.EXPECTED_IMS_CALL_TRACKER_BLOB,
            "basis": "fixture", "status": "PROPOSED_NOT_AUTHORIZED",
        },
        {
            "id": "M006", "domain": "PHH", "action": "TITAN_GUARD_MTKMAL_IMS_DISABLE_BRANCH",
            "target": "/fixture/android/device/phh/treble/phh-on-boot.sh",
            "source": "fixture", "sha256_or_blob": mod.EXPECTED_PHH_ON_BOOT_BLOB,
            "basis": "fixture", "status": "PROPOSED_NOT_AUTHORIZED",
        },
    ])
    for index, target in enumerate(refs, start=7):
        rows.append({
            "id": f"M{index:03d}",
            "domain": "NATIVE",
            "action": "ADMIT_ACCEPTED_A4_COMPATIBILITY_SUPERSET",
            "target": target,
            "source": "fixture",
            "sha256_or_blob": "FREEZE_DURING_IMPLEMENTATION_MATERIALIZATION",
            "basis": "fixture",
            "status": "PROPOSED_NOT_AUTHORIZED",
        })
    rows.extend([
        {
            "id": "M040", "domain": "INTEGRATION",
            "action": "ADD_SABLE_TITAN_CELLULAR_INTEGRATION_PACKAGE",
            "target": "vendor/sable/titan2/n1i-c2", "source": "fixture",
            "sha256_or_blob": "-", "basis": "fixture",
            "status": "PROPOSED_NOT_AUTHORIZED",
        },
        {
            "id": "M041", "domain": "HEALER",
            "action": "SHIP_DISABLED_BY_DEFAULT",
            "target": "Sable Titan cellular integration package",
            "source": "fixture", "sha256_or_blob": "-", "basis": "fixture",
            "status": "PROPOSED_NOT_AUTHORIZED",
        },
    ])
    assert len(rows) == 41
    write_tsv(
        manifest / "CELLULAR_MVP_MUTATION_MANIFEST.tsv",
        ["id", "domain", "action", "target", "source", "sha256_or_blob", "basis", "status"],
        rows,
    )
    write_tsv(
        manifest / "CELLULAR_MVP_NATIVE_CLOSURE.tsv",
        ["library", "partition", "target", "stock_path", "sha256", "needed",
         "admitted_by", "evidence_strength", "c3a_status", "decision"],
        [
            {
                "library": Path(target).name,
                "partition": Path(target).parts[1],
                "target": target,
                "stock_path": "fixture",
                "sha256": "FREEZE_DURING_IMPLEMENTATION_MATERIALIZATION",
                "needed": "-",
                "admitted_by": "fixture",
                "evidence_strength": "fixture",
                "c3a_status": "ABSENT_BY_ACCEPTED_A4",
                "decision": "ADMIT_ACCEPTED_A4_COMPATIBILITY_SUPERSET",
            }
            for target in refs
        ],
    )
    seal(manifest)
    return manifest, refs


def make_replay(root: Path) -> Path:
    replay = root / "replay"
    write_env(
        replay / "n1i-a-v010014-oem-ims.env",
        {
            "N1I_A_V010014_OEM_IMS_DEPENDENCY_CLOSURE": "PASS",
            "N1I_A_NATIVE_DEPENDENCY_CLOSURE": "PASS",
            "OEM_IMS_APK_SHA256": mod.EXPECTED_OEM_IMS_SHA,
        },
    )
    rows = [
        ("stock-system.img", mod.EXPECTED_STOCK_SYSTEM_SHA, "-", "UNPINNED"),
        ("product.img", mod.EXPECTED_STOCK_PRODUCT_SHA, mod.EXPECTED_STOCK_PRODUCT_SHA, "YES"),
        ("system_ext.img", mod.EXPECTED_STOCK_SYSTEM_EXT_SHA, mod.EXPECTED_STOCK_SYSTEM_EXT_SHA, "YES"),
        ("vendor.img", mod.EXPECTED_STOCK_VENDOR_SHA, mod.EXPECTED_STOCK_VENDOR_SHA, "YES"),
        ("c3a-system.img", mod.EXPECTED_C3A_SHA, mod.EXPECTED_C3A_SHA, "YES"),
    ]
    write_tsv(
        replay / "inputs.tsv",
        ["input", "path", "sha256", "pinned", "match"],
        [
            {
                "input": name,
                "path": f"/fixture/{name}",
                "sha256": digest,
                "pinned": pinned,
                "match": match,
            }
            for name, digest, pinned, match in rows
        ],
    )
    (replay / "work/stock/system_img").mkdir(parents=True)
    (replay / "work/stock/system_ext").mkdir(parents=True)
    (replay / "work/stock/product").mkdir(parents=True)
    return replay


def test_manifest_shape(tmp: Path) -> None:
    manifest, refs = make_manifest(tmp)
    mutations, natives = mod.validate_manifest(manifest)
    planned = mod.expected_stock_rows(mutations, natives)
    assert len(refs) == 33
    assert len(planned) == 36
    assert [row["mutation_id"] for row in planned[:3]] == ["M001", "M002", "M003"]
    assert sum(row["kind"] == "NATIVE" for row in planned) == 33


def test_replay_authority(tmp: Path) -> None:
    replay = make_replay(tmp)
    mod.verify_replay(replay)


def test_partition_mapping_and_elf(tmp: Path) -> None:
    replay = make_replay(tmp)
    system = replay / "work/stock/system_img"
    system_ext = replay / "work/stock/system_ext"
    (system / "lib64").mkdir(parents=True)
    (system_ext / "lib64").mkdir(parents=True)

    sys_file = system / "lib64/libfixture.so"
    ext_file = system_ext / "lib64/libfixture_ext.so"

    elf = bytearray(64)
    elf[:4] = b"\x7fELF"
    elf[4] = 2
    elf[5] = 1
    elf[18:20] = (183).to_bytes(2, "little")
    sys_file.write_bytes(elf)
    ext_file.write_bytes(elf)

    part, resolved = mod.source_for_target(replay, "/system/lib64/libfixture.so")
    assert part == "system"
    assert resolved == sys_file.resolve()

    part, resolved = mod.source_for_target(
        replay, "/system_ext/lib64/libfixture_ext.so"
    )
    assert part == "system_ext"
    assert resolved == ext_file.resolve()

    assert mod.elf64_aarch64(sys_file) == ("ELF64", 183)



def test_manifest_semantic_drift_fails(tmp: Path) -> None:
    manifest, _ = make_manifest(tmp)
    rows = read_rows(manifest / "CELLULAR_MVP_MUTATION_MANIFEST.tsv")
    for row in rows:
        if row["id"] == "M006":
            row["action"] = "FIXTURE_UNSAFE"
            break
    write_tsv(
        manifest / "CELLULAR_MVP_MUTATION_MANIFEST.tsv",
        ["id", "domain", "action", "target", "source", "sha256_or_blob", "basis", "status"],
        rows,
    )
    seal(manifest)
    try:
        mod.validate_manifest(manifest)
    except mod.MaterializeError as exc:
        assert "mutation_semantic_drift=M006:action" in str(exc)
    else:
        raise AssertionError("semantic mutation drift was accepted")


def test_symlink_source_rejected(tmp: Path) -> None:
    replay = make_replay(tmp)
    system_ext = replay / "work/stock/system_ext"
    (system_ext / "lib64").mkdir(parents=True)
    real = system_ext / "lib64/libreal.so"
    real.write_bytes(b"fixture")
    link = system_ext / "lib64/libalias.so"
    link.symlink_to(real.name)
    try:
        mod.source_for_target(replay, "/system_ext/lib64/libalias.so")
    except mod.MaterializeError as exc:
        assert "stock_source_symlink=" in str(exc)
    else:
        raise AssertionError("stock symlink source was accepted")


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        test_manifest_shape(root / "case1")
        test_replay_authority(root / "case2")
        test_partition_mapping_and_elf(root / "case3")
        test_manifest_semantic_drift_fails(root / "case4")
        test_symlink_source_rejected(root / "case5")

    print("N1I_C2_MATERIALIZATION_TEST_MANIFEST_SHAPE=PASS")
    print("N1I_C2_MATERIALIZATION_TEST_REPLAY_AUTHORITY=PASS")
    print("N1I_C2_MATERIALIZATION_TEST_PARTITION_MAPPING=PASS")
    print("N1I_C2_MATERIALIZATION_TEST_ELF64_AARCH64=PASS")
    print("N1I_C2_MATERIALIZATION_TEST_SEMANTIC_DRIFT_FAIL_CLOSED=PASS")
    print("N1I_C2_MATERIALIZATION_TEST_SYMLINK_FAIL_CLOSED=PASS")
    print("N1I_C2_CELLULAR_MVP_MATERIALIZATION_TEST=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
