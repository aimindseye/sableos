#!/usr/bin/env python3
"""Generate the N1I telephony-evidence replay fixtures deterministically.

The fixtures are SANITIZED SYNTHETIC ABSTRACTIONS. They are shaped after the
committed Titan 2 evidence (stock tray-2 key lines, N1F section 9AA, the Oct 9
N1F chronology summarized in the architecture review) but contain no raw log
lines, subscriber identifiers, IP addresses or cell identifiers.

    python3 make_fixtures.py            # (re)write fixtures/*.json
    python3 make_fixtures.py --check    # exit 1 if committed fixtures differ
"""

from __future__ import annotations

import hashlib
import json
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "fixtures"
T0 = datetime(2026, 10, 9, 21, 0, 0, tzinfo=timezone.utc)

PS_HOME = {"domain": "PS", "state": "HOME", "rat": "LTE", "reject_cause": None}


def ts(t: float) -> str:
    return (T0 + timedelta(seconds=t)).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def sha(events) -> str:
    raw = json.dumps(events, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def obs(value, ref):
    return {"status": "OBSERVED", "value": value, "evidence_ref": ref}


UNK = {"status": "UNKNOWN", "value": None, "evidence_ref": None}


def gsi_config(fid: str) -> dict:
    """Purely synthetic fixtures: every field observed, with a synthetic evidence reference."""
    r = f"synthetic:{fid}:config"
    return {
        "private_dns_mode": obs("opportunistic", r),
        "dns_servers": obs(["carrier-supplied"], r),
        "connectivity_check_urls": obs(["https://connectivity-check.invalid/generate_204"], r),
        "connectivity_check_source": obs("synthetic", r),
        "apn_name": obs("pwg", r),
        "apn_protocol": obs("IPV4V6", r),
        "apn_roaming_protocol": obs("IPV4V6", r),
    }


def historical_gsi_config(fid: str) -> dict:
    """Fixtures shaped after retained GSI evidence: only the APN name is in that evidence. Everything else
    stays UNKNOWN until the read-only normalizer finds it in a retained capture."""
    return {
        "private_dns_mode": UNK,
        "dns_servers": UNK,
        "connectivity_check_urls": UNK,
        "connectivity_check_source": UNK,
        "apn_name": obs("pwg", f"abstracted:{fid}:apn_name_in_data_setup_log"),
        "apn_protocol": UNK,
        "apn_roaming_protocol": UNK,
    }


def stock_config(fid: str) -> dict:
    """Stock-baseline fixtures: no network configuration is retained with the stock key lines."""
    return {k: dict(UNK) for k in gsi_config(fid)}


class B:
    """Event-stream builder for one fixture."""

    def __init__(self, fid: str, basis: str, mode: str = "PASSIVE_LOG", end: float = 1200.0,
                 config=None, kind: str = "SYNTHETIC_ABSTRACTION"):
        self.fid, self.basis, self.mode, self.end, self.kind = fid, basis, mode, end, kind
        if config is None:
            config = gsi_config(fid) if basis.startswith("synthetic") else historical_gsi_config(fid)
        self.config = config
        self.events: list[dict] = []
        self.seq: dict[str, int] = {}
        self.action_requests: list[dict] = []

    def ev(self, t, etype, payload, phone=None, slot=None, sub=None, cid=None,
           src="radio", clock="UTC_ALIGNED", **extra):
        n = self.seq.get(src, 0)
        self.seq[src] = n + 1
        e = {
            "schema_version": 1, "source_id": src, "sequence": n, "timestamp_utc": ts(t),
            "source_clock_kind": clock, "event_type": etype, "phone_id": phone, "slot_id": slot,
            "subscription_ref": sub, "cid": cid, "payload": payload,
            "evidence_ref": f"synthetic:{self.fid}:{src}:{n}",
        }
        e.update(extra)
        self.events.append(e)
        return e

    def attach(self, t, phone, slot, sub, cid=101, apn="pwg", other_absent=True, default=True):
        if other_absent:
            self.ev(t, "SIM_STATE", {"state": "ABSENT"}, phone=1 - phone, slot=1 - slot)
        self.ev(t, "SIM_STATE", {"state": "LOADED"}, phone=phone, slot=slot, sub=sub)
        if default:
            self.ev(t + 0.5, "DEFAULT_DATA", {"source": "subscription_manager"}, sub=sub, src="framework")
        self.ev(t + 1, "RADIO_STATE", {"state": "ON", "kind": "STATE"}, phone=phone, sub=sub)
        self.ev(t + 2, "REGISTRATION", dict(PS_HOME), phone=phone, sub=sub)
        self.ev(t + 3, "BEARER", {"active": 2, "fail_cause": None, "apn": apn, "apn_type": "default"},
                phone=phone, sub=sub, cid=cid)

    def samples(self, t0, t1, phone, sub, cid=101, validation="CAPABILITY_SNAPSHOT", bearer=True, step=5):
        """Periodic poller samples: PS registration, bearer state, validation state."""
        t = t0
        while t <= t1:
            self.ev(t, "REGISTRATION", dict(PS_HOME), phone=phone, sub=sub, src="sampler")
            if bearer:
                self.ev(t, "BEARER", {"active": 2, "fail_cause": None, "apn": "pwg", "apn_type": "default"},
                        phone=phone, sub=sub, cid=cid, src="sampler")
            if validation:
                self.ev(t, "VALIDATION", {"verdict": "VALID", "basis": validation}, phone=phone, sub=sub,
                        src="sampler")
            t += step

    def valid(self, t, phone, sub, verdict="VALID", basis="TRANSITION", src="connectivity", **p):
        self.ev(t, "VALIDATION", {"verdict": verdict, "basis": basis, **p}, phone=phone, sub=sub, src=src)

    def bundle(self) -> dict:
        return {
            "bundle_version": 1,
            "fixture_id": self.fid,
            "provenance": {"kind": self.kind, "basis": self.basis, "network_config": self.config},
            "validation_mode": self.mode,
            "capture": {"start_utc": ts(0), "end_utc": ts(self.end)},
            "action_requests": self.action_requests,
            "events_sha256": sha(self.events),
            "events": self.events,
        }


def loss_chain(b: B, t, phone, sub, cid=101, code=("0x140F7C", 1314684), rejects=(15, 13, 11)):
    """Oct 9 shape: DNS/validation failure, DSRM selection only, vendor deact, bearer down, rejects."""
    raw, res = code
    b.ev(t, "DNS_PROBE", {"result": "TIMEOUT"}, phone=phone, sub=sub, src="connectivity")
    b.valid(t + 1, phone, sub, "INVALID")
    b.ev(t + 2, "DSRM_ACTION", {"action": "GET_DATA_CALL_LIST", "stage": "SELECTED"}, phone=phone, sub=sub)
    b.ev(t + 3, "DSRM_ACTION", {"action": "GET_DATA_CALL_LIST", "stage": "SKIPPED"}, phone=phone, sub=sub)
    pl = {"aid": 0}
    if raw is not None:
        pl["raw_code"] = raw
    if res is not None:
        pl["res"] = res
    b.ev(t + 12, "VENDOR_DEACT", pl, phone=phone, sub=sub, cid=cid)
    b.ev(t + 12.1, "BEARER", {"active": 0, "fail_cause": "ERROR_UNSPECIFIED", "apn": "pwg", "apn_type": "default"},
         phone=phone, sub=sub, cid=cid)
    for i, rc in enumerate(rejects):
        b.ev(t + 13 + i, "REGISTRATION", {"domain": "PS", "state": "EMERGENCY_ONLY", "rat": "LTE",
                                          "reject_cause": rc}, phone=phone, sub=sub)


def build() -> dict[str, dict]:
    fx: list[B] = []
    raw_bundles: dict[str, dict] = {}

    # F01 Oct 3 historical shape: registration + bearer polling, one VALID transition only.
    b = B("F01_OCT03_HISTORICAL_POLLING_ONLY", "Oct 3 N1H tray-1 132/132 registration/data samples, abstracted")
    b.attach(0, 0, 0, "S1")
    b.valid(10, 0, "S1")
    b.samples(5, 1000, 0, "S1", validation=None)
    b.events.append(dict(b.events[-1]))  # exact duplicate copy: must be dropped, not counted
    b.end = 1000
    fx.append(b)

    # F02 tray 2 / phone 1, Oct 9 loss chain; vendor code present in both forms.
    b = B("F02_OCT09_LOSS", "Oct 9 N1F tray-2 chronology summary (V12-V27), abstracted")
    b.attach(0, 1, 1, "S1")
    b.ev(2, "REGISTRATION", {"domain": "PS", "state": "NOT_REG", "rat": None, "reject_cause": None,
                              "ril_error": "OPERATION_NOT_ALLOWED"}, phone=0)
    b.samples(5, 60, 1, "S1")
    loss_chain(b, 61, 1, "S1")
    b.end = 200
    fx.append(b)

    # F03 loss, operator radio cycle, fresh bearer, validation INVALID.
    b = B("F03_POST_CYCLE_INVALID", "Oct 9 post-cycle INVALID at 21:37:51, abstracted")
    b.attach(0, 1, 1, "S1")
    loss_chain(b, 30, 1, "S1")
    b.ev(100, "OPERATOR_ACTION", {"action": "RADIO_CYCLE", "origin": "HISTORICAL_RECORD"}, src="operator")
    b.ev(101, "RADIO_STATE", {"state": "OFF", "kind": "STATE"}, phone=1, sub="S1")
    b.ev(110, "RADIO_STATE", {"state": "ON", "kind": "STATE"}, phone=1, sub="S1")
    b.ev(115, "REGISTRATION", dict(PS_HOME), phone=1, sub="S1")
    b.ev(118, "BEARER", {"active": 2, "fail_cause": None, "apn": "pwg", "apn_type": "default"},
         phone=1, sub="S1", cid=102)
    b.valid(140, 1, "S1", "INVALID")
    b.end = 300
    fx.append(b)

    # F04 stock tray 2: different vendor code (decimal only) and reject 27; short window.
    b = B("F04_STOCK_DIFFERENT_CAUSE", "stock V01.00.14 tray-2 key lines: res 1317585, reject 27, recovered",
          config=stock_config("F04_STOCK_DIFFERENT_CAUSE"))
    b.attach(0, 1, 1, "S1", apn="fast.t-mobile.com")
    b.ev(20, "VENDOR_DEACT", {"res": 1317585, "aid": 0}, phone=1, sub="S1", cid=101)
    b.ev(20.1, "BEARER", {"active": 0, "fail_cause": "ERROR_UNSPECIFIED", "apn": "fast.t-mobile.com",
                          "apn_type": "default"}, phone=1, sub="S1", cid=101)
    b.ev(21, "REGISTRATION", {"domain": "PS", "state": "EMERGENCY_ONLY", "rat": "LTE", "reject_cause": 27},
         phone=1, sub="S1")
    b.ev(30, "REGISTRATION", dict(PS_HOME), phone=1, sub="S1")
    b.ev(33, "BEARER", {"active": 2, "fail_cause": None, "apn": "fast.t-mobile.com", "apn_type": "default"},
         phone=1, sub="S1", cid=103)
    b.samples(35, 120, 1, "S1", cid=103)
    b.end = 120
    fx.append(b)

    # F05 phone 0 empty with an error; active phone 1 healthy (short window).
    b = B("F05_EMPTY_PHONE0_ERROR", "tray-2 capture: phone 0 empty reports an error, phone 1 active")
    b.attach(0, 1, 1, "S1")
    b.ev(2, "REGISTRATION", {"domain": "PS", "state": "NOT_REG", "rat": None, "reject_cause": None,
                              "ril_error": "OPERATION_NOT_ALLOWED"}, phone=0)
    b.samples(5, 100, 1, "S1")
    b.end = 100
    fx.append(b)

    # F06 bearer connected, validation never logged, full window.
    b = B("F06_NO_VALIDATION", "synthetic: connected bearer, validation never logged")
    b.attach(0, 0, 0, "S1")
    b.samples(5, 1000, 0, "S1", validation=None)
    b.end = 1000
    fx.append(b)

    # F07 APN trial recorded after the original failure.
    b = B("F07_LATE_APN_TRIAL", "Oct 9: APN trial ~22:53 after the 21:28 failure, abstracted")
    b.attach(0, 1, 1, "S1")
    b.ev(30, "OPERATOR_ACTION", {"action": "SIM_TOGGLE_BEFORE", "origin": "HISTORICAL_RECORD"}, src="operator")
    loss_chain(b, 60, 1, "S1")
    b.ev(500, "OPERATOR_ACTION", {"action": "APN_TRIAL", "origin": "HISTORICAL_RECORD"}, src="operator")
    b.end = 600
    fx.append(b)

    # F08 replay asks for device actions: every one denied.
    b = B("F08_UNAUTHORIZED_ACTION", "synthetic: offline replay requests adb/radio/flash actions")
    b.attach(0, 0, 0, "S1")
    b.samples(5, 100, 0, "S1")
    b.action_requests = [{"action": "ADB_SHELL"}, {"action": "RADIO_CYCLE"}, {"action": "FLASH_SYSTEM"},
                         {"action": "SET_SIMSWITCH_PROPERTY"}]
    b.end = 100
    fx.append(b)

    # F09 corrupt evidence: hash mismatch; events also contain an invalid type that must never be parsed.
    b = B("F09_CORRUPT_EVIDENCE", "synthetic: tampered evidence")
    b.attach(0, 0, 0, "S1")
    b.end = 100
    bad = b.bundle()
    bad["events"].append({"event_type": "NOT_A_TYPE"})
    raw_bundles[b.fid] = bad

    # F10 DSDS: S1 stable, S2 lost, default data is S2 (sorted-first S1 must not decide).
    b = B("F10_DSDS_DEFAULT_S2_LOST", "synthetic: two SIMs; S1 stable, default-data S2 lost")
    b.attach(0, 0, 0, "S1", other_absent=False, default=False)
    b.attach(0, 1, 1, "S2", cid=201, other_absent=False, default=False)
    b.ev(1, "DEFAULT_DATA", {"source": "subscription_manager"}, sub="S2", src="framework")
    b.samples(5, 1000, 0, "S1")
    b.samples(5, 195, 1, "S2", cid=201)
    loss_chain(b, 200, 1, "S2", cid=201)
    b.end = 1000
    fx.append(b)

    # F11 stock transient recovered, then a full continuous validated window.
    b = B("F11_STOCK_TRANSIENT_RECOVERED", "stock tray-2: transient ERROR_UNSPECIFIED + reject 27, recovered",
          config=stock_config("F11_STOCK_TRANSIENT_RECOVERED"))
    b.attach(0, 1, 1, "S1", apn="fast.t-mobile.com")
    b.ev(20, "BEARER", {"active": 0, "fail_cause": "ERROR_UNSPECIFIED", "apn": "fast.t-mobile.com",
                        "apn_type": "default"}, phone=1, sub="S1", cid=101)
    b.ev(21, "REGISTRATION", {"domain": "PS", "state": "EMERGENCY_ONLY", "rat": "LTE", "reject_cause": 27},
         phone=1, sub="S1")
    b.ev(30, "REGISTRATION", dict(PS_HOME), phone=1, sub="S1")
    b.ev(33, "BEARER", {"active": 2, "fail_cause": None, "apn": "fast.t-mobile.com", "apn_type": "default"},
         phone=1, sub="S1", cid=103)
    b.samples(35, 1000, 1, "S1", cid=103)
    b.end = 1000
    fx.append(b)

    # F12 unknown clock domain on one source.
    b = B("F12_UNKNOWN_CLOCK", "synthetic: one source without a known clock")
    b.attach(0, 0, 0, "S1")
    b.samples(5, 1000, 0, "S1")
    b.ev(500, "DNS_PROBE", {"result": "OK"}, phone=0, sub="S1", src="unaligned", clock="UNKNOWN")
    b.end = 1000
    fx.append(b)

    # F13 no subscription mapping: SIM loaded without subscription_ref.
    b = B("F13_NO_SUB_MAPPING", "synthetic: SIM loaded but subscription not identified")
    b.ev(0, "SIM_STATE", {"state": "LOADED"}, phone=0, slot=0)
    b.ev(1, "RADIO_STATE", {"state": "ON", "kind": "STATE"}, phone=0)
    b.ev(3, "BEARER", {"active": 2, "fail_cause": None, "apn": "pwg", "apn_type": "default"}, phone=0, cid=101)
    b.end = 100
    fx.append(b)

    # F14 active-probe mode: bound probes stop after 100 s, validation goes stale.
    b = B("F14_STALE_VALIDATION", "synthetic: active probes stop after 100 s", mode="ACTIVE_PROBE")
    b.attach(0, 0, 0, "S1")
    t = 5
    while t <= 100:
        b.valid(t, 0, "S1", basis="PROBE", src="probe", bound_cid=101)
        t += 5
    b.samples(5, 1000, 0, "S1", validation=None)
    b.end = 1000
    fx.append(b)

    # F15 capture gap inside the window: window restarts after the gap and is then too short.
    b = B("F15_CAPTURE_GAP_IN_WINDOW", "synthetic: 60 s logging gap at 400 s")
    b.attach(0, 0, 0, "S1")
    b.samples(5, 1000, 0, "S1")
    b.ev(400, "CAPTURE_GAP", {"seconds": 60}, src="collector")
    b.end = 1000
    fx.append(b)

    # F16 duplicate (source_id, sequence) with different content.
    b = B("F16_DUPLICATE_CONFLICT", "synthetic: replayed log with conflicting duplicate")
    b.attach(0, 0, 0, "S1")
    dup = dict(b.events[-1])
    dup["payload"] = {"active": 0, "fail_cause": "ERROR_UNSPECIFIED", "apn": "pwg", "apn_type": "default"}
    b.events.append(dup)
    b.end = 100
    fx.append(b)

    # F17 event carries an extra action field.
    b = B("F17_SCHEMA_EXTRA_FIELD", "synthetic: event with an extra execute field")
    b.attach(0, 0, 0, "S1")
    b.ev(10, "OPERATOR_ACTION", {"action": "RADIO_CYCLE"}, src="operator", execute=True)
    b.end = 100
    fx.append(b)

    # F18 invalid event type.
    b = B("F18_INVALID_EVENT_TYPE", "synthetic: unknown event type")
    b.attach(0, 0, 0, "S1")
    b.ev(10, "RADIO_CYCLE_EXEC", {}, phone=0, sub="S1")
    b.end = 100
    fx.append(b)

    # F19 DSRM actually executed a radio restart.
    b = B("F19_DSRM_EXECUTED", "synthetic: DSRM executed RADIO_RESTART")
    b.attach(0, 0, 0, "S1")
    b.ev(50, "DSRM_ACTION", {"action": "RADIO_RESTART", "stage": "SELECTED"}, phone=0, sub="S1")
    b.ev(51, "DSRM_ACTION", {"action": "RADIO_RESTART", "stage": "EXECUTED"}, phone=0, sub="S1")
    b.end = 100
    fx.append(b)

    # F20 radio cycle, connected, no validation.
    b = B("F20_CYCLE_NO_VALID", "synthetic: radio cycle then connected without VALID")
    b.attach(0, 0, 0, "S1")
    b.ev(50, "RADIO_STATE", {"state": "OFF", "kind": "STATE"}, phone=0, sub="S1")
    b.ev(60, "RADIO_STATE", {"state": "ON", "kind": "STATE"}, phone=0, sub="S1")
    b.ev(62, "REGISTRATION", dict(PS_HOME), phone=0, sub="S1")
    b.ev(65, "BEARER", {"active": 2, "fail_cause": None, "apn": "pwg", "apn_type": "default"},
         phone=0, sub="S1", cid=102)
    b.end = 200
    fx.append(b)

    # F21 complete continuous passive evidence: the only shape that qualifies in PASSIVE_LOG.
    b = B("F21_CONTINUOUS_VALIDATED", "synthetic: registration, bearer and validation snapshots every 5 s")
    b.attach(0, 0, 0, "S1")
    b.samples(5, 1000, 0, "S1")
    b.end = 1000
    fx.append(b)

    # F22 event names S1 on phone 0 while S1 is mapped to phone 1.
    b = B("F22_IDENTITY_SUB_PHONE_CONFLICT", "synthetic: subscription/phone contradiction")
    b.attach(0, 1, 1, "S1")
    b.ev(20, "BEARER", {"active": 2, "fail_cause": None, "apn": "pwg", "apn_type": "default"},
         phone=0, sub="S1", cid=101)
    b.end = 100
    fx.append(b)

    # F23 event on phone 1 claims slot 0 while phone 1 is mapped to slot 1.
    b = B("F23_IDENTITY_SLOT_CONFLICT", "synthetic: phone/slot contradiction")
    b.attach(0, 1, 1, "S1")
    b.ev(20, "REGISTRATION", dict(PS_HOME), phone=1, slot=0)
    b.end = 100
    fx.append(b)

    # F24 mapping appears late; earlier phone-1 evidence must not be applied retroactively.
    b = B("F24_LATE_MAPPING_NOT_RETROACTIVE", "synthetic: SIM mapping first seen at 950 s")
    b.ev(0, "RADIO_STATE", {"state": "ON", "kind": "STATE"}, phone=1)
    t = 5
    while t <= 945:
        b.ev(t, "REGISTRATION", dict(PS_HOME), phone=1, src="sampler")
        b.ev(t, "BEARER", {"active": 2, "fail_cause": None, "apn": "pwg", "apn_type": "default"},
             phone=1, cid=101, src="sampler")
        b.ev(t, "VALIDATION", {"verdict": "VALID", "basis": "CAPABILITY_SNAPSHOT"}, phone=1, src="sampler")
        t += 5
    b.attach(950, 1, 1, "S1", other_absent=False)
    b.samples(955, 1000, 1, "S1")
    b.end = 1000
    fx.append(b)

    # F25 DSDS with both subscriptions stable but no default-data evidence.
    b = B("F25_DSDS_NO_DEFAULT_DATA", "synthetic: two SIMs, default-data subscription never logged")
    b.attach(0, 0, 0, "S1", other_absent=False, default=False)
    b.attach(0, 1, 1, "S2", cid=201, other_absent=False, default=False)
    b.samples(5, 1000, 0, "S1")
    b.samples(5, 1000, 1, "S2", cid=201)
    b.end = 1000
    fx.append(b)

    # F26 default data names a subscription that is never mapped.
    b = B("F26_DEFAULT_DATA_UNMAPPED", "synthetic: default-data subscription has no SIM mapping")
    b.attach(0, 0, 0, "S1", default=False)
    b.ev(1, "DEFAULT_DATA", {"source": "subscription_manager"}, sub="S9", src="framework")
    b.samples(5, 1000, 0, "S1")
    b.end = 1000
    fx.append(b)

    # F27 early capture gap, then a complete window: the gap resets, it does not poison.
    b = B("F27_GAP_EARLY_THEN_FULL_WINDOW", "synthetic: 30 s gap at 50 s, then 1000 s continuous")
    b.attach(0, 0, 0, "S1")
    b.samples(5, 45, 0, "S1")
    b.ev(50, "CAPTURE_GAP", {"seconds": 30}, src="collector")
    b.samples(80, 1100, 0, "S1")
    b.end = 1100
    fx.append(b)

    # F28 VALID -> INVALID -> VALID: the stability window restarts at the transition.
    b = B("F28_VALIDATION_TRANSITION_RESETS", "synthetic: INVALID at 300 s between VALID snapshots")
    b.attach(0, 0, 0, "S1")
    b.samples(5, 295, 0, "S1")
    b.valid(300, 0, "S1", "INVALID")
    b.samples(305, 1000, 0, "S1")
    b.end = 1000
    fx.append(b)

    # F29 bearer lost at 600 s and recovered: the recovery restarts the window.
    b = B("F29_RECOVERY_WINDOW_RESET", "synthetic: stable, bearer loss at 600 s, reconnect at 620 s")
    b.attach(0, 0, 0, "S1")
    b.samples(5, 595, 0, "S1")
    b.ev(600, "BEARER", {"active": 0, "fail_cause": "ERROR_UNSPECIFIED", "apn": "pwg", "apn_type": "default"},
         phone=0, sub="S1", cid=101)
    b.ev(620, "BEARER", {"active": 2, "fail_cause": None, "apn": "pwg", "apn_type": "default"},
         phone=0, sub="S1", cid=102)
    b.samples(625, 1000, 0, "S1", cid=102)
    b.end = 1000
    fx.append(b)

    # F30 active probes VALID but bound to a different network: they do not count.
    b = B("F30_ACTIVE_PROBE_UNBOUND", "synthetic: probes bound to cid 999, not the default bearer",
          mode="ACTIVE_PROBE")
    b.attach(0, 0, 0, "S1")
    b.samples(5, 1000, 0, "S1", validation=None)
    t = 5
    while t <= 1000:
        b.valid(t, 0, "S1", basis="PROBE", src="probe", bound_cid=999)
        t += 5
    b.end = 1000
    fx.append(b)

    # F31 active probes bound to the default bearer, continuous: qualifies.
    b = B("F31_ACTIVE_PROBE_BOUND_STABLE", "synthetic: probes bound to cid 101 every 5 s", mode="ACTIVE_PROBE")
    b.attach(0, 0, 0, "S1")
    b.samples(5, 1000, 0, "S1", validation=None)
    t = 5
    while t <= 1000:
        b.valid(t, 0, "S1", basis="PROBE", src="probe", bound_cid=101)
        t += 5
    b.end = 1000
    fx.append(b)

    # F32 N1I-B section 9AA tray-1 run: its own reject orders 13 -> 15 -> 11, then 11 -> 13 -> 15.
    # Section 9AA records no vendor deactivation code and no validation verdict: none is invented here.
    b = B("F32_N1IB_9AA_TRAY1_REJECT_ORDER", "N1I-B section 9AA tray-1 capture after IMS removal, abstracted")
    b.attach(0, 0, 0, "S1")
    b.samples(5, 90, 0, "S1", validation=None)
    b.ev(91, "BEARER", {"active": 0, "fail_cause": "ERROR_UNSPECIFIED", "apn": "pwg", "apn_type": "default"},
         phone=0, sub="S1", cid=101)
    for t, rc in ((91, 13), (92, 15), (92.5, 11)):
        b.ev(t, "REGISTRATION", {"domain": "PS", "state": "EMERGENCY_ONLY", "rat": "LTE", "reject_cause": rc},
             phone=0, sub="S1")
    b.ev(100, "REGISTRATION", dict(PS_HOME), phone=0, sub="S1")
    b.ev(103, "BEARER", {"active": 2, "fail_cause": None, "apn": "pwg", "apn_type": "default"},
         phone=0, sub="S1", cid=102)
    for t, rc in ((224, 11), (225, 13), (226, 15)):
        b.ev(t, "REGISTRATION", {"domain": "PS", "state": "EMERGENCY_ONLY", "rat": "LTE", "reject_cause": rc},
             phone=0, sub="S1")
    b.end = 300
    fx.append(b)

    # F33 IMS bearer comes and goes during a qualified window: out of scope, no effect.
    b = B("F33_IMS_BEARER_OUT_OF_SCOPE", "synthetic: IMS bearer up then down; internet bearer continuous")
    b.attach(0, 0, 0, "S1")
    b.samples(5, 1000, 0, "S1")
    b.ev(300, "BEARER", {"active": 2, "fail_cause": None, "apn": "ims", "apn_type": "ims"},
         phone=0, sub="S1", cid=150)
    b.ev(400, "BEARER", {"active": 0, "fail_cause": "ERROR_UNSPECIFIED", "apn": "ims", "apn_type": "ims"},
         phone=0, sub="S1", cid=150)
    b.ev(410, "REGISTRATION", {"domain": "IMS", "state": "NOT_REG", "rat": "LTE", "reject_cause": None},
         phone=0, sub="S1")
    b.end = 1000
    fx.append(b)

    # F34 only an IMS bearer is ever active: it cannot satisfy the internet bearer requirement.
    b = B("F34_IMS_BEARER_ONLY", "synthetic: IMS bearer only")
    b.ev(0, "SIM_STATE", {"state": "ABSENT"}, phone=1, slot=1)
    b.ev(0, "SIM_STATE", {"state": "LOADED"}, phone=0, slot=0, sub="S1")
    b.ev(0.5, "DEFAULT_DATA", {"source": "subscription_manager"}, sub="S1", src="framework")
    b.ev(1, "RADIO_STATE", {"state": "ON", "kind": "STATE"}, phone=0, sub="S1")
    b.ev(2, "REGISTRATION", dict(PS_HOME), phone=0, sub="S1")
    b.ev(3, "BEARER", {"active": 2, "fail_cause": None, "apn": "ims", "apn_type": "ims"},
         phone=0, sub="S1", cid=150)
    b.end = 100
    fx.append(b)

    # F35 the two forms of the vendor code disagree.
    b = B("F35_VENDOR_CODE_FORM_CONFLICT", "synthetic: raw 0x141AD1 with res 1314684")
    b.attach(0, 1, 1, "S1")
    loss_chain(b, 30, 1, "S1", code=("0x141AD1", 1314684))
    b.end = 100
    fx.append(b)

    # F36 network_config is missing a required field.
    b = B("F36_PROVENANCE_MISSING_FIELD", "synthetic: private_dns_mode absent")
    cfg = gsi_config(b.fid)
    del cfg["private_dns_mode"]
    b.config = cfg
    b.attach(0, 0, 0, "S1")
    b.end = 100
    fx.append(b)

    # F37 a value presented as observed without any evidence reference (i.e. inferred).
    b = B("F37_PROVENANCE_INFERRED_VALUE", "synthetic: connectivity_check_urls filled in without evidence")
    cfg = gsi_config(b.fid)
    cfg["connectivity_check_urls"] = {"status": "OBSERVED", "value": ["https://example.invalid/generate_204"],
                                      "evidence_ref": None}
    b.config = cfg
    b.attach(0, 0, 0, "S1")
    b.end = 100
    fx.append(b)

    # F38 everything unknown: evaluation proceeds and reports the unknowns verbatim.
    b = B("F38_PROVENANCE_ALL_UNKNOWN", "synthetic: no network configuration evidence",
          config={k: dict(UNK) for k in gsi_config("x")})
    b.attach(0, 0, 0, "S1")
    b.samples(5, 1000, 0, "S1")
    b.end = 1000
    fx.append(b)

    # F39 bearer lost at 100 s, silent until reconnect at 200 s, then a full window: the window
    # restarts at the recovery, not at the loss, so the silent outage is outside it.
    b = B("F39_RECOVERY_THEN_FULL_WINDOW", "synthetic: loss at 100 s, reconnect at 200 s, 905 s continuous")
    b.attach(0, 0, 0, "S1")
    b.samples(5, 95, 0, "S1")
    b.ev(100, "BEARER", {"active": 0, "fail_cause": "ERROR_UNSPECIFIED", "apn": "pwg", "apn_type": "default"},
         phone=0, sub="S1", cid=101)
    b.ev(200, "BEARER", {"active": 2, "fail_cause": None, "apn": "pwg", "apn_type": "default"},
         phone=0, sub="S1", cid=102)
    b.samples(205, 1105, 0, "S1", cid=102)
    b.end = 1105
    fx.append(b)

    out = {x.fid: x.bundle() for x in fx}
    out.update(raw_bundles)
    return dict(sorted(out.items()))


def dump(obj) -> str:
    """Stable JSON: header keys indented, one compact event per line (keeps fixture diffs reviewable)."""
    def one(v) -> str:
        return json.dumps(v, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    if not isinstance(obj, dict) or not isinstance(obj.get("events"), list):
        return json.dumps(obj, indent=1, sort_keys=True, ensure_ascii=False) + "\n"
    head = [f" {json.dumps(k)}: {one(obj[k])}" for k in sorted(obj) if k != "events"]
    body = ",\n".join(f"  {one(e)}" for e in obj["events"])
    head.append(f' "events": [\n{body}\n ]')
    return "{\n" + ",\n".join(head) + "\n}\n"


def main() -> int:
    bundles = build()
    check = "--check" in sys.argv[1:]
    bad = []
    for fid, bundle in bundles.items():
        p = OUT / f"{fid}.json"
        text = dump(bundle)
        if check:
            if not p.exists() or p.read_text(encoding="utf-8") != text:
                bad.append(p.name)
        else:
            OUT.mkdir(parents=True, exist_ok=True)
            p.write_text(text, encoding="utf-8")
    if check:
        extra = sorted(x.name for x in OUT.glob("*.json") if x.stem not in bundles)
        if bad or extra:
            print(f"FIXTURES_STALE={','.join(bad + extra)}")
            return 1
        print(f"FIXTURES_CURRENT={len(bundles)}")
    else:
        if OUT.exists():
            for x in OUT.glob("*.json"):
                if x.stem not in bundles:
                    x.unlink()
        print(f"FIXTURES_WRITTEN={len(bundles)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
