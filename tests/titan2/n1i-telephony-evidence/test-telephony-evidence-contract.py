#!/usr/bin/env python3
"""N1I Telephony Evidence Normalizer and Qualification Contract v1.2 self-tests.

Offline only: no device, no /srv, no network. Recovery execution is out of scope.

Output follows the N1I self-test convention:
  CASE<TAB>telephony_evidence<TAB>id<TAB>PASS|FAIL<TAB>detail
"""

from __future__ import annotations

import ast
import copy
import json
import random
import subprocess
import sys
import types
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = Path(subprocess.check_output(["git", "-C", str(HERE), "rev-parse", "--show-toplevel"], text=True).strip())
sys.path.insert(0, str(ROOT / "build/titan2"))
sys.path.insert(0, str(HERE))

import n1i_telephony_evidence_eval as E  # noqa: E402
import make_fixtures as M  # noqa: E402

EVAL = ROOT / "build/titan2/n1i_telephony_evidence_eval.py"
CONTRACT_PATH = ROOT / "docs/titan2/N1I_TELEPHONY_EVIDENCE_CONTRACT_V1_2.json"
FIXTURES = HERE / "fixtures"
STABLE = "F21_CONTINUOUS_VALIDATED"
FAILS = 0
COUNTS = {"cases": 0, "contract_mutations": 0, "contract_mutations_rejected": 0,
          "evaluator_faults": 0, "evaluator_faults_caught": 0}


def case(cid: str, ok: bool, detail: str = "") -> None:
    global FAILS
    COUNTS["cases"] += 1
    print(f"CASE\ttelephony_evidence\t{cid}\t{'PASS' if ok else 'FAIL'}\t{detail}".replace("\n", " ")[:500])
    FAILS += 0 if ok else 1


def load(p: Path):
    return json.loads(p.read_text(encoding="utf-8"))


CONTRACT = load(CONTRACT_PATH)


def bundle(fid: str) -> dict:
    return load(FIXTURES / f"{fid}.json")


def rehash(b: dict) -> dict:
    b["events_sha256"] = E.canonical_sha256(b["events"])
    return b


def rel(e: dict) -> float:
    return E.parse_ts(e["timestamp_utc"]) - E.parse_ts(M.ts(0))


# ---------------------------------------------------------------------------
# 1. Contract is valid, design-only, normalization-only; fixtures are generated
# ---------------------------------------------------------------------------
errs = E.validate_contract(CONTRACT)
case("contract_valid", not errs, ",".join(errs))
case("contract_design_only", CONTRACT["status"] == "DESIGN_ONLY_NOT_PRODUCTION_AUTHORIZED"
     and CONTRACT["execution_enabled"] is False and not any(CONTRACT["authority"].values()))
case("contract_scope_normalizer_only", CONTRACT["scope"] == "EVIDENCE_NORMALIZATION_AND_QUALIFICATION_ONLY"
     and CONTRACT["recovery_execution"] == "OUT_OF_SCOPE_PENDING_ROOT_CAUSE")
case("contract_ims_excluded", {"IMS_REGISTRATION", "IMS_BEARER"} <= set(CONTRACT["scope_exclusions"]))
case("contract_provenance_requirements", set(CONTRACT["evidence_requirements"]) >= {
    "validation_mode", "private_dns_mode", "dns_servers", "connectivity_check_urls",
    "connectivity_check_source", "apn_protocol"})

regen = subprocess.run([sys.executable, str(HERE / "make_fixtures.py"), "--check"], capture_output=True, text=True)
case("fixtures_match_generator", regen.returncode == 0, regen.stdout.strip())

ids = [f["id"] for f in CONTRACT["fixtures"]]
files = sorted(p.stem for p in FIXTURES.glob("*.json"))
case("fixture_files_match_contract", sorted(ids) == files, f"contract={len(ids)} files={len(files)}")

# ---------------------------------------------------------------------------
# 2. Gate coverage
# ---------------------------------------------------------------------------
cover = {g: [f["id"] for f in CONTRACT["fixtures"] if g in f["gates"]] for g in CONTRACT["gates"]}
for g, fs in cover.items():
    case(f"gate_covered:{g}", bool(fs), ",".join(fs))


