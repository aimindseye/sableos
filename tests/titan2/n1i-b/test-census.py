#!/usr/bin/env python3
"""N1I-B2 interface / reverse vendor->system census self-test (synthetic fixtures).

Prints CASE<TAB>census<TAB>id<TAB>PASS|FAIL<TAB>detail ; exit 0 only if every case passes.
"""
from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = Path(subprocess.check_output(["git", "-C", str(HERE), "rev-parse", "--show-toplevel"], text=True).strip())
TOOL = ROOT / "build/titan2/n1i-b2-census.py"
FX = HERE / "fixtures/census"
RT = FX / "runtime"
FAILS = 0


def case(cid: str, ok: bool, detail: str = "") -> None:
    global FAILS
    print(f"CASE\tcensus\t{cid}\t{'PASS' if ok else 'FAIL'}\t{detail}".replace("\n", " ")[:500])
    FAILS += 0 if ok else 1


def run(out: Path, *extra, stock=FX / "stock", c3a=FX / "c3a", runtime=True, logs=("c3a-logcat-wait.txt",)):
    args = [sys.executable, TOOL, "--stock-root", stock, "--c3a-root", c3a, "--out", out, *extra]
    if runtime:
        args += ["--stock-service-list", RT / "stock-service-list.txt", "--c3a-service-list", RT / "c3a-service-list.txt",
                 "--stock-lshal", RT / "stock-lshal.txt", "--c3a-lshal", RT / "c3a-lshal.txt"]
    for lg in logs:
        args += ["--c3a-log", RT / lg]
    if logs:
        args += ["--c3a-ps", RT / "c3a-ps.txt"]
    r = subprocess.run([str(x) for x in args], capture_output=True, text=True)
    edges, env = {}, {}
    if r.returncode == 0:
        lines = (out / "CENSUS_EDGES.tsv").read_text().splitlines()
        head = lines[0].split("\t")
        edges = {d["edge_id"]: d for d in (dict(zip(head, l.split("\t"))) for l in lines[1:])}
        env = dict(l.split("=", 1) for l in (out / "CENSUS_SUMMARY.env").read_text().splitlines())
    return r, edges, env


