#!/usr/bin/env python3
"""N1I-B0/B1 timeline tool self-test (synthetic fixtures only).

Prints:  CASE<TAB>timeline<TAB>case_id<TAB>PASS|FAIL<TAB>detail ; exit 0 only if all pass.
"""
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = Path(subprocess.check_output(["git", "-C", str(HERE), "rev-parse", "--show-toplevel"], text=True).strip())
TOOL = ROOT / "build/titan2/n1i-b1-timeline.py"
FX = HERE / "fixtures"
TL, APN, B0 = FX / "timeline", FX / "apn", FX / "b0"
VFP = "Unihertz/Titan_2/Titan_2:14/UP1A.231005.007/V01.00.14:user/release-keys"
FAILS = 0


def case(cid: str, ok: bool, detail: str = "") -> None:
    global FAILS
    print(f"CASE\ttimeline\t{cid}\t{'PASS' if ok else 'FAIL'}\t{detail}".replace("\n", " "))
    FAILS += 0 if ok else 1


def run(*args) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(TOOL), *map(str, args)], capture_output=True, text=True)


def env(path: Path) -> dict:
    out = {}
    if path.is_file():
        for line in path.read_text().splitlines():
            k, _, v = line.partition("=")
            out[k] = v
    return out


def runspec(side, tray, label, f):
    return ["--run", f"side={side},tray={tray},label={label},path={TL / f}"]


def expect(cid: str, e: dict, want: dict) -> None:
    bad = {k: (e.get(k), v) for k, v in want.items() if e.get(k) != v}
    case(cid, not bad, f"mismatch={bad}" if bad else "")