# ---------------------------------------------------------------------------
# 3. Behavioural suite. Runs against the real evaluator (every check must pass)
#    and against each injected evaluator fault (at least one check must fail).
# ---------------------------------------------------------------------------
def drop(pred):
    def fn(ev):
        ev[:] = [e for e in ev if not pred(e)]
    return fn


def in_band(e, lo=300, hi=400):
    return lo < rel(e) < hi


def flip_last_validation(ev):
    for e in reversed(ev):
        if e["event_type"] == "VALIDATION":
            e["payload"]["verdict"] = "INVALID"
            return


def flip_mid_validation(ev):
    for e in ev:
        if e["event_type"] == "VALIDATION" and rel(e) >= 500:
            e["payload"]["verdict"] = "INVALID"
            return


def registration_polling_only(ev):
    """Oct 3 shape: registration polling plus one VALID transition; no bearer or validation samples."""
    ev[:] = [e for e in ev if not (e["source_id"] == "sampler" and e["event_type"] != "REGISTRATION")]
    ev.append({**ev[-1], "source_id": "connectivity", "sequence": 0, "event_type": "VALIDATION", "cid": None,
               "timestamp_utc": M.ts(10), "payload": {"verdict": "VALID", "basis": "TRANSITION"},
               "evidence_ref": "synthetic:mutation:connectivity:0"})


def drop_sub_ref(ev):
    for e in ev:
        if e["event_type"] == "SIM_STATE":
            e["subscription_ref"] = None


def add_event(**kw):
    def fn(ev):
        base = {"schema_version": 1, "source_id": "mutation", "sequence": 0, "timestamp_utc": M.ts(500),
                "source_clock_kind": "UTC_ALIGNED", "event_type": "REGISTRATION", "phone_id": None,
                "slot_id": None, "subscription_ref": None, "cid": None,
                "payload": {"domain": "PS", "state": "HOME", "rat": "LTE", "reject_cause": None},
                "evidence_ref": "synthetic:mutation:0"}
        base.update(kw)
        ev.append(base)
    return fn


def rebind_probes(ev):
    for e in ev:
        if e["event_type"] == "VALIDATION" and e["payload"].get("basis") == "PROBE" and rel(e) > 500:
            e["payload"]["bound_cid"] = 999


def default_to(sub):
    def fn(ev):
        for e in ev:
            if e["event_type"] == "DEFAULT_DATA":
                e["subscription_ref"] = sub
    return fn


def split_vendor_forms(ev):
    for e in ev:
        if e["event_type"] == "VENDOR_DEACT":
            e["payload"]["res"] = 1317585


def move_apn_before_loss(ev):
    for e in ev:
        if e["event_type"] == "OPERATOR_ACTION" and e["payload"]["action"] == "APN_TRIAL":
            e["timestamp_utc"] = M.ts(50)


def unknown_clock(ev):
    ev[0]["source_clock_kind"] = "UNKNOWN"


def extra_field(ev):
    ev[0]["execute"] = True


def is_(outcome, reason=None):
    return lambda r: r.get("outcome") == outcome and (reason is None or r.get("inconclusive_reason") == reason)


def aborts(reason):
    return lambda r: r.get("abort") == reason


