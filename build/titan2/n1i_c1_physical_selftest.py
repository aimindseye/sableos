from __future__ import annotations

import csv
import pathlib
import tempfile

from n1i_c1_physical_evidence import (
    SCENARIOS, ever_data_connected, expected_sim_state, ims_bearer_count,
    ims_registered_end_state, text,
)
from n1i_c1_physical_eval import evaluate_all, evaluate_scenario


def _fixture(
    root: pathlib.Path,
    scenario: str,
    *,
    apn: str = "fast.t-mobile.com",
    provider: bool = True,
) -> None:
    (root / "raw" / "end").mkdir(parents=True, exist_ok=True)
    (root / "be2" / "redacted").mkdir(parents=True, exist_ok=True)
    serial_hash = "1" * 64
    system_sha = "2" * 64
    summary = {
        "N1I_C1_PHYSICAL_COLLECTOR": "PASS",
        "SCENARIO": scenario,
        "N1I_C1_TOOL_SOURCE_COMMIT": "3" * 40,
        "N1I_C1_IMAGE_SOURCE_COMMIT": "a745c7daa08267d851f45785a5bb7ff762ed4604",
        "N1I_C1_SYSTEM_IMAGE_SHA256": system_sha,
        "N1I_C1_DEVICE_SERIAL_SHA256": serial_hash,
        "N1I_C1_DEVICE_SERIAL_BINDING": "PASS",
        "N1I_C1_SYSTEM_IMAGE_SHA_BINDING": "PASS",
        "N1I_C1_RUNTIME_DEVICE_IDENTITY": "PASS",
        "N1I_C1_READ_ONLY_CONTRACT": "PASS",
        "N1I_C1_DUMPSYS_IMS_STANDALONE_GATE": "DISABLED",
        "N1I_C1_PROPERTY_WRITE_COUNT": "0",
        "N1I_C1_RADIO_RESTART_COUNT_BY_COLLECTOR": "0",
        "N1I_C1_AIRPLANE_TOGGLE_COUNT_BY_COLLECTOR": "0",
        "N1I_C1_APN_EDIT_COUNT": "0",
        "N1I_C1_HEALING_ACTION_COUNT": "0",
    }
    (root / "N1I_C1_COLLECTOR_SUMMARY.env").write_text(
        "".join(f"{k}={v}\n" for k, v in summary.items()),
        encoding="utf-8",
    )
    binding = {
        "SCENARIO": scenario,
        "N1I_C1_IMAGE_SOURCE_COMMIT": summary["N1I_C1_IMAGE_SOURCE_COMMIT"],
        "N1I_C1_SYSTEM_IMAGE_SHA256": system_sha,
        "N1I_C1_DEVICE_SERIAL_SHA256": serial_hash,
        "N1I_C1_DEVICE_SERIAL_BINDING": "PASS",
        "N1I_C1_SYSTEM_IMAGE_SHA_BINDING": "PASS",
        "N1I_C1_RUNTIME_DEVICE_IDENTITY": "PASS",
    }
    (root / "N1I_C1_BINDING.env").write_text(
        "".join(f"{k}={v}\n" for k, v in binding.items()),
        encoding="utf-8",
    )
    (root / "be2" / "CELLULAR_RUNTIME_SUMMARY.env").write_text(
        "CELLULAR_RUNTIME_CAPTURE=COMPLETE\nREAD_ONLY=YES\nDEVICE_SETTINGS_CHANGED_BY_SCRIPT=NO\n",
        encoding="utf-8",
    )
    (root / "raw" / "end" / "getprop.txt").write_text(
        f"[gsm.sim.state]: [{expected_sim_state(scenario)}]\n",
        encoding="utf-8",
    )
    pkg = (
        "Package [com.mediatek.ims] sharedUserId=android.uid.phone "
        "pkgFlags=[ SYSTEM PRIVILEGED ]"
        if provider
        else "package missing"
    )
    path = "package:/system_ext/priv-app/ImsService/ImsService.apk\n" if provider else ""
    (root / "raw" / "end" / "mediatek_ims_package.txt").write_text(pkg, encoding="utf-8")
    (root / "raw" / "end" / "mediatek_ims_path.txt").write_text(path, encoding="utf-8")
    (root / "raw" / "end" / "preferred_apn.txt").write_text(
        f"Row: 0 apn={apn}\n",
        encoding="utf-8",
    )
    for slot in (0, 1):
        service = "com.mediatek.ims\n" if provider else ""
        (root / "raw" / "end" / f"ims_slot{slot}_device.txt").write_text(service, encoding="utf-8")
        (root / "raw" / "end" / f"ims_slot{slot}_carrier.txt").write_text(service, encoding="utf-8")

    if scenario == "dsds":
        registry = "phoneId=0 mImsRegistered=true\nphoneId=1 mImsRegistered=true\n"
        connectivity = (
            "NetworkAgentInfo{ CELLULAR CONNECTED VALIDATED IMS MMTEL InterfaceName=ccmni2 }\n\n"
            "NetworkAgentInfo{ CELLULAR CONNECTED VALIDATED IMS MMTEL InterfaceName=ccmni3 }\n"
        )
        phones = (0, 1)
    else:
        phone = 0 if scenario == "tray1" else 1
        registry = f"phoneId={phone} mImsRegistered=true\n"
        if scenario == "tray2":
            registry += "mDefaultPhoneId=1\n"
        connectivity = (
            "NetworkAgentInfo{ CELLULAR CONNECTED VALIDATED IMS MMTEL "
            "InterfaceName=ccmni2 data=ccmni1 }\n"
        )
        phones = (phone,)

    (root / "raw" / "end" / "telephony_registry.txt").write_text(registry, encoding="utf-8")
    (root / "raw" / "end" / "connectivity.txt").write_text(connectivity, encoding="utf-8")
    (root / "raw" / "end" / "mediatek_ims_services.txt").write_text(
        "com.mediatek.ims running\n",
        encoding="utf-8",
    )
    (root / "be2" / "redacted" / "logcat_stream.log").write_text(
        "ERROR_UNSPECIFIED rejectCause=27\n"
        "setImsRegistrationState registered=false\n"
        "setImsRegistrationState registered=true\n"
        "+CIREGU:1,f\n"
        "MtkProxyController SET_RADIO_CAPABILITY "
        "EVENT_UNSOL_RADIO_CAPABILITY_CHANGED DSSExt Default data phoneid = 1\n",
        encoding="utf-8",
    )
    # Mirror the collector: every snapshot stdout has a sibling return code.
    # The evaluator must ignore partial stdout from any command whose rc is nonzero.
    for snapshot in (root / "raw" / "end").glob("*.txt"):
        snapshot.with_suffix(".rc").write_text("0\n", encoding="utf-8")

    with (root / "be2" / "redacted" / "timeline.tsv").open(
        "w", encoding="utf-8", newline=""
    ) as fp:
        writer = csv.DictWriter(
            fp,
            fieldnames=("device_time", "phone_id", "voice_reg", "data_reg", "data_conn"),
            delimiter="\t",
            lineterminator="\n",
        )
        writer.writeheader()
        for i in range(3):
            for phone in phones:
                writer.writerow({
                    "device_time": str(i),
                    "phone_id": str(phone),
                    "voice_reg": "IN_SERVICE",
                    "data_reg": "IN_SERVICE",
                    "data_conn": "CONNECTED",
                })


