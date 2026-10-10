#!/usr/bin/env python3
"""N1I Telephony Evidence Normalizer and Qualification Contract v1.2: pure offline evaluator.

Reads one contract (JSON) and one evidence bundle (JSON) and returns a verdict.
Recovery execution is out of scope pending root-cause identification: this
module never executes, schedules or simulates a device action.

READ-ONLY CONTRACT
  - No device contact, no subprocess, no network, no file writes.
  - The CLI prints the result as JSON on stdout and nothing else.

Bundle format (bundle_version 1):
  {
    "bundle_version": 1,
    "fixture_id": "...",
    "provenance": {
      "kind": "SYNTHETIC_ABSTRACTION" | "SANITIZED_CAPTURE",
      "basis": "...",
      "network_config": {<field>: {"status": "OBSERVED" | "UNKNOWN", "value": ..., "evidence_ref": ...}}
    },
    "validation_mode": "PASSIVE_LOG" | "ACTIVE_PROBE",
    "capture": {"start_utc": "...Z", "end_utc": "...Z"},
    "action_requests": [{"action": "..."}],
    "events_sha256": "<sha256 of canonical JSON of events>",
    "events": [ <event>, ... ]
  }

Fail-closed order: integrity (SHA-256) before anything inside events is parsed,
then provenance, schema, duplicates, vendor-code form, identity timeline.
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

CONTRACT_ID = "N1I_TELEPHONY_EVIDENCE_NORMALIZER"
CONTRACT_VERSION = "1.2"
CONTRACT_STATUS = "DESIGN_ONLY_NOT_PRODUCTION_AUTHORIZED"
CONTRACT_SCOPE = "EVIDENCE_NORMALIZATION_AND_QUALIFICATION_ONLY"
RECOVERY_EXECUTION = "OUT_OF_SCOPE_PENDING_ROOT_CAUSE"
SCOPE_EXCLUSIONS = ("IMS_REGISTRATION", "IMS_BEARER", "VOICE", "SMS_MMS")

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
    "DEFAULT_DATA",
)

CLOCK_KINDS = ("UTC_ALIGNED", "DEVICE_REALTIME_ALIGNED", "UNKNOWN")

VALIDATION_BASES = ("CAPABILITY_SNAPSHOT", "PROBE", "TRANSITION")

NETWORK_CONFIG_FIELDS = (
    "private_dns_mode", "dns_servers", "connectivity_check_urls", "connectivity_check_source",
    "apn_name", "apn_protocol", "apn_roaming_protocol",
)
EVIDENCE_REQUIREMENTS = ("validation_mode",) + NETWORK_CONFIG_FIELDS

GATES = (
    "G00_PROVENANCE", "G01_SCHEMA", "G02_MAPPING", "G03_ORDERING",
    "G04_BEARER_VS_INTERNET", "G05_VENDOR_CAUSE", "G06_DSRM_ATTRIBUTION",
    "G07_RECOVERY_CYCLE", "G08_TEMPORAL_CAUSALITY", "G09_STOCK_PARITY",
    "G10_SAFETY", "G11_NEGATIVE_CASES", "G12_DUAL_SIM",
)

QUALIFICATION_REQUIRED = (
    "explicit_time_scoped_subscription_mapping", "explicit_default_data_subscription",
    "sim_ready", "radio_on", "ps_registered", "bearer_active",
    "continuous_registration_samples", "continuous_bearer_samples",
    "continuous_validation_samples", "no_invalid_or_unknown_in_window", "stable_window",
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
    "no_default_data_evidence": "INCONCLUSIVE",
}

VALIDATION_MODES = ("PASSIVE_LOG", "ACTIVE_PROBE")
VALIDATION_MODE_RULES = {
    "PASSIVE_LOG": "CAPABILITY_SNAPSHOT_VALID_samples_continuous_TRANSITION_changes_state_only",
    "ACTIVE_PROBE": "PROBE_VALID_samples_bound_to_active_default_cid_continuous_last_within_max_age",
}
WINDOW_RESTART_EVENTS = (
    "IDENTITY", "SIM", "RADIO", "REGISTRATION", "BEARER", "DEFAULT_DATA",
    "OPERATOR_ACTION", "CAPTURE_GAP", "VALIDATION_TRANSITION",
)

OUTCOMES = (
    "VALIDATED_STABLE", "FAIL_INTERNET_VALIDATION", "NOT_QUALIFIED", "LOST",
    "INCONCLUSIVE", "UNKNOWN",
)

ABORT_REASONS = (
    "CONTRACT_INVALID", "SHA256_MISMATCH", "PROVENANCE", "SCHEMA", "DUPLICATE_CONFLICT",
    "IDENTITY_CONFLICT", "VENDOR_CODE_CONFLICT",
)

FAIL_CLOSED_RESULTS = ("INCONCLUSIVE", "UNKNOWN")
PROPOSALS = ("NO_ACTION", "OBSERVE", "ESCALATE_FOR_REVIEW")
PROVENANCE_KINDS = ("SYNTHETIC_ABSTRACTION", "SANITIZED_CAPTURE")
PS_REGISTERED_STATES = ("HOME", "ROAMING")
HEALTH_TYPES = ("RADIO_STATE", "REGISTRATION", "BEARER", "VALIDATION", "DNS_PROBE",
                "VENDOR_DEACT", "DSRM_ACTION")

ASSERT_KEYS = (
    "abort", "outcome", "root_cause", "subscriptions", "ignored_phones", "bearer_recovered",
    "loss_sequence", "vendor_codes", "dsrm_executed", "dsrm_selected_not_executed",
    "prior_cause_candidates", "post_failure_actions", "action_decisions", "dsds",
    "inconclusive_reason", "transient_losses", "per_subscription", "default_data_subscription",
    "reject_sequence", "provenance_unknown", "out_of_scope_events", "window_restart_cause",
    "unattached_events",
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
    need(c.get("scope") == CONTRACT_SCOPE, "scope_must_be_normalization_only")
    need(c.get("recovery_execution") == RECOVERY_EXECUTION, "recovery_execution_out_of_scope")
    need(c.get("scope_exclusions") == list(SCOPE_EXCLUSIONS), "scope_exclusions_exact")
    need(c.get("execution_enabled") is False, "execution_enabled_must_be_false")

    auth = c.get("authority")
    need(isinstance(auth, dict) and set(auth) == set(AUTHORITY_KEYS), "authority_key_set")
    need(isinstance(auth, dict) and all(v is False for v in auth.values()), "authority_all_false")

    need(c.get("evidence_requirements") == list(EVIDENCE_REQUIREMENTS), "evidence_requirements_exact")
    need(c.get("unknown_evidence_rule") == "explicit_UNKNOWN_never_inferred", "unknown_evidence_rule")

    s = c.get("event_schema", {})
    need(s.get("required_fields") == list(REQUIRED_FIELDS), "required_fields_exact")
    need(s.get("allowed_event_types") == list(EVENT_TYPES), "event_types_exact_closed_set")
    need(s.get("source_clock_kinds") == list(CLOCK_KINDS), "clock_kinds_exact")
    need(s.get("validation_bases") == list(VALIDATION_BASES), "validation_bases_exact")
    need("unknown_identity" in s and s.get("unknown_identity") is None, "unknown_identity_null")
    need(s.get("identity_rule") == "time_scoped_explicit_mapping_no_inference_no_retroactive_application",
         "identity_rule")
    need(s.get("identity_conflict") == "ABORT", "identity_conflict_abort")
    need(s.get("deduplication_key") == ["source_id", "sequence"], "dedup_key")
    need(s.get("duplicate_conflict") == "ABORT", "duplicate_conflict_abort")
    need(s.get("extra_fields") == "REJECT", "extra_fields_reject")
    need(s.get("vendor_code") == "opaque_single_canonical_form_no_decode", "vendor_code_opaque")
    need(s.get("vendor_code_form_conflict") == "ABORT", "vendor_code_conflict_abort")

    q = c.get("qualification", {})
    need(q.get("required") == list(QUALIFICATION_REQUIRED), "qualification_required_exact")
    need(q.get("thresholds") == QUALIFICATION_THRESHOLDS, "qualification_thresholds_exact")
    need(q.get("thresholds_binding") is True, "thresholds_binding")
    need(q.get("outcomes") == QUALIFICATION_OUTCOMES, "qualification_outcomes_exact")
    need(q.get("validation_modes") == list(VALIDATION_MODES), "validation_modes")
    need(q.get("validation_mode_rules") == VALIDATION_MODE_RULES, "validation_mode_rules_exact")
    need(q.get("window_restart_events") == list(WINDOW_RESTART_EVENTS), "window_restart_events_exact")
    need(q.get("overall_verdict_rule") == "default_data_subscription_only_never_inferred",
         "overall_verdict_rule")

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
        if "abort" in a:
            need(a["abort"] in ABORT_REASONS, f"fixture_abort_vocab:{fid}")
        if "outcome" in a:
            need(a["outcome"] in OUTCOMES, f"fixture_outcome_vocab:{fid}")
        if "root_cause" in a:
            need(a["root_cause"] == "UNKNOWN", f"fixture_root_cause_must_stay_unknown:{fid}")
        for sub in (a.get("per_subscription") or {}).values():
            need(sub in OUTCOMES, f"fixture_per_sub_vocab:{fid}")
        if "action_decisions" in a:
            need(all(v == "DENY" for v in a["action_decisions"].values()), f"fixture_action_must_deny:{fid}")
        if gates and "G11_NEGATIVE_CASES" in gates:
            need("abort" in a or a.get("outcome") in FAIL_CLOSED_RESULTS,
                 f"negative_fixture_must_fail_closed:{fid}")
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
    for fmt in ("%Y-%m-%dT%H:%M:%S.%fZ", "%Y-%m-%dT%H:%M:%SZ"):
        try:
            return datetime.strptime(value, fmt).replace(tzinfo=timezone.utc).timestamp()
        except ValueError:
            continue
    raise EvidenceAbort("SCHEMA", f"bad timestamp {value!r}")


def canonical_vendor_code(payload: dict) -> str:
    """One opaque canonical form for a vendor code given as hex string and/or decimal int.

    This changes only the number base of the representation. It never attaches a meaning.
    """
    forms: list[int] = []
    raw = payload.get("raw_code")
    if raw is not None:
        if not isinstance(raw, str):
            raise EvidenceAbort("SCHEMA", "raw_code must be a string")
        try:
            forms.append(int(raw, 16) if raw.lower().startswith("0x") else int(raw, 10))
        except ValueError as e:
            raise EvidenceAbort("SCHEMA", f"raw_code not numeric: {raw!r}") from e
    res = payload.get("res")
    if res is not None:
        if not isinstance(res, int) or isinstance(res, bool) or res < 0:
            raise EvidenceAbort("SCHEMA", "res must be a non-negative int")
        forms.append(res)
    if not forms:
        raise EvidenceAbort("SCHEMA", "VENDOR_DEACT needs raw_code or res")
    if len(set(forms)) != 1:
        raise EvidenceAbort("VENDOR_CODE_CONFLICT", f"forms disagree: {payload!r}")
    return f"0x{forms[0]:X}"


def _check_network_config(nc) -> list[str]:
    if not isinstance(nc, dict) or set(nc) != set(NETWORK_CONFIG_FIELDS):
        raise EvidenceAbort("PROVENANCE", "network_config must have exactly the required fields")
    unknown = []
    for k in NETWORK_CONFIG_FIELDS:
        v = nc[k]
        if not isinstance(v, dict) or set(v) != {"status", "value", "evidence_ref"}:
            raise EvidenceAbort("PROVENANCE", f"network_config.{k} shape")
        if v["status"] == "OBSERVED":
            if v["value"] is None or not isinstance(v["evidence_ref"], str) or not v["evidence_ref"]:
                raise EvidenceAbort("PROVENANCE", f"network_config.{k} OBSERVED needs value and evidence_ref")
        elif v["status"] == "UNKNOWN":
            if v["value"] is not None or v["evidence_ref"] is not None:
                raise EvidenceAbort("PROVENANCE", f"network_config.{k} UNKNOWN must not carry a value")
            unknown.append(k)
        else:
            raise EvidenceAbort("PROVENANCE", f"network_config.{k} status")
    return unknown


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
    if e["event_type"] == "VALIDATION":
        p = e["payload"]
        if p.get("verdict") not in ("VALID", "INVALID", "UNKNOWN", "NOT_OBSERVED"):
            raise EvidenceAbort("SCHEMA", "VALIDATION verdict")
        if p.get("basis") not in VALIDATION_BASES:
            raise EvidenceAbort("SCHEMA", "VALIDATION basis")
    if e["event_type"] == "VENDOR_DEACT":
        canonical_vendor_code(e["payload"])
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
    unknown = _check_network_config(prov.get("network_config"))
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
        "provenance_unknown": unknown,
        "validation_mode": bundle["validation_mode"],
        "start": start,
        "end": end,
        "action_requests": [r["action"] for r in reqs],
        "events": ordered,
        "duplicates_dropped": len(events) - len(seen),
    }


# ---------------------------------------------------------------------------
# Identity: time-scoped, explicit, never retroactive
# ---------------------------------------------------------------------------

def attribute(events: list) -> dict:
    """Walk events in time order and attach each to a subscription using only the
    mapping that is in force at that moment. Raises IDENTITY_CONFLICT on contradictions."""
    phone_map: dict[int, tuple[str, int]] = {}   # phone -> (sub, slot), current
    sub_map: dict[str, tuple[int, int]] = {}     # sub -> (phone, slot), current
    empty_phones: set[int] = set()
    per_sub: dict[str, list] = {}
    ever_mapped: set[str] = set()
    ignored_phones: set[int] = set()
    unattached = 0
    defaults: list[tuple[float, str | None]] = []

    def add(sub: str, e: dict) -> None:
        per_sub.setdefault(sub, []).append(e)

    for e in events:
        et, p = e["event_type"], e["payload"]
        phone, slot, sub = e["phone_id"], e["slot_id"], e["subscription_ref"]
        t = parse_ts(e["timestamp_utc"])

        if et == "SIM_STATE":
            st = p.get("state")
            if st == "LOADED":
                if None in (phone, slot, sub):
                    unattached += 1
                    continue
                if sub in sub_map and sub_map[sub] != (phone, slot):
                    raise EvidenceAbort("IDENTITY_CONFLICT", f"{sub} already on {sub_map[sub]} at {e['timestamp_utc']}")
                if phone in phone_map and phone_map[phone][0] != sub:
                    raise EvidenceAbort("IDENTITY_CONFLICT", f"phone {phone} already holds {phone_map[phone][0]}")
                if phone in phone_map and phone_map[phone][1] != slot:
                    raise EvidenceAbort("IDENTITY_CONFLICT", f"phone {phone} slot changed without ABSENT")
                phone_map[phone] = (sub, slot)
                sub_map[sub] = (phone, slot)
                empty_phones.discard(phone)
                ever_mapped.add(sub)
                add(sub, e)
            elif st == "ABSENT" and phone is not None:
                if phone in phone_map:
                    old_sub, _ = phone_map.pop(phone)
                    sub_map.pop(old_sub, None)
                    add(old_sub, e)
                empty_phones.add(phone)
            else:
                unattached += 1
            continue

        if et == "DEFAULT_DATA":
            defaults.append((t, sub, sub is not None and sub in sub_map))
            if sub is not None and sub in sub_map:
                add(sub, e)
            continue

        if et in ("OPERATOR_ACTION", "CAPTURE_GAP") and phone is None and sub is None:
            for s in sub_map:
                add(s, e)
            per_sub.setdefault("__global__", []).append(e)
            continue

        target = None
        if sub is not None:
            if sub in sub_map:
                mp, ms = sub_map[sub]
                if phone is not None and phone != mp:
                    raise EvidenceAbort("IDENTITY_CONFLICT", f"{sub} event on phone {phone}, mapped to {mp}")
                if slot is not None and slot != ms:
                    raise EvidenceAbort("IDENTITY_CONFLICT", f"{sub} event on slot {slot}, mapped to {ms}")
                target = sub
        elif phone is not None:
            if phone in phone_map:
                ms_sub, ms_slot = phone_map[phone]
                if slot is not None and slot != ms_slot:
                    raise EvidenceAbort("IDENTITY_CONFLICT", f"phone {phone} event on slot {slot}, mapped to {ms_slot}")
                target = ms_sub
            elif phone in empty_phones:
                ignored_phones.add(phone)
                continue
        if target is None:
            if et in HEALTH_TYPES or et == "ACTION_RESULT":
                unattached += 1
            continue
        add(target, e)

    return {
        "per_sub": {k: v for k, v in per_sub.items() if k != "__global__"},
        "global": per_sub.get("__global__", []),
        "subscriptions": sorted(ever_mapped),
        "mapped_at_end": dict(sub_map),
        "ignored_phones": sorted(ignored_phones - {p for p, _ in sub_map.values()}),
        "unattached": unattached,
        "defaults": defaults,
    }


# ---------------------------------------------------------------------------
# Per-subscription evaluation
# ---------------------------------------------------------------------------

def _continuous(samples: list, start: float, end: float, gap: float) -> bool:
    inside = [x for x in samples if start <= x <= end]
    if not inside:
        return False
    pts = [start] + inside + [end]
    return all(b - a <= gap for a, b in zip(pts, pts[1:]))


def _evaluate_sub(events: list, b: dict, c: dict) -> dict:
    th = c["qualification"]["thresholds"]
    gap_max = th["max_sample_gap_seconds"]
    end = b["end"]
    mode = b["validation_mode"]

    sim = radio = ps = None
    bearers: dict[int, bool] = {}
    ever_active = False
    window_start = b["start"]
    restart_cause = None
    last_verdict = None
    cycle_seen = False
    reg_samples: list[float] = []
    bearer_samples: list[float] = []
    val_samples: list[float] = []
    unbound_probes = 0
    loss_markers: dict[str, float] = {}
    loss_times: list[float] = []
    lost_now = False
    transient_losses = 0
    recovered = False
    vendor_codes: list[str] = []
    reject_sequence: list[int] = []
    dsrm_exec: list[str] = []
    dsrm_sel: list[str] = []
    out_of_scope = 0

    def restart(t: float, cause: str, keep_verdict: bool = False) -> None:
        nonlocal window_start, restart_cause, last_verdict
        window_start, restart_cause = t, cause
        if not keep_verdict:
            last_verdict = None
        reg_samples.clear()
        bearer_samples.clear()
        val_samples.clear()

    def active_cids() -> set:
        return {k for k, v in bearers.items() if v}

    def mark_loss(kind: str, t: float) -> None:
        nonlocal lost_now
        loss_markers.setdefault(kind, t)
        if kind in ("BEARER_INACTIVE", "PS_DEREGISTERED", "SIM_ABSENT") and not lost_now:
            lost_now = True
            loss_times.append(t)

    for e in events:
        t = parse_ts(e["timestamp_utc"])
        et, p = e["event_type"], e["payload"]
        if et == "SIM_STATE":
            st = p.get("state")
            if st != sim:
                sim = st
                restart(t, "IDENTITY" if st == "LOADED" else "SIM")
                if st == "ABSENT" and ever_active:
                    mark_loss("SIM_ABSENT", t)
        elif et == "RADIO_STATE":
            if p.get("kind") == "STATE" and p.get("state") != radio:
                if radio == "OFF" and p.get("state") == "ON":
                    cycle_seen = True
                radio = p.get("state")
                restart(t, "RADIO")
        elif et == "REGISTRATION":
            if p.get("domain") != "PS":
                if p.get("domain") == "IMS":
                    out_of_scope += 1
                continue
            if p.get("reject_cause") is not None:
                reject_sequence.append(p["reject_cause"])
            prev, ps = ps, p.get("state")
            if ps in PS_REGISTERED_STATES:
                if prev not in PS_REGISTERED_STATES:
                    restart(t, "REGISTRATION")
                reg_samples.append(t)
            else:
                if prev in PS_REGISTERED_STATES:
                    restart(t, "REGISTRATION")
                if ever_active:
                    mark_loss("PS_DEREGISTERED", t)
        elif et == "BEARER":
            if "ims" in str(p.get("apn_type", "")).lower().split(","):
                out_of_scope += 1
                continue
            if e["cid"] is None:
                continue
            was = active_cids()
            active = p.get("active") == 2
            bearers[e["cid"]] = active
            if active:
                if lost_now:
                    transient_losses += 1
                    recovered = True
                    lost_now = False
                ever_active = True
                if not was:
                    restart(t, "BEARER")
                bearer_samples.append(t)
            elif was and not active_cids():
                restart(t, "BEARER")
                if ever_active:
                    mark_loss("BEARER_INACTIVE", t)
        elif et == "VALIDATION":
            v, basis = p.get("verdict"), p.get("basis")
            if mode == "ACTIVE_PROBE" and basis == "PROBE":
                if p.get("bound_cid") not in active_cids():
                    unbound_probes += 1
                    continue
            if v in ("INVALID", "UNKNOWN"):
                if ever_active and v == "INVALID":
                    loss_markers.setdefault("VALIDATION_INVALID", t)
                restart(t, "VALIDATION_TRANSITION")
                last_verdict = v
            elif v == "VALID":
                last_verdict = "VALID"
                counts = (basis == "CAPABILITY_SNAPSHOT") if mode == "PASSIVE_LOG" else (basis == "PROBE")
                if counts:
                    val_samples.append(t)
        elif et == "DNS_PROBE":
            if p.get("result") != "OK" and ever_active:
                loss_markers.setdefault("DNS_TIMEOUT", t)
        elif et == "VENDOR_DEACT":
            vendor_codes.append(canonical_vendor_code(p))
            if ever_active:
                loss_markers.setdefault("VENDOR_DEACT", t)
        elif et == "DSRM_ACTION":
            stage, act = p.get("stage"), p.get("action")
            (dsrm_exec if stage in ("EXECUTED", "COMPLETED") else dsrm_sel).append(f"{act}:{stage}")
        elif et == "OPERATOR_ACTION":
            if p.get("action") == "RADIO_CYCLE":
                cycle_seen = True
            restart(t, "OPERATOR_ACTION")
        elif et == "DEFAULT_DATA":
            restart(t, "DEFAULT_DATA", keep_verdict=True)
        elif et == "CAPTURE_GAP":
            restart(t + float(p.get("seconds", 0)), "CAPTURE_GAP")

    loss_sequence = [k for k, _ in sorted(loss_markers.items(), key=lambda kv: kv[1])]
    connected = bool(active_cids())
    reason = None

    if sim != "LOADED":
        outcome = "LOST"
    elif radio != "ON":
        outcome = "LOST" if ever_active else "INCONCLUSIVE"
        reason = None if ever_active else "RADIO_NOT_CONFIRMED_ON"
    elif ps not in PS_REGISTERED_STATES or not connected:
        outcome = "LOST"
    elif last_verdict in ("INVALID",):
        outcome = QUALIFICATION_OUTCOMES["connected_with_INVALID"]
    elif last_verdict != "VALID":
        if cycle_seen:
            outcome = QUALIFICATION_OUTCOMES["observed_cycle_and_connected_without_VALID"]
        elif mode == "ACTIVE_PROBE" and unbound_probes:
            outcome, reason = "INCONCLUSIVE", "PROBE_NOT_BOUND"
        else:
            outcome, reason = QUALIFICATION_OUTCOMES["connected_without_VALID"], "VALIDATION_PENDING"
    elif end - window_start < th["stable_window_seconds"]:
        outcome, reason = "INCONCLUSIVE", "WINDOW_INCOMPLETE"
    elif mode == "ACTIVE_PROBE" and (not _continuous(val_samples, window_start, end, gap_max)
                                     or end - max(val_samples) > th["active_probe_max_validation_age_seconds"]):
        outcome, reason = "INCONCLUSIVE", "VALIDATION_STALE"
    elif mode == "PASSIVE_LOG" and not _continuous(val_samples, window_start, end, gap_max):
        outcome, reason = "INCONCLUSIVE", "VALIDATION_NOT_CONTINUOUS"
    elif not _continuous(reg_samples, window_start, end, gap_max):
        outcome, reason = "INCONCLUSIVE", "REGISTRATION_NOT_CONTINUOUS"
    elif not _continuous(bearer_samples, window_start, end, gap_max):
        outcome, reason = "INCONCLUSIVE", "BEARER_NOT_CONTINUOUS"
    else:
        outcome = "VALIDATED_STABLE"

    return {
        "outcome": outcome,
        "inconclusive_reason": reason,
        "window_restart_cause": restart_cause,
        "loss_sequence": loss_sequence,
        "first_loss_t": loss_times[0] if loss_times else None,
        "bearer_recovered": recovered,
        "transient_losses": transient_losses,
        "vendor_codes": vendor_codes,
        "reject_sequence": reject_sequence,
        "dsrm_executed": dsrm_exec,
        "dsrm_selected_not_executed": dsrm_sel,
        "out_of_scope_events": out_of_scope,
    }


def propose(outcome: str) -> str:
    """Advisory only. Never an action; recovery execution is out of scope."""
    return {
        "VALIDATED_STABLE": "NO_ACTION",
        "INCONCLUSIVE": "OBSERVE",
        "UNKNOWN": "OBSERVE",
        "NOT_QUALIFIED": "ESCALATE_FOR_REVIEW",
        "FAIL_INTERNET_VALIDATION": "ESCALATE_FOR_REVIEW",
        "LOST": "ESCALATE_FOR_REVIEW",
    }[outcome]


SUMMARY_KEYS = ("loss_sequence", "bearer_recovered", "transient_losses", "vendor_codes", "reject_sequence",
                "dsrm_executed", "dsrm_selected_not_executed", "out_of_scope_events", "window_restart_cause")


def evaluate(bundle: dict, contract: dict) -> dict:
    """Evaluate a raw bundle against the contract. Fail-closed stops are reported as abort."""
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
        events = b["events"]
        if any(e["source_clock_kind"] == "UNKNOWN" for e in events):
            ident = None
        else:
            ident = attribute(events)
    except EvidenceAbort as e:
        result["abort"] = e.reason
        result["abort_detail"] = e.detail
        return result

    # Requested actions are always denied; nothing is executed or simulated.
    result["action_decisions"] = {a: "DENY" for a in b["action_requests"]}
    result["evidence_class"] = b["provenance"]["kind"]
    result["provenance_unknown"] = b["provenance_unknown"]
    result["network_config"] = {k: v["value"] for k, v in b["provenance"]["network_config"].items()
                                if v["status"] == "OBSERVED"}
    result["validation_mode"] = b["validation_mode"]

    if ident is None:
        result.update(outcome="INCONCLUSIVE", inconclusive_reason="CLOCK_UNKNOWN", subscriptions=[],
                      per_subscription={}, proposal="OBSERVE", default_data_subscription=None,
                      dsds="NOT_QUALIFIED_SINGLE_SIM_EVIDENCE")
        return result

    subs = ident["subscriptions"]
    result["subscriptions"] = subs
    result["ignored_phones"] = ident["ignored_phones"]
    result["unattached_events"] = ident["unattached"]
    result["dsds"] = ("NOT_QUALIFIED_OFFLINE_REQUIRES_PHYSICAL" if len(subs) >= 2
                      else "NOT_QUALIFIED_SINGLE_SIM_EVIDENCE")
    if not subs:
        result.update(outcome="UNKNOWN", inconclusive_reason="NO_SUBSCRIPTION_MAPPING",
                      per_subscription={}, proposal="OBSERVE", default_data_subscription=None)
        return result

    per = {s: _evaluate_sub(ident["per_sub"].get(s, []), b, contract) for s in subs}
    result["per_subscription"] = {s: r["outcome"] for s, r in per.items()}
    result["detail"] = per

    # Overall verdict: only the explicitly evidenced default-data subscription.
    default = ident["defaults"][-1][1] if ident["defaults"] else None
    default_was_mapped = ident["defaults"][-1][2] if ident["defaults"] else False
    result["default_data_subscription"] = default
    if default is None:
        result.update(outcome=QUALIFICATION_OUTCOMES["no_default_data_evidence"],
                      inconclusive_reason="NO_DEFAULT_DATA_EVIDENCE")
        for k in SUMMARY_KEYS:
            result[k] = None
        first_loss = None
    elif not default_was_mapped or default not in ident["mapped_at_end"]:
        result.update(outcome="INCONCLUSIVE", inconclusive_reason="DEFAULT_DATA_UNMAPPED")
        for k in SUMMARY_KEYS:
            result[k] = None
        first_loss = None
    else:
        pr = per[default]
        result["outcome"] = pr["outcome"]
        result["inconclusive_reason"] = pr["inconclusive_reason"]
        for k in SUMMARY_KEYS:
            result[k] = pr[k]
        first_loss = pr["first_loss_t"]
        if result["outcome"] == "VALIDATED_STABLE" and ident["unattached"]:
            result.update(outcome="INCONCLUSIVE", inconclusive_reason="UNATTRIBUTED_EVIDENCE")

    # Temporal ordering only: prior operator actions are NOT demonstrated causes.
    ops = [(parse_ts(e["timestamp_utc"]), e["payload"].get("action")) for e in events
           if e["event_type"] == "OPERATOR_ACTION"]
    if first_loss is None:
        result["prior_cause_candidates"] = sorted({a for _, a in ops})  # Legacy key: temporal only
        result["post_failure_actions"] = []
    else:
        result["prior_cause_candidates"] = sorted({a for t, a in ops if t < first_loss})  # Temporal only
        result["post_failure_actions"] = sorted({a for t, a in ops if t >= first_loss})
    result["proposal"] = propose(result["outcome"])
    return result


def same_initial_cause(a: dict, b: dict) -> bool:
    """Two results share an initial condition only if first vendor code, loss order and
    reject order all match."""
    if a.get("abort") or b.get("abort"):
        return False
    va, vb = a.get("vendor_codes") or [], b.get("vendor_codes") or []
    return (bool(va) and bool(vb) and va[0] == vb[0] and a.get("loss_sequence") == b.get("loss_sequence")
            and a.get("reject_sequence") == b.get("reject_sequence"))


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="N1I telephony evidence evaluator (read-only).")
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