BUNDLE_MUTATIONS = [
    # (label, fixture, mutate(events), check(result))
    ("last_validation_invalid_fails_internet", STABLE, flip_last_validation, is_("FAIL_INTERNET_VALIDATION")),
    ("mid_window_invalid_restarts_window", STABLE, flip_mid_validation,
     lambda r: is_("INCONCLUSIVE", "WINDOW_INCOMPLETE")(r) and r["window_restart_cause"] == "VALIDATION_TRANSITION"),
    ("no_validation_pending", STABLE, drop(lambda e: e["event_type"] == "VALIDATION"),
     is_("INCONCLUSIVE", "VALIDATION_PENDING")),
    ("registration_polling_alone_not_stable", STABLE, registration_polling_only,
     is_("INCONCLUSIVE", "VALIDATION_NOT_CONTINUOUS")),
    ("validation_sample_gap", STABLE, drop(lambda e: e["event_type"] == "VALIDATION" and in_band(e)),
     is_("INCONCLUSIVE", "VALIDATION_NOT_CONTINUOUS")),
    ("registration_sample_gap", STABLE, drop(lambda e: e["event_type"] == "REGISTRATION" and in_band(e)),
     is_("INCONCLUSIVE", "REGISTRATION_NOT_CONTINUOUS")),
    ("bearer_sample_gap", STABLE, drop(lambda e: e["event_type"] == "BEARER" and in_band(e)),
     is_("INCONCLUSIVE", "BEARER_NOT_CONTINUOUS")),
    ("trailing_capture_silence", STABLE, drop(lambda e: rel(e) > 950),
     is_("INCONCLUSIVE", "VALIDATION_NOT_CONTINUOUS")),
    ("capture_gap_mid_window", STABLE, add_event(event_type="CAPTURE_GAP", payload={"seconds": 20}),
     lambda r: is_("INCONCLUSIVE", "WINDOW_INCOMPLETE")(r) and r["window_restart_cause"] == "CAPTURE_GAP"),
    ("operator_action_restarts_window", STABLE, add_event(event_type="OPERATOR_ACTION",
                                                         payload={"action": "APN_TRIAL"}),
     lambda r: is_("INCONCLUSIVE", "WINDOW_INCOMPLETE")(r) and r["window_restart_cause"] == "OPERATOR_ACTION"),
    ("active_probe_rebound_goes_stale", "F31_ACTIVE_PROBE_BOUND_STABLE", rebind_probes,
     is_("INCONCLUSIVE", "VALIDATION_STALE")),
    ("no_mapping_unknown", STABLE, drop_sub_ref, is_("UNKNOWN")),
    ("no_default_data_inconclusive", STABLE, drop(lambda e: e["event_type"] == "DEFAULT_DATA"),
     is_("INCONCLUSIVE", "NO_DEFAULT_DATA_EVIDENCE")),
    ("dsds_default_s1_follows_evidence", "F10_DSDS_DEFAULT_S2_LOST", default_to("S1"), is_("VALIDATED_STABLE")),
    ("dsds_default_s2_on_wrong_phone_aborts", "F10_DSDS_DEFAULT_S2_LOST",
     add_event(phone_id=0, subscription_ref="S2"), aborts("IDENTITY_CONFLICT")),
    ("sub_remapped_to_other_phone_aborts", STABLE,
     add_event(event_type="SIM_STATE", phone_id=1, slot_id=1, subscription_ref="S1", payload={"state": "LOADED"}),
     aborts("IDENTITY_CONFLICT")),
    ("phone_slot_mismatch_aborts", STABLE, add_event(phone_id=0, slot_id=1), aborts("IDENTITY_CONFLICT")),
    ("unmapped_phone_evidence_blocks_stable", STABLE, add_event(phone_id=3), is_("INCONCLUSIVE",
                                                                                 "UNATTRIBUTED_EVIDENCE")),
    ("vendor_code_forms_disagree_abort", "F02_OCT09_LOSS", split_vendor_forms, aborts("VENDOR_CODE_CONFLICT")),
    ("apn_before_loss_becomes_prior_candidate", "F07_LATE_APN_TRIAL", move_apn_before_loss,
     lambda r: "APN_TRIAL" in r["prior_cause_candidates"]),
    ("unknown_clock_inconclusive", STABLE, unknown_clock, is_("INCONCLUSIVE", "CLOCK_UNKNOWN")),
    ("extra_field_aborts", STABLE, extra_field, aborts("SCHEMA")),
]


