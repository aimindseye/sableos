#!/usr/bin/env python3
from __future__ import annotations

import csv
import importlib.util
import tempfile
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / "build/titan2/prepare-n1i-c2-cellular-mvp-mutation-manifest.py"

spec = importlib.util.spec_from_file_location("n1i_c2_manifest", TOOL)
assert spec is not None and spec.loader is not None
mod = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = mod
spec.loader.exec_module(mod)


def write_env(path: Path, values: dict[str, str]) -> None:
    path.write_text("".join(f"{k}={v}\n" for k, v in values.items()), encoding="utf-8")


def write_tsv(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as fp:
        w = csv.DictWriter(fp, fieldnames=fields, delimiter="\t", lineterminator="\n")
        w.writeheader()
        w.writerows(rows)


def native_fixture(root: Path, role: str, rows: list[dict[str, str]]) -> Path:
    d = root / role / "native"
    d.mkdir(parents=True)
    write_env(
        d / "NATIVE_SUMMARY.env",
        {"N1I_B2_NATIVE_APK_SHA256": mod.OEM_IMS_SHA256},
    )
    fields = [
        "library", "status", "partition", "provider_class", "path", "sha256",
        "needed", "admitted_by", "namespace_visibility", "evidence_strength",
    ]
    write_tsv(d / "NATIVE_CLOSURE.tsv", fields, rows)
    return d


def base_row(
    name: str,
    status: str,
    partition: str,
    *,
    visibility: str,
    sha: str = "a" * 64,
) -> dict[str, str]:
    return {
        "library": name,
        "status": status,
        "partition": partition,
        "provider_class": "fixture",
        "path": f"/fixture/{partition}/{name}",
        "sha256": sha,
        "needed": "NONE",
        "admitted_by": "DEX_LOAD",
        "namespace_visibility": visibility,
        "evidence_strength": "DEX_CALLSITE",
    }


def test_native_close_once(tmp: Path) -> None:
    stock_rows = [
        base_row("libneed.so", "FOUND", "system_ext", visibility="EXPLICIT"),
        base_row("libalready.so", "FOUND", "system", visibility="EXPLICIT", sha="b" * 64),
        base_row("libvendor.so", "FOUND", "vendor", visibility="EXPLICIT", sha="c" * 64),
    ]
    c3a_rows = [
        base_row("libneed.so", "NOT_FOUND", "NOT_FOUND", visibility="-", sha="-"),
        base_row("libalready.so", "FOUND", "system", visibility="EXPLICIT", sha="b" * 64),
        base_row("libvendor.so", "NOT_FOUND", "NOT_FOUND", visibility="-", sha="-"),
    ]
    stock = native_fixture(tmp, "stock", stock_rows)
    c3a = native_fixture(tmp, "c3a", c3a_rows)
    rows, blockers = mod.native_closure(stock, c3a)
    assert blockers == []
    assert [r["library"] for r in rows] == ["libneed.so"]
    assert rows[0]["target"] == "/system_ext/lib64/libneed.so"
    assert rows[0]["decision"] == "ADMIT_EXACT_STOCK_ONLY_SYSTEM_DEPENDENCY"


def test_native_namespace_fail_closed(tmp: Path) -> None:
    stock_rows = [
        base_row("libgap.so", "FOUND", "system_ext", visibility="EXPLICIT"),
    ]
    c3a_rows = [
        base_row(
            "libgap.so",
            "FILE_PRESENT_NAMESPACE_UNPROVEN",
            "system_ext",
            visibility="UNPROVEN",
        ),
    ]
    stock = native_fixture(tmp, "stock", stock_rows)
    c3a = native_fixture(tmp, "c3a", c3a_rows)
    rows, blockers = mod.native_closure(stock, c3a)
    assert rows == []
    assert blockers == ["libgap.so:FILE_PRESENT_NAMESPACE_UNPROVEN"]


def test_vendor_ua_attribution(tmp: Path) -> None:
    n1i = tmp / "n1i-a"
    n1i.mkdir()
    write_tsv(
        n1i / "a5-init-services.tsv",
        [
            "service", "exec", "partition", "user", "group", "seclabel", "class",
            "start_mode", "restart", "sockets", "triggers", "boot_completed_dep",
            "sim_nvram_modem_dep",
        ],
        [
            {
                "service": "titan2_volte_clientapi_ua",
                "exec": "/vendor/bin/volte_ua",
                "partition": "vendor",
                "user": "radio",
                "group": "radio",
                "seclabel": "u:r:vendor_ua:s0",
                "class": "main",
                "start_mode": "disabled",
                "restart": "-",
                "sockets": "-",
                "triggers": "property:vendor.mtk.ims.ready=1",
                "boot_completed_dep": "NO",
                "sim_nvram_modem_dep": "NO",
            },
            {
                "service": "unrelated",
                "exec": "/vendor/bin/unrelated",
                "partition": "vendor",
                "user": "root",
                "group": "root",
                "seclabel": "-",
                "class": "main",
                "start_mode": "class-start",
                "restart": "-",
                "sockets": "-",
                "triggers": "-",
                "boot_completed_dep": "NO",
                "sim_nvram_modem_dep": "NO",
            },
        ],
    )
    write_tsv(
        n1i / "a5-trigger-property-setters.tsv",
        ["property", "set_by"],
        [
            {
                "property": "vendor.mtk.ims.ready",
                "set_by": "SYSTEM_SIDE_OEM_IMS_CODE",
            }
        ],
    )
    rows = mod.vendor_ua_inventory(n1i)
    assert len(rows) == 1
    assert rows[0]["service"] == "titan2_volte_clientapi_ua"
    assert rows[0]["decision"] == "ALLOW_BOUNDED_START_IF_NOT_READY"
    assert rows[0]["system_attributed_trigger_properties"] == "vendor.mtk.ims.ready"


def test_b2_role_classification() -> None:
    assert mod.classify_b2_candidate(Path("/evidence/stock/native")) == "stock"
    assert mod.classify_b2_candidate(Path("/evidence/c3a/native")) == "c3a"
    assert mod.classify_b2_candidate(Path("/evidence/unknown/native")) is None


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        test_native_close_once(root / "case1")
        test_native_namespace_fail_closed(root / "case2")
        test_vendor_ua_attribution(root / "case3")
    test_b2_role_classification()
    print("N1I_C2_CELLULAR_MVP_MANIFEST_TEST_NATIVE_CLOSE_ONCE=PASS")
    print("N1I_C2_CELLULAR_MVP_MANIFEST_TEST_NAMESPACE_FAIL_CLOSED=PASS")
    print("N1I_C2_CELLULAR_MVP_MANIFEST_TEST_VENDOR_UA_ATTRIBUTION=PASS")
    print("N1I_C2_CELLULAR_MVP_MANIFEST_TEST_B2_ROLE_DISCOVERY=PASS")
    print("N1I_C2_CELLULAR_MVP_MANIFEST_TEST=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
