from __future__ import annotations

import csv
import pathlib
import tempfile

from n1i_c1_physical_evidence import SCENARIOS, expected_sim_state, text
from n1i_c1_physical_eval import evaluate_all, evaluate_scenario


def _fixture(root: pathlib.Path, scenario: str, *, apn: str = "fast.t-mobile.com", provider: bool = True) -> None:
    (root / "raw" / "end").mkdir(parents=True, exist_ok=True)
    (root / "be2" / "redacted").mkdir(parents=True, exist_ok=True)
    serial_hash = "1" * 64; system_sha = "2" * 64
    summary = {
        "N1I_C1_PHYSICAL_COLLECTOR": "PASS", "SCENARIO": scenario,
        "N1I_C1_IMAGE_SOURCE_COMMIT": "a745c7daa08267d851f45785a5bb7ff762ed4604",
        "N1I_C1_SYSTEM_IMAGE_SHA256": system_sha, "N1I_C1_DEVICE_SERIAL_SHA256": serial_hash,
        "N1I_C1_DEVICE_SERIAL_BINDING": "PASS", "N1I_C1_SYSTEM_IMAGE_SHA_BINDING": "PASS",
        "N1I_C1_RUNTIME_DEVICE_IDENTITY": "PASS", "N1I_C1_READ_ONLY_CONTRACT": "PASS",
        "N1I_C1_PROPERTY_WRITE_COUNT": "0", "N1I_C1_RADIO_RESTART_COUNT_BY_COLLECTOR": "0",
        "N1I_C1_AIRPLANE_TOGGLE_COUNT_BY_COLLECTOR": "0", "N1I_C1_APN_EDIT_COUNT": "0",
        "N1I_C1_HEALING_ACTION_COUNT": "0",
    }
    (root / "N1I_C1_COLLECTOR_SUMMARY.env").write_text("".join(f"{k}={v}\n" for k, v in summary.items()), encoding="utf-8")
    (root / "N1I_C1_BINDING.env").write_text(f"SCENARIO={scenario}\n", encoding="utf-8")
    (root / "raw" / "end" / "getprop.txt").write_text(f"[gsm.sim.state]: [{expected_sim_state(scenario)}]\n", encoding="utf-8")
    pkg = "Package [com.mediatek.ims] sharedUserId=android.uid.phone pkgFlags=[ SYSTEM PRIVILEGED ]" if provider else "package missing"
    path = "package:/system_ext/priv-app/ImsService/ImsService.apk\n" if provider else ""
    (root / "raw" / "end" / "mediatek_ims_package.txt").write_text(pkg, encoding="utf-8")
    (root / "raw" / "end" / "mediatek_ims_path.txt").write_text(path, encoding="utf-8")
    (root / "raw" / "end" / "preferred_apn.txt").write_text(f"Row: 0 apn={apn}\n", encoding="utf-8")
    if scenario == "dsds":
        registry = "phoneId=0 mImsRegistered=true\nphoneId=1 mImsRegistered=true\n"
        connectivity = "NetworkAgentInfo{ CELLULAR VALIDATED IMS MMTEL InterfaceName=ccmni2 }\n\nNetworkAgentInfo{ CELLULAR VALIDATED IMS MMTEL InterfaceName=ccmni3 }\n"
        phones = (0, 1)
    else:
        phone = 0 if scenario == "tray1" else 1
        registry = f"phoneId={phone} mImsRegistered=true\n" + ("mDefaultPhoneId=1\n" if scenario == "tray2" else "")
        connectivity = "NetworkAgentInfo{ CELLULAR VALIDATED IMS MMTEL InterfaceName=ccmni2 data=ccmni1 }\n"
        phones = (phone,)
    (root / "raw" / "end" / "telephony_registry.txt").write_text(registry, encoding="utf-8")
    (root / "raw" / "end" / "connectivity.txt").write_text(connectivity, encoding="utf-8")
    (root / "raw" / "end" / "mediatek_ims_services.txt").write_text("com.mediatek.ims running\n", encoding="utf-8")
    (root / "be2" / "redacted" / "logcat_stream.log").write_text(
        "ERROR_UNSPECIFIED rejectCause=27\nsetImsRegistrationState registered=true\n+CIREGU:1,f\nMtkProxyController SET_RADIO_CAPABILITY EVENT_UNSOL_RADIO_CAPABILITY_CHANGED DSSExt Default data phoneid = 1\n",
        encoding="utf-8",
    )
    with (root / "be2" / "redacted" / "timeline.tsv").open("w", encoding="utf-8", newline="") as fp:
        w = csv.DictWriter(fp, fieldnames=("device_time", "phone_id", "voice_reg", "data_reg", "data_conn"), delimiter="\t", lineterminator="\n")
        w.writeheader()
        for i in range(3):
            for phone in phones: w.writerow({"device_time": str(i), "phone_id": str(phone), "voice_reg": "IN_SERVICE", "data_reg": "IN_SERVICE", "data_conn": "CONNECTED"})