def main() -> int:
    with tempfile.TemporaryDirectory() as td:
        td = Path(td)

        # ---------------- timeline
        r = run("timeline", *runspec("stock", 2, "s2", "stock-tray2-transient.logcat.txt"),
                *runspec("c3a", 2, "c2", "c3a-tray2-norecovery.logcat.txt"), "--out", td / "rec")
        e = env(td / "rec/TIMELINE_SUMMARY.env")
        case("tl_recovery_exit0", r.returncode == 0, r.stderr[-200:])
        expect("tl_stock_transient_recovery_vs_c3a_no_recovery_selects_step12", e, {
            "N1I_B1_REGISTRATION_FIRST_DIVERGENCE": "12:recovery_to_service",
            "N1I_B1_REGISTRATION_FIRST_DIVERGENCE_REASON": "CONSISTENT_ACROSS_C3A_RUNS"})
        div = (td / "rec/DIVERGENCE.tsv").read_text()
        case("tl_stock_transient_causes_not_a_divergence", "\t11\trejection_causes\t" not in div and
             "\t4\tdefault_data_setup\t" not in div, "ERROR_UNSPECIFIED/27 and data fail seen on stock too")
        expect("tl_transient_cause27_not_collapse", e, {"N1I_B1_COLLAPSE_RUNS": "0/1",
                                                         "N1I_B1_REGISTRATION_COLLAPSE_REPRODUCED": "NO"})
        expect("tl_no_divergence_line_stops", e, {"N1I_B1_IMS_FIRST_DIVERGENCE": "STOP",
                                                   "N1I_B1_IMS_FIRST_DIVERGENCE_REASON": "c2:NO_DIVERGENCE_FOUND",
                                                   "N1I_B1_NEXT_ACTION": "STOP_AND_REPORT_NO_AUTOMATIC_FLASH"})
        expect("tl_never_recommends_flash_or_root_cause", e, {"N1I_B1_FLASH_RECOMMENDED": "NO",
                                                              "N1I_B1_ROOT_CAUSE_CONCLUDED": "NO",
                                                              "N1I_B1_DECISION_GATE": "NOT_COMPUTED_REQUIRES_B2",
                                                              "N1I_B1_DEVICE_CONTACT": "NO"})

        r = run("timeline", *runspec("stock", 2, "s2a", "stock-tray2-transient.logcat.txt"),
                *runspec("stock", 2, "s2b", "stock-tray2-clean.logcat.txt"),
                *runspec("c3a", 2, "c2r", "c3a-tray2-transient-recovered.logcat.txt"), "--out", td / "two")
        e = env(td / "two/TIMELINE_SUMMARY.env")
        expect("tl_behaviour_seen_in_any_stock_run_is_not_divergence", e, {
            "N1I_B1_REGISTRATION_FIRST_DIVERGENCE": "STOP",
            "N1I_B1_REGISTRATION_FIRST_DIVERGENCE_REASON": "c2r:NO_DIVERGENCE_FOUND"})

        r = run("timeline", *runspec("stock", 1, "s1", "stock-tray1.logcat.txt"),
                *runspec("c3a", 1, "ca", "c3a-tray1-collapse-a.logcat.txt"),
                *runspec("c3a", 1, "cb", "c3a-tray1-collapse-b.logcat.txt"), "--out", td / "col")
        e = env(td / "col/TIMELINE_SUMMARY.env")
        expect("tl_c3a_transient_no_recovery_new_causes_selects_step11", e, {
            "N1I_B1_REGISTRATION_FIRST_DIVERGENCE": "11:rejection_causes"})
        expect("tl_collapse_reproduced_two_runs", e, {"N1I_B1_COLLAPSE_RUNS": "2/2",
                                                      "N1I_B1_REGISTRATION_COLLAPSE_REPRODUCED": "YES"})
        r = run("timeline", *runspec("stock", 1, "s1", "stock-tray1.logcat.txt"),
                *runspec("c3a", 1, "ca", "c3a-tray1-collapse-a.logcat.txt"), "--out", td / "col1")
        e = env(td / "col1/TIMELINE_SUMMARY.env")
        expect("tl_collapse_single_run_not_reproduced", e, {"N1I_B1_COLLAPSE_RUNS": "1/1",
                                                            "N1I_B1_REGISTRATION_COLLAPSE_REPRODUCED": "NO"})

        r = run("timeline", *runspec("stock", 1, "s1", "stock-tray1.logcat.txt"),
                *runspec("c3a", 1, "cp", "c3a-tray1-apn-pwg.logcat.txt"), "--out", td / "apn")
        e = env(td / "apn/TIMELINE_SUMMARY.env")
        expect("tl_apn_mismatch_selects_step3", e, {
            "N1I_B1_REGISTRATION_FIRST_DIVERGENCE": "3:initial_attach_apn",
            "N1I_B1_INITIAL_ATTACH_APN_STOCK": "fast.t-mobile.com",
            "N1I_B1_INITIAL_ATTACH_APN_C3A": "pwg",
            "N1I_B1_APN_INITIAL_ATTACH_CLASSIFICATION": "PENDING_RUNTIME_EVIDENCE"})
        expect("tl_ims_provider_failure_selects_step6", e, {"N1I_B1_IMS_FIRST_DIVERGENCE": "6:ims_provider_bind",
                                                            "N1I_B1_TIMELINE_STOP": "NO"})
        rows = [l.split("\t") for l in (td / "apn/DIVERGENCE.tsv").read_text().splitlines()[1:]]
        top3 = [x for x in rows if x[2] == "ims" and x[4] == "TOP3"]
        case("tl_top3_candidates_reported", len(top3) == 3 and [x[5] for x in top3] == ["6", "7", "8"],
             f"ims top3 steps={[x[5] for x in top3]}")
        case("tl_divergence_has_sanitized_sha256_and_ref", all(len(x[12]) == 64 or x[12] == "-" for x in rows)
             and rows[0][11].endswith(":4"), "")

        r = run("timeline", *runspec("stock", 1, "s1", "stock-tray1.logcat.txt"),
                *runspec("c3a", 1, "ct", "c3a-tray1-truncated.logcat.txt"), "--out", td / "tr")
        e = env(td / "tr/TIMELINE_SUMMARY.env")
        case("tl_insufficient_evidence_exit0", r.returncode == 0, "STOP is a valid result")
        expect("tl_insufficient_retained_evidence_stops", e, {
            "N1I_B1_REGISTRATION_FIRST_DIVERGENCE": "STOP",
            "N1I_B1_REGISTRATION_FIRST_DIVERGENCE_REASON": "ct:EARLIEST_CANDIDATE_STEP_1_NOT_IN_RETAINED_EVIDENCE",
            "N1I_B1_TIMELINE_STOP": "YES", "N1I_B1_NEXT_ACTION": "STOP_AND_REPORT_NO_AUTOMATIC_FLASH",
            "N1I_B1_FLASH_RECOMMENDED": "NO"})
        cov = (td / "tr/COVERAGE.tsv").read_text()
        case("tl_coverage_marks_not_in_retained_evidence", "ct\tc3a\t1\t1\tcapability_placement\tregistration\t0\tNOT_IN_RETAINED_EVIDENCE" in cov, "")

        r = run("timeline", *runspec("stock", 1, "s1", "stock-tray1.logcat.txt"),
                *runspec("c3a", 1, "cp", "c3a-tray1-apn-pwg.logcat.txt"),
                *runspec("c3a", 1, "ca", "c3a-tray1-collapse-a.logcat.txt"), "--out", td / "inc")
        e = env(td / "inc/TIMELINE_SUMMARY.env")
        case("tl_inconsistent_c3a_runs_stop",
             e.get("N1I_B1_REGISTRATION_FIRST_DIVERGENCE") == "STOP"
             and e.get("N1I_B1_REGISTRATION_FIRST_DIVERGENCE_REASON", "").startswith("INCONSISTENT_ACROSS_C3A_RUNS"), "")

        r = run("timeline", *runspec("stock", 1, "s1", "stock-tray1.logcat.txt"),
                *runspec("c3a", 2, "c2", "c3a-tray2-norecovery.logcat.txt"), "--out", td / "nostock")
        e = env(td / "nostock/TIMELINE_SUMMARY.env")
        expect("tl_no_same_tray_stock_control_stops", e, {
            "N1I_B1_REGISTRATION_FIRST_DIVERGENCE": "STOP",
            "N1I_B1_REGISTRATION_FIRST_DIVERGENCE_REASON": "c2:NO_STOCK_CONTROL_FOR_TRAY"})

        tsv = (td / "rec/TIMELINE.tsv").read_text()
        case("tl_timeline_has_no_raw_line_text", "onSetupDataCallDone" not in tsv and "ServiceStateTracker" not in tsv, "")
        case("tl_timeline_utc_normalized", "2026-10-01T10:01:01.000Z" in tsv, "")
        r2 = run("timeline", "--run", f"side=stock,tray=1,label=s1,path={TL / 'stock-tray1.logcat.txt'},tz=+0200",
                 *runspec("c3a", 1, "cp", "c3a-tray1-apn-pwg.logcat.txt"), "--out", td / "tz")
        case("tl_timezone_applied", "2026-10-01T08:00:00.000Z" in (td / "tz/TIMELINE.tsv").read_text(), "")
        rules = (td / "rec/RULES.tsv").read_text()
        case("tl_rules_preregistered_in_output", "RECOVERY_WINDOW_SEC=120" in rules and "COLLAPSE_CAUSES=11,13,15" in rules
             and rules.count("\n") == 15, "")

        # fail-closed inputs
        r = run("timeline", *runspec("stock", 1, "s1", "stock-tray1.logcat.txt"), "--out", td / "noc3a")
        case("tl_requires_c3a_run", r.returncode == 2 and not (td / "noc3a").exists(), f"rc={r.returncode}")
        r = run("timeline", "--run", "side=c3a,tray=3,label=x,path=/nonexistent", "--out", td / "bad")
        case("tl_bad_run_spec_refused", r.returncode == 2 and not (td / "bad").exists(), f"rc={r.returncode}")
        (td / "noyear.logcat.txt").write_text("10-01 10:00:00.000  1 1 D RILJ: setInitialAttachApn apn=pwg\n")
        r = run("timeline", *runspec("stock", 1, "s1", "stock-tray1.logcat.txt"),
                "--run", f"side=c3a,tray=1,label=ny,path={td / 'noyear.log'}", "--out", td / "ny")
        case("tl_yearless_logcat_requires_year", r.returncode == 2 and not (td / "ny").exists(), f"rc={r.returncode}")
        r = run("timeline", *runspec("stock", 1, "s1", "stock-tray1.logcat.txt"),
                *runspec("c3a", 1, "cp", "c3a-tray1-apn-pwg.logcat.txt"), "--out", td / "apn")
        case("tl_refuses_nonempty_output", r.returncode == 2, f"rc={r.returncode}")

        # ---------------- APN facts / hypotheses
        r = run("apn", "--stock-apns", APN / "stock-apns-conf.xml", "--c3a-apns", APN / "c3a-apns-conf.xml",
                "--observed-apn", "stock=fast.t-mobile.com", "--observed-apn", "c3a=pwg",
                "--stock-carrier-list", APN / "stock-carrier_list.textpb",
                "--c3a-carrier-list", APN / "c3a-carrier_list.textpb", "--out", td / "apnf")
        f, h = env(td / "apnf/APN_FACTS.env"), env(td / "apnf/APN_HYPOTHESES.env")
        case("apn_exit0", r.returncode == 0, r.stderr[-200:])
        expect("apn_mismatch_facts", f, {"N1I_B1_APN_DB_DIFF_OFFLINE": "DIFFERS(4)",
                                         "N1I_B1_APN_ROWS_ONLY_STOCK": "1", "N1I_B1_APN_ROWS_ONLY_C3A": "2",
                                         "N1I_B1_APN_ROWS_FIELDS_DIFFER": "1",
                                         "N1I_B1_APN_EVIDENCE_KIND": "FACT_OFFLINE_PACKAGED_DATA",
                                         "N1I_B1_APN_OBSERVED_C3A_PWG_IN_STOCK_DB": "ABSENT",
                                         "N1I_B1_APN_OBSERVED_C3A_PWG_IN_C3A_DB": "310240/mvno=none;310260/mvno=gid",
                                         "N1I_B1_APN_STOCK_ROWS_310240": "1"})
        expect("apn_type_order_normalized", f, {"N1I_B1_APN_OBSERVED_STOCK_FAST_T_MOBILE_COM_IN_C3A_DB": "310260/mvno=none"})
        expect("apn_carrier_id_textproto_facts", f, {"N1I_B1_CARRIER_ID_DB_OFFLINE": "DIFFERS_BYTES",
                                                     "N1I_B1_CARRIER_ID_310240_STOCK": "1",
                                                     "N1I_B1_CARRIER_ID_310240_C3A": "2"})
        expect("apn_hypotheses_separate_and_not_proven", h, {
            "N1I_B1_APN_HYPOTHESIS_SOURCE": "OFFLINE_PACKAGED_DATA_ONLY",
            "N1I_B1_APN_HYPOTHESIS_RUNTIME_CAUSE_PROVEN": "NO",
            "N1I_B1_APN_HYP_CONFIGURATION_DIFFERENCE_ONLY": "CANDIDATE_FROM_PACKAGED_DATA",
            "N1I_B1_APN_HYP_TELEPHONY_PROVIDER_STATE_DIFFERENCE": "NOT_ESTABLISHABLE_OFFLINE",
            "N1I_B1_APN_HYP_MTK_FRAMEWORK_GENERATED_STATE": "NOT_ESTABLISHABLE_OFFLINE",
            "N1I_B1_APN_INITIAL_ATTACH_CLASSIFICATION": "PENDING_RUNTIME_EVIDENCE"})
        case("apn_facts_file_has_no_hypothesis_keys", not any("HYP" in k for k in f), "")
        alltext = "".join(p.read_text() for p in (td / "apnf").iterdir())
        case("apn_credentials_and_match_data_never_written",
             all(s not in alltext for s in ("synthapnuser", "synthapnpass", "5050")), "")
        r = run("apn", "--stock-apns", APN / "stock-apns-conf.xml", "--c3a-apns", APN / "stock-apns-conf.xml",
                "--out", td / "apnm")
        expect("apn_match_case", {**env(td / "apnm/APN_FACTS.env"), **env(td / "apnm/APN_HYPOTHESES.env")}, {
            "N1I_B1_APN_DB_DIFF_OFFLINE": "MATCH", "N1I_B1_CARRIER_ID_DB_OFFLINE": "NOT_PROVIDED",
            "N1I_B1_APN_HYP_CONFIGURATION_DIFFERENCE_ONLY": "NOT_INDICATED_BY_PACKAGED_DATA"})
        r = run("apn", "--stock-apns", APN / "doctype-apns-conf.xml", "--c3a-apns", APN / "stock-apns-conf.xml",
                "--out", td / "apnd")
        case("apn_doctype_refused", r.returncode == 2 and not (td / "apnd").exists(), f"rc={r.returncode}")
        r = run("apn", "--stock-apns", APN / "dup-apns-conf.xml", "--c3a-apns", APN / "stock-apns-conf.xml",
                "--out", td / "apndup")
        case("apn_duplicate_rows_refused", r.returncode == 2 and not (td / "apndup").exists(), f"rc={r.returncode}")
        r = run("apn", "--stock-apns", APN / "stock-apns-conf.xml", "--c3a-apns", APN / "c3a-apns-conf.xml",
                "--observed-apn", "c3a=pwg;rm", "--out", td / "apnbad")
        case("apn_bad_observed_refused", r.returncode == 2, f"rc={r.returncode}")

        # ---------------- B0
        def b0(name, cands, refs, basis=""):
            args = ["b0", "--expected-vendor-fingerprint", VFP, "--out", td / name]
            for c in cands:
                args += ["--candidate", B0 / c]
            for x in refs:
                args += ["--reference", B0 / x]
            if basis:
                args += ["--logical-basis", basis]
            rr = run(*args)
            return rr, env(td / name / "B0.env")
        BASIS = "docs/titan2/N1F_C3A_DERIVED_C3B5_BUILD_FLASH.md"
        r, e = b0("m", ["n1f-boot-getprop.txt"], ["n1d-preflash-getprop.txt"], BASIS)
        expect("b0_match", e, {"N1I_B0_N1F_VENDOR_IDENTITY": "PASS_MATCH",
                               "N1I_B0_N1D_CELLULAR_BOOT_CAUSALITY": "EXCLUDED_AS_PRIMARY_CAUSE",
                               "N1I_B0_N1D_CELLULAR_BOOT_CAUSALITY_QUALIFIER": "NONE",
                               "N1I_B0_KEY_RO_BOOT_VBMETA_DIGEST": "DIFFERS",
                               "N1I_B0_CANDIDATE_VENDOR_EQUALS_EXPECTED": "YES"})
        r, e = b0("m_nobasis", ["n1f-boot-getprop.txt"], ["n1d-preflash-getprop.txt"])
        expect("b0_match_without_logical_basis_not_proven", e, {
            "N1I_B0_N1F_VENDOR_IDENTITY": "PASS_MATCH", "N1I_B0_N1D_CELLULAR_BOOT_CAUSALITY": "NOT_FULLY_PROVEN"})
        r, e = b0("p", ["n1f-partial.env"], ["n1d-preflash-getprop.txt"], BASIS)
        expect("b0_partial", e, {"N1I_B0_N1F_VENDOR_IDENTITY": "PARTIAL",
                                 "N1I_B0_N1D_CELLULAR_BOOT_CAUSALITY": "EXCLUDED_AS_PRIMARY_CAUSE",
                                 "N1I_B0_N1D_CELLULAR_BOOT_CAUSALITY_QUALIFIER": "VENDOR_IDENTITY_UNVERIFIED",
                                 "N1I_B0_KEY_RO_VENDOR_DLKM_BUILD_FINGERPRINT": "CANDIDATE_UNRECOVERED"})
        r, e = b0("n", ["n1f-no-vendor.txt"], ["n1d-preflash-getprop.txt"], BASIS)
        expect("b0_not_recoverable", e, {"N1I_B0_N1F_VENDOR_IDENTITY": "NOT_RECOVERABLE",
                                         "N1I_B0_N1D_CELLULAR_BOOT_CAUSALITY_QUALIFIER": "VENDOR_IDENTITY_UNVERIFIED",
                                         "N1I_B0_CANDIDATE_VENDOR_EQUALS_EXPECTED": "UNRECOVERED"})
        r, e = b0("x", ["n1f-other-vendor.txt"], ["n1d-preflash-getprop.txt"], BASIS)
        expect("b0_vendor_mismatch_blocks_exclusion", e, {"N1I_B0_N1F_VENDOR_IDENTITY": "MISMATCH",
                                                           "N1I_B0_N1D_CELLULAR_BOOT_CAUSALITY": "NOT_FULLY_PROVEN"})
        r, e = b0("c", ["n1f-boot-getprop.txt", "n1f-conflict-second.txt"], ["n1d-preflash-getprop.txt"], BASIS)
        expect("b0_conflicting_candidate_evidence", e, {"N1I_B0_N1F_VENDOR_IDENTITY": "MISMATCH",
                                                        "N1I_B0_KEY_RO_VENDOR_BUILD_FINGERPRINT": "CONFLICT"})
        ident = (td / "m/B0_IDENTITY.tsv").read_text()
        case("b0_records_evidence_path_and_line", "n1f-boot-getprop.txt:1" in ident and "n1d-preflash-getprop.txt:1" in ident, "")
        r = run("b0", "--candidate", B0 / "missing.txt", "--reference", B0 / "n1d-preflash-getprop.txt", "--out", td / "mis")
        case("b0_missing_input_refused", r.returncode == 2 and not (td / "mis").exists(), f"rc={r.returncode}")
    return 1 if FAILS else 0


if __name__ == "__main__":
    raise SystemExit(main())
