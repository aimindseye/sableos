#!/usr/bin/env python3
"""N1I cellular-recovery contract: pure offline evaluator.

Reads one contract (JSON) and one evidence bundle (JSON) and returns a verdict.
It never executes, proposes as executable, or simulates any device action.

READ-ONLY CONTRACT
  - No device contact, no subprocess, no network, no file writes.
  - The CLI prints the result as JSON on stdout and nothing else.

Bundle format (bundle_version 1):
  {
    "bundle_version": 1,
    "fixture_id": "...",
    "provenance": {"kind": "SYNTHETIC_ABSTRACTION" | "SANITIZED_CAPTURE", "basis": "..."},
    "validation_mode": "PASSIVE_LOG" | "ACTIVE_PROBE",
    "capture": {"start_utc": "...Z", "end_utc": "...Z"},
    "action_requests": [{"action": "..."}],
    "events_sha256": "<sha256 of canonical JSON of events>",
    "events": [ <event>, ... ]
  }

The events_sha256 check runs before any event is parsed (fail closed on
tampered or corrupt evidence).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# Fixed vocabulary. The contract must match these exactly.
# ---------------------------------------------------------------------------

CONTRACT_ID = "N1I_CELLULAR_RECOVERY"
CONTRACT_VERSION = "1.1"
CONTRACT_STATUS = "DESIGN_ONLY_NOT_PRODUCTION_AUTHORIZED"

AUTHORITY_KEYS = (
    "device_contact", "adb", "fastboot", "sim_movement", "settings_mutation",
    "source_mutation", "build", "flash", "reboot", "network_fetch",
)

REQUIRED_FIELDS = (
    "schema_version", "source_id", "sequence", "timestamp_utc", "source_clock_kind",
    "event_type", "phone_id", "slot_id", "subscription_ref", "cid", "payload", "evidence_ref",
)

EVENT_TYPES = (
    "SIM_STATE", "RADIO_STATE", "REGISTRATION", "BEARER", "VALIDATION", "DNS_PROBE",
    "VENDOR_DEACT", "DSRM_ACTION", "OPERATOR_ACTION", "ACTION_RESULT", "CAPTURE_GAP",
)

CLOCK_KINDS = ("UTC_ALIGNED", "DEVICE_REALTIME_ALIGNED", "UNKNOWN")

GATES = (
    "G00_PROVENANCE", "G01_SCHEMA", "G02_MAPPING", "G03_ORDERING",
    "G04_BEARER_VS_INTERNET", "G05_VENDOR_CAUSE", "G06_DSRM_ATTRIBUTION",
    "G07_RECOVERY_CYCLE", "G08_TEMPORAL_CAUSALITY", "G09_STOCK_PARITY",
    "G10_SAFETY", "G11_NEGATIVE_CASES", "G12_DUAL_SIM",
)

QUALIFICATION_REQUIRED = (
    "active_subscription_mapping", "sim_ready", "radio_on", "ps_registered",
    "bearer_active", "explicit_VALID_after_window_start", "continuous_stable_window",
)

QUALIFICATION_THRESHOLDS = {
    "stable_window_seconds": 900,
    "max_sample_gap_seconds": 15,
    "active_probe_max_validation_age_seconds": 10,
}

QUALIFICATION_OUTCOMES = {
    "connected_without_VALID": "INCONCLUSIVE",
    "connected_with_INVALID": "FAIL_INTERNET_VALIDATION",
    "observed_cycle_and_connected_without_VALID": "NOT_QUALIFIED",
    "capture_gap_or_clock_conflict": "INCONCLUSIVE",
}

VALIDATION_MODES = ("PASSIVE_LOG", "ACTIVE_PROBE")

OUTCOMES = (
    "VALIDATED_STABLE", "FAIL_INTERNET_VALIDATION", "NOT_QUALIFIED", "LOST",
    "INCONCLUSIVE", "UNKNOWN",
)

# Outcomes that are acceptable for a negative (fail-closed) fixture.
FAIL_CLOSED_RESULTS = ("ABORT", "INCONCLUSIVE", "UNKNOWN")

PROPOSALS = ("NO_ACTION", "OBSERVE", "ESCALATE_FOR_REVIEW", "REQUEST_EXPLICIT_RECOVERY_APPROVAL")

PROVENANCE_KINDS = ("SYNTHETIC_ABSTRACTION", "SANITIZED_CAPTURE")

PS_REGISTERED_STATES = ("HOME", "ROAMING")

ASSERT_KEYS = (
    "abort", "outcome", "root_cause", "subscriptions", "ignored_phones", "bearer_recovered",
    "loss_sequence", "vendor_codes", "dsrm_executed", "dsrm_selected_not_executed",
    "prior_cause_candidates", "post_failure_actions", "action_decisions", "dsds",
    "inconclusive_reason", "transient_losses", "per_subscription",
)


class EvidenceAbort(Exception):
    """Fail-closed stop: the bundle must not be evaluated at all."""

    def __init__(self, reason: str, detail: str = ""):
        super().__init__(f"{reason}: {detail}" if detail else reason)
        self.reason = reason
        self.detail = detail


# ---------------------------------------------------------------------------
# Contract validation
# ---------------------------------------------------------------------------

def validate_contract(c: dict) -> list[str]:
    """Return every contract violation. Empty list means the contract is valid."""
    errs: list[str] = []

    def need(cond: bool, msg: str) -> None:
        if not cond:
            errs.append(msg)

    need(c.get("contract_id") == CONTRACT_ID, "contract_id")
    need(c.get("version") == CONTRACT_VERSION, "version")
    need(c.get("status") == CONTRACT_STATUS, "status_must_be_design_only")
    need(c.get("execution_enabled") is False, "execution_enabled_must_be_false")

    auth = c.get("authority")
    need(isinstance(auth, dict) and set(auth) == set(AUTHORITY_KEYS), "authority_key_set")
    need(isinstance(auth, dict) and all(v is False for v in auth.values()), "authority_all_false")

    s = c.get("event_schema", {})
    need(s.get("required_fields") == list(REQUIRED_FIELDS), "required_fields_exact")
    need(s.get("allowed_event_types") == list(EVENT_TYPES), "event_types_exact_closed_set")
    need(s.get("source_clock_kinds") == list(CLOCK_KINDS), "clock_kinds_exact")
    need("unknown_identity" in s and s.get("unknown_identity") is None, "unknown_identity_null")
    need(s.get("identity_rule") == "unknown_phone_slot_or_subscription_must_not_be_inferred", "identity_rule")
    need(s.get("deduplication_key") == ["source_id", "sequence"], "dedup_key")
    need(s.get("duplicate_conflict") == "ABORT", "duplicate_conflict_abort")
    need(s.get("extra_fields") == "REJECT", "extra_fields_reject")
    need(s.get("vendor_code") == "opaque_no_heuristic_decode", "vendor_code_opaque")

    q = c.get("qualification", {})
    need(q.get("required") == list(QUALIFICATION_REQUIRED), "qualification_required_exact")
    need(q.get("thresholds") == QUALIFICATION_THRESHOLDS, "qualification_thresholds_exact")
    need(q.get("thresholds_binding") is True, "thresholds_binding")
    need(q.get("outcomes") == QUALIFICATION_OUTCOMES, "qualification_outcomes_exact")
    need(q.get("validation_modes") == list(VALIDATION_MODES), "validation_modes")
    need(q.get("window_start_rule") == "latest_of_identity_sim_radio_registration_bearer_or_operator_action",
         "window_start_rule")

    need(c.get("gates") == list(GATES), "gates_exact_order")

    fx = c.get("fixtures")
    if not isinstance(fx, list) or not fx:
        errs.append("fixtures_missing")
        return errs
    ids = [f.get("id", "") for f in fx]
    need(len(ids) == len(set(ids)), "fixture_ids_unique")
    for i, fid in enumerate(ids, 1):
        need(fid.startswith(f"F{i:02d}_"), f"fixture_id_order:{fid}")
    covered: set[str] = set()
    for f in fx:
        fid = f.get("id", "?")
        gates = f.get("gates")
        need(isinstance(gates, list) and gates, f"fixture_gates:{fid}")
        for g in gates or []:
            need(g in GATES, f"fixture_unknown_gate:{fid}:{g}")
            covered.add(g)
        need(isinstance(f.get("bundle"), str) and f["bundle"].endswith(".json"), f"fixture_bundle:{fid}")
        a = f.get("assert")
        need(isinstance(a, dict) and a, f"fixture_assert:{fid}")
        if not isinstance(a, dict):
            continue
        for k in a:
            need(k in ASSERT_KEYS, f"fixture_assert_key:{fid}:{k}")
        if "outcome" in a:
            need(a["outcome"] in OUTCOMES, f"fixture_outcome_vocab:{fid}")
        if "root_cause" in a:
            need(a["root_cause"] == "UNKNOWN", f"fixture_root_cause_must_stay_unknown:{fid}")
        for sub in (a.get("per_subscription") or {}).values():
            need(sub in OUTCOMES, f"fixture_per_sub_vocab:{fid}")
        if "action_decisions" in a:
            need(all(v == "DENY" for v in a["action_decisions"].values()), f"fixture_action_must_deny:{fid}")
        if gates and "G11_NEGATIVE_CASES" in gates:
            closed = a.get("abort") or a.get("outcome")
            need(closed in FAIL_CLOSED_RESULTS or a.get("abort"), f"negative_fixture_must_fail_closed:{fid}")
            need(a.get("outcome") != "VALIDATED_STABLE", f"negative_fixture_cannot_pass:{fid}")
    for g in GATES:
        need(g in covered, f"gate_without_fixture:{g}")
    return errs


# ---------------------------------------------------------------------------
# Bundle loading
# ---------------------------------------------------------------------------

def canonical_sha256(obj) -> str:
    raw = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def parse_ts(value) -> float:
    if not isinstance(value, str) or not value.endswith("Z"):
        raise EvidenceAbort("SCHEMA", f"timestamp_utc must be ISO-8601 UTC ending in Z: {value!r}")
    try:
        dt = datetime.strptime(value, "%Y-%m-%dT%H:%M:%S.%fZ")
    except ValueError:
        try:
            dt = datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
        except ValueError as e:
            raise EvidenceAbort("SCHEMA", f"bad timestamp {value!r}") from e
    return dt.replace(tzinfo=timezone.utc).timestamp()


def _check_event(e) -> None:
    if not isinstance(e, dict):
        raise EvidenceAbort("SCHEMA", "event is not an object")
    keys = set(e)
    missing = set(REQUIRED_FIELDS) - keys
    extra = keys - set(REQUIRED_FIELDS)
    if missing:
        raise EvidenceAbort("SCHEMA", f"missing fields {sorted(missing)}")
    if extra:
        raise EvidenceAbort("SCHEMA", f"extra fields rejected {sorted(extra)}")
    if e["schema_version"] != 1:
        raise EvidenceAbort("SCHEMA", "schema_version")
    if e["event_type"] not in EVENT_TYPES:
        raise EvidenceAbort("SCHEMA", f"event_type {e['event_type']!r}")
    if e["source_clock_kind"] not in CLOCK_KINDS:
        raise EvidenceAbort("SCHEMA", f"source_clock_kind {e['source_clock_kind']!r}")
    if not isinstance(e["source_id"], str) or not e["source_id"]:
        raise EvidenceAbort("SCHEMA", "source_id")
    if not isinstance(e["sequence"], int) or isinstance(e["sequence"], bool) or e["sequence"] < 0:
        raise EvidenceAbort("SCHEMA", "sequence")
    if not isinstance(e["payload"], dict):
        raise EvidenceAbort("SCHEMA", "payload")
    if not isinstance(e["evidence_ref"], str) or not e["evidence_ref"]:
        raise EvidenceAbort("SCHEMA", "evidence_ref")
    for k in ("phone_id", "slot_id", "cid"):
        v = e[k]
        if v is not None and (not isinstance(v, int) or isinstance(v, bool)):
            raise EvidenceAbort("SCHEMA", f"{k} must be int or null")
    if e["subscription_ref"] is not None and not isinstance(e["subscription_ref"], str):
        raise EvidenceAbort("SCHEMA", "subscription_ref must be string or null")
    parse_ts(e["timestamp_utc"])


def load_bundle(bundle: dict) -> dict:
    """Validate a bundle. Raises EvidenceAbort; never returns a partial bundle."""
    if not isinstance(bundle, dict) or bundle.get("bundle_version") != 1:
        raise EvidenceAbort("PROVENANCE", "bundle_version")
    # Integrity first: nothing inside events is parsed before the hash matches.
    want = bundle.get("events_sha256")
    events = bundle.get("events")
    if not isinstance(want, str) or len(want) != 64:
        raise EvidenceAbort("PROVENANCE", "events_sha256 missing")
    if canonical_sha256(events) != want:
        raise EvidenceAbort("SHA256_MISMATCH", "events do not match events_sha256")
    prov = bundle.get("provenance")
    if not isinstance(prov, dict) or prov.get("kind") not in PROVENANCE_KINDS or not prov.get("basis"):
        raise EvidenceAbort("PROVENANCE", "provenance kind/basis")
    if bundle.get("validation_mode") not in VALIDATION_MODES:
        raise EvidenceAbort("PROVENANCE", "validation_mode")
    cap = bundle.get("capture") or {}
    start, end = parse_ts(cap.get("start_utc")), parse_ts(cap.get("end_utc"))
    if end <= start:
        raise EvidenceAbort("PROVENANCE", "capture window")
    reqs = bundle.get("action_requests", [])
    if not isinstance(reqs, list) or not all(isinstance(r, dict) and isinstance(r.get("action"), str) for r in reqs):
        raise EvidenceAbort("SCHEMA", "action_requests")
    if not isinstance(events, list):
        raise EvidenceAbort("SCHEMA", "events")

    seen: dict[tuple, dict] = {}
    for e in events:
        _check_event(e)
        key = (e["source_id"], e["sequence"])
        if key in seen:
            if seen[key] != e:
                raise EvidenceAbort("DUPLICATE_CONFLICT", f"{key} differs between copies")
            continue
        t = parse_ts(e["timestamp_utc"])
        if not (start <= t <= end):
            raise EvidenceAbort("PROVENANCE", f"event {key} outside capture window")
        seen[key] = e
    ordered = sorted(seen.values(), key=lambda e: (parse_ts(e["timestamp_utc"]), e["source_id"], e["sequence"]))
    return {
        "fixture_id": bundle.get("fixture_id"),
        "provenance": prov,
        "validation_mode": bundle["validation_mode"],
        "start": start,
        "end": end,
        "action_requests": [r["action"] for r in reqs],
        "events": ordered,
        "duplicates_dropped": len(events) - len(seen),
    }


# ---------------------------------------------------------------------------
# Evaluation
# ---------------------------------------------------------------------------

def _mapping(events: list) -> tuple[dict, set]:
    """subscription_ref -> (phone_id, slot_id) from explicit SIM_STATE LOADED events only."""
    subs: dict[str, tuple] = {}
    ignored: set = set()
    for e in events:
        if e["event_type"] != "SIM_STATE":
            continue
        st = e["payload"].get("state")
        if st == "LOADED" and None not in (e["phone_id"], e["slot_id"], e["subscription_ref"]):
            subs[e["subscription_ref"]] = (e["phone_id"], e["slot_id"])
        elif st == "ABSENT" and e["phone_id"] is not None:
            ignored.add(e["phone_id"])
    used_phones = {p for p, _ in subs.values()}
    return subs, ignored - used_phones


def _attach(e: dict, subs: dict) -> str | None:
    """Return the subscription an event belongs to, or None. Never guesses."""
    if e["subscription_ref"] is not None:
        return e["subscription_ref"] if e["subscription_ref"] in subs else None
    if e["phone_id"] is None:
        return None
    owners = [s for s, (p, _) in subs.items() if p == e["phone_id"]]
    return owners[0] if len(owners) == 1 else None


def _evaluate_sub(sub: str, events: list, b: dict, c: dict) -> dict:
    th = c["qualification"]["thresholds"]
    end = b["end"]
    sim = radio = ps = None
    bearer_active: dict[int, bool] = {}
    ever_active = False
    window_start = b["start"]
    last_verdict = None
    last_verdict_t = None
    cycle_seen = False
    sample_times: list[float] = []
    valid_times: list[float] = []
    gaps: list[tuple[float, float]] = []
    loss_markers: dict[str, float] = {}
    loss_times: list[float] = []
    transient_losses = 0
    lost_now = False
    vendor_codes: list[str] = []
    dsrm_exec: list[str] = []
    dsrm_sel: list[str] = []
    recovered_after_loss = False

    def restart_window(t: float) -> None:
        nonlocal window_start, last_verdict, last_verdict_t
        window_start = t
        last_verdict = None
        last_verdict_t = None
        sample_times.clear()
        valid_times.clear()

    def mark_loss(kind: str, t: float) -> None:
        nonlocal lost_now
        loss_markers.setdefault(kind, t)
        if kind in ("BEARER_INACTIVE", "PS_DEREGISTERED") and not lost_now:
            lost_now = True
            loss_times.append(t)

    for e in events:
        t = parse_ts(e["timestamp_utc"])
        et, p = e["event_type"], e["payload"]
        if et == "SIM_STATE":
            if p.get("state") != sim:
                sim = p.get("state")
                restart_window(t)
        elif et == "RADIO_STATE":
            if p.get("kind") == "STATE" and p.get("state") != radio:
                if radio == "OFF" and p.get("state") == "ON":
                    cycle_seen = True
                radio = p.get("state")
                restart_window(t)
        elif et == "REGISTRATION" and p.get("domain") == "PS":
            prev = ps
            ps = p.get("state")
            sample_times.append(t)
            if ps not in PS_REGISTERED_STATES:
                if ever_active:
                    mark_loss("PS_DEREGISTERED", t)
            elif prev not in PS_REGISTERED_STATES:
                restart_window(t)
                sample_times.append(t)
        elif et == "BEARER":
            if e["cid"] is None:
                continue
            active = p.get("active") == 2
            was = any(bearer_active.values())
            bearer_active[e["cid"]] = active
            if active:
                if lost_now:
                    transient_losses += 1
                    recovered_after_loss = True
                    lost_now = False
                ever_active = True
                if not was:
                    restart_window(t)
            elif ever_active and not any(bearer_active.values()):
                mark_loss("BEARER_INACTIVE", t)
        elif et == "VALIDATION":
            v = p.get("verdict")
            if v in ("VALID", "INVALID"):
                last_verdict, last_verdict_t = v, t
                if v == "VALID":
                    valid_times.append(t)
                elif ever_active:
                    loss_markers.setdefault("VALIDATION_INVALID", t)
        elif et == "DNS_PROBE":
            if p.get("result") != "OK" and ever_active:
                loss_markers.setdefault("DNS_TIMEOUT", t)
        elif et == "VENDOR_DEACT":
            vendor_codes.append(str(p.get("raw_code")))
            if ever_active:
                loss_markers.setdefault("VENDOR_DEACT", t)
        elif et == "DSRM_ACTION":
            stage, act = p.get("stage"), p.get("action")
            (dsrm_exec if stage in ("EXECUTED", "COMPLETED") else dsrm_sel).append(f"{act}:{stage}")
        elif et == "OPERATOR_ACTION":
            if p.get("action") == "RADIO_CYCLE":
                cycle_seen = True
            restart_window(t)
        elif et == "CAPTURE_GAP":
            gaps.append((t, t + float(p.get("seconds", 0))))

    loss_sequence = [k for k, _ in sorted(loss_markers.items(), key=lambda kv: kv[1])]
    first_loss = loss_times[0] if loss_times else None
    connected = any(bearer_active.values())
    reason = None

    if sim != "LOADED":
        outcome = "LOST"
    elif radio != "ON":
        outcome = "LOST" if ever_active else "INCONCLUSIVE"
        reason = None if ever_active else "RADIO_NOT_CONFIRMED_ON"
    elif ps not in PS_REGISTERED_STATES or not connected:
        outcome = "LOST"
    elif last_verdict == "INVALID":
        outcome = QUALIFICATION_OUTCOMES["connected_with_INVALID"]
    elif last_verdict != "VALID":
        outcome = (QUALIFICATION_OUTCOMES["observed_cycle_and_connected_without_VALID"] if cycle_seen
                   else QUALIFICATION_OUTCOMES["connected_without_VALID"])
        reason = None if cycle_seen else "VALIDATION_PENDING"
    else:
        outcome, reason = "VALIDATED_STABLE", None
        pts = sorted(set([window_start] + [x for x in sample_times if x >= window_start] + [end]))
        if any(gs < end and ge > window_start for gs, ge in gaps):
            outcome, reason = "INCONCLUSIVE", "CAPTURE_GAP"
        elif any(b2 - a2 > th["max_sample_gap_seconds"] for a2, b2 in zip(pts, pts[1:])):
            outcome, reason = "INCONCLUSIVE", "SAMPLE_GAP"
        elif end - window_start < th["stable_window_seconds"]:
            outcome, reason = "INCONCLUSIVE", "WINDOW_INCOMPLETE"
        elif b["validation_mode"] == "ACTIVE_PROBE":
            vts = sorted(set([window_start] + [x for x in valid_times if x >= window_start] + [end]))
            if any(b2 - a2 > th["max_sample_gap_seconds"] for a2, b2 in zip(vts, vts[1:])) or \
                    end - max(valid_times) > th["active_probe_max_validation_age_seconds"]:
                outcome, reason = "INCONCLUSIVE", "VALIDATION_STALE"

    return {
        "outcome": outcome,
        "inconclusive_reason": reason,
        "loss_sequence": loss_sequence,
        "first_loss_t": first_loss,
        "bearer_recovered": recovered_after_loss,
        "transient_losses": transient_losses,
        "vendor_codes": vendor_codes,
        "dsrm_executed": dsrm_exec,
        "dsrm_selected_not_executed": dsrm_sel,
        "window_start_t": window_start,
    }


def propose(outcome: str) -> str:
    """Advisory only. Never returns an executable action."""
    return {
        "VALIDATED_STABLE": "NO_ACTION",
        "INCONCLUSIVE": "OBSERVE",
        "UNKNOWN": "OBSERVE",
        "NOT_QUALIFIED": "ESCALATE_FOR_REVIEW",
        "FAIL_INTERNET_VALIDATION": "ESCALATE_FOR_REVIEW",
        "LOST": "ESCALATE_FOR_REVIEW",
    }[outcome]


def evaluate(bundle: dict, contract: dict) -> dict:
    """Evaluate a raw bundle against the contract. Returns a result dict, never raises
    except for programming errors; fail-closed stops are reported as abort."""
    result = {
        "fixture_id": bundle.get("fixture_id") if isinstance(bundle, dict) else None,
        "abort": None,
        "physical_qualification": "NOT_EXECUTED",
        "root_cause": "UNKNOWN",
        "execution_enabled": False,
    }
    errs = validate_contract(contract)
    if errs:
        result["abort"] = "CONTRACT_INVALID"
        result["contract_errors"] = errs
        return result
    try:
        b = load_bundle(bundle)
    except EvidenceAbort as e:
        result["abort"] = e.reason
        result["abort_detail"] = e.detail
        return result

    # Requested actions are always denied; nothing is executed or simulated.
    result["action_decisions"] = {a: "DENY" for a in b["action_requests"]}
    result["evidence_class"] = b["provenance"]["kind"]

    events = b["events"]
    if any(e["source_clock_kind"] == "UNKNOWN" for e in events):
        result.update(outcome="INCONCLUSIVE", inconclusive_reason="CLOCK_UNKNOWN",
                      subscriptions=[], per_subscription={}, proposal="OBSERVE",
                      dsds="NOT_QUALIFIED_SINGLE_SIM_EVIDENCE")
        return result

    subs, ignored = _mapping(events)
    result["subscriptions"] = sorted(subs)
    result["ignored_phones"] = sorted(ignored)
    result["unattached_events"] = sum(1 for e in events if e["event_type"] not in ("CAPTURE_GAP", "OPERATOR_ACTION")
                                      and _attach(e, subs) is None
                                      and not (e["event_type"] == "SIM_STATE"))
    result["dsds"] = ("NOT_QUALIFIED_OFFLINE_REQUIRES_PHYSICAL" if len(subs) >= 2
                      else "NOT_QUALIFIED_SINGLE_SIM_EVIDENCE")
    if not subs:
        result.update(outcome="UNKNOWN", inconclusive_reason="NO_SUBSCRIPTION_MAPPING",
                      per_subscription={}, proposal="OBSERVE")
        return result

    global_events = [e for e in events if e["event_type"] in ("OPERATOR_ACTION", "CAPTURE_GAP")
                     and e["phone_id"] is None and e["subscription_ref"] is None]
    per: dict[str, dict] = {}
    for sub in sorted(subs):
        mine = [e for e in events if _attach(e, subs) == sub or e in global_events]
        per[sub] = _evaluate_sub(sub, mine, b, contract)

    result["per_subscription"] = {s: r["outcome"] for s, r in per.items()}
    result["detail"] = per
    primary = sorted(subs)[0]
    pr = per[primary]
    result["outcome"] = pr["outcome"]
    result["inconclusive_reason"] = pr["inconclusive_reason"]
    for k in ("loss_sequence", "bearer_recovered", "transient_losses", "vendor_codes",
              "dsrm_executed", "dsrm_selected_not_executed"):
        result[k] = pr[k]

    # Temporal causality: only actions before the first loss can be prior candidates.
    first_loss = pr["first_loss_t"]
    ops = [(parse_ts(e["timestamp_utc"]), e["payload"].get("action")) for e in events
           if e["event_type"] == "OPERATOR_ACTION"]
    if first_loss is None:
        result["prior_cause_candidates"] = sorted({a for _, a in ops})
        result["post_failure_actions"] = []
    else:
        result["prior_cause_candidates"] = sorted({a for t, a in ops if t < first_loss})
        result["post_failure_actions"] = sorted({a for t, a in ops if t >= first_loss})
    result["proposal"] = propose(result["outcome"])
    return result


def same_initial_cause(a: dict, b: dict) -> bool:
    """Two results share an initial condition only if first vendor code and loss order match."""
    if a.get("abort") or b.get("abort"):
        return False
    va, vb = a.get("vendor_codes") or [], b.get("vendor_codes") or []
    return bool(va) and bool(vb) and va[0] == vb[0] and a.get("loss_sequence") == b.get("loss_sequence")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="N1I recovery contract offline evaluator (read-only).")
    ap.add_argument("--contract", required=True, type=Path)
    ap.add_argument("--bundle", type=Path, help="evidence bundle to evaluate")
    ap.add_argument("--validate-contract", action="store_true", help="only validate the contract")
    args = ap.parse_args(argv)
    contract = json.loads(args.contract.read_text(encoding="utf-8"))
    if args.validate_contract:
        errs = validate_contract(contract)
        print(json.dumps({"contract_errors": errs}, indent=2))
        return 0 if not errs else 1
    if args.bundle is None:
        ap.error("--bundle is required unless --validate-contract")
    bundle = json.loads(args.bundle.read_text(encoding="utf-8"))
    res = evaluate(bundle, contract)
    res.pop("detail", None)
    print(json.dumps(res, indent=2, sort_keys=True))
    return 0 if not res.get("abort") else 2


if __name__ == "__main__":
    sys.exit(main())