def _operator() -> dict[str, str]:
    out: dict[str, str] = {}
    for p in ("TRAY1", "TRAY2"):
        for k in ("DATA_USER_TEST", "SMS_SEND", "SMS_RECEIVE", "MMS_SEND", "MMS_RECEIVE", "OUTGOING_VOICE", "INCOMING_VOICE"):
            out[f"{p}_{k}"] = "PASS"
    for sim in ("SIM1", "SIM2"):
        out[f"DSDS_{sim}_DATA_AS_DDS"] = "PASS"
        for k in ("SMS_SEND", "SMS_RECEIVE", "MMS_SEND", "MMS_RECEIVE", "OUTGOING_VOICE", "INCOMING_VOICE"):
            out[f"DSDS_{sim}_{k}"] = "PASS"
    return out


def run_self_test() -> int:
    with tempfile.TemporaryDirectory() as td:
        base = pathlib.Path(td); roots = {s: base / s for s in SCENARIOS}; op = _operator()
        for s in SCENARIOS: _fixture(roots[s], s)
        results, _ = evaluate_all(roots["tray1"], roots["tray2"], roots["dsds"], op)
        assert all(v == "PASS" for r in results for v in r.markers.values())
        _fixture(roots["tray1"], "tray1", provider=False)
        r = evaluate_scenario(roots["tray1"], "tray1", op)
        assert r.markers["N1I_C1_TRAY1_REGISTRATION"] == "PASS" and r.markers["N1I_C1_TRAY1_DATA"] == "PASS" and r.markers["N1I_C1_TRAY1_IMS_PROVIDER"] == "FAIL"
        _fixture(roots["tray1"], "tray1"); op2 = dict(op); op2["TRAY1_OUTGOING_VOICE"] = "FAIL"
        r = evaluate_scenario(roots["tray1"], "tray1", op2)
        assert r.markers["N1I_C1_TRAY1_IMS_PROVIDER"] == "PASS" and r.markers["N1I_C1_TRAY1_IMS_REGISTRATION"] == "PASS" and r.markers["N1I_C1_TRAY1_IMS_BEARER"] == "PASS" and r.markers["N1I_C1_TRAY1_OUTGOING_VOICE"] == "FAIL"
        _fixture(roots["tray1"], "tray1", apn="example.apn"); r = evaluate_scenario(roots["tray1"], "tray1", op)
        assert r.markers["N1I_C1_TRAY1_DATA"] == "PASS" and r.stock["N1I_C1_TRAY1_STOCK_APN_TARGET"] == "FAIL"
        assert "ERROR_UNSPECIFIED" in text(roots["tray1"] / "be2" / "redacted" / "logcat_stream.log") and r.markers["N1I_C1_TRAY1_REGISTRATION"] == "PASS"
        assert not (roots["tray1"] / "raw" / "end" / "ims.txt").exists() and r.markers["N1I_C1_TRAY1_IMS_REGISTRATION"] == "PASS"
        _fixture(roots["dsds"], "dsds"); op3 = dict(op); op3["DSDS_SIM2_OUTGOING_VOICE"] = "FAIL"
        r = evaluate_scenario(roots["dsds"], "dsds", op3)
        assert r.internal["N1I_C1_DSDS_SIM1_OUTGOING_VOICE"] == "PASS" and r.internal["N1I_C1_DSDS_SIM2_OUTGOING_VOICE"] == "FAIL"
        assert r.markers["N1I_C1_DSDS_OUTGOING_VOICE"] == "FAIL" and r.markers["N1I_C1_DSDS_DATA"] == "PASS"
    print("N1I_C1_PHYSICAL_QUALIFIER_SELFTEST=PASS")
    return 0