def suite(mod) -> dict[str, tuple[bool, str]]:
    """Every behavioural check, evaluated with module `mod`. Exceptions count as failures."""
    out: dict[str, tuple[bool, str]] = {}

    def run(b, c=None):
        return mod.evaluate(b, c or CONTRACT)

    def chk(name, fn):
        try:
            ok, detail = fn()
        except Exception as ex:  # a crash is a detected fault, never a pass
            ok, detail = False, f"exception {type(ex).__name__}: {ex}"
        out[name] = (ok, detail)

    results: dict[str, dict] = {}
    for f in CONTRACT["fixtures"]:
        def replay(f=f):
            r = run(bundle(f["id"]))
            results[f["id"]] = r
            diff = {k: {"want": v, "got": r.get(k)} for k, v in f["assert"].items() if r.get(k) != v}
            return not diff, json.dumps(diff, sort_keys=True) if diff else f["expected"]
        chk(f"replay:{f['id']}", replay)

        def never(f=f):
            r = results.get(f["id"]) or run(bundle(f["id"]))
            return (r["execution_enabled"] is False and r["physical_qualification"] == "NOT_EXECUTED"
                    and r["root_cause"] == "UNKNOWN" and r.get("proposal") in (None, *mod.PROPOSALS)
                    and all(v == "DENY" for v in (r.get("action_decisions") or {}).values())), ""
        chk(f"replay_never_executes:{f['id']}", never)

    for label, fid, fn, check in BUNDLE_MUTATIONS:
        def mut(fid=fid, fn=fn, check=check):
            b = bundle(fid)
            fn(b["events"])
            r = run(rehash(b))
            return bool(check(r)), (f"outcome={r.get('outcome')} reason={r.get('inconclusive_reason')} "
                                    f"abort={r.get('abort')}")
        chk(f"bundle_mutation:{label}", mut)

    def tamper():
        b = bundle(STABLE)
        b["events"][3]["payload"]["active"] = 0
        return run(b)["abort"] == "SHA256_MISMATCH", ""
    chk("bundle_mutation:tamper_without_rehash_aborts", tamper)

    def outside():
        b = bundle(STABLE)
        b["capture"]["end_utc"] = M.ts(10)
        return run(b)["abort"] == "PROVENANCE", ""
    chk("bundle_mutation:event_outside_capture_aborts", outside)

    def r_(fid):
        return results.get(fid) or run(bundle(fid))

    chk("stock_cause_not_equivalent_to_oct09",
        lambda: (not mod.same_initial_cause(r_("F02_OCT09_LOSS"), r_("F04_STOCK_DIFFERENT_CAUSE")), ""))
    chk("reject_order_preserved_per_run",
        lambda: (r_("F02_OCT09_LOSS")["reject_sequence"] == [15, 13, 11]
                 and r_("F32_N1IB_9AA_TRAY1_REJECT_ORDER")["reject_sequence"] == [13, 15, 11, 11, 13, 15]
                 and not mod.same_initial_cause(r_("F02_OCT09_LOSS"), r_("F32_N1IB_9AA_TRAY1_REJECT_ORDER")),
                 f"{r_('F02_OCT09_LOSS').get('reject_sequence')} vs "
                 f"{r_('F32_N1IB_9AA_TRAY1_REJECT_ORDER').get('reject_sequence')}"))
    chk("absent_vendor_code_not_invented",
        lambda: (r_("F32_N1IB_9AA_TRAY1_REJECT_ORDER")["vendor_codes"] == [], ""))
    chk("same_cause_is_reflexive", lambda: (mod.same_initial_cause(r_("F02_OCT09_LOSS"), r_("F02_OCT09_LOSS")), ""))

    def opaque():
        r = r_("F02_OCT09_LOSS")
        decoded = {k for k in r if "meaning" in k or "decoded" in k}
        one = mod.canonical_vendor_code({"raw_code": "0x140F7C"}) == mod.canonical_vendor_code({"res": 1314684}) \
            == mod.canonical_vendor_code({"raw_code": "0x140F7C", "res": 1314684}) == "0x140F7C"
        return one and r["vendor_codes"] == ["0x140F7C"] and not decoded, "0x140F7C == res 1314684, one opaque code"
    chk("vendor_code_single_opaque_form", opaque)
    chk("exact_duplicate_dropped_not_counted",
        lambda: (r_("F01_OCT03_HISTORICAL_POLLING_ONLY")["abort"] is None, ""))
    chk("dsrm_selection_is_not_execution",
        lambda: (r_("F02_OCT09_LOSS")["dsrm_executed"] == [] and bool(r_("F19_DSRM_EXECUTED")["dsrm_executed"]), ""))
    chk("ims_never_in_qualification",
        lambda: (r_("F33_IMS_BEARER_OUT_OF_SCOPE")["outcome"] == "VALIDATED_STABLE"
                 and r_("F34_IMS_BEARER_ONLY")["outcome"] != "VALIDATED_STABLE", ""))
    chk("dsds_never_qualified_offline",
        lambda: (all(r.get("dsds") in (None, "NOT_QUALIFIED_OFFLINE_REQUIRES_PHYSICAL",
                                       "NOT_QUALIFIED_SINGLE_SIM_EVIDENCE") for r in results.values()), ""))
    chk("unknown_provenance_reported_not_filled",
        lambda: (r_("F38_PROVENANCE_ALL_UNKNOWN")["provenance_unknown"] == list(mod.NETWORK_CONFIG_FIELDS)
                 and r_("F38_PROVENANCE_ALL_UNKNOWN")["network_config"] == {}, ""))
    def verbatim():
        nc = bundle("F02_OCT09_LOSS")["provenance"]["network_config"]
        want = {k: v["value"] for k, v in nc.items() if v["status"] == "OBSERVED"}
        unk = [k for k in mod.NETWORK_CONFIG_FIELDS if nc[k]["status"] == "UNKNOWN"]
        r = r_("F02_OCT09_LOSS")
        return (r["network_config"] == want and r["provenance_unknown"] == unk
                and not set(want) & set(unk)), json.dumps(r["network_config"], sort_keys=True)
    chk("observed_provenance_reported_verbatim", verbatim)

    for fid in ("F02_OCT09_LOSS", "F03_POST_CYCLE_INVALID", "F10_DSDS_DEFAULT_S2_LOST",
                "F11_STOCK_TRANSIENT_RECOVERED", "F24_LATE_MAPPING_NOT_RETROACTIVE"):
        def shuffle(fid=fid):
            base = dict(r_(fid))
            base.pop("detail", None)
            for seed in range(5):
                b = bundle(fid)
                random.Random(seed).shuffle(b["events"])
                r = run(rehash(b))
                r.pop("detail", None)
                if r != base:
                    return False, f"seed={seed}"
            return True, ""
        chk(f"shuffle_deterministic:{fid}", shuffle)
    return out


