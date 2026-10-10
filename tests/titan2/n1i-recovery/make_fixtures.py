#!/usr/bin/env python3
"""Generate the N1I recovery-contract replay fixtures deterministically.

The fixtures are SANITIZED SYNTHETIC ABSTRACTIONS. They are shaped after the
committed Titan 2 evidence (stock tray-2 key lines, N1F section 9AA, the Oct 9
N1F chronology summarized in the recovery architecture review) but contain no
raw log lines, subscriber identifiers, IPs or cell identifiers.

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


def ts(t: float) -> str:
    return (T0 + timedelta(seconds=t)).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def sha(events) -> str:
    raw = json.dumps(events, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


class B:
    """Event-stream builder for one fixture."""

    def __init__(self, fid: str, basis: str, mode: str = "PASSIVE_LOG", end: float = 1200.0,
                 kind: str = "SYNTHETIC_ABSTRACTION"):
        self.fid, self.basis, self.mode, self.end, self.kind = fid, basis, mode, end, kind
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

    # common shapes ---------------------------------------------------------
    def attach(self, t, phone, slot, sub, cid=101, apn="pwg", other_absent=True):
        if other_absent:
            self.ev(t, "SIM_STATE", {"state": "ABSENT"}, phone=1 - phone, slot=1 - slot)
        self.ev(t, "SIM_STATE", {"state": "LOADED"}, phone=phone, slot=slot, sub=sub)
        self.ev(t + 1, "RADIO_STATE", {"state": "ON", "kind": "STATE"}, phone=phone, sub=sub)
        self.ev(t + 2, "REGISTRATION", {"domain": "PS", "state": "HOME", "rat": "LTE", "reject_cause": None},
                phone=phone, sub=sub)
        self.ev(t + 3, "BEARER", {"active": 2, "fail_cause": None, "apn": apn}, phone=phone, sub=sub, cid=cid)

    def samples(self, t0, t1, phone, sub, step=5):
        t = t0
        while t <= t1:
            self.ev(t, "REGISTRATION", {"domain": "PS", "state": "HOME", "rat": "LTE", "reject_cause": None},
                    phone=phone, sub=sub, src="sampler")
            t += step

    def valid(self, t, phone, sub, verdict="VALID", src="connectivity"):
        self.ev(t, "VALIDATION", {"verdict": verdict}, phone=phone, sub=sub, src=src)

    def bundle(self) -> dict:
        return {
            "bundle_version": 1,
            "fixture_id": self.fid,
            "provenance": {"kind": self.kind, "basis": self.basis},
            "validation_mode": self.mode,
            "capture": {"start_utc": ts(0), "end_utc": ts(self.end)},
            "action_requests": self.action_requests,
            "events_sha256": sha(self.events),
            "events": self.events,
        }


def loss_chain(b: B, t, phone, sub, cid=101, code="0x140F7C", rejects=(15, 13, 11)):
    """Oct 9 shape: DNS/validation failure, DSRM selection only, vendor deact, bearer down, rejects."""
    b.ev(t, "DNS_PROBE", {"result": "TIMEOUT"}, phone=phone, sub=sub, src="connectivity")
    b.valid(t + 1, phone, sub, "INVALID")
    b.ev(t + 2, "DSRM_ACTION", {"action": "GET_DATA_CALL_LIST", "stage": "SELECTED"}, phone=phone, sub=sub)
    b.ev(t + 3, "DSRM_ACTION", {"action": "GET_DATA_CALL_LIST", "stage": "SKIPPED"}, phone=phone, sub=sub)
    b.ev(t + 12, "VENDOR_DEACT", {"raw_code": code, "aid": 0}, phone=phone, sub=sub, cid=cid)
    b.ev(t + 12.1, "BEARER", {"active": 0, "fail_cause": "ERROR_UNSPECIFIED", "apn": "pwg"},
         phone=phone, sub=sub, cid=cid)
    for i, rc in enumerate(rejects):
        b.ev(t + 13 + i, "REGISTRATION", {"domain": "PS", "state": "EMERGENCY_ONLY", "rat": "LTE",
                                          "reject_cause": rc}, phone=phone, sub=sub)


def build() -> dict[str, dict]:
    fx: dict[str, B] = {}

    # F01 tray 1 / phone 0, validated, 15+ min continuous samples, one exact duplicate (dedup).
    b = B("F01_OCT03_STABLE", "Oct 3 N1H tray-1 132/132 window, abstracted; not a probe-by-probe replay")
    b.attach(0, 0, 0, "S1")
    b.valid(10, 0, "S1")
    b.samples(5, 1000, 0, "S1")
    b.events.append(dict(b.events[-1]))  # exact duplicate copy: must be dropped, not counted
    b.end = 1000
    fx[b.fid] = b

    # F02 tray 2 / phone 1, Oct 9 loss chain.
    b = B("F02_OCT09_LOSS", "Oct 9 N1F tray-2 chronology summary (V12-V27), abstracted")
    b.attach(0, 1, 1, "S1")
    b.samples(5, 60, 1, "S1")
    loss_chain(b, 61, 1, "S1")
    b.end = 200
    fx[b.fid] = b

    # F03 loss, then operator radio cycle, fresh bearer, validation INVALID.
    b = B("F03_POST_CYCLE_INVALID", "Oct 9 post-cycle INVALID at 21:37:51, abstracted")
    b.attach(0, 1, 1, "S1")
    loss_chain(b, 30, 1, "S1")
    b.ev(100, "OPERATOR_ACTION", {"action": "RADIO_CYCLE", "origin": "HISTORICAL_RECORD"}, src="operator")
    b.ev(101, "RADIO_STATE", {"state": "OFF", "kind": "STATE"}, phone=1, sub="S1")
    b.ev(110, "RADIO_STATE", {"state": "ON", "kind": "STATE"}, phone=1, sub="S1")
    b.ev(115, "REGISTRATION", {"domain": "PS", "state": "HOME", "rat": "LTE", "reject_cause": None}, phone=1, sub="S1")
    b.ev(118, "BEARER", {"active": 2, "fail_cause": None, "apn": "pwg"}, phone=1, sub="S1", cid=102)
    b.valid(140, 1, "S1", "INVALID")
    b.end = 300
    fx[b.fid] = b

    # F04 stock tray 2: different vendor code and reject, bearer re-established, short window.
    b = B("F04_STOCK_DIFFERENT_CAUSE", "stock V01.00.14 tray-2 key lines: res 1317585, reject 27, recovered")
    b.attach(0, 1, 1, "S1", apn="fast.t-mobile.com")
    b.ev(20, "VENDOR_DEACT", {"raw_code": "0x141AD1", "aid": 0}, phone=1, sub="S1", cid=101)
    b.ev(20.1, "BEARER", {"active": 0, "fail_cause": "ERROR_UNSPECIFIED", "apn": "fast.t-mobile.com"},
         phone=1, sub="S1", cid=101)
    b.ev(21, "REGISTRATION", {"domain": "PS", "state": "EMERGENCY_ONLY", "rat": "LTE", "reject_cause": 27},
         phone=1, sub="S1")
    b.ev(30, "REGISTRATION", {"domain": "PS", "state": "HOME", "rat": "LTE", "reject_cause": None}, phone=1, sub="S1")
    b.ev(33, "BEARER", {"active": 2, "fail_cause": None, "apn": "fast.t-mobile.com"}, phone=1, sub="S1", cid=103)
    b.valid(40, 1, "S1")
    b.samples(35, 120, 1, "S1")
    b.end = 120
    fx[b.fid] = b

    # F05 phone 0 empty with an error; active phone 1 healthy (short window).
    b = B("F05_EMPTY_PHONE0_ERROR", "tray-2 capture: phone 0 empty reports an error, phone 1 active")
    b.attach(0, 1, 1, "S1")
    b.ev(2, "REGISTRATION", {"domain": "PS", "state": "NOT_REG", "rat": None, "reject_cause": None,
                              "ril_error": "OPERATION_NOT_ALLOWED"}, phone=0)
    b.valid(10, 1, "S1")
    b.samples(5, 100, 1, "S1")
    b.end = 100
    fx[b.fid] = b

    # F06 bearer connected, no validation ever observed, full window.
    b = B("F06_NO_VALIDATION", "synthetic: connected bearer, validation never logged")
    b.attach(0, 0, 0, "S1")
    b.samples(5, 1000, 0, "S1")
    b.end = 1000
    fx[b.fid] = b

    # F07 APN trial recorded after the original failure.
    b = B("F07_LATE_APN_TRIAL", "Oct 9: APN trial ~22:53 after the 21:28 failure, abstracted")
    b.attach(0, 1, 1, "S1")
    b.ev(30, "OPERATOR_ACTION", {"action": "SIM_TOGGLE_BEFORE", "origin": "HISTORICAL_RECORD"}, src="operator")
    loss_chain(b, 60, 1, "S1")
    b.ev(500, "OPERATOR_ACTION", {"action": "APN_TRIAL", "origin": "HISTORICAL_RECORD"}, src="operator")
    b.end = 600
    fx[b.fid] = b

    # F08 replay asks for device actions: every one denied.
    b = B("F08_UNAUTHORIZED_ACTION", "synthetic: offline replay requests adb/radio/flash actions")
    b.attach(0, 0, 0, "S1")
    b.valid(10, 0, "S1")
    b.samples(5, 100, 0, "S1")
    b.action_requests = [{"action": "ADB_SHELL"}, {"action": "RADIO_CYCLE"}, {"action": "FLASH_SYSTEM"},
                         {"action": "SET_SIMSWITCH_PROPERTY"}]
    b.end = 100
    fx[b.fid] = b

    # F09 corrupt evidence: hash mismatch; events also contain an invalid type that must never be parsed.
    b = B("F09_CORRUPT_EVIDENCE", "synthetic: tampered evidence")
    b.attach(0, 0, 0, "S1")
    b.end = 100
    bad = b.bundle()
    bad["events"].append({"event_type": "NOT_A_TYPE"})
    fx_bundles = {"F09_CORRUPT_EVIDENCE": bad}

    # F10 DSDS: two subscriptions, independent state.
    b = B("F10_DSDS", "synthetic: two SIMs; S1 stable, S2 lost")
    b.attach(0, 0, 0, "S1", other_absent=False)
    b.attach(0, 1, 1, "S2", cid=201, other_absent=False)
    b.valid(10, 0, "S1")
    b.valid(10, 1, "S2")
    b.samples(5, 1000, 0, "S1")
    loss_chain(b, 200, 1, "S2", cid=201)
    b.end = 1000
    fx[b.fid] = b

    # F11 stock transient recovered, then full validated window.
    b = B("F11_STOCK_TRANSIENT_RECOVERED", "stock tray-2: transient ERROR_UNSPECIFIED + reject 27, recovered")
    b.attach(0, 1, 1, "S1", apn="fast.t-mobile.com")
    b.ev(20, "BEARER", {"active": 0, "fail_cause": "ERROR_UNSPECIFIED", "apn": "fast.t-mobile.com"},
         phone=1, sub="S1", cid=101)
    b.ev(21, "REGISTRATION", {"domain": "PS", "state": "EMERGENCY_ONLY", "rat": "LTE", "reject_cause": 27},
         phone=1, sub="S1")
    b.ev(30, "REGISTRATION", {"domain": "PS", "state": "HOME", "rat": "LTE", "reject_cause": None}, phone=1, sub="S1")
    b.ev(33, "BEARER", {"active": 2, "fail_cause": None, "apn": "fast.t-mobile.com"}, phone=1, sub="S1", cid=103)
    b.valid(40, 1, "S1")
    b.samples(35, 1000, 1, "S1")
    b.end = 1000
    fx[b.fid] = b

    # F12 unknown clock domain on one source.
    b = B("F12_UNKNOWN_CLOCK", "synthetic: one source without a known clock")
    b.attach(0, 0, 0, "S1")
    b.valid(10, 0, "S1")
    b.samples(5, 1000, 0, "S1")
    b.ev(500, "DNS_PROBE", {"result": "OK"}, phone=0, sub="S1", src="unaligned", clock="UNKNOWN")
    b.end = 1000
    fx[b.fid] = b

    # F13 no subscription mapping: SIM loaded without subscription_ref.
    b = B("F13_NO_SUB_MAPPING", "synthetic: SIM loaded but subscription not identified")
    b.ev(0, "SIM_STATE", {"state": "LOADED"}, phone=0, slot=0)
    b.ev(1, "RADIO_STATE", {"state": "ON", "kind": "STATE"}, phone=0)
    b.ev(3, "BEARER", {"active": 2, "fail_cause": None, "apn": "pwg"}, phone=0, cid=101)
    b.end = 100
    fx[b.fid] = b

    # F14 active-probe mode: probes stop, validation goes stale.
    b = B("F14_STALE_VALIDATION", "synthetic: active probes stop after 100 s", mode="ACTIVE_PROBE")
    b.attach(0, 0, 0, "S1")
    t = 5
    while t <= 100:
        b.valid(t, 0, "S1", src="probe")
        t += 5
    b.samples(5, 1000, 0, "S1")
    b.end = 1000
    fx[b.fid] = b

    # F15 explicit capture gap inside the stability window.
    b = B("F15_CAPTURE_GAP", "synthetic: 60 s logging gap")
    b.attach(0, 0, 0, "S1")
    b.valid(10, 0, "S1")
    b.samples(5, 1000, 0, "S1")
    b.ev(400, "CAPTURE_GAP", {"seconds": 60}, src="collector")
    b.end = 1000
    fx[b.fid] = b

    # F16 duplicate (source_id, sequence) with different content.
    b = B("F16_DUPLICATE_CONFLICT", "synthetic: replayed log with conflicting duplicate")
    b.attach(0, 0, 0, "S1")
    dup = dict(b.events[-1])
    dup["payload"] = {"active": 0, "fail_cause": "ERROR_UNSPECIFIED", "apn": "pwg"}
    b.events.append(dup)
    b.end = 100
    fx[b.fid] = b

    # F17 event carries an extra action field.
    b = B("F17_SCHEMA_EXTRA_FIELD", "synthetic: event with an extra execute field")
    b.attach(0, 0, 0, "S1")
    b.ev(10, "OPERATOR_ACTION", {"action": "RADIO_CYCLE"}, src="operator", execute=True)
    b.end = 100
    fx[b.fid] = b

    # F18 invalid event type.
    b = B("F18_INVALID_EVENT_TYPE", "synthetic: unknown event type")
    b.attach(0, 0, 0, "S1")
    b.ev(10, "RADIO_CYCLE_EXEC", {}, phone=0, sub="S1")
    b.end = 100
    fx[b.fid] = b

    # F19 DSRM actually executed a radio restart.
    b = B("F19_DSRM_EXECUTED", "synthetic: DSRM executed RADIO_RESTART")
    b.attach(0, 0, 0, "S1")
    b.ev(50, "DSRM_ACTION", {"action": "RADIO_RESTART", "stage": "SELECTED"}, phone=0, sub="S1")
    b.ev(51, "DSRM_ACTION", {"action": "RADIO_RESTART", "stage": "EXECUTED"}, phone=0, sub="S1")
    b.end = 100
    fx[b.fid] = b

    # F20 radio cycle, connected, no validation.
    b = B("F20_CYCLE_NO_VALID", "synthetic: radio cycle then connected without VALID")
    b.attach(0, 0, 0, "S1")
    b.ev(50, "RADIO_STATE", {"state": "OFF", "kind": "STATE"}, phone=0, sub="S1")
    b.ev(60, "RADIO_STATE", {"state": "ON", "kind": "STATE"}, phone=0, sub="S1")
    b.ev(62, "REGISTRATION", {"domain": "PS", "state": "HOME", "rat": "LTE", "reject_cause": None}, phone=0, sub="S1")
    b.ev(65, "BEARER", {"active": 2, "fail_cause": None, "apn": "pwg"}, phone=0, sub="S1", cid=102)
    b.end = 200
    fx[b.fid] = b

    out = {k: v.bundle() for k, v in fx.items()}
    out.update(fx_bundles)
    return dict(sorted(out.items()))


def dump(obj) -> str:
    return json.dumps(obj, indent=1, sort_keys=True, ensure_ascii=False) + "\n"


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
        print(f"FIXTURES_WRITTEN={len(bundles)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
