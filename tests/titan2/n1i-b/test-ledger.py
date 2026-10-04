#!/usr/bin/env python3
"""N1I-B2 evidence ledger self-tests using synthetic upstream outputs."""

from __future__ import annotations

import csv
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = Path(subprocess.check_output(["git", "-C", str(HERE), "rev-parse", "--show-toplevel"], text=True).strip())
TOOL = ROOT / "build/titan2/n1i-b2-ledger.py"
FAILS = 0
SHA = "a" * 64


def case(cid: str, ok: bool, detail: str = "") -> None:
    global FAILS
    print(f"CASE\tledger\t{cid}\t{'PASS' if ok else 'FAIL'}\t{detail}".replace("\n", " ")[:500])
    FAILS += 0 if ok else 1


def write_env(path: Path, rows: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(f"{k}={v}\n" for k, v in rows.items()), encoding="utf-8")


def write_tsv(path: Path, header: list[str], rows: list[list[str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as fp:
        w = csv.writer(fp, delimiter="\t", lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)


def set_env(path: Path, key: str, value: str) -> None:
    rows = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        k, v = line.split("=", 1)
        rows[k] = v
    rows[key] = value
    write_env(path, rows)


def fixture(root: Path) -> dict[str, Path]:
    d = {name: root / name for name in ("ms", "mc", "mcmp", "ns", "nc", "census")}
    for p in d.values():
        p.mkdir(parents=True)

    common_member = {
        "N1I_B2_MEMBERS_APP_SHA256": SHA,
        "N1I_B2_MEMBERS_DEXDUMP_ORACLE": "PASS(app:1)",
        "N1I_B2_MEMBERS_REQUIRED_LIBRARIES_UNAVAILABLE": "NONE",
        "N1I_B2_MEMBERS_UNRESOLVED": "0",
    }
    write_env(d["ms"] / "MEMBERS_SUMMARY.env", common_member)
    write_env(d["mc"] / "MEMBERS_SUMMARY.env", common_member)
    write_env(
        d["mcmp"] / "MEMBERS_COMPARE.env",
        {
            "N1I_B2_MEMBERS_COMPARE_APP_SHA256": SHA,
            "N1I_B2_MEMBERS_GAP_IS_IMPORT_AUTHORIZATION": "NO",
            "N1I_B2_CORE_AOSP_BINARY_IMPORT_AUTHORIZED": "NO",
        },
    )
    write_tsv(
        d["mcmp"] / "BEHAVIOR_GAP_CANDIDATES.tsv",
        [
            "caller", "ref_kind", "owner", "name", "descriptor", "stock_result", "c3a_result",
            "comparison", "candidate_class", "stock_provider", "c3a_detail",
        ],
        [[
            "Lapp/Main;", "invoke-virtual", "Lvendor/Mtk;", "call", "()V", "RESOLVED",
            "METHOD_MISSING", "STOCK_ONLY_RESOLVES",
            "AOSP_EQUIVALENT_WITH_BEHAVIOR_GAP(candidate)", "BOOT", "missing on C3A",
        ]],
    )

    native_common = {
        "N1I_B2_NATIVE_APK_SHA256": SHA,
        "N1I_B2_NATIVE_DEXDUMP_ORACLE": "PASS(app:1)",
        "N1I_B2_NATIVE_DYNAMIC_LOAD_UNRESOLVED": "0",
        "N1I_B2_NATIVE_REQUIRED_USES_NATIVE_LIBRARY_MISSING": "NONE",
        "N1I_B2_NATIVE_JNI_CANDIDATE_ONLY": "0",
        "N1I_B2_NATIVE_JNI_UNRESOLVED": "0",
        "N1I_B2_NATIVE_FILE_PRESENT_NAMESPACE_UNPROVEN": "NONE",
        "N1I_B2_NATIVE_NAMESPACE_VISIBILITY_INFERRED": "NO",
        "N1I_B2_NATIVE_KEYWORD_ROOTS_USED": "NO",
    }
    write_env(d["ns"] / "NATIVE_SUMMARY.env", native_common)
    write_env(d["nc"] / "NATIVE_SUMMARY.env", native_common)
    native_head = [
        "library", "status", "partition", "provider_class", "path", "sha256", "needed",
        "admitted_by", "evidence_strength",
    ]
    write_tsv(
        d["ns"] / "NATIVE_CLOSURE.tsv",
        native_head,
        [["libmtk.so", "FOUND", "system_ext", "SYSTEM_EXT_OR_PRODUCT", "/stock/libmtk.so",
          "b" * 64, "-", "LOADLIBRARY:site", "DEX_CALLSITE"]],
    )
    write_tsv(
        d["nc"] / "NATIVE_CLOSURE.tsv",
        native_head,
        [["libmtk.so", "NOT_FOUND", "NOT_FOUND", "-", "-", "-", "-", "LOADLIBRARY:site", "DEX_CALLSITE"]],
    )

    write_env(
        d["census"] / "CENSUS_SUMMARY.env",
        {
            "N1I_B2_CENSUS_VENDOR_TREES_IDENTICAL": "YES",
            "N1I_B2_CENSUS_RUNTIME_PROOF_VENDOR_IDENTITY_REQUIRED": "YES",
            "N1I_B2_CENSUS_UNMAPPED_POLICY_FINDS": "0",
            "N1I_B2_CENSUS_RUNTIME_INPUTS": "stock_service_list,c3a_service_list,stock_lshal,c3a_lshal",
            "N1I_B2_MTK_SYSTEM_EDGE_PROVEN_COUNT": "1",
        },
    )
    census_head = [
        "edge_id", "component_kind", "name", "status", "counted_as_vendor_expected_system_edge",
        "consumer_evidence_strength", "consumer_evidence", "stock_producer", "c3a_producer",
        "vendor_producer", "stock_runtime", "c3a_runtime", "vendor_wait_on_c3a", "optional",
    ]
    write_tsv(
        d["census"] / "CENSUS_EDGES.tsv",
        census_head,
        [
            ["BINDER_SERVICE:mtk.sys.svc", "BINDER_SERVICE", "mtk.sys.svc", "MTK_SYSTEM_EDGE_PROVEN",
             "YES", "RUNTIME_OBSERVED", "runtime_wait@x", "stock_context", "-", "-", "PRESENT", "ABSENT",
             "c3a.log:2", "NO"],
            ["PROPERTY:sys.mtk.flag", "PROPERTY", "sys.mtk.flag", "MISSING_ON_C3A_RUNTIME_CONFIRMED",
             "YES", "PARSED_DECLARATION", "vendor_init@x", "stock.rc", "-", "-", "PRESENT", "ABSENT",
             "-", "NO"],
            ["BINDER_SERVICE:mtk.string", "BINDER_SERVICE", "mtk.string",
             "MISSING_ON_C3A_STRING_ONLY_CANDIDATE", "NO", "STRING_ONLY", "vendor.bin", "stock_context",
             "-", "-", "PRESENT", "ABSENT", "-", "NO"],
        ],
    )
    return d


def invoke(d: dict[str, Path], out: Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        [
            sys.executable,
            str(TOOL),
            "--members-stock", str(d["ms"]),
            "--members-c3a", str(d["mc"]),
            "--members-compare", str(d["mcmp"]),
            "--native-stock", str(d["ns"]),
            "--native-c3a", str(d["nc"]),
            "--census", str(d["census"]),
            "--out", str(out),
        ],
        capture_output=True,
        text=True,
    )


def env(path: Path) -> dict[str, str]:
    return dict(line.split("=", 1) for line in path.read_text(encoding="utf-8").splitlines())


def copy_fixture(src: Path, dst: Path) -> dict[str, Path]:
    shutil.copytree(src, dst)
    return {name: dst / name for name in ("ms", "mc", "mcmp", "ns", "nc", "census")}


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        td = Path(tmp)
        base = td / "base"
        d = fixture(base)

        r = invoke(d, td / "out")
        case("baseline_exit0", r.returncode == 0, r.stderr[-300:])
        if r.returncode == 0:
            s = env(td / "out/LEDGER_SUMMARY.env")
            case("baseline_coverage_complete", s.get("N1I_B2_LEDGER_COVERAGE_COMPLETE") == "YES", str(s))
            case("baseline_next_step_review_only",
                 s.get("N1I_B2_LEDGER_NEXT_STEP") == "B3_MINIMAL_ADMISSION_REVIEW_ONLY", "")
            case("baseline_counts",
                 s.get("N1I_B2_LEDGER_PROVEN_EDGE_COUNT") == "1"
                 and s.get("N1I_B2_LEDGER_RUNTIME_CONFIRMED_COUNT") == "1"
                 and s.get("N1I_B2_LEDGER_CANDIDATE_COUNT") == "2"
                 and s.get("N1I_B2_LEDGER_STRING_ONLY_COUNT") == "1", str(s))
            case("no_import_or_device_authority",
                 s.get("N1I_B2_LEDGER_IMPORT_AUTHORIZED") == "NO"
                 and s.get("N1I_B2_LEDGER_DEVICE_MUTATION_AUTHORIZED") == "NO"
                 and s.get("N1I_B2_LEDGER_FLASH_AUTHORIZED") == "NO", "")
            ledger = (td / "out/DEPENDENCY_LEDGER.tsv").read_text(encoding="utf-8").splitlines()
            case("all_ledger_rows_import_no", all(line.split("\t")[8] == "NO" for line in ledger[1:]), "")
            matrix = (td / "out/COVERAGE_MATRIX.tsv").read_text(encoding="utf-8")
            case("verifier_limitation_explicit",
                 "MEMBERS_PROTECTED_TARGET_RECEIVER_VERIFIER\tLIMITATION\tNO" in matrix, "")

        x = copy_fixture(base, td / "hash-mismatch")
        set_env(x["nc"] / "NATIVE_SUMMARY.env", "N1I_B2_NATIVE_APK_SHA256", "c" * 64)
        r = invoke(x, td / "o-hash")
        case("cross_domain_apk_hash_mismatch_refused", r.returncode == 2 and not (td / "o-hash").exists(), r.stderr[-200:])

        x = copy_fixture(base, td / "auth")
        set_env(x["mcmp"] / "MEMBERS_COMPARE.env", "N1I_B2_MEMBERS_GAP_IS_IMPORT_AUTHORIZATION", "YES")
        r = invoke(x, td / "o-auth")
        case("upstream_import_authority_refused", r.returncode == 2 and not (td / "o-auth").exists(), r.stderr[-200:])

        x = copy_fixture(base, td / "vid")
        set_env(x["census"] / "CENSUS_SUMMARY.env", "N1I_B2_CENSUS_VENDOR_TREES_IDENTICAL", "NO")
        r = invoke(x, td / "o-vid")
        case("proven_edge_without_vendor_identity_refused",
             r.returncode == 2 and not (td / "o-vid").exists(), r.stderr[-200:])

        x = copy_fixture(base, td / "unknown")
        p = x["census"] / "CENSUS_EDGES.tsv"
        p.write_text(p.read_text(encoding="utf-8").replace(
            "MISSING_ON_C3A_RUNTIME_CONFIRMED", "MAGIC_PROVEN_STATUS", 1), encoding="utf-8")
        r = invoke(x, td / "o-unknown")
        case("unknown_status_refused", r.returncode == 2 and not (td / "o-unknown").exists(), r.stderr[-200:])

        x = copy_fixture(base, td / "duplicate")
        p = x["census"] / "CENSUS_EDGES.tsv"
        lines = p.read_text(encoding="utf-8").splitlines()
        p.write_text("\n".join(lines + [lines[1]]) + "\n", encoding="utf-8")
        r = invoke(x, td / "o-duplicate")
        case("duplicate_edge_refused", r.returncode == 2 and not (td / "o-duplicate").exists(), r.stderr[-200:])

        x = copy_fixture(base, td / "namespace")
        set_env(x["nc"] / "NATIVE_SUMMARY.env", "N1I_B2_NATIVE_FILE_PRESENT_NAMESPACE_UNPROVEN", "libmtk.so")
        p = x["nc"] / "NATIVE_CLOSURE.tsv"
        p.write_text(p.read_text(encoding="utf-8").replace(
            "libmtk.so\tNOT_FOUND\tNOT_FOUND", "libmtk.so\tFILE_PRESENT_NAMESPACE_UNPROVEN\tvendor", 1),
            encoding="utf-8")
        r = invoke(x, td / "o-namespace")
        s = env(td / "o-namespace/LEDGER_SUMMARY.env") if r.returncode == 0 else {}
        case("vendor_namespace_unproven_holds_progress",
             r.returncode == 0
             and s.get("N1I_B2_LEDGER_NAMESPACE_UNPROVEN_COUNT") == "1"
             and s.get("N1I_B2_LEDGER_COVERAGE_COMPLETE") == "NO"
             and s.get("N1I_B2_LEDGER_NEXT_STEP") == "HOLD_FOR_EVIDENCE", r.stderr[-200:])

        x = copy_fixture(base, td / "dynamic")
        set_env(x["nc"] / "NATIVE_SUMMARY.env", "N1I_B2_NATIVE_DYNAMIC_LOAD_UNRESOLVED", "1")
        r = invoke(x, td / "o-dynamic")
        s = env(td / "o-dynamic/LEDGER_SUMMARY.env") if r.returncode == 0 else {}
        case("dynamic_load_gap_holds_progress",
             r.returncode == 0 and s.get("N1I_B2_LEDGER_COVERAGE_COMPLETE") == "NO"
             and s.get("N1I_B2_LEDGER_NEXT_STEP") == "HOLD_FOR_EVIDENCE", "")

        x = copy_fixture(base, td / "memberlib")
        set_env(x["mc"] / "MEMBERS_SUMMARY.env", "N1I_B2_MEMBERS_REQUIRED_LIBRARIES_UNAVAILABLE", "com.mtk.req")
        r = invoke(x, td / "o-memberlib")
        s = env(td / "o-memberlib/LEDGER_SUMMARY.env") if r.returncode == 0 else {}
        case("required_member_library_gap_holds_progress",
             r.returncode == 0 and s.get("N1I_B2_LEDGER_COVERAGE_COMPLETE") == "NO", "")

        x = copy_fixture(base, td / "noidentity")
        set_env(x["census"] / "CENSUS_SUMMARY.env", "N1I_B2_CENSUS_VENDOR_TREES_IDENTICAL", "NO")
        set_env(x["census"] / "CENSUS_SUMMARY.env", "N1I_B2_MTK_SYSTEM_EDGE_PROVEN_COUNT", "0")
        p = x["census"] / "CENSUS_EDGES.tsv"
        p.write_text(p.read_text(encoding="utf-8").replace(
            "MTK_SYSTEM_EDGE_PROVEN", "MISSING_ON_C3A_RUNTIME_CONFIRMED", 1), encoding="utf-8")
        r = invoke(x, td / "o-noidentity")
        s = env(td / "o-noidentity/LEDGER_SUMMARY.env") if r.returncode == 0 else {}
        case("vendor_identity_gap_holds_progress_without_false_proof",
             r.returncode == 0 and s.get("N1I_B2_LEDGER_PROVEN_EDGE_COUNT") == "0"
             and s.get("N1I_B2_LEDGER_COVERAGE_COMPLETE") == "NO", "")

        x = copy_fixture(base, td / "runtime")
        set_env(x["census"] / "CENSUS_SUMMARY.env", "N1I_B2_CENSUS_RUNTIME_INPUTS",
                "stock_service_list,c3a_service_list")
        r = invoke(x, td / "o-runtime")
        s = env(td / "o-runtime/LEDGER_SUMMARY.env") if r.returncode == 0 else {}
        case("incomplete_runtime_presence_holds_progress",
             r.returncode == 0 and s.get("N1I_B2_LEDGER_COVERAGE_COMPLETE") == "NO", "")

        r = invoke(d, td / "out")
        case("nonempty_output_refused", r.returncode == 2, f"rc={r.returncode}")

    return 1 if FAILS else 0


if __name__ == "__main__":
    raise SystemExit(main())