BASELINE = suite(E)
for name, (ok, detail) in BASELINE.items():
    case(name, ok, detail)
BASELINE_FAILED = {k for k, (ok, _) in BASELINE.items() if not ok}


# ---------------------------------------------------------------------------
# 4. Contract mutations: each must be rejected by validate_contract and must
#    make evaluate() refuse to run.
# ---------------------------------------------------------------------------
def fx(c, fid):
    return next(f for f in c["fixtures"] if f["id"] == fid)


CONTRACT_MUTATIONS = {
    # v1.1 mutations, carried forward
    "drop_required_evidence_ref": lambda c: c["event_schema"]["required_fields"].remove("evidence_ref"),
    "add_action_event_type": lambda c: c["event_schema"]["allowed_event_types"].append("RADIO_CYCLE_EXEC"),
    "corrupt_fixture_expected_pass": lambda c: fx(c, "F09_CORRUPT_EVIDENCE").__setitem__(
        "assert", {"outcome": "VALIDATED_STABLE"}),
    "invent_root_cause": lambda c: fx(c, "F02_OCT09_LOSS")["assert"].__setitem__("root_cause", "0x140F7C_CARRIER_RELEASE"),
    "capture_gap_to_pass": lambda c: c["qualification"]["outcomes"].__setitem__("capture_gap_or_clock_conflict", "PASS"),
    "validation_age_3600": lambda c: c["qualification"]["thresholds"].__setitem__("active_probe_max_validation_age_seconds", 3600),
    "status_production": lambda c: c.__setitem__("status", "PRODUCTION_AUTHORIZED"),
    "remove_flash_authority": lambda c: c["authority"].pop("flash"),
    "drop_stable_window_requirement": lambda c: c["qualification"]["required"].remove("stable_window"),
    "enable_execution": lambda c: c.__setitem__("execution_enabled", True),
    "grant_adb": lambda c: c["authority"].__setitem__("adb", True),
    "action_allowed": lambda c: fx(c, "F08_UNAUTHORIZED_ACTION")["assert"]["action_decisions"].__setitem__("ADB_SHELL", "ALLOW"),
    "uncover_dual_sim_gate": lambda c: c["fixtures"].__setitem__(slice(None), [
        f for f in c["fixtures"] if "G12_DUAL_SIM" not in f["gates"]]),
    "unknown_gate_on_fixture": lambda c: fx(c, STABLE)["gates"].append("G99_NONE"),
    "duplicate_dedup_allowed": lambda c: c["event_schema"].__setitem__("duplicate_conflict", "KEEP_FIRST"),
    "extra_fields_allowed": lambda c: c["event_schema"].__setitem__("extra_fields", "ALLOW"),
    "thresholds_advisory": lambda c: c["qualification"].__setitem__("thresholds_binding", False),
    "negative_fixture_passes": lambda c: fx(c, "F15_CAPTURE_GAP_IN_WINDOW")["assert"].__setitem__("outcome", "VALIDATED_STABLE"),
    # v1.2 mutations
    "identity_rule_inferred": lambda c: c["event_schema"].__setitem__("identity_rule", "phone_index_fallback"),
    "identity_rule_retroactive": lambda c: c["event_schema"].__setitem__(
        "identity_rule", "time_scoped_explicit_mapping_retroactive_application"),
    "identity_conflict_last_wins": lambda c: c["event_schema"].__setitem__("identity_conflict", "LAST_WINS"),
    "overall_verdict_sorted_first": lambda c: c["qualification"].__setitem__("overall_verdict_rule", "sorted_first_subscription"),
    "drop_default_data_requirement": lambda c: c["qualification"]["required"].remove("explicit_default_data_subscription"),
    "no_default_data_to_pass": lambda c: c["qualification"]["outcomes"].__setitem__("no_default_data_evidence", "VALIDATED_STABLE"),
    "drop_continuous_validation": lambda c: c["qualification"]["required"].remove("continuous_validation_samples"),
    "sample_gap_3600": lambda c: c["qualification"]["thresholds"].__setitem__("max_sample_gap_seconds", 3600),
    "passive_rule_transition_counts": lambda c: c["qualification"]["validation_mode_rules"].__setitem__(
        "PASSIVE_LOG", "any_VALID_counts"),
    "active_probe_unbound_allowed": lambda c: c["qualification"]["validation_mode_rules"].__setitem__(
        "ACTIVE_PROBE", "PROBE_VALID_samples_any_network"),
    "drop_validation_transition_restart": lambda c: c["qualification"]["window_restart_events"].remove("VALIDATION_TRANSITION"),
    "drop_capture_gap_restart": lambda c: c["qualification"]["window_restart_events"].remove("CAPTURE_GAP"),
    "drop_evidence_requirement_private_dns": lambda c: c["evidence_requirements"].remove("private_dns_mode"),
    "drop_evidence_requirement_validation_mode": lambda c: c["evidence_requirements"].remove("validation_mode"),
    "unknown_evidence_inferred": lambda c: c.__setitem__("unknown_evidence_rule", "infer_from_defaults"),
    "include_ims_in_scope": lambda c: c["scope_exclusions"].remove("IMS_BEARER"),
    "include_ims_registration_in_scope": lambda c: c["scope_exclusions"].remove("IMS_REGISTRATION"),
    "recovery_execution_in_scope": lambda c: c.__setitem__("recovery_execution", "IN_SCOPE"),
    "scope_widened": lambda c: c.__setitem__("scope", "EVIDENCE_NORMALIZATION_AND_RECOVERY"),
    "vendor_code_form_conflict_allow": lambda c: c["event_schema"].__setitem__("vendor_code_form_conflict", "ALLOW"),
    "vendor_code_decoded": lambda c: c["event_schema"].__setitem__("vendor_code", "decode_to_cause"),
    "drop_default_data_event_type": lambda c: c["event_schema"]["allowed_event_types"].remove("DEFAULT_DATA"),
    "negative_identity_fixture_passes": lambda c: fx(c, "F22_IDENTITY_SUB_PHONE_CONFLICT").__setitem__(
        "assert", {"outcome": "VALIDATED_STABLE"}),
}
for name, mut in CONTRACT_MUTATIONS.items():
    c = copy.deepcopy(CONTRACT)
    mut(c)
    errs = E.validate_contract(c)
    refused = E.evaluate(bundle(STABLE), c)["abort"] == "CONTRACT_INVALID"
    COUNTS["contract_mutations"] += 1
    COUNTS["contract_mutations_rejected"] += bool(errs) and refused
    case(f"contract_mutation_rejected:{name}", bool(errs) and refused, ",".join(errs[:3]))