def st(edges: dict, eid: str) -> str:
    return edges.get(eid, {}).get("status", "NOT_PRESENT")


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)
        r, e, env = run(td / "full")
        case("census_exit0", r.returncode == 0, r.stderr[-300:])

        # 1. vendor property consumer with a system producer
        case("vendor_property_consumer_system_producer", st(e, "PROPERTY:sys.mtk.ready") == "MISSING_ON_C3A_CANDIDATE"
             and "stock/system/etc/init/mtk_system.rc" in e["PROPERTY:sys.mtk.ready"]["stock_producer"]
             and e["PROPERTY:sys.mtk.ready"]["consumer_evidence_strength"] == "PARSED_DECLARATION", "")
        case("system_build_prop_producer", st(e, "PROPERTY:ro.mtk.sys.flag") == "MISSING_ON_C3A_CANDIDATE"
             and "stock/system/build.prop" in e["PROPERTY:ro.mtk.sys.flag"]["stock_producer"], "")
        # 2. vendor self-produced property must NOT become a missing system edge
        case("vendor_self_produced_property_not_system_edge", st(e, "PROPERTY:vendor.ril.ready") == "VENDOR_SELF_PROVIDED"
             and e["PROPERTY:vendor.ril.ready"]["counted_as_vendor_expected_system_edge"] == "NO", "")
        case("code_produced_property_not_claimed", st(e, "PROPERTY:sys.boot_completed") == "NO_SYSTEM_PRODUCER_ON_STOCK"
             and e["PROPERTY:sys.boot_completed"]["counted_as_vendor_expected_system_edge"] == "NO", "")
        # 3. service present on stock, absent on C3A (runtime)
        case("service_present_stock_absent_c3a", e.get("BINDER_SERVICE:mtk.sys.svc", {}).get("stock_runtime") == "PRESENT"
             and e["BINDER_SERVICE:mtk.sys.svc"]["c3a_runtime"] == "ABSENT", "")
        case("service_present_on_both_satisfied", st(e, "BINDER_SERVICE:phone") == "SATISFIED_ON_C3A", "")
        case("vendor_registered_service_self_provided", st(e, "BINDER_SERVICE:vendor.mtk.own") == "VENDOR_SELF_PROVIDED", "")
        # 4. mere binary string: candidate only, never counted, never proven
        case("binary_string_candidate_only", st(e, "BINDER_SERVICE:mtkradioex_sys") == "MISSING_ON_C3A_STRING_ONLY_CANDIDATE"
             and e["BINDER_SERVICE:mtkradioex_sys"]["consumer_evidence_strength"] == "STRING_ONLY"
             and e["BINDER_SERVICE:mtkradioex_sys"]["counted_as_vendor_expected_system_edge"] == "NO", "")
        case("string_only_cannot_prove_even_with_runtime_absence",
             e.get("BINDER_SERVICE:mtkradioex_sys", {}).get("c3a_runtime") == "ABSENT"
             and e["BINDER_SERVICE:mtkradioex_sys"]["stock_runtime"] == "PRESENT"
             and st(e, "BINDER_SERVICE:mtkradioex_sys") != "MTK_SYSTEM_EDGE_PROVEN"
             and env.get("N1I_B2_CENSUS_STRING_ONLY_CAN_PROVE") == "NO", "")
        # 5. VINTF provided (device manifest) vs required (device compatibility matrix)
        vprov = (td / "full/VINTF_PROVIDED_BY_VENDOR.tsv").read_text()
        case("vintf_device_manifest_is_vendor_provided_not_edge", "vendor.mediatek.hardware.mtkradioex" in vprov
             and not any("mtkradioex" in k and k.startswith("VINTF_REQUIREMENT") for k in e), "")
        case("vintf_required_missing_on_c3a",
             st(e, "VINTF_REQUIREMENT:vendor.mediatek.framework.mtkservice/IMtkFw/default") == "MISSING_ON_C3A_CANDIDATE", "")
        case("vintf_required_satisfied",
             st(e, "VINTF_REQUIREMENT:android.frameworks.sensorservice/ISensorManager/default") == "SATISFIED_ON_C3A", "")
        case("vintf_optional_requirement_not_counted",
             st(e, "VINTF_REQUIREMENT:android.frameworks.stats/IStats/default") == "MISSING_ON_C3A_OPTIONAL", "")
        freq = (td / "full/FRAMEWORK_REQUIRES_FROM_VENDOR.tsv").read_text()
        case("framework_matrix_context_only", "android.hardware.radio.ims" in freq
             and not any("android.hardware.radio.ims" in k for k in e), "")
        case("framework_type_matrix_on_vendor_side_not_edge", not any("android.hardware.synthetic.odm" in k for k in e), "")
        # 6. runtime service confirmation
        case("runtime_vendor_wait_proves_edge", st(e, "BINDER_SERVICE:mtk.sys.svc") == "MTK_SYSTEM_EDGE_PROVEN"
             and "c3a-logcat-wait.txt:2" in e["BINDER_SERVICE:mtk.sys.svc"]["vendor_wait_on_c3a"], "")
        case("runtime_vendor_wait_hidl", st(e, "AIDL_HIDL_INTERFACE:vendor.mediatek.framework.hw::IMtkFwHw")
             == "MTK_SYSTEM_EDGE_PROVEN", "")
        case("non_vendor_wait_ignored", env.get("N1I_B2_CENSUS_UNATTRIBUTED_WAITS_IGNORED") == "1"
             and st(e, "BINDER_SERVICE:phone") == "SATISFIED_ON_C3A", "")
        case("counts_derived_from_edges", env.get("N1I_B2_VENDOR_EXPECTED_SYSTEM_EDGE_COUNT") == str(
            sum(1 for d in e.values() if d["counted_as_vendor_expected_system_edge"] == "YES"))
             and env.get("N1I_B2_MTK_SYSTEM_EDGE_PROVEN_COUNT") == "2", env.get("N1I_B2_VENDOR_EXPECTED_SYSTEM_EDGE_COUNT"))
        case("vendor_tree_identity_checked", env.get("N1I_B2_CENSUS_VENDOR_TREES_IDENTICAL") == "YES", "")
        case("runtime_proof_requires_vendor_identity",
             env.get("N1I_B2_CENSUS_RUNTIME_PROOF_VENDOR_IDENTITY_REQUIRED") == "YES", "")
        case("every_edge_has_strength_and_one_status", all(d["consumer_evidence_strength"] != "-" and d["status"] for d in e.values()), "")

        r, e2, _ = run(td / "nolog", logs=())
        case("runtime_absence_without_wait_is_confirmed_not_proven",
             st(e2, "BINDER_SERVICE:mtk.sys.svc") == "MISSING_ON_C3A_RUNTIME_CONFIRMED", st(e2, "BINDER_SERVICE:mtk.sys.svc"))
        r, e3, _ = run(td / "static", runtime=False, logs=())
        case("static_only_absence_is_candidate", st(e3, "BINDER_SERVICE:mtk.sys.svc") == "MISSING_ON_C3A_CANDIDATE"
             and e3["BINDER_SERVICE:mtk.sys.svc"]["c3a_runtime"] == "NOT_PROVIDED", st(e3, "BINDER_SERVICE:mtk.sys.svc"))
        r, e4, _ = run(td / "strwait", logs=("c3a-logcat-wait.txt", "c3a-logcat-wait-string.txt"))
        case("string_edge_with_runtime_wait_proven_by_runtime_not_string",
             st(e4, "BINDER_SERVICE:mtkradioex_sys") == "MTK_SYSTEM_EDGE_PROVEN"
             and e4["BINDER_SERVICE:mtkradioex_sys"]["consumer_evidence_strength"] == "RUNTIME_OBSERVED", "")

        # Vendor identity is a prerequisite for the strongest runtime proof.
        c3b = td / "c3a-other-vendor"
        shutil.copytree(FX / "c3a", c3b)
        (c3b / "vendor/build.prop").write_text("ro.vendor.build.fingerprint=Synthetic/other\n")
        r, e5, env5 = run(td / "vdiff", c3a=c3b)
        case("vendor_tree_mismatch_reported", env5.get("N1I_B2_CENSUS_VENDOR_TREES_IDENTICAL") == "NO", "")
        case("vendor_tree_mismatch_blocks_proven_edge",
             env5.get("N1I_B2_MTK_SYSTEM_EDGE_PROVEN_COUNT") == "0"
             and st(e5, "BINDER_SERVICE:mtk.sys.svc") == "MISSING_ON_C3A_RUNTIME_CONFIRMED"
             and st(e5, "AIDL_HIDL_INTERFACE:vendor.mediatek.framework.hw::IMtkFwHw")
             != "MTK_SYSTEM_EDGE_PROVEN", "")

        c3nov = td / "c3a-no-vendor"
        shutil.copytree(FX / "c3a", c3nov)
        shutil.rmtree(c3nov / "vendor")
        r, e6, env6 = run(td / "vabsent", c3a=c3nov)
        case("c3a_vendor_absent_reported",
             env6.get("N1I_B2_CENSUS_VENDOR_TREES_IDENTICAL") == "C3A_VENDOR_NOT_PROVIDED", "")
        case("c3a_vendor_absent_blocks_proven_edge",
             env6.get("N1I_B2_MTK_SYSTEM_EDGE_PROVEN_COUNT") == "0"
             and st(e6, "BINDER_SERVICE:mtk.sys.svc") == "MISSING_ON_C3A_RUNTIME_CONFIRMED", "")

        # fail closed
        bad = td / "badvintf"
        shutil.copytree(FX / "stock", bad)
        (bad / "vendor/etc/vintf/manifest.xml").write_text('<?xml version="1.0"?><!DOCTYPE m [<!ENTITY x "y">]><manifest type="device"/>')
        r, _, _ = run(td / "o1", stock=bad)
        case("vintf_doctype_refused", r.returncode == 2 and not (td / "o1").exists(), f"rc={r.returncode}")
        bad2 = td / "badtype"
        shutil.copytree(FX / "stock", bad2)
        (bad2 / "vendor/etc/vintf/manifest.xml").write_text('<manifest version="1.0" type="mystery"></manifest>')
        r, _, _ = run(td / "o2", stock=bad2)
        case("vintf_unknown_type_refused", r.returncode == 2, f"rc={r.returncode}")
        r = subprocess.run([sys.executable, str(TOOL), "--stock-root", str(td), "--c3a-root", str(FX / "c3a"),
                            "--out", str(td / "o3")], capture_output=True, text=True)
        case("missing_partitions_refused", r.returncode == 2 and not (td / "o3").exists(), f"rc={r.returncode}")
        r, _, _ = run(td / "full")
        case("nonempty_output_refused", r.returncode == 2, f"rc={r.returncode}")
    return 1 if FAILS else 0


if __name__ == "__main__":
    raise SystemExit(main())