def _operator() -> dict[str, str]:
    out: dict[str, str] = {}
    for prefix in ("TRAY1", "TRAY2"):
        for key in (
            "DATA_USER_TEST", "SMS_SEND", "SMS_RECEIVE", "MMS_SEND",
            "MMS_RECEIVE", "OUTGOING_VOICE", "INCOMING_VOICE",
        ):
            out[f"{prefix}_{key}"] = "PASS"
    for sim in ("SIM1", "SIM2"):
        out[f"DSDS_{sim}_DATA_AS_DDS"] = "PASS"
        for key in (
            "SMS_SEND", "SMS_RECEIVE", "MMS_SEND", "MMS_RECEIVE",
            "OUTGOING_VOICE", "INCOMING_VOICE",
        ):
            out[f"DSDS_{sim}_{key}"] = "PASS"
    return out


def run_self_test() -> int:
    with tempfile.TemporaryDirectory() as td:
        base = pathlib.Path(td)
        roots = {scenario: base / scenario for scenario in SCENARIOS}
        op = _operator()
        for scenario in SCENARIOS:
            _fixture(roots[scenario], scenario)

        results, _ = evaluate_all(roots["tray1"], roots["tray2"], roots["dsds"], op)
        assert all(v == "PASS" for result in results for v in result.markers.values())

        # Registration/data can pass while IMS provider independently fails.
        _fixture(roots["tray1"], "tray1", provider=False)
        result = evaluate_scenario(roots["tray1"], "tray1", op)
        assert result.markers["N1I_C1_TRAY1_REGISTRATION"] == "PASS"
        assert result.markers["N1I_C1_TRAY1_DATA"] == "PASS"
        assert result.markers["N1I_C1_TRAY1_IMS_PROVIDER"] == "FAIL"

        # Slot service exposure is part of provider acceptance.
        _fixture(roots["tray1"], "tray1")
        (roots["tray1"] / "raw" / "end" / "ims_slot0_device.txt").write_text("", encoding="utf-8")
        (roots["tray1"] / "raw" / "end" / "ims_slot0_carrier.txt").write_text("", encoding="utf-8")
        result = evaluate_scenario(roots["tray1"], "tray1", op)
        assert result.markers["N1I_C1_TRAY1_IMS_PROVIDER"] == "FAIL"

        # IMS success never masks a failed voice direction.
        _fixture(roots["tray1"], "tray1")
        op2 = dict(op)
        op2["TRAY1_OUTGOING_VOICE"] = "FAIL"
        result = evaluate_scenario(roots["tray1"], "tray1", op2)
        assert result.markers["N1I_C1_TRAY1_IMS_PROVIDER"] == "PASS"
        assert result.markers["N1I_C1_TRAY1_IMS_REGISTRATION"] == "PASS"
        assert result.markers["N1I_C1_TRAY1_IMS_BEARER"] == "PASS"
        assert result.markers["N1I_C1_TRAY1_OUTGOING_VOICE"] == "FAIL"

        # Functional data is independent of stock APN parity.
        _fixture(roots["tray1"], "tray1", apn="example.apn")
        result = evaluate_scenario(roots["tray1"], "tray1", op)
        assert result.markers["N1I_C1_TRAY1_DATA"] == "PASS"
        assert result.stock["N1I_C1_TRAY1_STOCK_APN_TARGET"] == "FAIL"

        # Known stock transients do not fail a recovered final state.
        assert "ERROR_UNSPECIFIED" in text(
            roots["tray1"] / "be2" / "redacted" / "logcat_stream.log"
        )
        assert result.markers["N1I_C1_TRAY1_REGISTRATION"] == "PASS"

        # Missing dumpsys ims remains irrelevant.
        assert not (roots["tray1"] / "raw" / "end" / "ims.txt").exists()
        assert result.markers["N1I_C1_TRAY1_IMS_REGISTRATION"] == "PASS"

        # Log fallback is end-state, not "any success ever".
        assert ims_registered_end_state(
            "", 0,
            "setImsRegistrationState registered=true\n"
            "setImsRegistrationState registered=false\n",
        ) is False

        # IMS/MMTEL bearer must be usable/connected, not merely named.
        assert ims_bearer_count(
            "NetworkAgentInfo{ CELLULAR IMS MMTEL InterfaceName=ccmni2 }"
        ) == 0

        # Snapshot stdout is not evidence unless the corresponding command
        # returned zero. Partial output from a failed command must not false-PASS
        # data, IMS bearer, or IMS provider surfaces.
        _fixture(roots["tray1"], "tray1")
        (roots["tray1"] / "raw" / "end" / "connectivity.rc").write_text(
            "1\n", encoding="utf-8"
        )
        result = evaluate_scenario(roots["tray1"], "tray1", op)
        assert result.markers["N1I_C1_TRAY1_DATA"] == "FAIL"
        assert result.markers["N1I_C1_TRAY1_IMS_BEARER"] == "FAIL"

        _fixture(roots["tray1"], "tray1")
        (roots["tray1"] / "raw" / "end" / "mediatek_ims_package.rc").write_text(
            "1\n", encoding="utf-8"
        )
        result = evaluate_scenario(roots["tray1"], "tray1", op)
        assert result.markers["N1I_C1_TRAY1_IMS_PROVIDER"] == "FAIL"

        # DSDS one-line failure cannot be masked.
        _fixture(roots["dsds"], "dsds")
        op3 = dict(op)
        op3["DSDS_SIM2_OUTGOING_VOICE"] = "FAIL"
        result = evaluate_scenario(roots["dsds"], "dsds", op3)
        assert result.internal["N1I_C1_DSDS_SIM1_OUTGOING_VOICE"] == "PASS"
        assert result.internal["N1I_C1_DSDS_SIM2_OUTGOING_VOICE"] == "FAIL"
        assert result.markers["N1I_C1_DSDS_OUTGOING_VOICE"] == "FAIL"
        assert result.markers["N1I_C1_DSDS_DATA"] == "PASS"

        # DSDS data requires observed connected service for each phone, not only
        # operator PASS flags.
        rows = [
            {"phone_id": "0", "voice_reg": "IN_SERVICE", "data_reg": "IN_SERVICE", "data_conn": "CONNECTED"},
            {"phone_id": "0", "voice_reg": "IN_SERVICE", "data_reg": "IN_SERVICE", "data_conn": "CONNECTED"},
            {"phone_id": "0", "voice_reg": "IN_SERVICE", "data_reg": "IN_SERVICE", "data_conn": "CONNECTED"},
            {"phone_id": "1", "voice_reg": "IN_SERVICE", "data_reg": "IN_SERVICE", "data_conn": "DISCONNECTED"},
            {"phone_id": "1", "voice_reg": "IN_SERVICE", "data_reg": "IN_SERVICE", "data_conn": "DISCONNECTED"},
            {"phone_id": "1", "voice_reg": "IN_SERVICE", "data_reg": "IN_SERVICE", "data_conn": "DISCONNECTED"},
        ]
        assert ever_data_connected(rows, 0)
        assert not ever_data_connected(rows, 1)

    print("N1I_C1_PHYSICAL_QUALIFIER_SELFTEST=PASS")
    return 0