# ---------------------------------------------------------------------------
# 5. Evaluator fault injection: each fault is a source edit of the evaluator,
#    loaded in memory only (nothing is written). The behavioural suite must
#    fail at least one check for every fault.
# ---------------------------------------------------------------------------
SRC = EVAL.read_text(encoding="utf-8")
FAULTS = {
    # v1.2 faults
    "retroactive_mapping": [
        ("    defaults: list[tuple[float, str | None]] = []\n",
         "    defaults: list[tuple[float, str | None]] = []\n"
         "    _late = {x['phone_id']: x['subscription_ref'] for x in events if x['event_type'] == 'SIM_STATE'\n"
         "             and x['payload'].get('state') == 'LOADED' and x['subscription_ref']}\n"),
        ("            elif phone in empty_phones:\n",
         "            elif phone in _late:\n                target = _late[phone]\n"
         "            elif phone in empty_phones:\n")],
    "phone_index_fallback": [
        ("            elif phone in empty_phones:\n",
         "            elif phone is not None and per_sub:\n                target = sorted(k for k in per_sub "
         "if k != '__global__')[0]\n            elif phone in empty_phones:\n")],
    "sorted_first_primary": [
        ('default = ident["defaults"][-1][1] if ident["defaults"] else None', "default = sorted(subs)[0]")],
    "registration_only_acceptance": [
        ('elif mode == "PASSIVE_LOG" and not _continuous(', 'elif False and not _continuous(')],
    "transition_counts_as_sample": [
        ('counts = (basis == "CAPABILITY_SNAPSHOT") if mode == "PASSIVE_LOG"',
         'counts = (basis in ("CAPABILITY_SNAPSHOT", "TRANSITION")) if mode == "PASSIVE_LOG"'),
        ('            last_verdict = "VALID"\n', '            last_verdict = "VALID"\n'
         '            if basis == "TRANSITION":\n                val_samples.extend(range(int(t), int(end) + 1, 5))\n')],
    "ignore_probe_binding": [('if p.get("bound_cid") not in active_cids():', 'if False:')],
    "split_vendor_code_forms": [('return f"0x{forms[0]:X}"', 'return raw if raw is not None else str(res)')],
    "vendor_form_conflict_ignored": [("if len(set(forms)) != 1:", "if False:")],
    "sort_rejects": [('"reject_sequence": reject_sequence,', '"reject_sequence": sorted(reject_sequence),')],
    "count_ims_bearers": [('if "ims" in str(p.get("apn_type", "")).lower().split(","):', 'if False:')],
    "ignore_identity_conflicts": [('raise EvidenceAbort("IDENTITY_CONFLICT"', 'if False: raise EvidenceAbort("IDENTITY_CONFLICT"')],
    "no_validation_transition_restart": [('restart(t, "VALIDATION_TRANSITION")', 'pass')],
    "no_recovery_restart": [('                if not was:\n                    restart(t, "BEARER")',
                             '                if False:\n                    pass')],
    "unattached_ignored": [('if result["outcome"] == "VALIDATED_STABLE" and ident["unattached"]:', 'if False:')],
    "inferred_provenance_accepted": [
        ('if v["value"] is None or not isinstance(v["evidence_ref"], str) or not v["evidence_ref"]:', 'if False:')],
    # v1.1 faults, carried forward
    "skip_sha256": [("if canonical_sha256(events) != want:", "if False:")],
    "accept_unknown_clock": [('if any(e["source_clock_kind"] == "UNKNOWN" for e in events):', "if False:")],
    "keep_first_duplicate": [("if seen[key] != e:", "if False:")],
    "allow_extra_fields": [("    if extra:\n", "    if False:\n")],
    "dsrm_selected_as_executed": [('stage in ("EXECUTED", "COMPLETED")', "True")],
    "no_capture_gap_restart": [('restart(t + float(p.get("seconds", 0)), "CAPTURE_GAP")', "pass")],
    "post_failure_as_prior": [("for t, a in ops if t < first_loss", "for t, a in ops if True")],
    "allow_actions": [('{a: "DENY" for a in', '{a: "ALLOW" for a in')],
    "invalid_ignored": [('elif last_verdict in ("INVALID",):', "elif False:")],
    "no_stable_window": [('elif end - window_start < th["stable_window_seconds"]:', "elif False:")],
}
for name, edits in FAULTS.items():
    src = SRC
    applied = True
    for old, new in edits:
        applied &= old in src
        src = src.replace(old, new)
    mod = types.ModuleType(f"fault_{name}")
    try:
        exec(compile(src, f"<fault:{name}>", "exec"), mod.__dict__)
        failed = [k for k, (ok, _) in suite(mod).items() if not ok and k not in BASELINE_FAILED]
    except Exception as ex:
        failed = [f"load:{type(ex).__name__}"]
    COUNTS["evaluator_faults"] += 1
    COUNTS["evaluator_faults_caught"] += applied and bool(failed) and not BASELINE_FAILED
    case(f"evaluator_fault_caught:{name}", applied and bool(failed) and not BASELINE_FAILED,
         f"applied={applied} caught_by={len(failed)}:{','.join(failed[:4])}")

# ---------------------------------------------------------------------------
# 6. G10 safety: static scan of the evaluator source
# ---------------------------------------------------------------------------
tree = ast.parse(SRC)
ALLOWED_IMPORTS = {"__future__", "argparse", "hashlib", "json", "sys", "datetime", "pathlib"}
imports = set()
for node in ast.walk(tree):
    if isinstance(node, ast.Import):
        imports |= {a.name.split(".")[0] for a in node.names}
    elif isinstance(node, ast.ImportFrom):
        imports.add((node.module or "").split(".")[0])
case("g10_imports_allowlisted", imports <= ALLOWED_IMPORTS, f"extra={sorted(imports - ALLOWED_IMPORTS)}")

FORBIDDEN_CALLS = {"system", "popen", "Popen", "run", "call", "check_call", "check_output", "exec", "eval",
                   "execv", "execvp", "spawnl", "urlopen", "connect", "socket", "open", "write_text",
                   "write_bytes", "write", "unlink", "remove", "rmtree", "kill"}
called = set()
for node in ast.walk(tree):
    if isinstance(node, ast.Call):
        fn = node.func
        called.add(fn.attr if isinstance(fn, ast.Attribute) else getattr(fn, "id", ""))
case("g10_no_process_network_or_write_calls", not (called & FORBIDDEN_CALLS), f"found={sorted(called & FORBIDDEN_CALLS)}")

low = SRC.lower()
case("g10_no_device_tool_strings", not any(t in low for t in ("adb ", "fastboot ", "resetprop", "setprop", "svc data",
                                                              "cmd phone", "reboot ", "reboot(")))
case("g10_no_recovery_action_vocabulary", not any(t in SRC for t in ("REQUEST_EXPLICIT_RECOVERY_APPROVAL",
                                                                    "EXECUTE_RECOVERY", "def recover")))

# ---------------------------------------------------------------------------
# 7. CLI behaves and stays read-only
# ---------------------------------------------------------------------------
before = subprocess.check_output(["git", "-C", str(ROOT), "status", "--porcelain"], text=True)
cli = subprocess.run([sys.executable, str(EVAL), "--contract", str(CONTRACT_PATH),
                      "--bundle", str(FIXTURES / "F02_OCT09_LOSS.json")], capture_output=True, text=True)
out = json.loads(cli.stdout) if cli.returncode == 0 else {}
case("cli_evaluates_bundle", cli.returncode == 0 and out.get("outcome") == "LOST", cli.stderr.strip()[:200])
cli = subprocess.run([sys.executable, str(EVAL), "--contract", str(CONTRACT_PATH),
                      "--bundle", str(FIXTURES / "F09_CORRUPT_EVIDENCE.json")], capture_output=True, text=True)
case("cli_abort_exit_code", cli.returncode == 2 and json.loads(cli.stdout).get("abort") == "SHA256_MISMATCH")
cli = subprocess.run([sys.executable, str(EVAL), "--contract", str(CONTRACT_PATH), "--validate-contract"],
                     capture_output=True, text=True)
case("cli_validate_contract", cli.returncode == 0)
after = subprocess.check_output(["git", "-C", str(ROOT), "status", "--porcelain"], text=True)
case("cli_wrote_nothing", before == after)

print(f"COUNTS cases={COUNTS['cases']} contract_mutations={COUNTS['contract_mutations_rejected']}/"
      f"{COUNTS['contract_mutations']} evaluator_faults={COUNTS['evaluator_faults_caught']}/"
      f"{COUNTS['evaluator_faults']}")
print(f"TELEPHONY_EVIDENCE_CONTRACT_TESTS={'PASS' if FAILS == 0 else 'FAIL'} failed={FAILS}")
sys.exit(1 if FAILS else 0)
